import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { HttpError } from "../_shared/http.ts";
import {
  contextFrom,
  endReasonFrom,
  sessionIDFrom,
  type TranscriptEntry,
  transcriptFrom,
} from "./coaching.ts";
import { PIPELINE_ENGINE_LABEL } from "./contract.ts";

type Admin = SupabaseClient;

/**
 * The pipeline has no daily allowance. A session is still bounded (the
 * table allows at most an hour per reservation) and the learner can start
 * another right away; starts per day are capped against abuse only.
 */
export const SESSION_SECONDS = 3600;
export const DAILY_START_LIMIT = 200;
/** `kumusta_live_rounds.used_seconds` is capped by a check constraint. */
const ROUND_SECONDS_CAP = 3600;

type OpenSession = {
  id: string;
  round_id: string | null;
  reserved_seconds: number;
  started_at: string | null;
};

const unavailable = () =>
  new HttpError(503, "usage_unavailable", "Your practice could not be loaded. Please retry.");

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export function allowance(available: boolean) {
  return {
    daily_limit_seconds: null,
    remaining_seconds: SESSION_SECONDS,
    resets_at: new Date(Date.parse(today()) + 86_400_000).toISOString(),
    available,
  };
}

export async function start(admin: Admin, userID: string, body: Record<string, unknown>) {
  let context: ReturnType<typeof contextFrom>;
  try {
    context = contextFrom(body);
  } catch {
    throw new HttpError(
      400,
      "invalid_context",
      "Your conversation couldn’t start. Please try again.",
    );
  }
  // One conversation at a time: a session the app never closed (killed,
  // crashed) is settled from the wall clock before the next one starts.
  await settleOpen(admin, userID);
  const day = today();
  const { count, error: countError } = await admin.from("kumusta_live_sessions")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userID)
    .eq("usage_day", day);
  if (countError) throw unavailable();
  if ((count ?? 0) >= DAILY_START_LIMIT) {
    throw new HttpError(
      429,
      "start_limit",
      "You’ve started a lot of conversations today. Try again tomorrow.",
    );
  }
  const round = await dailyRound(admin, userID, day, context);
  const now = new Date();
  const { data: session, error } = await admin.from("kumusta_live_sessions").insert({
    user_id: userID,
    usage_day: day,
    round_id: round.id,
    expires_at: new Date(now.getTime() + (SESSION_SECONDS + 20) * 1000).toISOString(),
    reserved_seconds: SESSION_SECONDS,
    charged_seconds: 0,
    topic_source: context.source,
    topic: context.topic,
    latest_lesson: context.lesson,
    model: PIPELINE_ENGINE_LABEL,
    // The conversation starts as soon as the reservation exists.
    started_at: now.toISOString(),
  }).select("id").single();
  if (error || !session) throw unavailable();
  await admin.from("kumusta_live_rounds")
    .update({
      session_count: round.session_count + 1,
      model: PIPELINE_ENGINE_LABEL,
      updated_at: now.toISOString(),
    })
    .eq("id", round.id);
  return { session_id: session.id as string, seconds: SESSION_SECONDS };
}

async function dailyRound(
  admin: Admin,
  userID: string,
  day: string,
  context: ReturnType<typeof contextFrom>,
): Promise<{ id: string; session_count: number }> {
  const find = () =>
    admin.from("kumusta_live_rounds")
      .select("id, session_count")
      .eq("user_id", userID)
      .eq("usage_day", day)
      .maybeSingle();
  const existing = await find();
  if (existing.error) throw unavailable();
  if (existing.data) return existing.data;
  const { data, error } = await admin.from("kumusta_live_rounds").insert({
    user_id: userID,
    usage_day: day,
    topic_source: context.source,
    topic: context.topic,
    latest_lesson: context.lesson,
    model: PIPELINE_ENGINE_LABEL,
  }).select("id, session_count").single();
  if (data) return data;
  // A concurrent start created today's round first.
  const retried = await find();
  if (error && !retried.data) throw unavailable();
  return retried.data!;
}

export async function finish(admin: Admin, userID: string, body: Record<string, unknown>) {
  let sessionID: string;
  try {
    sessionID = sessionIDFrom(body.session_id);
  } catch {
    throw new HttpError(400, "invalid_session", "This conversation could not be found.");
  }
  const { data, error } = await admin.from("kumusta_live_sessions")
    .select("id, round_id, reserved_seconds, started_at")
    .eq("id", sessionID)
    .eq("user_id", userID)
    .is("ended_at", null)
    .maybeSingle();
  if (error) throw unavailable();
  if (!data) return { seconds: 0, already_settled: true };
  const mutes = typeof body.mutes === "number" && Number.isFinite(body.mutes)
    ? Math.min(10_000, Math.max(0, Math.round(body.mutes)))
    : 0;
  const seconds = await settle(
    admin,
    data as OpenSession,
    endReasonFrom(body.reason),
    transcriptFrom(body.transcript),
    mutes,
  );
  return { seconds };
}

/** Settles every session of the learner the app left open. */
export async function settleOpen(admin: Admin, userID: string) {
  const { data, error } = await admin.from("kumusta_live_sessions")
    .select("id, round_id, reserved_seconds, started_at")
    .eq("user_id", userID)
    .is("ended_at", null)
    .limit(5);
  if (error) throw unavailable();
  for (const session of (data ?? []) as OpenSession[]) {
    await settle(admin, session, "abandoned", [], 0);
  }
}

function elapsedSeconds(session: OpenSession): number {
  const started = session.started_at ? Date.parse(session.started_at) : NaN;
  if (!Number.isFinite(started)) return 0;
  return Math.max(0, Math.min(session.reserved_seconds, Math.ceil((Date.now() - started) / 1000)));
}

async function settle(
  admin: Admin,
  session: OpenSession,
  reason: string,
  transcript: TranscriptEntry[],
  mutes: number,
): Promise<number> {
  const seconds = elapsedSeconds(session);
  const userFragments = transcript.filter((entry) => entry.speaker === "user").length;
  const assistantFragments = transcript.length - userFragments;
  if (session.round_id && transcript.length > 0) {
    const { error } = await admin.from("kumusta_live_transcripts").insert(
      transcript.map((entry) => ({
        round_id: session.round_id,
        session_id: session.id,
        speaker: entry.speaker,
        text: entry.text,
        start_ms: entry.start_ms,
        end_ms: null,
      })),
    );
    if (error) {
      console.error("live_pipeline_transcript_write_failed", {
        session_id: session.id,
        code: error.code,
      });
    }
  }
  const { data: closed, error } = await admin.from("kumusta_live_sessions")
    .update({
      ended_at: new Date().toISOString(),
      charged_seconds: seconds,
      usage_confirmed: true,
      end_reason: reason.slice(0, 80),
      user_fragments: userFragments,
      assistant_fragments: assistantFragments,
      mute_count: mutes,
    })
    .eq("id", session.id)
    .is("ended_at", null)
    .select("id");
  if (error) throw unavailable();
  // Already settled by a concurrent request: count its time only once.
  if (!closed?.length || !session.round_id) return seconds;
  const { data: round } = await admin.from("kumusta_live_rounds")
    .select("used_seconds, user_fragments, assistant_fragments, mute_count")
    .eq("id", session.round_id)
    .maybeSingle();
  if (round) {
    await admin.from("kumusta_live_rounds").update({
      used_seconds: Math.min(ROUND_SECONDS_CAP, round.used_seconds + seconds),
      user_fragments: round.user_fragments + userFragments,
      assistant_fragments: round.assistant_fragments + assistantFragments,
      mute_count: round.mute_count + mutes,
      updated_at: new Date().toISOString(),
    }).eq("id", session.round_id);
  }
  return seconds;
}
