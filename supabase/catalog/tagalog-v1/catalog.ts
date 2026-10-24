import {
  type GeneratedLessonDraft,
  type GeneratedWordGloss,
  validateGeneratedBatchDetailed,
} from "../../functions/kumusta-lessons/contract.ts";

export type RoadmapLevel = "beginner" | "intermediate" | "advanced";

export interface SegmentSpec {
  tl: string;
  en: string;
  note?: string;
}

export interface RoundSpec {
  situation: string;
  translation: string;
  speakingPrompt: string;
  segments: SegmentSpec[];
}

export interface LessonSpec {
  order: number;
  unitOrder: number;
  unitSlug: string;
  unitTitle: string;
  title: string;
  scenario: string;
  difficulty: number;
  goalTags: GoalTag[];
  rounds: RoundSpec[];
}

/** Onboarding goals a lesson serves, used to reorder the roadmap per learner. */
export type GoalTag =
  | "family"
  | "partner"
  | "travel"
  | "lifeInThePhilippines"
  | "work"
  | "culture";

/**
 * Contextual English for each Tagalog word, keyed by the lowercased token with
 * punctuation removed. Two-word keys ("salamat po") gloss a pair together and
 * win over the single words.
 */
export type Lexicon = Record<string, string>;

export interface BuiltRoadmapLesson {
  id: string;
  slug: string;
  summary: string;
  level: RoadmapLevel;
  estimatedMinutes: number;
  sortOrder: number;
  contentVersion: number;
  roadmapVersion: string;
  unitSlug: string;
  unitTitle: string;
  unitOrder: number;
  lessonOrder: number;
  schemaVersion: number;
  promptVersion: number;
  difficulty: number;
  goalTags: GoalTag[];
  contentSource: "authored_roadmap";
  reviewStatus: "native_speaker_review_required";
  content: GeneratedLessonDraft;
  contentHash: string;
  validation: Record<string, unknown>;
}

export interface RoadmapBuildConfig {
  level: RoadmapLevel;
  expectedLessonCount: number;
  /** First UUID group prefix, e.g. "4301" for beginner. */
  uuidFamily: string;
  lexicon: Lexicon;
}

export const lessonSchemaVersion = 3;
export const lessonPromptVersion = 14;

export function roadmapVersion(level: RoadmapLevel): string {
  return `${level}-v1`;
}

export function segment(tl: string, en: string, note?: string): SegmentSpec {
  return { tl, en, note };
}

export function round(
  situation: string,
  translation: string,
  speakingPrompt: string,
  segments: SegmentSpec[],
): RoundSpec {
  return { situation, translation, speakingPrompt, segments };
}

export async function buildRoadmap(
  specs: LessonSpec[],
  config: RoadmapBuildConfig,
): Promise<BuiltRoadmapLesson[]> {
  assertCatalogShape(specs, config.expectedLessonCount);
  const output: BuiltRoadmapLesson[] = [];
  for (const spec of specs) {
    const rawLesson = toRawLesson(spec, config);
    const validation = validateGeneratedBatchDetailed(
      { version: 1, lessons: [rawLesson] },
      1,
      5,
      5,
      true,
    );
    if (!validation.batch) {
      throw new Error(
        `${config.level} lesson ${spec.order} failed contract validation: ${validation.issue}`,
      );
    }
    const content = validation.batch.lessons[0];
    const contentHash = await sha256Hex(JSON.stringify(content));
    output.push({
      id: roadmapUUID(spec.order, config),
      slug: `${config.level}-${String(spec.order).padStart(2, "0")}-${slugify(spec.title)}`,
      summary: spec.scenario,
      level: config.level,
      estimatedMinutes: 5,
      sortOrder: spec.order,
      contentVersion: 1,
      roadmapVersion: roadmapVersion(config.level),
      unitSlug: spec.unitSlug,
      unitTitle: spec.unitTitle,
      unitOrder: spec.unitOrder,
      lessonOrder: spec.order,
      schemaVersion: lessonSchemaVersion,
      promptVersion: lessonPromptVersion,
      difficulty: spec.difficulty,
      goalTags: spec.goalTags,
      contentSource: "authored_roadmap",
      reviewStatus: "native_speaker_review_required",
      content,
      contentHash,
      validation: {
        contract: "kumusta_lesson_v3",
        structured_output: true,
        local_validation: true,
        ordered_chunks: true,
        vocabulary_grounded: true,
        vocabulary_examples_grounded: true,
        hear_respond_rounds: [2, 4],
        authored_curriculum: true,
        native_speaker_review: false,
      },
    });
  }
  return output;
}

const fallbackDistractors = [
  "Please tell me where the nearest station is.",
  "I would like another bottle of water.",
] as const;

/// Picks the next two translations after the target round that differ from the
/// target and from each other, so the three options are always distinct.
function lessonDistractors(translations: string[], targetIndex: number): [string, string] {
  const normalize = (value: string) => value.trim().toLocaleLowerCase("en");
  const seen = new Set([normalize(translations[targetIndex])]);
  const picked: string[] = [];
  for (let offset = 1; offset < translations.length && picked.length < 2; offset += 1) {
    const candidate = translations[(targetIndex + offset) % translations.length];
    if (seen.has(normalize(candidate))) continue;
    seen.add(normalize(candidate));
    picked.push(candidate);
  }
  for (const fallback of fallbackDistractors) {
    if (picked.length === 2) break;
    if (!seen.has(normalize(fallback))) picked.push(fallback);
  }
  return [picked[0], picked[1]];
}

function toRawLesson(spec: LessonSpec, config: RoadmapBuildConfig): Record<string, unknown> {
  const builtRounds = spec.rounds.map((item, roundIndex) => {
    assertSegments(spec, roundIndex, item.segments);
    const tagalog = item.segments.map((value) => value.tl).join(" ");
    return {
      topic_key: scenarioKey(spec, config),
      situation: item.situation,
      tagalog,
      translation: item.translation,
      chunks: item.segments.map((value, index) => ({
        tagalog: value.tl,
        english: value.en,
        note: value.note ?? defaultChunkNote(index, item.segments.length),
      })),
      word_glosses: glossTagalogSentence(tagalog, config.lexicon, `${config.level} ${spec.order}`),
      speaking_prompt: item.speakingPrompt,
    };
  });

  for (const roundIndex of [2, 4]) {
    const target = builtRounds[roundIndex];
    const [distractorA, distractorB] = lessonDistractors(
      builtRounds.map((value) => value.translation),
      roundIndex,
    );
    Object.assign(target, {
      response_exercise: {
        prompt_tagalog: target.tagalog,
        prompt_translation: target.translation,
        options: [
          { english_translation: distractorA },
          { english_translation: target.translation },
          { english_translation: distractorB },
        ],
        correct_option_index: 1,
      },
    });
  }

  const vocabulary: Array<Record<string, string>> = [];
  const seen = new Set<string>();
  for (const builtRound of builtRounds) {
    for (const chunk of builtRound.chunks) {
      const tagalog = stripTerminalPunctuation(chunk.tagalog);
      const key = tagalog.toLocaleLowerCase("fil");
      if (!tagalog || seen.has(key)) continue;
      seen.add(key);
      vocabulary.push({
        tagalog,
        english: chunk.english,
        example: builtRound.tagalog,
        example_translation: builtRound.translation,
      });
      if (vocabulary.length === 10) break;
    }
    if (vocabulary.length === 10) break;
  }
  for (const builtRound of builtRounds) {
    if (vocabulary.length >= 8) break;
    const tagalog = stripTerminalPunctuation(builtRound.tagalog);
    const key = tagalog.toLocaleLowerCase("fil");
    if (seen.has(key)) continue;
    seen.add(key);
    vocabulary.push({
      tagalog,
      english: builtRound.translation,
      example: builtRound.tagalog,
      example_translation: builtRound.translation,
    });
  }
  if (vocabulary.length < 8) {
    throw new Error(
      `${config.level} lesson ${spec.order} has only ${vocabulary.length} vocabulary chunks.`,
    );
  }

  return {
    title: spec.title,
    scenario_key: scenarioKey(spec, config),
    scenario: spec.scenario,
    minutes: 5,
    difficulty: spec.difficulty,
    rounds: builtRounds,
    vocabulary,
  };
}

/**
 * Glosses every whitespace token of an utterance from the lexicon. A missing
 * word fails the build with its location, so the lexicon stays complete.
 */
export function glossTagalogSentence(
  utterance: string,
  lexicon: Lexicon,
  location: string,
): GeneratedWordGloss[] {
  const tokens = utterance.split(/\s+/u);
  const glosses: GeneratedWordGloss[] = [];
  for (let index = 0; index < tokens.length;) {
    const pair = index + 1 < tokens.length
      ? lexicon[`${lexiconKey(tokens[index])} ${lexiconKey(tokens[index + 1])}`]
      : undefined;
    if (pair) {
      glosses.push({ token: `${tokens[index]} ${tokens[index + 1]}`, english: pair });
      index += 2;
      continue;
    }
    const single = lexicon[lexiconKey(tokens[index])];
    if (!single) {
      throw new Error(`Missing lexicon entry for "${lexiconKey(tokens[index])}" (${location}).`);
    }
    glosses.push({ token: tokens[index], english: single });
    index += 1;
  }
  return glosses;
}

export function lexiconKey(token: string): string {
  // Keep in-word hyphens and apostrophes ("halo-halo", "nag-'hi'"); drop the rest.
  return token.normalize("NFC").toLocaleLowerCase("fil")
    .replace(/[^\p{L}\p{N}'’-]+/gu, "")
    .replace(/^[-'’]+|[-'’]+$/gu, "");
}

function assertCatalogShape(specs: LessonSpec[], expectedLessonCount: number): void {
  if (specs.length !== expectedLessonCount) {
    throw new Error(`Expected ${expectedLessonCount} lessons, received ${specs.length}.`);
  }
  const orders = specs.map((spec) => spec.order);
  if (
    new Set(orders).size !== expectedLessonCount ||
    orders.some((order, index) => order !== index + 1)
  ) {
    throw new Error(`Roadmap lesson order must be exactly 1 through ${expectedLessonCount}.`);
  }
  for (const spec of specs) {
    if (spec.rounds.length !== 5) {
      throw new Error(`Roadmap lesson ${spec.order} must contain exactly five rounds.`);
    }
    if (spec.goalTags.length === 0) {
      throw new Error(`Roadmap lesson ${spec.order} needs at least one goal tag.`);
    }
  }
}

function assertSegments(spec: LessonSpec, roundIndex: number, segments: SegmentSpec[]): void {
  if (segments.length < 2 || segments.length > 5) {
    throw new Error(
      `Roadmap lesson ${spec.order} round ${roundIndex + 1} needs 2 to 5 segments.`,
    );
  }
}

function scenarioKey(spec: LessonSpec, config: RoadmapBuildConfig): string {
  return `roadmap_${config.level}_${String(spec.order).padStart(2, "0")}_${
    spec.unitSlug.replaceAll("-", "_")
  }`;
}

function roadmapUUID(order: number, config: RoadmapBuildConfig): string {
  return `${config.uuidFamily}0000-0000-4000-8100-${String(order).padStart(12, "0")}`;
}

function slugify(value: string): string {
  return value.toLocaleLowerCase("en-US").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function stripTerminalPunctuation(value: string): string {
  return value.replace(/[.!?,;:]+$/u, "").trim();
}

function defaultChunkNote(index: number, count: number): string {
  if (index === 0) return "Start the thought with this reusable chunk.";
  if (index === count - 1) return "Use this ending to complete the spoken thought naturally.";
  return "Keep this chunk together in the middle of the sentence.";
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
