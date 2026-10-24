/// <reference lib="deno.ns" />

import {
  completionOwnedQueueStatuses,
  extractFamiliarLanguage,
  hydrateGeneratedVocabularyProgress,
  isGeneratedVocabularyID,
  isPendingTopicExpired,
  isRetryableGenerationErrorCode,
  isSupportedGeneratedLessonVersion,
  lessonGenerationDailyLimit,
  maximumPendingTopicAgeMilliseconds,
  negotiatedLessonPromptVersion,
} from "./repository.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("owned completed lessons can request a replay follow-up", () => {
  assert(
    completionOwnedQueueStatuses.includes("completed"),
    "completed owned lesson was rejected",
  );
  assert(
    !(completionOwnedQueueStatuses as readonly string[]).includes("skipped"),
    "unconsumed skipped lesson was accepted",
  );
});

Deno.test("stale or malformed topic requests expire to the ready queue", () => {
  const now = Date.parse("2026-09-03T08:00:00.000Z");
  assert(
    !isPendingTopicExpired(
      new Date(now - maximumPendingTopicAgeMilliseconds + 1).toISOString(),
      now,
    ),
    "a fresh topic request expired early",
  );
  assert(
    isPendingTopicExpired(
      new Date(now - maximumPendingTopicAgeMilliseconds).toISOString(),
      now,
    ),
    "a stale topic request remained pending",
  );
  assert(isPendingTopicExpired("not-a-date", now), "a malformed request date remained pending");
});

Deno.test("lesson generation keeps the documented daily allowance", () => {
  assert(lessonGenerationDailyLimit === 30, "daily lesson allowance drifted from the runbook");
});

Deno.test("quota failures remain retryable instead of poisoning lesson polling", () => {
  assert(isRetryableGenerationErrorCode("rate_limited"), "rate limit became terminal");
  assert(isRetryableGenerationErrorCode("quota_unavailable"), "quota outage became terminal");
  assert(
    !isRetryableGenerationErrorCode("validation_lesson_scenario"),
    "validation failure became retryable",
  );
});

Deno.test("generated vocabulary membership rejects arbitrary UUIDs", async () => {
  const lessonID = "11111111-1111-4111-8111-111111111111";
  assert(
    !await isGeneratedVocabularyID(
      lessonID,
      "22222222-2222-4222-8222-222222222222",
      4,
    ),
    "Arbitrary UUID was accepted",
  );
});

Deno.test("generated vocabulary membership accepts a presented deterministic ID", async () => {
  const lessonID = "11111111-1111-4111-8111-111111111111";
  // SHA-256("<lesson>:vocabulary:0") with RFC-4122 version/variant bits.
  const firstVocabularyID = "2902da82-252b-5794-a688-0e24b9153a51";
  assert(
    await isGeneratedVocabularyID(lessonID, firstVocabularyID, 4),
    "Presented vocabulary UUID was rejected",
  );
});

Deno.test("generated vocabulary response hydrates persisted due dates", () => {
  const vocabulary = [{
    id: "2902da82-252b-5794-a688-0e24b9153a51",
    tagalog: "salamat po",
  }];
  const dueAt = "2026-08-04T14:00:00.000Z";
  const hydrated = hydrateGeneratedVocabularyProgress(vocabulary, [{
    vocabulary_id: vocabulary[0].id,
    mastery: 0.42,
    due_at: dueAt,
  }]);
  assert(hydrated[0].mastery === 0.42, "Persisted mastery was discarded");
  assert(hydrated[0].due_at === dueAt, "Persisted due date was discarded");
});

Deno.test("only the latest generated prompt version remains eligible for queued lessons", () => {
  assert(!isSupportedGeneratedLessonVersion(3, 4), "old prompt v4 was accepted");
  assert(!isSupportedGeneratedLessonVersion(3, 9), "old whitespace-gloss prompt was accepted");
  assert(!isSupportedGeneratedLessonVersion(3, 10), "old lexical-gloss prompt was accepted");
  assert(!isSupportedGeneratedLessonVersion(2, 5), "old schema was accepted");
  assert(!isSupportedGeneratedLessonVersion(3, 3), "unsafe old prompt was accepted");
  assert(!isSupportedGeneratedLessonVersion(3, 11), "old hear/respond prompt was accepted");
  assert(!isSupportedGeneratedLessonVersion(3, 13), "old level-agnostic prompt was accepted");
  assert(isSupportedGeneratedLessonVersion(3, 14), "latest prompt was discarded");
  assert(!isSupportedGeneratedLessonVersion(3, 15), "unknown future prompt was accepted");
});

Deno.test("lesson presentation negotiates legacy and latest client contracts", () => {
  assert(
    negotiatedLessonPromptVersion(14, 12) === 10,
    "production client did not receive the compatible projection",
  );
  assert(
    negotiatedLessonPromptVersion(14, 14) === 14,
    "latest client did not receive the latest lesson contract",
  );
  assert(
    negotiatedLessonPromptVersion(14, 15) === 14,
    "forward-compatible client did not receive the stored contract",
  );
});

Deno.test("familiar language extraction is recent-first, normalized, deduplicated, and bounded", () => {
  const contents = [{
    vocabulary: [
      { tagalog: "  salamat po  " },
      { tagalog: "ATE" },
      { tagalog: "ate" },
    ],
    rounds: [{
      chunks: [
        { tagalog: "ate   pabili po" },
        { tagalog: "Ate pabili po" },
      ],
    }],
  }];
  const familiar = extractFamiliarLanguage(contents);

  assert(
    JSON.stringify(familiar.vocabulary) === JSON.stringify(["salamat po", "ATE"]),
    "vocabulary was not normalized and deduplicated",
  );
  assert(
    JSON.stringify(familiar.chunks) === JSON.stringify(["ate pabili po"]),
    "chunks were not normalized and deduplicated",
  );
});
