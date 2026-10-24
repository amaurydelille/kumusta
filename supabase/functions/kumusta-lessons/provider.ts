/// <reference lib="deno.ns" />

import { fetchWithTimeout, isPlainObject, readBoundedResponseBody } from "../_shared/http.ts";
import {
  containsVietnameseOrthography,
  type GeneratedLessonBatch,
  hearRespondRoundIndexes,
  lessonBatchJSONSchemaForContext,
  lessonRoundCount,
  validateGeneratedBatchDetailed,
} from "./contract.ts";
import { type LessonPromptContext, systemPrompt, userPrompt } from "./prompt.ts";

export interface LessonGenerationResult {
  ok: true;
  batch: GeneratedLessonBatch;
  model: string;
  attemptCount: number;
}

export interface LessonGenerationFailure {
  ok: false;
  attemptCount: number;
  errorCode: string;
}

export type LessonGenerationOutcome = LessonGenerationResult | LessonGenerationFailure;

export const qwenLessonAPIURL =
  "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions";
export const defaultQwenLessonModel = "qwen3.8-max-0902";
const maximumProviderResponseBytes = 1_048_576;
export const maximumLessonGenerationAttempts = 3;
const lessonGenerationTimeoutMilliseconds = 90_000;
const lessonGenerationTotalBudgetMilliseconds = 120_000;
const minimumUsefulAttemptMilliseconds = 15_000;

export async function generateLessonBatch(
  apiKey: string,
  context: LessonPromptContext,
): Promise<LessonGenerationOutcome> {
  const providerName = "qwen";
  const primaryModel = Deno.env.get("QWEN_LESSON_MODEL")?.trim() || defaultQwenLessonModel;
  const expectedMinutes = Math.max(5, Math.min(15, context.profile.dailyMinutes));
  const expectedRounds = lessonRoundCount(context.profile.dailyMinutes);
  const responseSchema = lessonBatchJSONSchemaForContext(
    context.count,
    expectedMinutes,
    expectedRounds,
  );
  let lastErrorCode = "provider_response_invalid";
  let retryIssue: string | null = null;
  let attemptCount = 0;
  const generationStartedAt = Date.now();

  for (let attempt = 1; attempt <= maximumLessonGenerationAttempts; attempt += 1) {
    const remainingBudget = lessonGenerationTotalBudgetMilliseconds -
      (Date.now() - generationStartedAt);
    if (remainingBudget < minimumUsefulAttemptMilliseconds) break;
    attemptCount = attempt;
    let response: Response;
    try {
      response = await fetchWithTimeout(
        qwenLessonAPIURL,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: primaryModel,
            reasoning_effort: "none",
            temperature: attempt === 1 ? 0.18 : 0.05,
            // Qwen maps `none` to disabled thinking, keeping the token
            // budget focused on the structured lesson payload.
            seed: 41 + attempt,
            max_completion_tokens: 8_000,
            messages: [
              { role: "system", content: systemPrompt() },
              { role: "user", content: userPrompt(context) },
              ...(retryIssue
                ? [{
                  role: "user",
                  content:
                    `The previous draft failed the deterministic contract check (${retryIssue}). Generate a complete new draft and obey every supplied schema and grounding constraint exactly.`,
                }]
                : []),
            ],
            response_format: {
              type: "json_schema",
              json_schema: {
                name: "kumusta_lesson_batch_v3",
                strict: true,
                schema: responseSchema,
              },
            },
          }),
        },
        Math.min(lessonGenerationTimeoutMilliseconds, remainingBudget),
      );
    } catch (error) {
      lastErrorCode = "provider_transport_failed";
      console.error(`${providerName}_lesson_transport_failed`, {
        attempt,
        reason: error instanceof Error ? error.name : "unknown",
      });
      continue;
    }

    if (!response.ok) {
      lastErrorCode = `provider_rejected_${response.status}`;
      console.error(`${providerName}_lesson_rejected`, { status: response.status, attempt });
      if (response.status >= 400 && response.status < 500 && response.status !== 429) {
        return { ok: false, attemptCount: attempt, errorCode: lastErrorCode };
      }
      continue;
    }

    try {
      const bytes = await readBoundedResponseBody(response, maximumProviderResponseBytes);
      const payload: unknown = JSON.parse(new TextDecoder().decode(bytes));
      const content = extractContent(payload);
      if (!content) {
        lastErrorCode = "provider_response_invalid";
        retryIssue = "missing JSON content";
        continue;
      }
      const parsedContent = repairGeneratedBatchStructure(JSON.parse(content));
      const validation = validateGeneratedBatchDetailed(
        parsedContent,
        context.count,
        context.profile.accent,
        expectedMinutes,
        expectedRounds,
        true,
      );
      if (validation.batch) {
        return {
          ok: true,
          batch: validation.batch,
          model: primaryModel,
          attemptCount: attempt,
        };
      }
      retryIssue = validation.issue ?? "unknown validation failure";
      lastErrorCode = validation.issue ? `validation_${validation.issue}` : "validation_unknown";
      console.error(`${providerName}_lesson_validation_failed`, {
        attempt,
        issue: validation.issue,
      });
    } catch (error) {
      lastErrorCode = "provider_response_invalid";
      retryIssue = "invalid provider JSON";
      // Structured output is still validated locally because provider/model
      // changes must never bypass the product contract.
      console.error(`${providerName}_lesson_response_failed`, {
        attempt,
        reason: error instanceof Error ? error.name : "unknown",
      });
    }
  }

  return {
    ok: false,
    attemptCount,
    errorCode: lastErrorCode,
  };
}

export function repairGeneratedBatchStructure(value: unknown): unknown {
  const repaired = structuredClone(value);
  if (!isPlainObject(repaired) || !Array.isArray(repaired.lessons)) return repaired;

  for (const lesson of repaired.lessons) {
    if (
      !isPlainObject(lesson) || typeof lesson.scenario_key !== "string" ||
      !Array.isArray(lesson.rounds)
    ) continue;
    const hearRespondRoundIndexesForLesson = new Set(
      hearRespondRoundIndexes(lesson.rounds.length),
    );
    for (const [roundIndex, round] of lesson.rounds.entries()) {
      if (!isPlainObject(round)) continue;
      // The provider schema keeps response_exercise optional so the model can
      // emit it on the selected rounds. Some model responses still copy it to
      // every round, though; strip those extras before the deterministic
      // contract check instead of rejecting an otherwise usable lesson.
      if (!hearRespondRoundIndexesForLesson.has(roundIndex)) {
        delete round.response_exercise;
      }
      round.topic_key = lesson.scenario_key;
      repairRoundWordGlosses(round);
      if (typeof round.vietnamese !== "string" || !Array.isArray(round.chunks)) continue;
      const phrase = normalizeGroundingText(round.vietnamese);
      const indexedChunks = round.chunks.map((chunk, originalIndex) => {
        if (!isPlainObject(chunk) || typeof chunk.vietnamese !== "string") return null;
        const index = phrase.indexOf(normalizeGroundingText(chunk.vietnamese));
        return index < 0 ? null : { chunk, index, originalIndex };
      });
      if (indexedChunks.some((item) => item === null)) continue;
      round.chunks = indexedChunks
        .filter((item) => item !== null)
        .sort((left, right) => left.index - right.index || left.originalIndex - right.originalIndex)
        .map((item) => item.chunk);
    }
    repairHearRespondExercises(lesson);
  }
  return repaired;
}

function repairHearRespondExercises(lesson: Record<string, unknown>): void {
  if (!Array.isArray(lesson.rounds)) return;

  const responseRoundIndexes = new Set(hearRespondRoundIndexes(lesson.rounds.length));
  const lessonTranslations = lesson.rounds.flatMap((candidate) => {
    if (!isPlainObject(candidate) || typeof candidate.translation !== "string") return [];
    const translation = candidate.translation.trim();
    return translation.length > 0 ? [translation] : [];
  });

  for (const roundIndex of responseRoundIndexes) {
    const round = lesson.rounds[roundIndex];
    if (
      !isPlainObject(round) || typeof round.vietnamese !== "string" ||
      typeof round.translation !== "string"
    ) continue;

    const targetTranslation = round.translation.trim();
    if (targetTranslation.length === 0) continue;

    const distractors: string[] = [];
    const addDistractor = (value: unknown): void => {
      if (typeof value !== "string") return;
      const candidate = value.trim();
      if (
        candidate.length === 0 || containsVietnameseOrthography(candidate) ||
        normalizeGroundingText(candidate) === normalizeGroundingText(targetTranslation) ||
        distractors.some((existing) =>
          normalizeGroundingText(existing) === normalizeGroundingText(candidate)
        )
      ) return;
      distractors.push(candidate);
    };

    if (isPlainObject(round.response_exercise) && Array.isArray(round.response_exercise.options)) {
      for (const option of round.response_exercise.options) {
        if (isPlainObject(option)) addDistractor(option.english_translation);
      }
    }
    for (const translation of lessonTranslations) addDistractor(translation);
    addDistractor("The speaker is asking about a different topic.");
    addDistractor("The conversation is ending now.");

    if (distractors.length < 2) continue;
    round.response_exercise = {
      prompt_vietnamese: round.vietnamese,
      prompt_translation: round.translation,
      options: [targetTranslation, ...distractors.slice(0, 2)].map((englishTranslation) => ({
        english_translation: englishTranslation,
      })),
      correct_option_index: 0,
    };
  }
}

function repairRoundWordGlosses(round: Record<string, unknown>): void {
  if (typeof round.vietnamese !== "string" || !Array.isArray(round.word_glosses)) return;

  const expectedTokens = round.vietnamese.split(/\s+/u);
  const repaired: Array<{ token: string; english: string }> = [];
  let expectedIndex = 0;
  let preservedGlossCount = 0;

  for (const rawGloss of round.word_glosses) {
    if (
      !isPlainObject(rawGloss) || typeof rawGloss.token !== "string" ||
      typeof rawGloss.english !== "string" || rawGloss.english.trim().length === 0
    ) continue;

    while (
      expectedIndex < expectedTokens.length &&
      normalizeGlossAlignment(expectedTokens[expectedIndex]).length === 0
    ) {
      repaired.push({ token: expectedTokens[expectedIndex], english: "punctuation" });
      expectedIndex += 1;
    }

    const target = normalizeGlossAlignment(rawGloss.token);
    if (target.length === 0) continue;

    const match = findGlossRange(expectedTokens, expectedIndex, target);
    if (!match) continue;

    // The model occasionally skips a meaningful token even though the rest of
    // the glosses are aligned. Keep the lesson usable and retain the source
    // punctuation while providing a neutral fallback for that missing gloss.
    while (expectedIndex < match.start) {
      repaired.push({
        token: expectedTokens[expectedIndex],
        english: glossFallback(expectedTokens[expectedIndex]),
      });
      expectedIndex += 1;
    }

    repaired.push({
      token: expectedTokens.slice(match.start, match.end).join(" "),
      english: rawGloss.english.trim(),
    });
    preservedGlossCount += 1;
    expectedIndex = match.end;
  }

  while (expectedIndex < expectedTokens.length) {
    repaired.push({
      token: expectedTokens[expectedIndex],
      english: glossFallback(expectedTokens[expectedIndex]),
    });
    expectedIndex += 1;
  }

  if (preservedGlossCount > 0 && repaired.length > 0) {
    round.word_glosses = repaired;
  }
}

function findGlossRange(
  expectedTokens: string[],
  startIndex: number,
  target: string,
): { start: number; end: number } | null {
  for (
    let candidateStart = startIndex;
    candidateStart < expectedTokens.length;
    candidateStart += 1
  ) {
    let combined = "";
    for (
      let candidateEnd = candidateStart;
      candidateEnd < expectedTokens.length && candidateEnd < candidateStart + 2;
      candidateEnd += 1
    ) {
      combined += normalizeGlossAlignment(expectedTokens[candidateEnd]);
      if (combined === target) {
        return { start: candidateStart, end: candidateEnd + 1 };
      }
      if (combined.length >= target.length) break;
    }
  }
  return null;
}

function glossFallback(token: string): string {
  return normalizeGlossAlignment(token).length === 0 ? "punctuation" : "contextual meaning";
}

function normalizeGlossAlignment(value: string): string {
  return value
    .normalize("NFC")
    .toLocaleLowerCase("vi")
    .replace(/[\p{P}\p{S}\s]+/gu, "");
}

function normalizeGroundingText(value: string): string {
  return value.normalize("NFC").toLocaleLowerCase("vi").replace(/\s+/gu, " ").trim();
}

function extractContent(payload: unknown): string | null {
  if (payload === null || typeof payload !== "object") return null;
  const choices = (payload as Record<string, unknown>).choices;
  if (!Array.isArray(choices) || choices.length < 1) return null;
  const first = choices[0];
  if (first === null || typeof first !== "object") return null;
  const message = (first as Record<string, unknown>).message;
  if (message === null || typeof message !== "object") return null;
  const content = (message as Record<string, unknown>).content;
  return typeof content === "string" ? content : null;
}
