import {
  buildRoadmap as buildConfiguredRoadmap,
  type BuiltRoadmapLesson,
  type LessonSpec,
  type RoadmapBuildConfig,
  round,
  segment,
} from "../new-vietnamese-v1/catalog.ts";

export type { BuiltRoadmapLesson, LessonSpec };

export const roadmapVersion = "rusty-v1";

const config: RoadmapBuildConfig = {
  roadmapVersion,
  level: "rusty",
  expectedLessonCount: 30,
  uuidFamily: "4400",
  distractorsFromLesson: true,
};

export function spokenRound(
  situation: string,
  translation: string,
  speakingPrompt: string,
  southernVietnamese: string,
  southernEnglish: string,
  northernVietnamese?: string,
  northernEnglish?: string,
) {
  const southern = chunks(southernVietnamese, southernEnglish);
  const northern = northernVietnamese && northernEnglish
    ? chunks(northernVietnamese, northernEnglish)
    : undefined;
  return round(situation, translation, speakingPrompt, southern, northern);
}

export function buildRoadmap(specs: LessonSpec[]): Promise<BuiltRoadmapLesson[]> {
  return buildConfiguredRoadmap(specs, config);
}

function chunks(vietnamese: string, english: string) {
  const vi = vietnamese.split("|");
  const en = english.split("|");
  if (vi.length !== 2 || en.length !== 2) {
    throw new Error("Advanced roadmap lines must contain exactly two authored chunks.");
  }
  return vi.map((value, index) => segment(value.trim(), en[index].trim()));
}
