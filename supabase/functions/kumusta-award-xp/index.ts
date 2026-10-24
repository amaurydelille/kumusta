/// <reference lib="deno.ns" />

import { createAdminClient, requireAuthenticatedUser } from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  HttpError,
  isPlainObject,
  jsonResponse,
  readJSONBody,
  requestID,
} from "../_shared/http.ts";

const maximumRequestBytes = 12_000;

Deno.serve(async (req: Request) => {
  const id = requestID(req);

  try {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (req.method !== "POST") {
      throw new HttpError(405, "method_not_allowed", "Use POST.");
    }

    const input = await readJSONBody(req, maximumRequestBytes);
    const context = await requireAuthenticatedUser(req);
    const reasonCode = parseReasonCode(input.reason_code);
    const sourceID = parseOptionalText(input.source_id, "source_id", 200);
    const idempotencyKey = parseText(input.idempotency_key, "idempotency_key", 200);
    const metadata = parseMetadata(input.metadata);
    await validateCompletedSource(context.admin, context.userID, reasonCode, sourceID);

    const { data, error } = await context.admin.rpc("kumusta_award_xp", {
      p_user_id: context.userID,
      p_reason_code: reasonCode,
      p_source_id: sourceID,
      p_idempotency_key: idempotencyKey,
      p_metadata: metadata,
    });
    if (error) {
      console.error("xp_award_failed", { request_id: id, code: error.code });
      throw new HttpError(422, "xp_award_rejected", "This XP award could not be applied.");
    }

    const result = Array.isArray(data) ? data[0] : data;
    if (!result || typeof result !== "object") {
      throw new HttpError(503, "xp_award_invalid_response", "Please try again shortly.");
    }

    return jsonResponse(200, result, id);
  } catch (error) {
    return errorResponse(error, id);
  }
});

function parseReasonCode(value: unknown): string {
  const text = parseText(value, "reason_code", 80).toLowerCase();
  if (!/^[a-z][a-z0-9_]{2,79}$/.test(text)) {
    throw new HttpError(400, "invalid_reason_code", "The XP reason is invalid.");
  }
  return text;
}

async function validateCompletedSource(
  admin: ReturnType<typeof createAdminClient>,
  userID: string,
  reasonCode: string,
  sourceID: string | null,
): Promise<void> {
  if (!sourceID || !/^[0-9a-f-]{36}$/i.test(sourceID)) {
    if (!reasonCode.startsWith("achievement_")) {
      throw new HttpError(422, "invalid_xp_source", "This XP source is invalid.");
    }
  }

  if (reasonCode.startsWith("achievement_")) {
    const achievementID = reasonCode.slice("achievement_".length);
    if (!/^[a-z][a-z0-9_]{2,49}$/.test(achievementID) || sourceID !== achievementID) {
      throw new HttpError(422, "invalid_achievement", "This achievement is invalid.");
    }

    const { data, error } = await admin
      .from("kumusta_user_state")
      .select("state")
      .eq("user_id", userID)
      .maybeSingle();
    if (error) {
      console.error("achievement_state_validation_failed", { code: error.code });
      throw new HttpError(503, "achievement_state_unavailable", "Please try again shortly.");
    }

    const state = isPlainObject(data?.state) ? data.state : null;
    const achievements = state?.achievements;
    const hasAchievement = Array.isArray(achievements) &&
      achievements.some((achievement) =>
        isPlainObject(achievement) && achievement.kind === achievementID
      );
    if (!hasAchievement) {
      throw new HttpError(
        409,
        "achievement_not_synced",
        "Unlock the achievement before claiming its XP.",
      );
    }
    return;
  }

  const sourceTable = reasonCode === "lesson_completed"
    ? "kumusta_learning_sessions"
    : reasonCode === "vocabulary_flashcard_session_completed"
    ? "kumusta_flashcard_sessions"
    : null;

  if (!sourceTable) {
    throw new HttpError(422, "invalid_xp_reason", "This XP reason is not available.");
  }

  const query = admin
    .from(sourceTable)
    .select("id")
    .eq("id", sourceID)
    .eq("user_id", userID);

  const { data, error } = await query.eq("completed", true).maybeSingle();

  if (error) {
    console.error("xp_source_validation_failed", { code: error.code });
    throw new HttpError(503, "xp_source_unavailable", "Please try again shortly.");
  }
  if (!data) {
    throw new HttpError(409, "xp_source_incomplete", "Complete the activity before claiming XP.");
  }
}

function parseText(value: unknown, field: string, maximumLength: number): string {
  if (typeof value !== "string") {
    throw new HttpError(400, "invalid_request", `${field} must be text.`);
  }
  const text = value.trim();
  if (text.length < 1 || text.length > maximumLength) {
    throw new HttpError(400, "invalid_request", `${field} is invalid.`);
  }
  return text;
}

function parseOptionalText(
  value: unknown,
  field: string,
  maximumLength: number,
): string | null {
  if (value === undefined || value === null) return null;
  return parseText(value, field, maximumLength);
}

function parseMetadata(value: unknown): Record<string, unknown> {
  if (value === undefined) return {};
  if (!isPlainObject(value)) {
    throw new HttpError(400, "invalid_metadata", "metadata must be an object.");
  }
  if (new TextEncoder().encode(JSON.stringify(value)).byteLength > 8_000) {
    throw new HttpError(400, "invalid_metadata", "metadata is too large.");
  }
  return value;
}
