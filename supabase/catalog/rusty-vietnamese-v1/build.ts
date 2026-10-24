import { buildRoadmap } from "./catalog.ts";
import { unit01 } from "./unit-01.ts";
import { unit02 } from "./unit-02.ts";
import { unit03 } from "./unit-03.ts";
import { unit04 } from "./unit-04.ts";
import { unit05 } from "./unit-05.ts";
import { unit06 } from "./unit-06.ts";

const lessons = await buildRoadmap([unit01, unit02, unit03, unit04, unit05, unit06].flat());
const supabaseRoot = new URL("../../", import.meta.url);
const projectRoot = new URL("../../../", import.meta.url);
const jsonURL = new URL("catalog/rusty-vietnamese-v1.json", supabaseRoot);
const bundledURL = new URL("Kumusta/Resources/Seed/rusty-vietnamese-v1.json", projectRoot);
const migrationURL = new URL(
  "migrations/20260909140000_seed_kumusta_rusty_roadmap_v1.sql",
  supabaseRoot,
);
const document = `${JSON.stringify({ version: 1, roadmap: "rusty-v1", lessons }, null, 2)}\n`;

await Deno.writeTextFile(jsonURL, document);
await Deno.writeTextFile(bundledURL, document);
await Deno.writeTextFile(migrationURL, renderSeedMigration(lessons));
console.log(`Validated and generated ${lessons.length} accent-specific advanced lesson rows.`);

function renderSeedMigration(rows: Awaited<ReturnType<typeof buildRoadmap>>): string {
  const values = rows.map((lesson) =>
    `(
    '${lesson.id}'::uuid,
    ${literal(lesson.slug)}, ${literal(lesson.content.title)}, ${literal(lesson.summary)},
    ${literal(lesson.level)}, ${literal(lesson.accent)}, ${lesson.estimatedMinutes}, ${lesson.sortOrder}, false, 1,
    ${literal(lesson.roadmapVersion)}, ${literal(lesson.unitSlug)}, ${literal(lesson.unitTitle)},
    ${lesson.unitOrder}, ${lesson.lessonOrder}, ${lesson.schemaVersion}, ${lesson.promptVersion},
    ${lesson.difficulty.toFixed(2)}, ${literal(lesson.contentSource)}, ${literal(lesson.reviewStatus)},
    ${jsonLiteral(lesson.content)}, ${literal(lesson.contentHash)}, ${jsonLiteral(lesson.validation)}
  )`
  ).join(",\n");
  return `begin;

insert into public.kumusta_lessons (
  id, slug, title, summary, level, accent, estimated_minutes, sort_order,
  is_published, content_version, roadmap_version, unit_slug, unit_title,
  unit_order, lesson_order, schema_version, prompt_version, difficulty,
  content_source, review_status, content, content_hash, validation
) values
${values}
on conflict (slug) do update set
  title = excluded.title,
  summary = excluded.summary,
  level = excluded.level,
  accent = excluded.accent,
  estimated_minutes = excluded.estimated_minutes,
  sort_order = excluded.sort_order,
  is_published = false,
  content_version = excluded.content_version,
  roadmap_version = excluded.roadmap_version,
  unit_slug = excluded.unit_slug,
  unit_title = excluded.unit_title,
  unit_order = excluded.unit_order,
  lesson_order = excluded.lesson_order,
  schema_version = excluded.schema_version,
  prompt_version = excluded.prompt_version,
  difficulty = excluded.difficulty,
  content_source = excluded.content_source,
  review_status = 'native_speaker_review_required',
  editorial_review = '{}'::jsonb,
  content = excluded.content,
  content_hash = excluded.content_hash,
  validation = excluded.validation,
  updated_at = now();

commit;
`;
}

function literal(value: string): string {
  return `'${value.replaceAll("'", "''")}'`;
}

function jsonLiteral(value: unknown): string {
  return `${literal(JSON.stringify(value))}::jsonb`;
}
