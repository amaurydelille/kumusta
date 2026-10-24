import {
  buildRoadmap as buildConfiguredRoadmap,
  type BuiltRoadmapLesson,
  type LessonSpec,
  type RoadmapBuildConfig,
  round,
  segment,
} from "../new-vietnamese-v1/catalog.ts";

export type { BuiltRoadmapLesson, LessonSpec };
export { round, segment };

export const roadmapVersion = "familiar-v1";

const config: RoadmapBuildConfig = {
  roadmapVersion,
  level: "familiar",
  expectedLessonCount: 20,
  uuidFamily: "4200",
  distractorsFromLesson: true,
};

export function buildRoadmap(specs: LessonSpec[]): Promise<BuiltRoadmapLesson[]> {
  return buildConfiguredRoadmap(specs, config);
}
