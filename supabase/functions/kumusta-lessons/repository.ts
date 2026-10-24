import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import {
  type GeneratedLessonDraft,
  hearRespondRoundIndexes,
  type LearnerProfileInput,
  legacyHearRespondRoundIndexes,
  lessonContractVersion,
  lessonPromptVersion,
  minimumSupportedLessonPromptVersion,
} from "./contract.ts";
import { HttpError } from "../_shared/http.ts";
import type { FamiliarLanguageInput } from "./prompt.ts";

export interface LearnerState {
  user_id: string;
  goal: string;
  self_assessed_level: string;
  estimated_level: number;
  target_level: number;
  challenge_preference: string;
  challenge_offset: number;
  speech_speed: string;
  skill_mastery: Record<string, number>;
  completed_lessons: number;
  state_version: number;
  next_topic_preference: string | null;
  next_topic_requested_at: string | null;
}

interface QueueRow {
  id: string;
  generated_lesson_id: string;
  status: string;
  priority: number;
}

interface GeneratedLessonRow {
  id: string;
  schema_version: number;
  prompt_version: number;
  model: string;
  difficulty: number;
  content: GeneratedLessonDraft;
}

export interface QueuedLesson {
  queue: QueueRow;
  generated: GeneratedLessonRow;
}

export async function ensureLearnerState(
  admin: SupabaseClient,
  userID: string,
  profile: LearnerProfileInput,
): Promise<LearnerState> {
  const { data: existing, error: readError } = await admin
    .from("kumusta_learner_states")
    .select("*")
    .eq("user_id", userID)
    .maybeSingle();
  if (readError) throw readError;

  const baseLevel = initialEstimatedLevel(profile.selfAssessedLevel);
  const mutation = existing
    ? {
      goal: profile.goal,
      self_assessed_level: profile.selfAssessedLevel,
      target_level: Math.max(profile.targetLevel, Math.ceil(Number(existing.estimated_level))),
      challenge_preference: profile.challengePreference,
    }
    : {
      user_id: userID,
      goal: profile.goal,
      self_assessed_level: profile.selfAssessedLevel,
      estimated_level: baseLevel,
      target_level: Math.max(profile.targetLevel, Math.ceil(baseLevel)),
      challenge_preference: profile.challengePreference,
    };

  const query = existing
    ? admin.from("kumusta_learner_states").update(mutation).eq("user_id", userID)
    : admin.from("kumusta_learner_states").upsert(mutation, { onConflict: "user_id" });
  const { data, error } = await query.select("*").single();
  if (error || !data) throw error ?? new Error("learner_state_unavailable");
  return normalizeState(data);
}

export async function fetchCurrentLesson(
  admin: SupabaseClient,
  userID: string,
  excludingLessonID: string | null = null,
  generatedAfter: string | null = null,
): Promise<QueuedLesson | null> {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    let selection = admin
      .from("kumusta_user_lesson_queue")
      .select(
        "id,generated_lesson_id,status,priority",
      )
      .eq("user_id", userID)
      .in("status", ["ready", "started"])
      .order("priority", { ascending: false })
      .order("assigned_at", { ascending: true })
      .limit(1);
    if (excludingLessonID) selection = selection.neq("generated_lesson_id", excludingLessonID);
    if (generatedAfter) selection = selection.gte("assigned_at", generatedAfter);
    const { data: queueRows, error: queueError } = await selection;
    if (queueError) throw queueError;
    const queue = (queueRows?.[0] ?? null) as QueueRow | null;
    if (!queue) return null;

    const { data: generated, error: lessonError } = await admin
      .from("kumusta_generated_lessons")
      .select("id,schema_version,prompt_version,model,difficulty,content")
      .eq("id", queue.generated_lesson_id)
      .eq("user_id", userID)
      .eq("status", "ready")
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (lessonError) throw lessonError;
    if (!generated) {
      await admin.from("kumusta_user_lesson_queue").update({
        status: "skipped",
        updated_at: new Date().toISOString(),
      }).eq(
        "id",
        queue.id,
      ).in("status", ["ready", "started"]);
      continue;
    }
    if (
      !isSupportedGeneratedLessonVersion(
        Number(generated.schema_version),
        Number(generated.prompt_version),
      )
    ) {
      await admin.from("kumusta_user_lesson_queue").update({
        status: "skipped",
        updated_at: new Date().toISOString(),
      }).eq(
        "id",
        queue.id,
      ).in("status", ["ready", "started"]);
      continue;
    }

    if (queue.status === "ready") {
      const { error } = await admin
        .from("kumusta_user_lesson_queue")
        .update({ status: "started", started_at: new Date().toISOString() })
        .eq("id", queue.id)
        .eq("user_id", userID)
        .eq("status", "ready");
      if (error) throw error;
      queue.status = "started";
    }
    return { queue, generated: generated as GeneratedLessonRow };
  }
  return null;
}

export function isSupportedGeneratedLessonVersion(
  schemaVersion: number,
  promptVersion: number,
): boolean {
  return schemaVersion === lessonContractVersion &&
    promptVersion >= minimumSupportedLessonPromptVersion &&
    promptVersion <= lessonPromptVersion;
}

export async function readyQueueDepth(
  admin: SupabaseClient,
  userID: string,
): Promise<number> {
  const { count, error } = await admin
    .from("kumusta_user_lesson_queue")
    .select(
      "id,lesson:kumusta_generated_lessons!kumusta_lesson_queue_lesson_owner_fk!inner(status,expires_at,schema_version,prompt_version)",
      { count: "exact", head: true },
    )
    .eq("user_id", userID)
    .eq("lesson.status", "ready")
    .gt("lesson.expires_at", new Date().toISOString())
    .eq("lesson.schema_version", lessonContractVersion)
    .gte("lesson.prompt_version", minimumSupportedLessonPromptVersion)
    .lte("lesson.prompt_version", lessonPromptVersion)
    .in("status", ["ready", "started"]);
  if (error) throw error;
  return count ?? 0;
}

export async function sweepStaleLessonQueue(admin: SupabaseClient, userID: string): Promise<void> {
  // Preserve the deployed stale-session cleanup without depending on an
  // out-of-band RPC that is missing from local migration history.
  const { error } = await admin.from("kumusta_user_lesson_queue")
    .update({ status: "skipped", updated_at: new Date().toISOString() })
    .eq("user_id", userID)
    .eq("status", "started")
    .lt("started_at", new Date(Date.now() - 30 * 60_000).toISOString());
  if (error) throw error;
}

export async function hasActiveGenerationJob(
  admin: SupabaseClient,
  userID: string,
): Promise<boolean> {
  const leaseThreshold = new Date(Date.now() - 180_000).toISOString();
  const { data, error } = await admin
    .from("kumusta_lesson_generation_jobs")
    .select("id")
    .eq("user_id", userID)
    .in("status", ["queued", "generating"])
    .gte("started_at", leaseThreshold)
    .limit(1);
  if (error) throw error;
  return (data?.length ?? 0) > 0;
}

export async function hasFailedGenerationSince(
  admin: SupabaseClient,
  userID: string,
  requestedAt: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("kumusta_lesson_generation_jobs")
    .select("error_code")
    .eq("user_id", userID)
    .eq("status", "failed")
    .gte("prompt_version", minimumSupportedLessonPromptVersion)
    .lte("prompt_version", lessonPromptVersion)
    .gte("created_at", requestedAt)
    .order("created_at", { ascending: false })
    .limit(8);
  if (error) throw error;
  return (data ?? []).some((row) => !isRetryableGenerationErrorCode(row.error_code));
}

export function isRetryableGenerationErrorCode(errorCode: unknown): boolean {
  return errorCode === "rate_limited" || errorCode === "quota_unavailable";
}

export async function generationQuotaBlock(
  admin: SupabaseClient,
  userID: string,
): Promise<{ code: string; retryAfterSeconds: number } | null> {
  const generationLimits = await lessonGenerationLimits(admin, userID);
  const limits = new Map<string, { limit: number; windowSeconds: number; code: string }>([
    [
      "lessons",
      { limit: generationLimits.minuteLimit, windowSeconds: 60, code: "generation_pacing_limit" },
    ],
    [
      "lessons_daily",
      {
        limit: generationLimits.dailyLimit,
        windowSeconds: 86_400,
        code: "generation_daily_limit",
      },
    ],
  ]);
  const { data, error } = await admin
    .from("kumusta_api_rate_limits")
    .select("scope,window_started_at,request_count")
    .eq("user_id", userID)
    .in("scope", [...limits.keys()]);
  if (error) throw error;

  const now = Date.now();
  const blocks = (data ?? []).flatMap((row) => {
    const rule = typeof row.scope === "string" ? limits.get(row.scope) : undefined;
    const startedAt = typeof row.window_started_at === "string"
      ? new Date(row.window_started_at).getTime()
      : Number.NaN;
    const requestCount = Number(row.request_count);
    if (
      !rule || !Number.isFinite(startedAt) || !Number.isFinite(requestCount) ||
      requestCount < rule.limit
    ) return [];
    const remainingMilliseconds = startedAt + rule.windowSeconds * 1_000 - now;
    if (remainingMilliseconds <= 0) return [];
    return [{
      code: rule.code,
      retryAfterSeconds: Math.max(1, Math.ceil(remainingMilliseconds / 1_000)),
    }];
  });
  return blocks.sort((left, right) => right.retryAfterSeconds - left.retryAfterSeconds)[0] ?? null;
}

export const lessonGenerationMinuteLimit = 4;
export const lessonGenerationDailyLimit = 30;
export const maximumPendingTopicAgeMilliseconds = 10 * 60 * 1_000;

export function isPendingTopicExpired(
  requestedAt: string | null,
  nowMilliseconds = Date.now(),
): boolean {
  if (!requestedAt) return true;
  const requestedAtMilliseconds = new Date(requestedAt).getTime();
  return !Number.isFinite(requestedAtMilliseconds) ||
    nowMilliseconds - requestedAtMilliseconds >= maximumPendingTopicAgeMilliseconds;
}

export async function lessonGenerationLimits(
  admin: SupabaseClient,
  userID: string,
): Promise<{ minuteLimit: number; dailyLimit: number }> {
  const defaults = {
    minuteLimit: lessonGenerationMinuteLimit,
    dailyLimit: lessonGenerationDailyLimit,
  };
  const { data, error } = await admin
    .from("kumusta_lesson_generation_quota_overrides")
    .select("minute_limit,daily_limit,expires_at")
    .eq("user_id", userID)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();
  if (error) throw error;

  const minuteLimit = Number(data?.minute_limit);
  const dailyLimit = Number(data?.daily_limit);
  if (
    !Number.isInteger(minuteLimit) || minuteLimit < defaults.minuteLimit ||
    !Number.isInteger(dailyLimit) || dailyLimit < defaults.dailyLimit
  ) {
    return defaults;
  }
  return { minuteLimit, dailyLimit };
}

export async function recentScenarioKeys(
  admin: SupabaseClient,
  userID: string,
): Promise<string[]> {
  const { data, error } = await admin
    .from("kumusta_generated_lessons")
    .select("scenario_key")
    .eq("user_id", userID)
    .order("created_at", { ascending: false })
    .limit(12);
  if (error) throw error;
  return (data ?? []).flatMap((row) =>
    typeof row.scenario_key === "string" ? [row.scenario_key] : []
  );
}

export async function familiarLanguageForPrompt(
  admin: SupabaseClient,
  userID: string,
): Promise<FamiliarLanguageInput> {
  const { data: queueRows, error: queueError } = await admin
    .from("kumusta_user_lesson_queue")
    .select("generated_lesson_id,completed_at")
    .eq("user_id", userID)
    .eq("status", "completed")
    .order("completed_at", { ascending: false })
    .limit(8);
  if (queueError) throw queueError;

  const lessonIDs = (queueRows ?? []).flatMap((row) =>
    typeof row.generated_lesson_id === "string" ? [row.generated_lesson_id] : []
  );
  if (lessonIDs.length === 0) return { vocabulary: [], chunks: [] };

  const { data: lessonRows, error: lessonError } = await admin
    .from("kumusta_generated_lessons")
    .select("id,content")
    .eq("user_id", userID)
    .in("id", lessonIDs);
  if (lessonError) throw lessonError;

  const contentByID = new Map(
    (lessonRows ?? []).flatMap((row) =>
      typeof row.id === "string" ? [[row.id, row.content] as const] : []
    ),
  );
  return extractFamiliarLanguage(
    lessonIDs.flatMap((lessonID) => contentByID.has(lessonID) ? [contentByID.get(lessonID)] : []),
  );
}

export function extractFamiliarLanguage(contents: unknown[]): FamiliarLanguageInput {
  const vocabulary: string[] = [];
  const chunks: string[] = [];
  const seenVocabulary = new Set<string>();
  const seenChunks = new Set<string>();

  for (const content of contents) {
    if (!isLanguageRecord(content)) continue;
    collectTagalogValues(content.vocabulary, vocabulary, seenVocabulary, 24);
    if (!Array.isArray(content.rounds)) continue;
    for (const round of content.rounds) {
      if (!isLanguageRecord(round)) continue;
      collectTagalogValues(round.chunks, chunks, seenChunks, 24);
    }
  }
  return { vocabulary, chunks };
}

function collectTagalogValues(
  values: unknown,
  output: string[],
  seen: Set<string>,
  limit: number,
): void {
  if (!Array.isArray(values) || output.length >= limit) return;
  for (const value of values) {
    if (!isLanguageRecord(value) || typeof value.tagalog !== "string") continue;
    const normalized = value.tagalog.trim().replace(/\s+/g, " ");
    const key = normalized.toLocaleLowerCase("fil");
    if (!normalized || seen.has(key)) continue;
    seen.add(key);
    output.push(normalized);
    if (output.length >= limit) return;
  }
}

function isLanguageRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export async function beginGenerationJob(
  admin: SupabaseClient,
  userID: string,
  requestID: string,
  trigger: string,
  count: number,
  state: LearnerState,
): Promise<string | null> {
  const { data, error } = await admin.rpc("kumusta_begin_lesson_generation_job", {
    p_user_id: userID,
    p_client_request_id: requestID,
    p_trigger: trigger,
    p_requested_count: count,
    p_learner_snapshot: state,
    p_prompt_version: lessonPromptVersion,
    p_lease_seconds: 180,
  });
  if (error) throw error;
  return typeof data === "string" ? data : null;
}

export async function finishGenerationJob(
  admin: SupabaseClient,
  jobID: string,
  status: "completed" | "failed",
  model: string | null,
  attemptCount: number,
  errorCode: string | null,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_lesson_generation_jobs")
    .update({
      status,
      model,
      attempt_count: attemptCount,
      error_code: errorCode,
      finished_at: new Date().toISOString(),
    })
    .eq("id", jobID);
  if (error) throw error;
}

export async function persistGeneratedLessons(
  admin: SupabaseClient,
  userID: string,
  jobID: string,
  model: string,
  lessons: GeneratedLessonDraft[],
  deliveryPriority = 0,
): Promise<number> {
  const prepared = await Promise.all(lessons.map(async (lesson) => ({
    schema_version: lessonContractVersion,
    prompt_version: lessonPromptVersion,
    difficulty: lesson.difficulty,
    scenario_key: lesson.scenarioKey,
    title: lesson.title,
    content: lesson,
    content_hash: await sha256Hex(JSON.stringify(lesson)),
    // This is a deterministic contract score, not a human or pedagogical
    // quality prediction. Every persisted lesson has passed every v1 gate.
    quality_score: 1,
    validation: {
      contract: "kumusta_lesson_v3",
      structured_output: true,
      local_validation: true,
      ordered_chunks: true,
      vocabulary_grounded: true,
      vocabulary_examples_grounded: true,
      prohibited_subject_filter: "v1",
    },
  })));
  const { data, error } = await admin.rpc("kumusta_persist_generated_lesson_batch", {
    p_user_id: userID,
    p_job_id: jobID,
    p_model: model,
    p_lessons: prepared,
  });
  if (error) throw error;
  const inserted = Number(data);
  if (!Number.isInteger(inserted) || inserted < 0 || inserted > lessons.length) {
    throw new Error("generated_lesson_persistence_invalid");
  }
  if (inserted > 0 && deliveryPriority > 0) {
    const { data: generatedRows, error: generatedError } = await admin
      .from("kumusta_generated_lessons")
      .select("id")
      .eq("user_id", userID)
      .eq("generation_job_id", jobID);
    if (generatedError) throw generatedError;
    const generatedLessonIDs = (generatedRows ?? []).flatMap((row) =>
      typeof row.id === "string" ? [row.id] : []
    );
    if (generatedLessonIDs.length > 0) {
      const { error: priorityError } = await admin
        .from("kumusta_user_lesson_queue")
        .update({ priority: Math.min(100, Math.max(0, deliveryPriority)) })
        .eq("user_id", userID)
        .in("generated_lesson_id", generatedLessonIDs)
        .eq("status", "ready");
      if (priorityError) throw priorityError;
    }
  }
  return inserted;
}

export async function setNextTopicPreference(
  admin: SupabaseClient,
  userID: string,
  topicPreference: string,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_learner_states")
    .update({
      next_topic_preference: topicPreference,
      next_topic_requested_at: new Date().toISOString(),
    })
    .eq("user_id", userID);
  if (error) throw error;
}

export async function clearNextTopicPreference(
  admin: SupabaseClient,
  userID: string,
  expectedTopicPreference: string,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_learner_states")
    .update({
      next_topic_preference: null,
      next_topic_requested_at: null,
    })
    .eq("user_id", userID)
    .eq("next_topic_preference", expectedTopicPreference);
  if (error) throw error;
}

/**
 * A topic request is a replacement for any older explicit request still
 * waiting in the queue. Keep generic lessons available, but remove the old
 * request priority so the newly generated topic is the only priority item.
 */
export async function demoteOlderTopicLessons(
  admin: SupabaseClient,
  userID: string,
): Promise<void> {
  const { error } = await admin
    .from("kumusta_user_lesson_queue")
    .update({ priority: 0 })
    .eq("user_id", userID)
    .eq("status", "ready")
    .gt("priority", 0);
  if (error) throw error;
}

export async function assertGeneratedCompletionOwnership(
  admin: SupabaseClient,
  userID: string,
  generatedLessonID: string | null,
): Promise<void> {
  if (!generatedLessonID) return;
  const { data, error } = await admin
    .from("kumusta_user_lesson_queue")
    .select("id")
    .eq("user_id", userID)
    .eq("generated_lesson_id", generatedLessonID)
    .in("status", [...completionOwnedQueueStatuses])
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    throw new HttpError(
      409,
      "invalid_lesson_completion",
      "This lesson is not available for completion.",
    );
  }
}

// A replay can legitimately ask for another lesson after its queue row has
// already been completed. The completion RPC is idempotent for that row, so
// accepting it here preserves the new topic request without double-counting
// learner progress.
export const completionOwnedQueueStatuses = ["ready", "started", "completed"] as const;

export async function hasRecordedDifficultyFeedbackEvent(
  admin: SupabaseClient,
  userID: string,
  clientEventID: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("kumusta_difficulty_feedback")
    .select("id")
    .eq("user_id", userID)
    .eq("client_event_id", clientEventID)
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data !== null;
}

export async function assertGeneratedVocabularyMembership(
  admin: SupabaseClient,
  userID: string,
  generatedLessonID: string,
  vocabularyID: string,
): Promise<void> {
  const { data, error } = await admin
    .from("kumusta_generated_lessons")
    .select("content")
    .eq("id", generatedLessonID)
    .eq("user_id", userID)
    .eq("status", "ready")
    .maybeSingle();
  if (error) throw error;
  const vocabulary = isRecord(data?.content) && Array.isArray(data.content.vocabulary)
    ? data.content.vocabulary
    : null;
  if (!vocabulary) {
    throw new HttpError(400, "invalid_vocabulary_reference", "The word is not available.");
  }
  if (!await isGeneratedVocabularyID(generatedLessonID, vocabularyID, vocabulary.length)) {
    throw new HttpError(400, "invalid_vocabulary_reference", "The word is not available.");
  }
}

export async function isGeneratedVocabularyID(
  generatedLessonID: string,
  vocabularyID: string,
  vocabularyCount: number,
): Promise<boolean> {
  if (!Number.isInteger(vocabularyCount) || vocabularyCount < 1 || vocabularyCount > 18) {
    return false;
  }
  const expectedIDs = await Promise.all(
    Array.from(
      { length: vocabularyCount },
      (_, index) => deterministicUUID(`${generatedLessonID}:vocabulary:${index}`),
    ),
  );
  return expectedIDs.includes(vocabularyID.toLowerCase());
}

export async function recordFeedback(
  admin: SupabaseClient,
  userID: string,
  input: {
    clientEventID: string;
    generatedLessonID: string | null;
    context: string;
    feedback: string;
    stepKind: string | null;
    paceFeedback: string | null;
    markComplete: boolean;
  },
): Promise<Record<string, unknown>> {
  const { data, error } = await admin.rpc("kumusta_record_difficulty_feedback", {
    p_user_id: userID,
    p_client_event_id: input.clientEventID,
    p_generated_lesson_id: input.generatedLessonID,
    p_context: input.context,
    p_rating: input.feedback,
    p_step_kind: input.stepKind,
    p_pace_rating: input.paceFeedback,
    p_mark_complete: input.markComplete,
  });
  if (error || data === null || typeof data !== "object") {
    throw error ?? new Error("feedback_unavailable");
  }
  return data as Record<string, unknown>;
}

export async function recordGeneratedVocabularyReview(
  admin: SupabaseClient,
  userID: string,
  input: {
    clientEventID: string;
    generatedLessonID: string;
    vocabularyID: string;
    rating: string;
  },
): Promise<Record<string, unknown>> {
  const { data, error } = await admin.rpc("kumusta_record_generated_vocabulary_review", {
    p_user_id: userID,
    p_generated_lesson_id: input.generatedLessonID,
    p_vocabulary_id: input.vocabularyID,
    p_client_event_id: input.clientEventID,
    p_rating: input.rating,
  });
  if (error || data === null || typeof data !== "object") {
    throw error ?? new Error("generated_vocabulary_review_unavailable");
  }
  return data as Record<string, unknown>;
}

export function publicLearnerState(
  state: LearnerState | Record<string, unknown>,
): Record<string, unknown> {
  return {
    estimated_level: Number(state.estimated_level),
    target_level: Number(state.target_level),
    challenge_offset: Number(state.challenge_offset),
    speech_speed: state.speech_speed,
    skill_mastery: state.skill_mastery,
    completed_lessons: Number(state.completed_lessons),
    state_version: Number(state.state_version),
  };
}

export async function presentQueuedLesson(
  admin: SupabaseClient,
  userID: string,
  queued: QueuedLesson,
  clientMaxPromptVersion: number,
): Promise<Record<string, unknown>> {
  const lesson = queued.generated.content;
  const presentedPromptVersion = negotiatedLessonPromptVersion(
    queued.generated.prompt_version,
    clientMaxPromptVersion,
  );
  const vocabulary = await Promise.all(lesson.vocabulary.map(async (item, index) => ({
    id: await deterministicUUID(`${queued.generated.id}:vocabulary:${index}`),
    tagalog: item.tagalog,
    english: item.english,
    example: item.example,
    example_translation: item.exampleTranslation,
  })));
  const vocabularyIDs = vocabulary.map((item) => item.id);
  const { data: progressRows, error: progressError } = await admin
    .from("kumusta_generated_vocabulary_progress")
    .select("vocabulary_id,mastery,due_at")
    .eq("user_id", userID)
    .eq("generated_lesson_id", queued.generated.id)
    .in("vocabulary_id", vocabularyIDs);
  if (progressError) throw progressError;
  const hydratedVocabulary = hydrateGeneratedVocabularyProgress(
    vocabulary,
    progressRows ?? [],
  );

  return {
    id: queued.generated.id,
    queue_entry_id: queued.queue.id,
    queue_priority: Math.max(0, Number(queued.queue.priority) || 0),
    schema_version: queued.generated.schema_version,
    prompt_version: presentedPromptVersion,
    model: queued.generated.model,
    source: "generated",
    title: lesson.title,
    scenario: lesson.scenario,
    minutes: lesson.minutes,
    difficulty: Number(queued.generated.difficulty),
    steps: await Promise.all(
      lesson.rounds.flatMap((round, roundIndex) => {
        const stages = ["coldListen", "decode", "speak"] as const;
        const responseRoundIndexes = presentedPromptVersion >= 13
          ? hearRespondRoundIndexes(lesson.rounds.length)
          : presentedPromptVersion >= 11
          ? legacyHearRespondRoundIndexes(lesson.rounds.length)
          : [];
        return stages.map((stageKind, stageIndex) => ({
          round,
          roundIndex,
          stageIndex,
          kind: stageIndex === 1 && round.responseExercise !== undefined &&
              responseRoundIndexes.includes(roundIndex)
            ? "hearRespond" as const
            : stageKind,
        }));
      }).map(async ({ round, roundIndex, kind, stageIndex }) => {
        const response = kind === "hearRespond" ? round.responseExercise : undefined;
        const responseOptions = response
          ? await Promise.all(response.options.map(async (option, optionIndex) => ({
            id: await deterministicUUID(
              `${queued.generated.id}:round:${roundIndex}:response-option:${optionIndex}`,
            ),
            english_translation: option.englishTranslation,
          })))
          : [];
        const correctOptionID = response
          ? responseOptions[response.correctOptionIndex]?.id
          : undefined;

        return {
          id: await deterministicUUID(
            `${queued.generated.id}:round:${roundIndex}:stage:${stageIndex}`,
          ),
          kind,
          prompt: kind === "coldListen"
            ? round.situation
            : kind === "speak"
            ? round.speakingPrompt
            : "Listen to the audio, then choose the matching meaning.",
          tagalog: round.tagalog,
          translation: round.translation,
          chunks: await Promise.all(round.chunks.map(async (chunk, chunkIndex) => ({
            id: await deterministicUUID(
              `${queued.generated.id}:round:${roundIndex}:stage:${stageIndex}:chunk:${chunkIndex}`,
            ),
            tagalog: chunk.tagalog,
            english: chunk.english,
            note: chunk.note,
          }))),
          word_glosses: await Promise.all(
            round.wordGlosses.map(async (gloss, glossIndex) => ({
              id: await deterministicUUID(
                `${queued.generated.id}:round:${roundIndex}:stage:${stageIndex}:gloss:${glossIndex}`,
              ),
              token: gloss.token,
              translation: gloss.english,
            })),
          ),
          ...(response && correctOptionID
            ? {
              hear_respond: {
                prompt_tagalog: response.promptTagalog,
                prompt_translation: response.promptTranslation,
                options: responseOptions,
                correct_option_id: correctOptionID,
              },
            }
            : {}),
        };
      }),
    ),
    vocabulary: hydratedVocabulary,
  };
}

/**
 * Lessons remain generated and stored with the latest prompt. Builds released
 * before capability negotiation receive the stable v10 decode-only projection,
 * which is understood by the production 1.0.4 app.
 */
export function negotiatedLessonPromptVersion(
  storedPromptVersion: number,
  clientMaxPromptVersion: number,
): number {
  return clientMaxPromptVersion >= lessonPromptVersion ? storedPromptVersion : 10;
}

export function hydrateGeneratedVocabularyProgress(
  vocabulary: Array<Record<string, unknown> & { id: string }>,
  progressRows: Array<Record<string, unknown>>,
): Array<Record<string, unknown>> {
  const progressByVocabularyID = new Map(
    progressRows.flatMap((row) =>
      typeof row.vocabulary_id === "string" ? [[row.vocabulary_id.toLowerCase(), row]] : []
    ),
  );
  return vocabulary.map((item) => {
    const progress = progressByVocabularyID.get(item.id.toLowerCase());
    const mastery = Number(progress?.mastery);
    return {
      ...item,
      mastery: Number.isFinite(mastery) && mastery >= 0 && mastery <= 1 ? mastery : 0.05,
      due_at: typeof progress?.due_at === "string" ? progress.due_at : null,
    };
  });
}

function normalizeState(value: Record<string, unknown>): LearnerState {
  const rawMastery = value.skill_mastery;
  const mastery =
    rawMastery !== null && typeof rawMastery === "object" && !Array.isArray(rawMastery)
      ? rawMastery as Record<string, number>
      : {};
  return {
    user_id: String(value.user_id),
    goal: String(value.goal),
    self_assessed_level: String(value.self_assessed_level),
    estimated_level: Number(value.estimated_level),
    target_level: Number(value.target_level),
    challenge_preference: String(value.challenge_preference),
    challenge_offset: Number(value.challenge_offset),
    speech_speed: String(value.speech_speed),
    skill_mastery: mastery,
    completed_lessons: Number(value.completed_lessons),
    state_version: Number(value.state_version),
    next_topic_preference: typeof value.next_topic_preference === "string"
      ? value.next_topic_preference
      : null,
    next_topic_requested_at: typeof value.next_topic_requested_at === "string"
      ? value.next_topic_requested_at
      : null,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function initialEstimatedLevel(level: string): number {
  switch (level) {
    case "beginner":
      return 1;
    case "intermediate":
      return 2.25;
    case "advanced":
      return 3.25;
    default:
      return 1;
  }
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function deterministicUUID(value: string): Promise<string> {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  ).slice(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${
    hex.slice(20)
  }`;
}
