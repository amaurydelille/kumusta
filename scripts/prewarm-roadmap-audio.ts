import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { ttsCacheKey } from "../supabase/functions/kumusta-elevenlabs-tts/cache.ts";
import {
  ttsModelIDForPurpose,
  voiceIDForAccent,
} from "../supabase/functions/kumusta-elevenlabs-tts/contract.ts";

type Accent = "southern" | "northern";
interface Session {
  userID: string;
  accessToken: string;
  accent: Accent;
}
interface CatalogLesson {
  accent: Accent;
  content: { rounds: Array<{ vietnamese: string }> };
}

const command = Deno.args[0] ?? "generate";
const statePath = Deno.args[1] ?? "/private/tmp/kumusta-roadmap-tts-sessions.json";
const manifestPath = Deno.args[2] ?? "/private/tmp/kumusta-roadmap-tts-manifest.json";
const catalogPath = Deno.args[3] ?? "supabase/catalog/new-vietnamese-v1.json";
const auditPath = Deno.args[4] ?? "/private/tmp/kumusta-roadmap-tts-audit.sql";
const configuration = await Deno.readTextFile("Config/Secrets.xcconfig");
const baseURL = setting("SUPABASE_PROJECT_URL");
const publishableKey = setting("SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY");

if (command === "prepare") {
  const sessions: Session[] = [];
  for (const accent of ["southern", "northern"] as const) {
    for (let index = 0; index < 3; index += 1) {
      const client = createClient(baseURL, publishableKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await client.auth.signInAnonymously();
      if (error || !data.user || !data.session) {
        throw error ?? new Error("Anonymous session missing");
      }
      sessions.push({ userID: data.user.id, accessToken: data.session.access_token, accent });
    }
  }
  await Deno.writeTextFile(statePath, JSON.stringify(sessions));
  await Deno.chmod(statePath, 0o600);
  console.log(JSON.stringify(sessions.map(({ userID, accent }) => ({ userID, accent }))));
  Deno.exit(0);
}

if (command === "cleanup") {
  for (const path of [statePath, manifestPath, auditPath]) {
    await Deno.remove(path).catch((error) => {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    });
  }
  console.log("Temporary TTS session files removed.");
  Deno.exit(0);
}

const sessions: Session[] = JSON.parse(await Deno.readTextFile(statePath));
if (sessions.length !== 6) throw new Error("Expected six prepared TTS sessions.");
const catalogPayload: { lessons: CatalogLesson[] } | CatalogLesson[] = JSON.parse(
  await Deno.readTextFile(catalogPath),
);
const catalog = Array.isArray(catalogPayload)
  ? { lessons: catalogPayload }
  : catalogPayload;
const manifest: Array<{ cacheKey: string; accent: Accent; text: string }> = [];
let generated = 0;
let hits = 0;
const expectedTotal = new Set(
  catalog.lessons.flatMap((lesson) =>
    lesson.content.rounds.map((round) => `${lesson.accent}:${round.vietnamese}`)
  ),
).size;

await Promise.all((["southern", "northern"] as const).map(async (accent) => {
  const texts = [
    ...new Set(
      catalog.lessons
        .filter((lesson) => lesson.accent === accent)
        .flatMap((lesson) => lesson.content.rounds.map((round) => round.vietnamese)),
    ),
  ];
  const workers = sessions.filter((session) => session.accent === accent);
  const queues = workers.map(() => [] as string[]);
  texts.forEach((text, index) => queues[index % workers.length].push(text));
  await Promise.all(workers.map((session, index) => processQueue(session, queues[index])));
}));

await Deno.writeTextFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
const cacheKeys = manifest.map(({ cacheKey }) => `'${cacheKey}'`).join(",\n  ");
await Deno.writeTextFile(
  auditPath,
  `select accent, status, count(*) as clips, min(byte_size) as smallest_clip_bytes,
  sum(byte_size) as total_audio_bytes
from public.kumusta_tts_cache
where cache_key in (
  ${cacheKeys}
)
group by accent, status
order by accent, status;\n`,
);
console.log(JSON.stringify({ total: manifest.length, generated, hits }));

async function processQueue(session: Session, texts: string[]): Promise<void> {
  for (const text of texts) {
    const input = {
      text,
      accent: session.accent,
      speed: "natural" as const,
      purpose: "lesson" as const,
    };
    const cacheKey = await ttsCacheKey(
      input,
      voiceIDForAccent(session.accent),
      ttsModelIDForPurpose("lesson"),
    );
    manifest.push({ cacheKey, accent: session.accent, text });
    const response = await invokeWithRetry(session, input);
    const audio = new Uint8Array(await response.arrayBuffer());
    if (audio.byteLength < 129 || !response.headers.get("content-type")?.startsWith("audio/")) {
      throw new Error(`Invalid TTS audio for ${session.accent}: ${text}`);
    }
    if (response.headers.get("x-kumusta-tts-cache") === "hit") hits += 1;
    else generated += 1;
    console.log(`${session.accent} ${generated + hits}/${expectedTotal} ${audio.byteLength}B`);
  }
}

async function invokeWithRetry(
  session: Session,
  input: Record<string, unknown>,
): Promise<Response> {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const response = await fetch(`${baseURL}/functions/v1/kumusta-elevenlabs-tts`, {
      method: "POST",
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${session.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(input),
    });
    if (response.ok) return response;
    const detail = (await response.text()).slice(0, 300);
    if (attempt === 4 || ![429, 502, 503].includes(response.status)) {
      throw new Error(`TTS request failed (${response.status}): ${detail}`);
    }
    await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
  }
  throw new Error("TTS retry loop exhausted");
}

function setting(primary: string, fallback?: string): string {
  for (const name of [primary, fallback].filter(Boolean) as string[]) {
    const value = configuration.match(new RegExp(`^${name}\\s*=\\s*(.+)$`, "m"))?.[1]
      .trim().replaceAll("$()", "");
    if (value) return value;
  }
  throw new Error(`Missing ${primary}`);
}
