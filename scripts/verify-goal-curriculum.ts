import { validateGeneratedBatchDetailed } from "../supabase/functions/kumusta-lessons/contract.ts";
import { assignment, goals } from "../supabase/functions/kumusta-curriculum-admin/plan.ts";

// Reads only lesson catalog data; credentials stay in memory. Publication is a separate step.
const project = "vpitjvtfzpqfnqgzcpla";
const result = await new Deno.Command("supabase", { args: ["projects", "api-keys", "--project-ref", project, "--reveal", "-o", "json"], stdout: "piped", stderr: "piped" }).output();
if (!result.success) throw new Error("Unable to obtain operations credential");
const parsed = JSON.parse(new TextDecoder().decode(result.stdout));
const keys = Array.isArray(parsed) ? parsed : parsed.api_keys ?? parsed.keys;
const key = keys?.find((k: { name: string }) => k.name === "service_role")?.api_key;
if (!key) throw new Error("Missing operations credential");
const response = await fetch(`https://${project}.supabase.co/rest/v1/kumusta_goal_lessons?curriculum_version=eq.goals-v1&select=*&order=goal,stage,accent,lesson_order`, {
  headers: { apikey: key, Authorization: `Bearer ${key}` },
});
if (!response.ok) throw new Error(`Catalog read failed: ${response.status}`);
const rows = await response.json();
function snake(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(snake);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k,v]) => [k.replace(/[A-Z]/g, c => `_${c.toLowerCase()}`), snake(v)]));
  return value;
}
const issues: string[] = [];
const counts: Record<string, number> = {};
let generationInput = 0, generationOutput = 0, reviewInput = 0, reviewOutput = 0;
for (const row of rows) {
  const slot = `${row.goal}/${row.stage}/${row.accent}/${row.lesson_order}`;
  const group = `${row.goal}/${row.stage}/${row.accent}`;
  counts[group] = (counts[group] ?? 0) + 1;
  const check = validateGeneratedBatchDetailed({ version: 1, lessons: [snake(row.content)] }, 1, row.accent, 5, 5, true);
  if (!check.batch) issues.push(`${slot}: contract ${check.issue}`);
  const brief = assignment(row.goal, row.stage, row.lesson_order, row.accent);
  if (row.content.scenarioKey !== brief.required_scenario_key || Math.abs(row.content.difficulty - brief.difficulty) > 0.02) issues.push(`${slot}: assignment mismatch`);
  if (!row.review.passed || row.review.issues.length || row.review.naturalness_score < 4) issues.push(`${slot}: review failed`);
  if (/contextual meaning/i.test(JSON.stringify(row.content))) issues.push(`${slot}: placeholder gloss`);
  for (const [i, round] of row.content.rounds.entries()) {
    if (/\b(?:choose|select|correct.*meaning)\b/i.test(round.speakingPrompt)) issues.push(`${slot}: round ${i + 1} speaking prompt`);
    if (Boolean(round.responseExercise) !== [2,4].includes(i)) issues.push(`${slot}: round ${i + 1} exercise placement`);
    if (row.stage === 1 && round.vietnamese.split(/\s+/u).length > 9) issues.push(`${slot}: beginner length`);
  }
  generationInput += row.usage.generation.prompt_tokens ?? 0;
  generationOutput += row.usage.generation.completion_tokens ?? 0;
  reviewInput += row.usage.review.prompt_tokens ?? 0;
  reviewOutput += row.usage.review.completion_tokens ?? 0;
}
for (const goal of goals) for (const stage of [1,2,3,4]) for (const accent of ["southern", "northern"]) {
  const group = `${goal}/${stage}/${accent}`;
  const orders = rows.filter((r: {goal:string;stage:number;accent:string}) => r.goal === goal && r.stage === stage && r.accent === accent).map((r: {lesson_order:number}) => r.lesson_order).sort((a:number,b:number) => a-b);
  if (orders.join(",") !== "1,2,3,4,5,6,7,8,9,10") issues.push(`${group}: incomplete orders [${orders}]`);
}
const report = { lessons: rows.length, published: rows.filter((r: {is_published:boolean}) => r.is_published).length, counts, issues,
  averageTokensPerAcceptedLesson: { generationInput: generationInput / rows.length, generationOutput: generationOutput / rows.length, reviewInput: reviewInput / rows.length, reviewOutput: reviewOutput / rows.length },
  tokenScope: "Successful stored generation and editorial review only; unsuccessful attempts are not included." };
console.log(JSON.stringify(report, null, 2));
const exportPath = Deno.args.find(a => a.startsWith("--export="))?.slice(9);
if (exportPath && issues.length === 0 && rows.length === 320) {
  await Deno.writeTextFile(exportPath, JSON.stringify(rows, null, 2) + "\n");
  await Deno.writeTextFile(`${exportPath}.report.json`, JSON.stringify(report, null, 2) + "\n");
}
if (issues.length || rows.length !== 320) Deno.exit(1);
