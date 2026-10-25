import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import {
  ttsCacheKey,
  ttsObjectPath,
} from "../supabase/functions/kumusta-elevenlabs-tts/cache.ts";
import {
  onboardingConversationText,
  tagalogVoiceID,
  ttsModelIDForPurpose,
  type TTSPurpose,
} from "../supabase/functions/kumusta-elevenlabs-tts/contract.ts";

type Purpose = TTSPurpose;

interface ManifestEntry {
  cacheKey: string;
  objectPath: string;
  purpose: Purpose;
  text: string;
  sources: string[];
}

const command = Deno.args[0] ?? "plan";
const root = new URL("../", import.meta.url);
const manifestPath = "/private/tmp/kumusta-all-tts-manifest.json";
const failurePath = "/private/tmp/kumusta-all-tts-failures.json";
const configuration = await Deno.readTextFile(
  new URL("../Config/Secrets.xcconfig", import.meta.url),
);
const baseURL = setting("SUPABASE_PROJECT_URL");
const projectRef = new URL(baseURL).hostname.split(".")[0];
// Only ever the Kumusta project.
if (projectRef !== "vpitjvtfzpqfnqgzcpla") {
  throw new Error(`Refusing to prewarm ${projectRef}: only the Kumusta project is allowed.`);
}
// Must match the deployed KUMUSTA_TTS_VOICE_ID (unset means the default voice).
const voiceID = tagalogVoiceID(Deno.env.get("KUMUSTA_TTS_VOICE_ID"));

if (command === "plan") {
  const serviceKey = await serviceRoleKey();
  const entries = await buildManifest(serviceKey);
  await Deno.writeTextFile(manifestPath, `${JSON.stringify(entries, null, 2)}\n`);
  console.log(JSON.stringify(summarize(entries), null, 2));
  Deno.exit(0);
}

if (command === "generate") {
  const entries: ManifestEntry[] = JSON.parse(await Deno.readTextFile(manifestPath));
  const serviceKey = await serviceRoleKey();
  const workerCount = 5;
  const validKeys = await fullyPersistedCacheKeys(serviceKey, entries);
  const workEntries = entries.filter((entry) => !validKeys.has(entry.cacheKey));
  console.log(
    JSON.stringify({
      manifest: entries.length,
      alreadyReady: validKeys.size,
      remaining: workEntries.length,
    }),
  );

  const queues = Array.from({ length: workerCount }, () => [] as ManifestEntry[]);
  workEntries.forEach((entry, index) => queues[index % queues.length].push(entry));
  let completed = 0;
  let hits = 0;
  let generated = 0;
  const failures: Array<{ entry: ManifestEntry; error: string }> = [];

  await Promise.all(queues.map(async (queue) => {
    for (const entry of queue) {
      try {
        const response = await invokeWithRetry(serviceKey, entry);
        const audio = new Uint8Array(await response.arrayBuffer());
        if (audio.byteLength < 129 || !response.headers.get("content-type")?.startsWith("audio/")) {
          throw new Error(`Invalid audio response (${audio.byteLength} bytes)`);
        }
        if (response.headers.get("x-kumusta-tts-cache") === "hit") hits += 1;
        else generated += 1;
      } catch (error) {
        failures.push({ entry, error: String(error) });
      } finally {
        completed += 1;
        if (completed % 25 === 0 || completed === workEntries.length) {
          console.log(
            JSON.stringify({
              completed,
              total: workEntries.length,
              generated,
              hits,
              failures: failures.length,
            }),
          );
        }
      }
    }
  }));

  await Deno.writeTextFile(failurePath, `${JSON.stringify(failures, null, 2)}\n`);
  console.log(
    JSON.stringify({
      completed,
      total: workEntries.length,
      generated,
      hits,
      failures: failures.length,
    }),
  );
  if (failures.length) Deno.exit(1);
  Deno.exit(0);
}

if (command === "audit") {
  const entries: ManifestEntry[] = JSON.parse(await Deno.readTextFile(manifestPath));
  const serviceKey = await serviceRoleKey();
  const client = createClient(baseURL, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const rows = await fetchAllCacheRows(serviceKey);
  const rowByKey = new Map(rows.map((row) => [row.cache_key, row]));
  const objects = new Set<string>();
  for (const version of ["v1", "v2"]) {
    for (let offset = 0;; offset += 1000) {
      const { data, error } = await client.storage.from("kumusta-tts").list(version, {
        limit: 1000,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw error;
      for (const item of data ?? []) objects.add(`${version}/${item.name}`);
      if ((data?.length ?? 0) < 1000) break;
    }
  }
  const missingRows: ManifestEntry[] = [];
  const invalidRows: ManifestEntry[] = [];
  const missingObjects: ManifestEntry[] = [];
  for (const entry of entries) {
    const row = rowByKey.get(entry.cacheKey);
    if (!row) missingRows.push(entry);
    else if (
      row.status !== "ready" || Number(row.byte_size ?? 0) < 129 ||
      row.object_path !== entry.objectPath
    ) {
      invalidRows.push(entry);
    }
    if (!objects.has(entry.objectPath)) missingObjects.push(entry);
  }
  const result = {
    expected: entries.length,
    ready: entries.length - new Set([
      ...missingRows.map((entry) => entry.cacheKey),
      ...invalidRows.map((entry) => entry.cacheKey),
      ...missingObjects.map((entry) => entry.cacheKey),
    ]).size,
    missingRows: missingRows.length,
    invalidRows: invalidRows.length,
    missingObjects: missingObjects.length,
    databaseRowsInBucket: rows.length,
    storageObjectsInBucket: objects.size,
  };
  console.log(JSON.stringify(result, null, 2));
  if (result.ready !== result.expected) Deno.exit(1);
  Deno.exit(0);
}

if (command === "probe") {
  const entries: ManifestEntry[] = JSON.parse(await Deno.readTextFile(manifestPath));
  const serviceKey = await serviceRoleKey();
  const rows = await fetchAllCacheRows(serviceKey);
  const ready = new Set(
    rows.filter((row) => row.status === "ready" && Number(row.byte_size ?? 0) >= 129).map((row) =>
      row.cache_key
    ),
  );
  const entry = entries.find((candidate) => !ready.has(candidate.cacheKey));
  if (!entry) throw new Error("No missing manifest entry to probe.");
  const response = await fetch(`${baseURL}/functions/v1/kumusta-elevenlabs-tts`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      "x-kumusta-operations-prewarm": "true",
    },
    body: JSON.stringify({
      text: entry.text,
      speed: "natural",
      purpose: entry.purpose,
    }),
  });
  const contentType = response.headers.get("content-type") ?? "";
  const detail = contentType.startsWith("audio/")
    ? {
      bytes: (await response.arrayBuffer()).byteLength,
      cache: response.headers.get("x-kumusta-tts-cache"),
    }
    : { body: (await response.text()).slice(0, 1000) };
  console.log(
    JSON.stringify(
      {
        status: response.status,
        entry: { purpose: entry.purpose, text: entry.text },
        detail,
      },
      null,
      2,
    ),
  );
  if (!response.ok) Deno.exit(1);
  Deno.exit(0);
}

if (command === "provider-logs") {
  const tokenResult = await new Deno.Command("security", {
    args: ["find-generic-password", "-s", "Supabase CLI", "-a", "supabase", "-w"],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!tokenResult.success) throw new Error("Unable to read the existing Supabase CLI credential");
  const accessToken = new TextDecoder().decode(tokenResult.stdout).trim();
  const end = new Date();
  const start = new Date(end.getTime() - 2 * 60 * 60_000);
  const url = new URL(
    `https://api.supabase.com/v1/projects/${projectRef}/analytics/endpoints/logs`,
  );
  url.searchParams.set("iso_timestamp_start", start.toISOString());
  url.searchParams.set("iso_timestamp_end", end.toISOString());
  url.searchParams.set(
    "sql",
    `select timestamp, source, event_message from logs where event_message ilike '%elevenlabs%' or event_message ilike '%voice_unavailable%' order by timestamp desc limit 100`,
  );
  const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!response.ok) {
    throw new Error(
      `Log query failed (${response.status}): ${(await response.text()).slice(0, 500)}`,
    );
  }
  console.log(JSON.stringify(await response.json(), null, 2));
  Deno.exit(0);
}

if (command === "cleanup") {
  for (const path of [failurePath]) {
    await Deno.remove(path).catch((error) => {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    });
  }
  console.log("Failure report removed; manifest retained for audit.");
  Deno.exit(0);
}

throw new Error(`Unknown command: ${command}`);

async function buildManifest(serviceKey: string): Promise<ManifestEntry[]> {
  const pending = new Map<string, { purpose: Purpose; text: string; sources: Set<string> }>();
  const add = (purpose: Purpose, rawText: unknown, source: string) => {
    if (typeof rawText !== "string") return;
    const text = rawText.trim().replace(/\s+/gu, " ");
    if (!text || text.length > 500) return;
    const id = `${purpose}\u0000${text}`;
    const existing = pending.get(id);
    if (existing) existing.sources.add(source);
    else pending.set(id, { purpose, text, sources: new Set([source]) });
  };

  const collectLesson = (content: Record<string, unknown>, source: string) => {
    const rounds = Array.isArray(content.rounds) ? content.rounds : [];
    const steps = Array.isArray(content.steps) ? content.steps : [];
    for (const item of [...rounds, ...steps]) {
      if (!item || typeof item !== "object") continue;
      const record = item as Record<string, unknown>;
      add("lesson", record.tagalog, source);
    }
  };

  // The roadmap ships with the app, so it is prewarmed whether or not it is published yet.
  for (const level of ["beginner", "intermediate", "advanced"]) {
    const payload = JSON.parse(
      await Deno.readTextFile(
        new URL(`../Kumusta/Resources/Seed/${level}-tagalog-v1.json`, import.meta.url),
      ),
    );
    for (const lesson of payload.lessons ?? []) {
      collectLesson(lesson.content, `roadmap:${level}`);
      if (level !== "beginner") continue;
      // The offline word bank (`SampleContent.vocabulary`) is the beginner vocabulary.
      for (const word of lesson.content.vocabulary ?? []) {
        add("vocabulary", word.tagalog, "beginner-vocabulary");
        add("vocabulary", word.example, "beginner-vocabulary-example");
      }
    }
  }

  const goalRows = await restRows(serviceKey, "kumusta_goal_lessons", {
    select: "content",
    curriculum_version: "eq.goals-v1",
    is_published: "eq.true",
  });
  console.log(JSON.stringify({ publishedGoalLessons: goalRows.length }));
  for (const lesson of goalRows) collectLesson(lesson.content, "goal-curriculum");

  const queueRows = await restRows(serviceKey, "kumusta_user_lesson_queue", {
    select:
      "lesson:kumusta_generated_lessons!kumusta_lesson_queue_lesson_owner_fk!inner(status,expires_at,content)",
    status: "in.(ready,started)",
    "lesson.status": "eq.ready",
    "lesson.expires_at": `gt.${new Date().toISOString()}`,
  });
  for (const row of queueRows) {
    if (row.lesson?.content) collectLesson(row.lesson.content, "adaptive-current");
  }

  // The First Steps cheat sheet plays each entry's reference text or example.
  const cheatSheet = await Deno.readTextFile(
    new URL("../Kumusta/Features/FirstSteps/FirstStepsViews.swift", import.meta.url),
  );
  for (const match of cheatSheet.matchAll(/^\s*(?:example|referenceAudioText): "([^"]+)"/gmu)) {
    add("lesson", match[1], "first-steps-cheat-sheet");
  }

  // The generic lines of the pre-paywall first conversation share the lesson cache.
  const onboardingLines = [
    "greeting",
    "ask_name",
    "reply_hello",
    "ask_wellbeing",
    "reply_wellbeing",
    "nice_to_meet",
  ] as const;
  for (const line of onboardingLines) {
    add("lesson", onboardingConversationText(line, null), "onboarding-conversation");
  }

  const entries: ManifestEntry[] = [];
  for (const value of pending.values()) {
    const input = { text: value.text, speed: "natural" as const, purpose: value.purpose };
    const cacheKey = await ttsCacheKey(input, voiceID, ttsModelIDForPurpose(value.purpose));
    entries.push({
      cacheKey,
      objectPath: ttsObjectPath(cacheKey, value.purpose),
      purpose: value.purpose,
      text: value.text,
      sources: [...value.sources].sort(),
    });
  }
  return entries.sort((a, b) =>
    a.purpose.localeCompare(b.purpose) || a.text.localeCompare(b.text, "fil")
  );
}

function summarize(entries: ManifestEntry[]) {
  const byPurpose: Record<string, number> = {};
  const bySource: Record<string, number> = {};
  for (const entry of entries) {
    byPurpose[entry.purpose] = (byPurpose[entry.purpose] ?? 0) + 1;
    for (const source of entry.sources) bySource[source] = (bySource[source] ?? 0) + 1;
  }
  return { total: entries.length, byPurpose, bySource };
}

async function restRows(
  serviceKey: string,
  table: string,
  query: Record<string, string>,
): Promise<any[]> {
  const rows: any[] = [];
  for (let offset = 0;; offset += 1000) {
    const url = new URL(`${baseURL}/rest/v1/${table}`);
    for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);
    const response = await fetch(url, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Range: `${offset}-${offset + 999}`,
      },
    });
    if (!response.ok) {
      throw new Error(
        `${table} read failed (${response.status}): ${(await response.text()).slice(0, 500)}`,
      );
    }
    const page = await response.json();
    rows.push(...page);
    if (page.length < 1000) break;
  }
  return rows;
}

async function fetchAllCacheRows(serviceKey: string): Promise<any[]> {
  return await restRows(serviceKey, "kumusta_tts_cache", {
    select: "cache_key,status,object_path,byte_size",
  });
}

async function fullyPersistedCacheKeys(
  serviceKey: string,
  entries: ManifestEntry[],
): Promise<Set<string>> {
  const rows = await fetchAllCacheRows(serviceKey);
  const objects = new Set<string>();
  const client = createClient(baseURL, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  for (const version of ["v1", "v2"]) {
    for (let offset = 0;; offset += 1000) {
      const { data, error } = await client.storage.from("kumusta-tts").list(version, {
        limit: 1000,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw error;
      for (const item of data ?? []) objects.add(`${version}/${item.name}`);
      if ((data?.length ?? 0) < 1000) break;
    }
  }
  const expected = new Map(entries.map((entry) => [entry.cacheKey, entry.objectPath]));
  return new Set(
    rows.filter((row) =>
      row.status === "ready" &&
      Number(row.byte_size ?? 0) >= 129 &&
      expected.get(row.cache_key) === row.object_path &&
      objects.has(row.object_path)
    ).map((row) => row.cache_key),
  );
}

async function invokeWithRetry(serviceKey: string, entry: ManifestEntry): Promise<Response> {
  for (let attempt = 1; attempt <= 7; attempt += 1) {
    const response = await fetch(`${baseURL}/functions/v1/kumusta-elevenlabs-tts`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        "x-kumusta-operations-prewarm": "true",
      },
      body: JSON.stringify({
        text: entry.text,
        speed: "natural",
        purpose: entry.purpose,
      }),
    });
    if (response.ok) return response;
    const detail = (await response.text()).slice(0, 500);
    if (attempt === 7 || ![429, 500, 502, 503, 504].includes(response.status)) {
      throw new Error(`TTS failed (${response.status}): ${detail}`);
    }
    await new Promise((resolve) => setTimeout(resolve, Math.min(15_000, attempt * 2_000)));
  }
  throw new Error("TTS retry loop exhausted");
}

async function serviceRoleKey(): Promise<string> {
  const result = await new Deno.Command("supabase", {
    args: ["projects", "api-keys", "--project-ref", projectRef, "--reveal", "-o", "json"],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!result.success) throw new Error("Unable to obtain Supabase operations credential");
  const parsed = JSON.parse(new TextDecoder().decode(result.stdout));
  const keys = Array.isArray(parsed) ? parsed : parsed.api_keys ?? parsed.keys;
  const key = keys?.find((candidate: { name: string }) => candidate.name === "service_role")
    ?.api_key;
  if (!key) throw new Error("Missing Supabase service-role credential");
  return key;
}

function setting(primary: string, fallback?: string): string {
  for (const name of [primary, fallback].filter(Boolean) as string[]) {
    const value = configuration.match(new RegExp(`^${name}\\s*=\\s*(.+)$`, "m"))?.[1]
      .trim().replaceAll("$()", "");
    if (value) return value;
  }
  throw new Error(`Missing ${primary}`);
}
