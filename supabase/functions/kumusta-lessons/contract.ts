import { HttpError, isPlainObject } from "../_shared/http.ts";

export const lessonContractVersion = 3 as const;
export const lessonPromptVersion = 14 as const;
export const minimumSupportedLessonPromptVersion = 14 as const;
export const legacyClientMaximumLessonPromptVersion = 12 as const;
export const targetQueueDepth = 2;

export function lessonRoundCount(dailyMinutes: number): number {
  return Math.min(12, Math.max(5, dailyMinutes));
}

export function hearRespondRoundIndexes(roundCount: number): number[] {
  if (roundCount >= 10) return [4, 7];
  return [2, 4];
}

/** The v11 queue remains readable while new lessons use two response rounds. */
export function legacyHearRespondRoundIndexes(roundCount: number): number[] {
  if (roundCount >= 10) return [4, 7];
  if (roundCount >= 7) return [4];
  return [2];
}

export type Goal =
  | "family"
  | "lifeInThePhilippines"
  | "travel"
  | "partner"
  | "work"
  | "culture";
export type SelfAssessedLevel =
  | "beginner"
  | "intermediate"
  | "advanced";
export type ChallengePreference = "gentle" | "balanced" | "stretch";
export type DifficultyRating = "too_easy" | "just_right" | "too_hard";
export type PaceRating = "too_slow" | "pace_right" | "too_fast";
export type FeedbackContext = "question" | "lesson";
export type LessonStepKind = "coldListen" | "decode" | "hearRespond" | "speak";
export type VocabularyReviewRating = "again" | "almost" | "got_it";

export interface LearnerProfileInput {
  goal: Goal;
  selfAssessedLevel: SelfAssessedLevel;
  targetLevel: number;
  challengePreference: ChallengePreference;
  dailyMinutes: number;
}

export type LessonEngineRequest =
  | {
    action: "get_next";
    requestID: string;
    topicPreference: string | null;
    excludingLessonID: string | null;
    generatedAfter: string | null;
    clientMaxPromptVersion: number;
    profile: LearnerProfileInput;
  }
  | {
    action: "retry_generation";
    requestID: string;
    topicPreference: string | null;
    excludingLessonID: string | null;
    generatedAfter: string | null;
    clientMaxPromptVersion: number;
    profile: LearnerProfileInput;
  }
  | {
    action: "request_generation";
    requestID: string;
    clientEventID: string;
    generatedLessonID: string | null;
    feedback: DifficultyRating;
    paceFeedback: PaceRating;
    topicPreference: string | null;
    profile: LearnerProfileInput;
  }
  | {
    action: "complete";
    requestID: string;
    clientEventID: string;
    generatedLessonID: string | null;
    feedback: DifficultyRating;
    paceFeedback: PaceRating;
    topicPreference: string | null;
    profile: LearnerProfileInput;
  }
  | {
    action: "feedback";
    requestID: string;
    clientEventID: string;
    generatedLessonID: string | null;
    context: FeedbackContext;
    stepKind: LessonStepKind | null;
    feedback: DifficultyRating;
    profile: LearnerProfileInput;
  }
  | {
    action: "review_word";
    requestID: string;
    clientEventID: string;
    generatedLessonID: string;
    vocabularyID: string;
    rating: VocabularyReviewRating;
    profile: LearnerProfileInput;
  };

export interface GeneratedChunk {
  tagalog: string;
  english: string;
  note: string;
}

export interface GeneratedStep {
  kind: LessonStepKind;
  prompt: string;
  tagalog: string;
  translation: string;
  chunks: GeneratedChunk[];
}

export interface GeneratedRound {
  topicKey: string;
  situation: string;
  tagalog: string;
  translation: string;
  chunks: GeneratedChunk[];
  wordGlosses: GeneratedWordGloss[];
  speakingPrompt: string;
  responseExercise?: GeneratedHearRespondExercise;
}

export interface GeneratedHearRespondOption {
  englishTranslation: string;
}

export interface GeneratedHearRespondExercise {
  promptTagalog: string;
  promptTranslation: string;
  options: GeneratedHearRespondOption[];
  correctOptionIndex: number;
}

export interface GeneratedWordGloss {
  token: string;
  english: string;
}

export interface GeneratedVocabulary {
  tagalog: string;
  english: string;
  example: string;
  exampleTranslation: string;
}

export interface GeneratedLessonDraft {
  title: string;
  scenarioKey: string;
  scenario: string;
  minutes: number;
  difficulty: number;
  rounds: GeneratedRound[];
  vocabulary: GeneratedVocabulary[];
}

export interface GeneratedLessonBatch {
  version: 1;
  lessons: GeneratedLessonDraft[];
}

export interface GeneratedBatchValidationResult {
  batch: GeneratedLessonBatch | null;
  issue: string | null;
}

interface ValidationContext {
  issue: string | null;
}

export const lessonBatchJSONSchema = {
  type: "object",
  additionalProperties: false,
  required: ["version", "lessons"],
  properties: {
    version: { type: "integer", const: 1 },
    lessons: {
      type: "array",
      minItems: 1,
      maxItems: 3,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "title",
          "scenario_key",
          "scenario",
          "minutes",
          "difficulty",
          "rounds",
          "vocabulary",
        ],
        properties: {
          title: { type: "string", minLength: 1, maxLength: 100 },
          scenario_key: {
            type: "string",
            pattern: "^[a-z0-9]+(?:_[a-z0-9]+)*$",
            minLength: 1,
            maxLength: 80,
          },
          scenario: { type: "string", minLength: 1, maxLength: 72 },
          minutes: { type: "integer", minimum: 5, maximum: 15 },
          difficulty: { type: "number", minimum: 1, maximum: 5 },
          rounds: {
            type: "array",
            minItems: 5,
            maxItems: 12,
            items: {
              type: "object",
              additionalProperties: false,
              required: [
                "topic_key",
                "situation",
                "tagalog",
                "translation",
                "chunks",
                "word_glosses",
                "speaking_prompt",
              ],
              properties: {
                topic_key: {
                  type: "string",
                  pattern: "^[a-z0-9]+(?:_[a-z0-9]+)*$",
                  minLength: 1,
                  maxLength: 80,
                },
                situation: { type: "string", minLength: 1, maxLength: 160 },
                tagalog: { type: "string", minLength: 1, maxLength: 280 },
                translation: { type: "string", minLength: 1, maxLength: 280 },
                speaking_prompt: { type: "string", minLength: 1, maxLength: 180 },
                response_exercise: {
                  type: "object",
                  additionalProperties: false,
                  required: [
                    "prompt_tagalog",
                    "prompt_translation",
                    "options",
                    "correct_option_index",
                  ],
                  properties: {
                    prompt_tagalog: { type: "string", minLength: 1, maxLength: 280 },
                    prompt_translation: { type: "string", minLength: 1, maxLength: 280 },
                    options: {
                      type: "array",
                      minItems: 3,
                      maxItems: 3,
                      items: {
                        type: "object",
                        additionalProperties: false,
                        required: ["english_translation"],
                        properties: {
                          english_translation: { type: "string", minLength: 1, maxLength: 280 },
                        },
                      },
                    },
                    correct_option_index: { type: "integer", minimum: 0, maximum: 2 },
                  },
                },
                chunks: {
                  type: "array",
                  minItems: 2,
                  maxItems: 5,
                  items: {
                    type: "object",
                    additionalProperties: false,
                    required: ["tagalog", "english", "note"],
                    properties: {
                      tagalog: { type: "string", minLength: 1, maxLength: 100 },
                      english: { type: "string", minLength: 1, maxLength: 140 },
                      note: { type: "string", minLength: 1, maxLength: 180 },
                    },
                  },
                },
                word_glosses: {
                  type: "array",
                  minItems: 1,
                  maxItems: 40,
                  items: {
                    type: "object",
                    additionalProperties: false,
                    required: ["token", "english"],
                    properties: {
                      token: { type: "string", minLength: 1, maxLength: 80 },
                      english: { type: "string", minLength: 1, maxLength: 140 },
                    },
                  },
                },
              },
            },
          },
          vocabulary: {
            type: "array",
            minItems: 8,
            maxItems: 18,
            items: {
              type: "object",
              additionalProperties: false,
              required: [
                "tagalog",
                "english",
                "example",
                "example_translation",
              ],
              properties: {
                tagalog: { type: "string", minLength: 1, maxLength: 100 },
                english: { type: "string", minLength: 1, maxLength: 140 },
                example: { type: "string", minLength: 1, maxLength: 240 },
                example_translation: { type: "string", minLength: 1, maxLength: 240 },
              },
            },
          },
        },
      },
    },
  },
} as const;

export function lessonBatchJSONSchemaForContext(
  expectedCount: number,
  expectedMinutes: number,
  expectedRounds: number,
) {
  const lessons = lessonBatchJSONSchema.properties.lessons;
  const lesson = lessons.items;
  const rounds = lesson.properties.rounds;
  return {
    ...lessonBatchJSONSchema,
    properties: {
      ...lessonBatchJSONSchema.properties,
      lessons: {
        ...lessons,
        minItems: expectedCount,
        maxItems: expectedCount,
        items: {
          ...lesson,
          properties: {
            ...lesson.properties,
            minutes: { type: "integer", const: expectedMinutes },
            rounds: {
              ...rounds,
              minItems: expectedRounds,
              maxItems: expectedRounds,
            },
          },
        },
      },
    },
  } as const;
}

export function parseLessonEngineRequest(
  body: Record<string, unknown>,
): LessonEngineRequest {
  if (typeof body.action !== "string") {
    throw new HttpError(400, "invalid_request", "Choose a lesson action.");
  }
  const requestID = parseUUID(body.request_id, "request_id");
  const profile = parseProfile(body.profile);

  if (body.action === "get_next" || body.action === "retry_generation") {
    assertRequiredAndOptionalKeys(
      body,
      ["action", "request_id", "profile"],
      ["client_max_prompt_version", "excluding_lesson_id", "generated_after", "topic_preference"],
    );
    let generatedAfter: string | null = null;
    if (body.generated_after != null) {
      if (
        typeof body.generated_after !== "string" || body.generated_after.length > 40 ||
        !Number.isFinite(Date.parse(body.generated_after))
      ) {
        throw new HttpError(400, "invalid_request", "Send a valid generation timestamp.");
      }
      // A device clock ahead of the server must not make every lesson ineligible.
      generatedAfter = new Date(Math.min(Date.parse(body.generated_after), Date.now()))
        .toISOString();
    }
    return {
      action: body.action,
      requestID,
      excludingLessonID: parseNullableLessonID(body.excluding_lesson_id ?? null),
      generatedAfter,
      topicPreference: parseTopicPreference(body.topic_preference ?? null),
      clientMaxPromptVersion: parseClientMaxPromptVersion(body.client_max_prompt_version),
      profile,
    };
  }

  if (body.action === "request_generation") {
    assertRequiredAndOptionalKeys(body, [
      "action",
      "request_id",
      "client_event_id",
      "generated_lesson_id",
      "feedback",
      "pace_feedback",
      "profile",
    ], ["topic_preference"]);
    return {
      action: "request_generation",
      requestID,
      clientEventID: parseUUID(body.client_event_id, "client_event_id"),
      generatedLessonID: parseNullableUUID(body.generated_lesson_id),
      feedback: parseRating(body.feedback),
      paceFeedback: parsePaceRating(body.pace_feedback),
      topicPreference: parseTopicPreference(body.topic_preference ?? null),
      profile,
    };
  }

  if (body.action === "complete") {
    assertRequiredAndOptionalKeys(body, [
      "action",
      "request_id",
      "client_event_id",
      "generated_lesson_id",
      "feedback",
      "pace_feedback",
      "profile",
    ], ["topic_preference"]);
    return {
      action: "complete",
      requestID,
      clientEventID: parseUUID(body.client_event_id, "client_event_id"),
      generatedLessonID: parseNullableUUID(body.generated_lesson_id),
      feedback: parseRating(body.feedback),
      paceFeedback: parsePaceRating(body.pace_feedback),
      topicPreference: parseTopicPreference(body.topic_preference ?? null),
      profile,
    };
  }

  if (body.action === "feedback") {
    assertExactKeys(body, [
      "action",
      "request_id",
      "client_event_id",
      "generated_lesson_id",
      "context",
      "step_kind",
      "feedback",
      "profile",
    ]);
    if (body.context !== "question" && body.context !== "lesson") {
      throw new HttpError(400, "invalid_context", "Choose question or lesson.");
    }
    const stepKind = body.step_kind === null ? null : body.step_kind === "coldListen" ||
        body.step_kind === "decode" || body.step_kind === "hearRespond" ||
        body.step_kind === "speak"
      ? body.step_kind
      : undefined;
    if (stepKind === undefined) {
      throw new HttpError(400, "invalid_step", "The lesson step is invalid.");
    }
    return {
      action: "feedback",
      requestID,
      clientEventID: parseUUID(body.client_event_id, "client_event_id"),
      generatedLessonID: parseNullableUUID(body.generated_lesson_id),
      context: body.context,
      stepKind,
      feedback: parseRating(body.feedback),
      profile,
    };
  }

  if (body.action === "review_word") {
    assertExactKeys(body, [
      "action",
      "request_id",
      "client_event_id",
      "generated_lesson_id",
      "vocabulary_id",
      "rating",
      "profile",
    ]);
    if (body.rating !== "again" && body.rating !== "almost" && body.rating !== "got_it") {
      throw new HttpError(400, "invalid_rating", "Choose a supported word rating.");
    }
    return {
      action: "review_word",
      requestID,
      clientEventID: parseUUID(body.client_event_id, "client_event_id"),
      generatedLessonID: parseUUID(body.generated_lesson_id, "generated_lesson_id"),
      vocabularyID: parseUUID(body.vocabulary_id, "vocabulary_id"),
      rating: body.rating,
      profile,
    };
  }

  throw new HttpError(400, "unsupported_action", "Choose a supported lesson action.");
}

export function parseTopicPreference(value: unknown): string | null {
  if (value === null) return null;
  if (typeof value !== "string") {
    throw new HttpError(
      400,
      "invalid_topic_preference",
      "Describe one real-life situation, or leave the topic blank.",
    );
  }

  const normalized = value.normalize("NFKC").trim().replace(/\s+/gu, " ");
  if (
    normalized.length < 3 ||
    // Keep this boundary aligned with NextLessonTopicPreference.maximumLength
    // in the iOS client. A learner may describe a real-life situation in a
    // sentence or two; rejecting text the app already validated leaves the
    // durable completion outbox permanently blocked at its first event.
    normalized.length > 200 ||
    !/^[\p{L}\p{N}\s,.'’&/()\-]+$/u.test(normalized)
  ) {
    throw new HttpError(
      400,
      "invalid_topic_preference",
      "Use a short, plain-language real-life situation.",
    );
  }

  const folded = normalized.toLocaleLowerCase("en-US");
  const instructionFragments = [
    "ignore previous",
    "ignore all",
    "disregard previous",
    "system prompt",
    "developer message",
    "assistant message",
    "return json",
    "output schema",
    "jailbreak",
    "prompt injection",
  ];
  if (instructionFragments.some((fragment) => folded.includes(fragment))) {
    throw new HttpError(
      400,
      "invalid_topic_preference",
      "Describe a situation, not instructions for the lesson generator.",
    );
  }
  return normalized;
}

export function validateGeneratedBatch(
  value: unknown,
  expectedCount: number,
  expectedMinutes?: number,
  expectedRounds?: number,
  requireHearRespond = false,
): GeneratedLessonBatch | null {
  return validateGeneratedBatchDetailed(
    value,
    expectedCount,
    expectedMinutes,
    expectedRounds,
    requireHearRespond,
  ).batch;
}

export function validateGeneratedBatchDetailed(
  value: unknown,
  expectedCount: number,
  expectedMinutes?: number,
  expectedRounds?: number,
  requireHearRespond = false,
): GeneratedBatchValidationResult {
  const validation: ValidationContext = { issue: null };
  const batch = validateGeneratedBatchInternal(
    value,
    expectedCount,
    validation,
    expectedMinutes,
    expectedRounds,
    requireHearRespond,
  );
  return { batch, issue: validation.issue };
}

function validateGeneratedBatchInternal(
  value: unknown,
  expectedCount: number,
  validation: ValidationContext,
  expectedMinutes?: number,
  expectedRounds?: number,
  requireHearRespond = false,
): GeneratedLessonBatch | null {
  if (!isPlainObject(value) || value.version !== 1 || !Array.isArray(value.lessons)) {
    return reject(validation, "batch_shape");
  }
  if (value.lessons.length !== expectedCount || expectedCount < 1 || expectedCount > 3) {
    return reject(validation, "lesson_count");
  }

  const lessons: GeneratedLessonDraft[] = [];
  const scenarios = new Set<string>();
  for (const rawLesson of value.lessons) {
    const lesson = validateLesson(
      rawLesson,
      expectedMinutes,
      expectedRounds,
      requireHearRespond,
      validation,
    );
    if (!lesson) return null;
    if (scenarios.has(lesson.scenarioKey)) return reject(validation, "duplicate_scenario");
    scenarios.add(lesson.scenarioKey);
    lessons.push(lesson);
  }
  return { version: 1, lessons };
}

function validateLesson(
  value: unknown,
  expectedMinutes?: number,
  expectedRounds?: number,
  requireHearRespond = false,
  validation: ValidationContext = { issue: null },
): GeneratedLessonDraft | null {
  if (!isPlainObject(value)) return reject(validation, "lesson_shape");
  const title = boundedText(value.title, 1, 100);
  const scenarioKey = boundedText(value.scenario_key, 1, 80);
  const scenario = boundedText(value.scenario, 1, 72);
  if (!title) return reject(validation, "lesson_title");
  if (!scenarioKey || !/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(scenarioKey)) {
    return reject(validation, "lesson_scenario_key");
  }
  if (!scenario) return reject(validation, "lesson_scenario");
  if (containsTagalogSentence(title) || containsTagalogSentence(scenario)) {
    return reject(validation, "lesson_ui_language");
  }
  if (
    !Number.isInteger(value.minutes) || Number(value.minutes) < 5 || Number(value.minutes) > 15 ||
    (expectedMinutes !== undefined && Number(value.minutes) !== expectedMinutes)
  ) return reject(validation, "lesson_minutes");
  if (typeof value.difficulty !== "number" || value.difficulty < 1 || value.difficulty > 5) {
    return reject(validation, "lesson_difficulty");
  }
  if (
    !Array.isArray(value.rounds) || value.rounds.length < 5 || value.rounds.length > 12 ||
    (expectedRounds !== undefined && value.rounds.length !== expectedRounds)
  ) return reject(validation, "lesson_round_count");
  if (
    !Array.isArray(value.vocabulary) || value.vocabulary.length < 8 ||
    value.vocabulary.length > 18
  ) return reject(validation, "lesson_vocabulary_count");

  const rounds: GeneratedRound[] = [];
  const seenPhrases = new Set<string>();
  const responseRoundIndexes = hearRespondRoundIndexes(
    expectedRounds ?? Number(value.minutes),
  );
  for (const [roundIndex, rawRound] of value.rounds.entries()) {
    const round = validateRound(
      rawRound,
      scenarioKey,
      responseRoundIndexes.includes(roundIndex),
      requireHearRespond,
      validation,
    );
    if (!round) return null;
    const normalizedPhrase = round.tagalog.toLocaleLowerCase("fil");
    if (seenPhrases.has(normalizedPhrase)) return reject(validation, "duplicate_utterance");
    seenPhrases.add(normalizedPhrase);
    rounds.push(round);
  }
  if (
    rounds.some((round) =>
      interfaceCopyRevealsUtterance(title, round.tagalog) ||
      interfaceCopyRevealsUtterance(scenario, round.tagalog) ||
      interfaceCopyRevealsUtterance(round.situation, round.tagalog)
    )
  ) return reject(validation, "answer_leakage");
  const safetyCopy = [
    title,
    scenario,
    ...rounds.flatMap((round) => [
      round.situation,
      round.speakingPrompt,
      round.tagalog,
      round.translation,
      ...(round.responseExercise
        ? [
          round.responseExercise.promptTagalog,
          round.responseExercise.promptTranslation,
          ...round.responseExercise.options.map((option) => option.englishTranslation),
        ]
        : []),
      ...round.chunks.flatMap((chunk) => [chunk.tagalog, chunk.english, chunk.note]),
      ...round.wordGlosses.flatMap((gloss) => [gloss.token, gloss.english]),
    ]),
  ].join(" ");
  if (containsProhibitedLessonSubject(safetyCopy)) {
    return reject(validation, "prohibited_subject");
  }

  const vocabulary: GeneratedVocabulary[] = [];
  const seenTerms = new Set<string>();
  for (const rawVocabulary of value.vocabulary) {
    const item = validateVocabulary(rawVocabulary, validation);
    if (!item) return null;
    const normalizedTerm = item.tagalog.toLocaleLowerCase("fil");
    if (seenTerms.has(normalizedTerm)) return reject(validation, "duplicate_vocabulary");
    if (
      !rounds.some((round) => normalizedIncludes(round.tagalog, item.tagalog)) ||
      !normalizedIncludes(item.example, item.tagalog) ||
      containsProhibitedLessonSubject(
        `${item.tagalog} ${item.english} ${item.example} ${item.exampleTranslation}`,
      )
    ) return reject(validation, "vocabulary_not_grounded");
    seenTerms.add(normalizedTerm);
    vocabulary.push(item);
  }

  return {
    title,
    scenarioKey,
    scenario,
    minutes: Number(value.minutes),
    difficulty: Math.round(value.difficulty * 100) / 100,
    rounds,
    vocabulary,
  };
}

function validateRound(
  value: unknown,
  expectedTopicKey: string,
  shouldHaveHearRespond: boolean,
  requireHearRespond: boolean,
  validation: ValidationContext,
): GeneratedRound | null {
  if (
    !isPlainObject(value) || !Array.isArray(value.chunks) ||
    !Array.isArray(value.word_glosses)
  ) {
    return reject(validation, "round_shape");
  }
  const topicKey = boundedText(value.topic_key, 1, 80);
  const situation = boundedText(value.situation, 1, 160);
  const tagalog = boundedTagalog(value.tagalog, 1, 280);
  const translation = boundedText(value.translation, 1, 280);
  const speakingPrompt = boundedText(value.speaking_prompt, 1, 180);
  if (
    !topicKey || topicKey !== expectedTopicKey ||
    !situation || !tagalog || !translation || !speakingPrompt ||
    containsTagalogSentence(situation) ||
    hasLeadingSpeakerLabel(tagalog) || hasLeadingSpeakerLabel(translation) ||
    value.chunks.length < 2 || value.chunks.length > 5
  ) {
    return reject(validation, "round_fields");
  }
  const chunks: GeneratedChunk[] = [];
  for (const rawChunk of value.chunks) {
    if (!isPlainObject(rawChunk)) return reject(validation, "chunk_shape");
    const chunkTagalog = boundedText(rawChunk.tagalog, 1, 100);
    const english = boundedText(rawChunk.english, 1, 140);
    const note = boundedText(rawChunk.note, 1, 180);
    if (!chunkTagalog || !english || !note) return reject(validation, "chunk_fields");
    chunks.push({ tagalog: chunkTagalog, english, note });
  }
  if (!chunksAppearInOrder(tagalog, chunks.map((chunk) => chunk.tagalog))) {
    return reject(validation, "chunks_not_ordered_substrings");
  }

  const responseExercise = value.response_exercise === undefined
    ? undefined
    : validateHearRespondExercise(value.response_exercise, tagalog, translation, validation);
  if (value.response_exercise !== undefined && !responseExercise) return null;
  if (requireHearRespond && shouldHaveHearRespond && !responseExercise) {
    return reject(validation, "missing_hear_respond_exercise");
  }
  if (requireHearRespond && !shouldHaveHearRespond && responseExercise) {
    return reject(validation, "unexpected_hear_respond_exercise");
  }

  const expectedTokens = tagalog.split(/\s+/u);
  if (value.word_glosses.length < 1 || value.word_glosses.length > 40) {
    return reject(validation, "word_gloss_count");
  }
  const wordGlosses: GeneratedWordGloss[] = [];
  let tokenCursor = 0;
  for (const rawGloss of value.word_glosses) {
    if (!isPlainObject(rawGloss)) return reject(validation, "word_gloss_shape");
    const token = boundedText(rawGloss.token, 1, 80);
    const english = boundedText(rawGloss.english, 1, 140);
    if (!token || !english) return reject(validation, "word_gloss_fields");
    const glossTokens = token.split(/\s+/u);
    if (glossTokens.length > 2 || tokenCursor + glossTokens.length > expectedTokens.length) {
      return reject(validation, "word_gloss_group_too_large");
    }
    for (let offset = 0; offset < glossTokens.length; offset += 1) {
      if (
        normalizeGlossToken(glossTokens[offset]) !==
          normalizeGlossToken(expectedTokens[tokenCursor + offset])
      ) {
        return reject(validation, "word_gloss_token_mismatch");
      }
    }
    // The semantic value here is the contextual English gloss. Token identity
    // is deterministic from the already-validated utterance, so canonicalize
    // punctuation/casing instead of paying for another model generation when
    // a provider returns `po` for the source token `po?`.
    wordGlosses.push({
      token: expectedTokens.slice(tokenCursor, tokenCursor + glossTokens.length).join(" "),
      english,
    });
    tokenCursor += glossTokens.length;
  }
  if (tokenCursor !== expectedTokens.length) {
    return reject(validation, "word_gloss_incomplete");
  }
  return {
    topicKey,
    situation,
    tagalog,
    translation,
    chunks,
    wordGlosses,
    speakingPrompt,
    responseExercise: responseExercise ?? undefined,
  };
}

function validateHearRespondExercise(
  value: unknown,
  targetTagalog: string,
  targetTranslation: string,
  validation: ValidationContext,
): GeneratedHearRespondExercise | null {
  if (!isPlainObject(value) || !Array.isArray(value.options)) {
    return reject(validation, "response_exercise_shape");
  }
  const promptTagalog = boundedTagalog(value.prompt_tagalog, 1, 280);
  const promptTranslation = boundedText(value.prompt_translation, 1, 280);
  const correctOptionIndex = value.correct_option_index;
  if (
    !promptTagalog || !promptTranslation ||
    containsTagalogSentence(promptTranslation) ||
    hasLeadingSpeakerLabel(promptTagalog) ||
    normalizeForGrounding(promptTagalog) !== normalizeForGrounding(targetTagalog) ||
    normalizeForGrounding(promptTranslation) !== normalizeForGrounding(targetTranslation) ||
    !Number.isInteger(correctOptionIndex) ||
    Number(correctOptionIndex) < 0 || Number(correctOptionIndex) > 2 ||
    value.options.length !== 3
  ) {
    return reject(validation, "response_exercise_fields");
  }

  const options: GeneratedHearRespondOption[] = [];
  const seenOptions = new Set<string>();
  for (const rawOption of value.options) {
    if (!isPlainObject(rawOption)) return reject(validation, "response_option_shape");
    const englishTranslation = boundedText(rawOption.english_translation, 1, 280);
    if (
      !englishTranslation ||
      containsTagalogSentence(englishTranslation) ||
      hasLeadingSpeakerLabel(englishTranslation)
    ) {
      return reject(validation, "response_option_fields");
    }
    const normalizedOption = normalizeForGrounding(englishTranslation);
    if (seenOptions.has(normalizedOption)) return reject(validation, "duplicate_response_option");
    seenOptions.add(normalizedOption);
    options.push({ englishTranslation });
  }

  const matchingTargetCount =
    options.filter((option) =>
      normalizeForGrounding(option.englishTranslation) === normalizeForGrounding(targetTranslation)
    ).length;
  if (
    matchingTargetCount !== 1 ||
    normalizeForGrounding(options[Number(correctOptionIndex)].englishTranslation) !==
      normalizeForGrounding(targetTranslation)
  ) {
    return reject(validation, "response_target_mismatch");
  }

  return {
    promptTagalog,
    promptTranslation,
    options,
    correctOptionIndex: Number(correctOptionIndex),
  };
}

function normalizeGlossToken(value: string): string {
  return value.toLocaleLowerCase("fil").replace(/[\p{P}\p{S}]+/gu, "");
}

function chunksAppearInOrder(phrase: string, chunks: string[]): boolean {
  const normalizedPhrase = normalizeForGrounding(phrase);
  let cursor = 0;
  for (const chunk of chunks) {
    const normalizedChunk = normalizeForGrounding(chunk);
    const index = normalizedPhrase.indexOf(normalizedChunk, cursor);
    if (index < 0) return false;
    // Reusable chunks may overlap (for example, a short address term inside a
    // longer request). They must move left-to-right, but need not partition
    // the utterance into non-overlapping slices.
    cursor = index;
  }
  return true;
}

function normalizedIncludes(haystack: string, needle: string): boolean {
  return normalizeForGrounding(haystack).includes(normalizeForGrounding(needle));
}

function normalizeForGrounding(value: string): string {
  return value.normalize("NFC").toLocaleLowerCase("fil").replace(/\s+/gu, " ").trim();
}

function hasLeadingSpeakerLabel(value: string): boolean {
  return /^[\p{L}\s·-]{1,60}[:：]\s*\S/u.test(value);
}

/**
 * Tagalog shares the Latin alphabet with English, so interface copy is checked
 * for Tagalog function words instead of letters. One word is allowed (a
 * culture term such as "po" or "Lola" can be part of an English title); two
 * distinct ones mean the copy is a Tagalog sentence. Full utterance leakage is
 * independently rejected below.
 */
export function containsTagalogSentence(value: string): boolean {
  const words = value.normalize("NFC").toLocaleLowerCase("fil").match(/\p{L}+/gu) ?? [];
  const found = new Set(words.filter((word) => tagalogFunctionWords.has(word)));
  return found.size >= 2;
}

// Common Tagalog words that never appear in English copy. Ambiguous ones such
// as "na", "ba" and "din" are left out on purpose.
const tagalogFunctionWords = new Set([
  "ang",
  "ng",
  "mga",
  "ako",
  "ikaw",
  "siya",
  "kami",
  "tayo",
  "kayo",
  "sila",
  "hindi",
  "opo",
  "po",
  "salamat",
  "kumusta",
  "ito",
  "iyan",
  "iyon",
  "dito",
  "doon",
  "naman",
  "lang",
  "rin",
  "yung",
  "ninyo",
  "natin",
  "namin",
  "akin",
  "magkano",
  "saan",
  "ano",
  "paano",
]);

function interfaceCopyRevealsUtterance(copy: string, utterance: string): boolean {
  const normalizedCopy = normalizeForAnswerLeakage(copy);
  const normalizedUtterance = normalizeForAnswerLeakage(utterance);
  return normalizedCopy.length >= 8 && normalizedUtterance.length >= 8 &&
    (normalizedCopy.includes(normalizedUtterance) ||
      normalizedUtterance.includes(normalizedCopy));
}

function normalizeForAnswerLeakage(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{M}+/gu, "")
    .toLocaleLowerCase("en")
    .replace(/[^a-z0-9]+/gu, " ")
    .trim()
    .replace(/\s+/gu, " ");
}

function containsProhibitedLessonSubject(value: string): boolean {
  return /\b(?:suicide|self[- ]?harm|murder|weapon|gun|bomb|cocaine|heroin|porn(?:ography)?|sexual|gambling|political campaign)\b|\b(?:magpakamatay|pagpapakamatay|baril|bomba|droga|shabu|sugal|pornograpiya)\b/iu
    .test(value);
}

function validateVocabulary(
  value: unknown,
  validation: ValidationContext,
): GeneratedVocabulary | null {
  if (!isPlainObject(value)) return reject(validation, "vocabulary_shape");
  const tagalog = boundedText(value.tagalog, 1, 100);
  const english = boundedText(value.english, 1, 140);
  const example = boundedTagalog(value.example, 1, 240);
  const exampleTranslation = boundedText(value.example_translation, 1, 240);
  const result = tagalog && english && example && exampleTranslation &&
      !hasLeadingSpeakerLabel(example) && !hasLeadingSpeakerLabel(exampleTranslation)
    ? { tagalog, english, example, exampleTranslation }
    : null;
  return result ?? reject(validation, "vocabulary_fields");
}

function reject<T>(validation: ValidationContext, issue: string): T | null {
  validation.issue ??= issue;
  return null;
}

function parseProfile(value: unknown): LearnerProfileInput {
  if (!isPlainObject(value)) {
    throw new HttpError(400, "invalid_profile", "A learner profile is required.");
  }
  assertExactKeys(value, [
    "goal",
    "self_assessed_level",
    "target_level",
    "challenge_preference",
    "daily_minutes",
  ]);
  const goals: Goal[] = [
    "family",
    "lifeInThePhilippines",
    "travel",
    "partner",
    "work",
    "culture",
  ];
  const levels: SelfAssessedLevel[] = ["beginner", "intermediate", "advanced"];
  const challenges: ChallengePreference[] = ["gentle", "balanced", "stretch"];
  if (
    !goals.includes(value.goal as Goal) ||
    !levels.includes(value.self_assessed_level as SelfAssessedLevel) ||
    !challenges.includes(value.challenge_preference as ChallengePreference) ||
    !Number.isInteger(value.target_level) || Number(value.target_level) < 1 ||
    Number(value.target_level) > 5 ||
    !Number.isInteger(value.daily_minutes) || Number(value.daily_minutes) < 3 ||
    Number(value.daily_minutes) > 30
  ) {
    throw new HttpError(400, "invalid_profile", "The learner profile is invalid.");
  }
  return {
    goal: value.goal as Goal,
    selfAssessedLevel: value.self_assessed_level as SelfAssessedLevel,
    targetLevel: Number(value.target_level),
    challengePreference: value.challenge_preference as ChallengePreference,
    dailyMinutes: Number(value.daily_minutes),
  };
}

function parseRating(value: unknown): DifficultyRating {
  if (value === "too_easy" || value === "just_right" || value === "too_hard") return value;
  throw new HttpError(400, "invalid_feedback", "Choose too easy, just right, or too hard.");
}

function parsePaceRating(value: unknown): PaceRating {
  if (value === "too_slow" || value === "pace_right" || value === "too_fast") return value;
  throw new HttpError(400, "invalid_pace_feedback", "Choose too slow, just right, or too fast.");
}

function parseNullableUUID(value: unknown): string | null {
  return value === null ? null : parseUUID(value, "generated_lesson_id");
}

function parseNullableLessonID(value: unknown): string | null {
  if (value === null) return null;
  // Authored lessons predate the generated-content schema and use stable UUID-
  // shaped seed IDs whose version/variant nibbles are zero. This field is only
  // used to exclude a queue result; ownership-sensitive identifiers below
  // remain restricted to RFC 4122 versions 1–5.
  if (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  ) {
    return value;
  }
  throw new HttpError(400, "invalid_identifier", "The excluding_lesson_id is invalid.");
}

function parseUUID(value: unknown, field: string): string {
  if (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
  ) {
    return value;
  }
  throw new HttpError(400, "invalid_identifier", `The ${field} is invalid.`);
}

/** Tagalog is written in Latin letters (ñ and stress marks included); other scripts are rejected. */
function boundedTagalog(value: unknown, minimum: number, maximum: number): string | null {
  const text = boundedText(value, minimum, maximum);
  if (
    !text || !/\p{Script=Latin}/u.test(text) ||
    /[^\p{Script=Latin}\p{M}\p{N}\p{P}\p{Zs}\p{S}]/u.test(text)
  ) {
    return null;
  }
  return text;
}

function boundedText(value: unknown, minimum: number, maximum: number): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().replace(/\s+/gu, " ");
  if (
    normalized.length < minimum || normalized.length > maximum ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(normalized) ||
    /(?:https?:\/\/|<\/?script|javascript:|\bprompt injection\b)/iu.test(normalized)
  ) return null;
  return normalized;
}

function parseClientMaxPromptVersion(value: unknown): number {
  if (value === undefined) return legacyClientMaximumLessonPromptVersion;
  if (!Number.isInteger(value) || Number(value) < 10 || Number(value) > 100) {
    throw new HttpError(
      400,
      "invalid_client_prompt_version",
      "The supported lesson prompt version is invalid.",
    );
  }
  return Number(value);
}

function assertExactKeys(value: Record<string, unknown>, expectedKeys: readonly string[]): void {
  const expected = new Set(expectedKeys);
  const actual = Object.keys(value);
  if (actual.length !== expected.size || actual.some((key) => !expected.has(key))) {
    throw new HttpError(400, "invalid_request", "The request contains unsupported fields.");
  }
}

function assertRequiredAndOptionalKeys(
  value: Record<string, unknown>,
  requiredKeys: readonly string[],
  optionalKeys: readonly string[],
): void {
  const allowed = new Set([...requiredKeys, ...optionalKeys]);
  const actual = Object.keys(value);
  if (
    requiredKeys.some((key) => !Object.hasOwn(value, key)) ||
    actual.some((key) => !allowed.has(key))
  ) {
    throw new HttpError(400, "invalid_request", "The request contains unsupported fields.");
  }
}
