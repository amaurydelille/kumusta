// Run with: deno run --allow-run=supabase --allow-net=vpitjvtfzpqfnqgzcpla.supabase.co scripts/generate-goal-curriculum.ts
// Credentials remain in memory and are never logged or written into artifacts.
import { goals } from "../supabase/functions/kumusta-curriculum-admin/plan.ts";

const project = "vpitjvtfzpqfnqgzcpla";
const result = await new Deno.Command("supabase", { args: ["projects", "api-keys", "--project-ref", project, "--reveal", "-o", "json"], stdout: "piped", stderr: "piped" }).output();
if (!result.success) throw new Error("Unable to obtain Supabase operations credentials");
const parsed = JSON.parse(new TextDecoder().decode(result.stdout));
const keys = Array.isArray(parsed) ? parsed : parsed.api_keys ?? parsed.keys;
const key = keys?.find((k: { name: string }) => k.name === "service_role")?.api_key;
if (!key) throw new Error("No service role credential available");
const limit = Number(Deno.args.find((a) => a.startsWith("--limit="))?.split("=")[1] ?? 160);
const concurrency = Number(Deno.args.find((a) => a.startsWith("--concurrency="))?.split("=")[1] ?? 12);
const jobs = goals.flatMap(goal =>
  [1, 2, 3, 4].flatMap(stage =>
    Array.from({ length: 10 }, (_, i) => ({ goal, stage, order: i + 1 })))).slice(0, limit);
let cursor = 0;
let successes = 0;
const failures: unknown[] = [];
async function worker() {
  while (cursor < jobs.length) {
    const job = jobs[cursor++];
    let correction = "";
    let done = false;
    for (let attempt = 1; attempt <= 5; attempt++) {
      try {
        const response = await fetch(`https://${project}.supabase.co/functions/v1/kumusta-curriculum-admin`, {
          method: "POST", headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
          body: JSON.stringify({ ...job, correction }), signal: AbortSignal.timeout(220_000),
        });
        const value = await response.json();
        if (response.ok) {
          successes++;
          console.log(JSON.stringify({ ...job, completed: successes, total: jobs.length, cached: value.cached ?? false, model: value.model }));
          done = true; break;
        }
        correction = value.correction ?? "";
        console.log(JSON.stringify({ ...job, attempt, error: value.error, correction, diagnostic: value.diagnostic }));
        if (response.status === 401 || response.status === 403) throw new Error("Operations authorization rejected");
      } catch (error) {
        console.log(JSON.stringify({ ...job, attempt, error: String(error) }));
      }
      await new Promise(resolve => setTimeout(resolve, attempt * 1500));
    }
    if (!done) failures.push(job);
  }
}
await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, worker));
console.log(JSON.stringify({ successes, total: jobs.length, failures }));
if (failures.length) Deno.exit(1);
