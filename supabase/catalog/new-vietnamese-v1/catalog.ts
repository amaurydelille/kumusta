import {
  type Accent,
  type GeneratedLessonDraft,
  validateGeneratedBatchDetailed,
} from "../../functions/kumusta-lessons/contract.ts";
import { glossVietnameseSentence } from "./word-gloss-lexicon.ts";

export interface SegmentSpec {
  vi: string;
  en: string;
  note?: string;
}

export interface RoundSpec {
  situation: string;
  translation: string;
  speakingPrompt: string;
  southern: SegmentSpec[];
  northern?: SegmentSpec[];
}

export interface LessonSpec {
  order: number;
  unitOrder: number;
  unitSlug: string;
  unitTitle: string;
  title: string;
  scenario: string;
  difficulty: number;
  rounds: RoundSpec[];
}

export interface BuiltRoadmapLesson {
  id: string;
  slug: string;
  summary: string;
  level: "new" | "familiar" | "conversational" | "rusty";
  accent: Accent;
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
  contentSource: "authored_roadmap";
  reviewStatus: "native_speaker_review_required";
  content: GeneratedLessonDraft;
  contentHash: string;
  validation: Record<string, unknown>;
}

export interface RoadmapBuildConfig {
  roadmapVersion: string;
  level: BuiltRoadmapLesson["level"];
  expectedLessonCount: number;
  uuidFamily: string;
  distractorsFromLesson?: boolean;
}

export const roadmapVersion = "new-v1";
export const lessonSchemaVersion = 3;
export const lessonPromptVersion = 14;
const defaultBuildConfig: RoadmapBuildConfig = {
  roadmapVersion,
  level: "new",
  expectedLessonCount: 30,
  uuidFamily: "4100",
  distractorsFromLesson: true,
};

export function segment(vi: string, en: string, note?: string): SegmentSpec {
  return { vi, en, note };
}

export function round(
  situation: string,
  translation: string,
  speakingPrompt: string,
  southern: SegmentSpec[],
  northern?: SegmentSpec[],
): RoundSpec {
  return { situation, translation, speakingPrompt, southern, northern };
}

export async function buildRoadmap(
  specs: LessonSpec[],
  config: RoadmapBuildConfig = defaultBuildConfig,
): Promise<BuiltRoadmapLesson[]> {
  assertCatalogShape(specs, config.expectedLessonCount);
  const output: BuiltRoadmapLesson[] = [];
  for (const spec of specs) {
    for (const accent of ["southern", "northern"] as const) {
      const rawLesson = toRawLesson(spec, accent, config);
      const validation = validateGeneratedBatchDetailed(
        { version: 1, lessons: [rawLesson] },
        1,
        accent,
        5,
        5,
        true,
      );
      if (!validation.batch) {
        throw new Error(
          `Roadmap lesson ${spec.order} (${accent}) failed contract validation: ${validation.issue}`,
        );
      }
      const content = validation.batch.lessons[0];
      const contentHash = await sha256Hex(JSON.stringify(content));
      output.push({
        id: roadmapUUID(spec.order, accent, config),
        slug: `${config.level}-${String(spec.order).padStart(2, "0")}-${
          slugify(spec.title)
        }-${accent}`,
        summary: spec.scenario,
        level: config.level,
        accent,
        estimatedMinutes: 5,
        sortOrder: spec.order,
        contentVersion: 1,
        roadmapVersion: config.roadmapVersion,
        unitSlug: spec.unitSlug,
        unitTitle: spec.unitTitle,
        unitOrder: spec.unitOrder,
        lessonOrder: spec.order,
        schemaVersion: lessonSchemaVersion,
        promptVersion: lessonPromptVersion,
        difficulty: spec.difficulty,
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
  }
  return output;
}

const fallbackDistractors = [
  "Please tell me where the nearest station is.",
  "I would like another bottle of water.",
] as const;

/// Picks the next two translations after the target round that differ from the
/// target and from each other. Some lessons repeat a meaning across rounds
/// (several greetings all mean "Hello."), so neighbours alone can collide.
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

function toRawLesson(
  spec: LessonSpec,
  accent: Accent,
  config: RoadmapBuildConfig,
): Record<string, unknown> {
  const builtRounds = spec.rounds.map((item) => {
    const segments = accent === "northern" ? item.northern ?? item.southern : item.southern;
    assertSegments(spec, segments);
    const vietnamese = segments.map((value) => value.vi).join(" ");
    return {
      topic_key: scenarioKey(spec, config),
      situation: item.situation,
      vietnamese,
      translation: item.translation,
      chunks: segments.map((value, index) => ({
        vietnamese: value.vi,
        english: value.en,
        note: value.note ?? defaultChunkNote(index, segments.length),
      })),
      word_glosses: glossVietnameseSentence(vietnamese),
      speaking_prompt: item.speakingPrompt,
    };
  });

  for (const roundIndex of [2, 4]) {
    const target = builtRounds[roundIndex];
    const [distractorA, distractorB] = config.distractorsFromLesson
      ? lessonDistractors(builtRounds.map((value) => value.translation), roundIndex)
      : fallbackDistractors;
    Object.assign(target, {
      response_exercise: {
        prompt_vietnamese: target.vietnamese,
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
      const vietnamese = stripTerminalPunctuation(chunk.vietnamese);
      const key = vietnamese.toLocaleLowerCase("vi");
      if (!vietnamese || seen.has(key)) continue;
      seen.add(key);
      vocabulary.push({
        vietnamese,
        english: chunk.english,
        example: builtRound.vietnamese,
        example_translation: builtRound.translation,
      });
      if (vocabulary.length === 10) break;
    }
    if (vocabulary.length === 10) break;
  }
  for (const builtRound of builtRounds) {
    if (vocabulary.length >= 8) break;
    const vietnamese = stripTerminalPunctuation(builtRound.vietnamese);
    const key = vietnamese.toLocaleLowerCase("vi");
    if (seen.has(key)) continue;
    seen.add(key);
    vocabulary.push({
      vietnamese,
      english: builtRound.translation,
      example: builtRound.vietnamese,
      example_translation: builtRound.translation,
    });
  }
  if (vocabulary.length < 8) {
    throw new Error(
      `Roadmap lesson ${spec.order} has only ${vocabulary.length} vocabulary chunks.`,
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
  }
}

function assertSegments(spec: LessonSpec, segments: SegmentSpec[]): void {
  if (segments.length < 2 || segments.length > 5) {
    throw new Error(`Roadmap lesson ${spec.order} has an invalid chunk count.`);
  }
}

function scenarioKey(spec: LessonSpec, config: RoadmapBuildConfig): string {
  return `roadmap_${config.level}_${String(spec.order).padStart(2, "0")}_${
    spec.unitSlug.replaceAll("-", "_")
  }`;
}

function roadmapUUID(order: number, accent: Accent, config: RoadmapBuildConfig): string {
  const accentCode = accent === "southern" ? "8101" : "8102";
  return `${config.uuidFamily}0000-0000-4000-${accentCode}-${String(order).padStart(12, "0")}`;
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
