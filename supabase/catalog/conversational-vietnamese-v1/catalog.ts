import {
  buildRoadmap as buildConfiguredRoadmap,
  type BuiltRoadmapLesson,
  type LessonSpec,
  type RoadmapBuildConfig,
  round,
  segment,
} from "../new-vietnamese-v1/catalog.ts";

export type { BuiltRoadmapLesson, LessonSpec };

export const roadmapVersion = "conversational-v1";

const config: RoadmapBuildConfig = {
  roadmapVersion,
  level: "conversational",
  expectedLessonCount: 30,
  uuidFamily: "4300",
  distractorsFromLesson: true,
};

type ChunkPair = readonly [vietnamese: string, english: string];
type TwoPartLine = readonly [ChunkPair, ChunkPair];

export function spokenRound(
  situation: string,
  translation: string,
  speakingPrompt: string,
  southern: TwoPartLine,
  northern?: TwoPartLine,
) {
  return round(
    situation,
    translation,
    speakingPrompt,
    southern.map(([vi, en]) => segment(vi, en)),
    northern?.map(([vi, en]) => segment(vi, en)),
  );
}

export function buildRoadmap(specs: LessonSpec[]): Promise<BuiltRoadmapLesson[]> {
  return buildConfiguredRoadmap(specs, config);
}
