/// <reference lib="deno.ns" />

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
};

import {
  consumeQuota,
  requireActiveEntitlement,
  requireAuthenticatedUser,
} from "../_shared/auth.ts";
import {
  corsHeaders,
  errorResponse,
  HttpError,
  jsonResponse,
  readJSONBody,
  requestID,
  requiredEnv,
} from "../_shared/http.ts";
import { lessonContractVersion, parseLessonEngineRequest, targetQueueDepth } from "./contract.ts";
import { generateLessonBatch } from "./provider.ts";
import {
  assertGeneratedCompletionOwnership,
  assertGeneratedVocabularyMembership,
  beginGenerationJob,
  clearNextTopicPreference,
  demoteOlderTopicLessons,
  ensureLearnerState,
  familiarLanguageForPrompt,
  fetchCurrentLesson,
  finishGenerationJob,
  generationQuotaBlock,
  hasActiveGenerationJob,
  hasFailedGenerationSince,
  hasRecordedDifficultyFeedbackEvent,
  isPendingTopicExpired,
  type LearnerState,
  lessonGenerationLimits,
  persistGeneratedLessons,
  presentQueuedLesson,
  publicLearnerState,
  readyQueueDepth,
  recentScenarioKeys,
  recordFeedback,
  recordGeneratedVocabularyReview,
  setNextTopicPreference,
  sweepStaleLessonQueue,
} from "./repository.ts";

Deno.serve(async (req: Request) => {
  const id = requestID(req);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") {
    return errorResponse(new HttpError(405, "method_not_allowed", "Use POST."), id);
  }

  try {
    const context = await requireAuthenticatedUser(req, { allowAnonymous: true });
    const input = parseLessonEngineRequest(await readJSONBody(req, 8_192));
    if (input.action !== "get_next" && input.action !== "retry_generation") {
      await consumeQuota(
        context.admin,
        context.userID,
        "lessons_mutation",
        120,
        60,
      );
      await consumeQuota(
        context.admin,
        context.userID,
        "lessons_mutation_daily",
        2_000,
        86_400,
      );
    }
    let state = await ensureLearnerState(context.admin, context.userID, input.profile);
    // The server-owned preference may differ from a stale client snapshot.
    // Carry the effective accent through every queue and generation operation
    // so lesson text and its later TTS request cannot drift apart.
    const effectiveProfile = {
      ...input.profile,
      accent: state.accent as "southern" | "northern",
    };

    if (input.action === "review_word") {
      await assertGeneratedVocabularyMembership(
        context.admin,
        context.userID,
        input.generatedLessonID,
        input.vocabularyID,
      );
      const review = await recordGeneratedVocabularyReview(context.admin, context.userID, {
        clientEventID: input.clientEventID,
        generatedLessonID: input.generatedLessonID,
        vocabularyID: input.vocabularyID,
        rating: input.rating,
      });
      return jsonResponse(200, {
        version: lessonContractVersion,
        ...review,
      }, id);
    }

    if (input.action === "request_generation") {
      await requireActiveEntitlement(context.admin, context.userID);
      await assertGenerationAvailable(context.admin, context.userID);
      const isRecordedRequest = await hasRecordedDifficultyFeedbackEvent(
        context.admin,
        context.userID,
        input.clientEventID,
      );
      const updated = isRecordedRequest
        ? state
        : await recordFeedback(context.admin, context.userID, {
          clientEventID: input.clientEventID,
          generatedLessonID: input.generatedLessonID,
          context: "lesson",
          feedback: input.feedback,
          stepKind: null,
          paceFeedback: input.paceFeedback,
          markComplete: false,
        });
      state = { ...state, ...updated } as LearnerState;

      if (input.topicPreference) {
        await demoteOlderTopicLessons(context.admin, context.userID);
        await setNextTopicPreference(context.admin, context.userID, input.topicPreference);
        state = {
          ...state,
          next_topic_preference: input.topicPreference,
          next_topic_requested_at: new Date().toISOString(),
        };
      } else {
        if (state.next_topic_preference) {
          await clearNextTopicPreference(
            context.admin,
            context.userID,
            state.next_topic_preference,
          );
        }
        state = {
          ...state,
          next_topic_preference: null,
          next_topic_requested_at: null,
        };
      }

      scheduleBackground("manual_lesson_generation", id, () =>
        replenishQueue(
          context.admin,
          context.userID,
          input.requestID,
          "manual_refresh",
          state,
          effectiveProfile,
          input.topicPreference,
          true,
        ));
      return jsonResponse(200, {
        version: lessonContractVersion,
        accepted: true,
        queue_depth: await readyQueueDepth(context.admin, context.userID, effectiveProfile.accent),
        generation_pending: true,
        learner_state: publicLearnerState(state),
      }, id);
    }

    if (input.action === "feedback" || input.action === "complete") {
      const isRecordedCompletionRetry = input.action === "complete" &&
        await hasRecordedDifficultyFeedbackEvent(
          context.admin,
          context.userID,
          input.clientEventID,
        );
      if (input.action === "complete") {
        if (!isRecordedCompletionRetry) {
          await assertGeneratedCompletionOwnership(
            context.admin,
            context.userID,
            input.generatedLessonID,
          );
        }
      }
      const updated = isRecordedCompletionRetry
        ? state
        : await recordFeedback(context.admin, context.userID, {
          clientEventID: input.clientEventID,
          generatedLessonID: input.generatedLessonID,
          context: input.action === "complete" ? "lesson" : input.context,
          feedback: input.feedback,
          stepKind: input.action === "complete" ? null : input.stepKind,
          paceFeedback: input.action === "complete" ? input.paceFeedback : null,
          markComplete: input.action === "complete",
        });
      state = { ...state, ...updated } as LearnerState;

      if (input.action === "feedback") {
        return jsonResponse(200, {
          version: lessonContractVersion,
          accepted: true,
          learner_state: publicLearnerState(updated),
        }, id);
      }

      if (input.topicPreference) {
        await demoteOlderTopicLessons(context.admin, context.userID);
        await setNextTopicPreference(context.admin, context.userID, input.topicPreference);
        state = {
          ...state,
          next_topic_preference: input.topicPreference,
          next_topic_requested_at: new Date().toISOString(),
        };
      }

      // Completion is the user-facing transaction. Queue replenishment is
      // deliberately outside the response path so provider latency can never
      // hold the completion acknowledgement open.
      scheduleBackground("lesson_replenishment", id, async () => {
        await requireActiveEntitlement(context.admin, context.userID);
        // Keep quota exhaustion out of the generation-job failure stream.
        // The next client poll will receive the precise pacing/daily-limit
        // response from assertGenerationAvailable instead of a generic snag.
        await assertGenerationAvailable(context.admin, context.userID);
        await replenishQueue(
          context.admin,
          context.userID,
          input.requestID,
          "lesson_completed",
          state,
          effectiveProfile,
          input.topicPreference,
        );
      });
      return jsonResponse(200, {
        version: lessonContractVersion,
        accepted: true,
        queue_depth: await readyQueueDepth(context.admin, context.userID, effectiveProfile.accent),
        generation_pending: input.topicPreference !== null,
        learner_state: publicLearnerState(state),
      }, id);
    }

    await requireActiveEntitlement(context.admin, context.userID);
    if (input.action === "retry_generation" && input.topicPreference) {
      await assertGenerationAvailable(context.admin, context.userID);
      await setNextTopicPreference(context.admin, context.userID, input.topicPreference);
      state = {
        ...state,
        next_topic_preference: input.topicPreference,
        next_topic_requested_at: new Date().toISOString(),
      };
    }
    if (state.next_topic_preference) {
      const pendingTopic = state.next_topic_preference;
      const requestExpired = isPendingTopicExpired(state.next_topic_requested_at);
      const hasActiveJob = requestExpired
        ? false
        : await hasActiveGenerationJob(context.admin, context.userID);
      const generationFailed = !requestExpired && input.action === "get_next" && !hasActiveJob &&
        state.next_topic_requested_at &&
        await hasFailedGenerationSince(
          context.admin,
          context.userID,
          state.next_topic_requested_at,
        );

      if (generationFailed) {
        throw new HttpError(
          503,
          "lesson_generation_failed",
          "We couldn’t prepare that lesson. Please try again.",
        );
      }
      if (requestExpired) {
        await clearNextTopicPreference(context.admin, context.userID, pendingTopic);
        state = {
          ...state,
          next_topic_preference: null,
          next_topic_requested_at: null,
        };
      } else {
        if (!hasActiveJob) {
          const quotaBlock = await generationQuotaBlock(context.admin, context.userID);
          if (quotaBlock) {
            throw new HttpError(
              429,
              quotaBlock.code,
              quotaBlock.retryAfterSeconds >= 3_600
                ? "Your next personalized lesson can be generated after the daily limit resets."
                : "Lesson generation is catching its breath. Please try again shortly.",
            );
          }
        }
        scheduleBackground("requested_topic_generation", id, () =>
          replenishQueue(
            context.admin,
            context.userID,
            input.requestID,
            "manual_refresh",
            state,
            effectiveProfile,
            pendingTopic,
          ));
        return jsonResponse(200, {
          version: lessonContractVersion,
          lesson: null,
          queue_depth: await readyQueueDepth(
            context.admin,
            context.userID,
            effectiveProfile.accent,
          ),
          generation_pending: true,
          requested_topic: pendingTopic,
          learner_state: publicLearnerState(state),
        }, id);
      }
    }

    // Sweep before selection: never return a lesson and then invalidate the
    // very queue row the learner is about to complete.
    await sweepStaleLessonQueue(context.admin, context.userID);
    const queued = await fetchCurrentLesson(
      context.admin,
      context.userID,
      effectiveProfile.accent,
      input.excludingLessonID,
      input.generatedAfter,
    );
    const queueDepth = await readyQueueDepth(
      context.admin,
      context.userID,
      effectiveProfile.accent,
    );
    const needsFreshLesson = !queued &&
      (input.generatedAfter !== null || input.action === "retry_generation");
    if (!queued && !await hasActiveGenerationJob(context.admin, context.userID)) {
      if (
        input.action === "get_next" && input.generatedAfter &&
        await hasFailedGenerationSince(context.admin, context.userID, input.generatedAfter)
      ) {
        throw new HttpError(
          503,
          "lesson_generation_failed",
          "We couldn’t prepare that lesson. Please try again.",
        );
      }
      await assertGenerationAvailable(context.admin, context.userID);
    }

    // Always serve the existing queue first. If it is empty or running low,
    // replenish after returning; the mobile app immediately uses authored
    // content when no generated lesson is ready yet.
    if (needsFreshLesson || queueDepth < targetQueueDepth) {
      scheduleBackground("lesson_replenishment", id, () =>
        replenishQueue(
          context.admin,
          context.userID,
          input.requestID,
          needsFreshLesson ? "manual_refresh" : "initial",
          state,
          effectiveProfile,
          null,
          needsFreshLesson,
        ));
    }

    return jsonResponse(200, {
      version: lessonContractVersion,
      lesson: queued
        ? await presentQueuedLesson(
          context.admin,
          context.userID,
          queued,
          input.clientMaxPromptVersion,
        )
        : null,
      queue_depth: queueDepth,
      learner_state: publicLearnerState(state),
    }, id);
  } catch (error) {
    if (error instanceof HttpError) {
      console.warn("lesson_request_rejected", {
        request_id: id,
        status: error.status,
        code: error.code,
      });
    }
    return errorResponse(error, id);
  }
});

async function assertGenerationAvailable(
  admin: Parameters<typeof generationQuotaBlock>[0],
  userID: string,
): Promise<void> {
  const block = await generationQuotaBlock(admin, userID);
  if (block) {
    throw new HttpError(
      429,
      block.code,
      block.retryAfterSeconds >= 3_600
        ? "Your next personalized lesson can be generated after the daily limit resets."
        : "Lesson generation is catching its breath. Please try again shortly.",
    );
  }
}

function scheduleBackground(
  operation: string,
  requestID: string,
  work: () => Promise<unknown>,
): void {
  EdgeRuntime.waitUntil(
    work().catch((error) => {
      console.error("background_task_failed", {
        operation,
        request_id: requestID,
        code: error instanceof HttpError ? error.code : "internal",
      });
    }),
  );
}

async function replenishQueue(
  admin: Parameters<typeof readyQueueDepth>[0],
  userID: string,
  clientRequestID: string,
  trigger: "initial" | "lesson_completed" | "manual_refresh",
  state: LearnerState,
  profile: Parameters<typeof ensureLearnerState>[2],
  nextTopicPreference: string | null,
  forceGeneration = false,
): Promise<void> {
  const currentDepth = await readyQueueDepth(admin, userID, profile.accent);
  const missingLessons = Math.max(0, targetQueueDepth - currentDepth);
  // Generate one complete long-form session per job. The unique active-job
  // lease prevents concurrent Today/Practice requests from duplicating work.
  const count = forceGeneration || nextTopicPreference ? 1 : Math.min(1, missingLessons);
  if (count === 0) return;

  // get_next polling is intentionally frequent while the learner waits. Do
  // not charge provider quota or create work while an existing generation
  // lease is still healthy.
  if (await hasActiveGenerationJob(admin, userID)) return;

  // Claim the single-user generation lease before consuming provider quota.
  // Polling can reach this point concurrently; only the caller that acquires
  // the lease is allowed to spend a generation quota unit.
  const jobID = await beginGenerationJob(
    admin,
    userID,
    clientRequestID,
    currentDepth === 0 ? trigger : "queue_low",
    count,
    state,
  );
  if (!jobID) return;

  let model: string | null = null;
  let attempts = 0;
  try {
    const generationLimits = await lessonGenerationLimits(admin, userID);
    await consumeQuota(
      admin,
      userID,
      "lessons",
      generationLimits.minuteLimit,
      60,
    );
    await consumeQuota(
      admin,
      userID,
      "lessons_daily",
      generationLimits.dailyLimit,
      86_400,
    );

    const apiKey = requiredEnv(
      "DASHSCOPE_API_KEY",
    );
    const [recentScenarios, familiarLanguage] = await Promise.all([
      recentScenarioKeys(admin, userID),
      familiarLanguageForPrompt(admin, userID),
    ]);
    const generation = await generateLessonBatch(apiKey, {
      profile,
      estimatedLevel: state.estimated_level,
      challengeOffset: state.challenge_offset,
      skillMastery: state.skill_mastery,
      recentScenarioKeys: recentScenarios,
      familiarLanguage,
      nextTopicPreference,
      count,
    });
    if (!generation.ok) {
      await finishGenerationJob(
        admin,
        jobID,
        "failed",
        null,
        generation.attemptCount,
        generation.errorCode,
      );
      return;
    }
    model = generation.model;
    attempts = generation.attemptCount;
    const inserted = await persistGeneratedLessons(
      admin,
      userID,
      jobID,
      profile.accent,
      generation.model,
      generation.batch.lessons,
      // A manual refresh is an explicit request even when the learner leaves
      // the topic blank. Put its freshly generated lesson ahead of any older
      // generic queue entries so the request cannot appear to be ignored.
      nextTopicPreference || trigger === "manual_refresh" ? 100 : 0,
    );
    if (inserted > 0 && nextTopicPreference) {
      await clearNextTopicPreference(admin, userID, nextTopicPreference);
    }
    await finishGenerationJob(
      admin,
      jobID,
      inserted > 0 ? "completed" : "failed",
      model,
      attempts,
      inserted > 0 ? null : "duplicate_content",
    );
  } catch (error) {
    try {
      await finishGenerationJob(
        admin,
        jobID,
        "failed",
        model,
        attempts,
        error instanceof HttpError ? error.code : "generation_failed",
      );
    } catch {
      console.error("generation_job_finalization_failed", { job_id: jobID });
    }
    throw error;
  }
}
