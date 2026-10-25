// Generates the bundled clips for the first lessons (the onboarding welcome
// lessons and the First Steps lesson). Onboarding runs before
// the paywall, where the TTS Edge Function only speaks fixed templates, so
// every fixed line ships with the app. Lines with the learner's name still use
// the server's `reply_name` template at runtime.
//
// The clips come from the deployed `kumusta-elevenlabs-tts` Edge Function in
// its operations mode, so they use the server's ElevenLabs key, voice, model,
// settings and seed, sound identical to lesson audio, and land in the shared
// TTS cache. No provider key is needed locally: the Supabase CLI supplies the
// Kumusta service-role key at run time. Each file is named by the 64-bit
// FNV-1a hash of its normalized text, the same key the app computes in
// `FirstLessonScript.audioKey(for:)`.
//
// Usage (from the repo root, logged in to the Supabase CLI):
//   deno run --allow-read --allow-write --allow-net --allow-env --allow-run=supabase \
//     scripts/generate-first-lesson-audio.ts [--force] [--dry-run]

// deno-lint-ignore no-explicit-any
type Json = any;

const lessonsDirectory = "Kumusta/Resources/FirstLessons";
// Only ever the Kumusta project.
const projectRef = "vpitjvtfzpqfnqgzcpla";
const ttsEndpoint = `https://${projectRef}.supabase.co/functions/v1/kumusta-elevenlabs-tts`;
const lessonFiles = [
  "onboarding-beginner.json",
  "onboarding-intermediate.json",
  "onboarding-advanced.json",
  "first-lesson-beginner.json",
];
const force = Deno.args.includes("--force");
const dryRun = Deno.args.includes("--dry-run");

function resolve(value: string | undefined): string | null {
  if (value === undefined || value === null) return null;
  return value;
}

/// Mirrors `FirstLessonScript.audioTexts`: every line the app can play.
/// Lines holding `{name}` are personalized at runtime and skipped here.
function spokenTexts(lesson: Json): string[] {
  const texts: (string | null)[] = [resolve(lesson.intro.hook)];
  for (const step of lesson.steps) {
    switch (step.kind) {
      case "teach":
        for (const sample of step.samples ?? []) texts.push(resolve(sample.text));
        break;
      case "listenPick":
        for (const option of step.options ?? []) texts.push(resolve(option.text));
        break;
      case "newPhrase":
        texts.push(resolve(step.tagalog));
        for (const chunk of step.chunks ?? []) texts.push(resolve(chunk.tagalog));
        break;
      case "speak":
        texts.push(resolve(step.target));
        texts.push(resolve(step.audio));
        break;
      case "meaningPick":
        texts.push(resolve(step.audio));
        break;
      case "naturalPick":
        texts.push(resolve(step.context));
        for (const option of step.options ?? []) texts.push(resolve(option.text));
        break;
      case "build": {
        const answer = (step.answer ?? []).map((tile: Json) => resolve(tile.text));
        for (const tile of [...(step.answer ?? []), ...(step.distractors ?? [])]) {
          texts.push(resolve(tile.text));
        }
        texts.push(answer.join(" "));
        break;
      }
      case "conversation":
        for (const turn of step.turns ?? []) texts.push(resolve(turn.buddy));
        if (step.closing) texts.push(resolve(step.closing.text));
        break;
      default:
        throw new Error(`Unknown step kind ${step.kind} in ${lesson.id}`);
    }
  }
  for (const phrase of lesson.completion.phrases ?? []) {
    const text = resolve(phrase.tagalog);
    texts.push(text ? text.replaceAll("…", "").trim() : null);
  }
  return texts.filter((text): text is string =>
    text !== null && text.trim().length > 0 && !text.includes("{name}")
  );
}

/// NFC, trimmed, single-spaced; matches `FirstLessonScript.normalizedAudioText`.
function normalizedAudioText(text: string): string {
  return text.normalize("NFC").trim().split(/\s+/u).join(" ");
}

/// 64-bit FNV-1a over UTF-8; matches `FirstLessonScript.audioKey(for:)`.
function audioKey(text: string): string {
  let hash = 0xcbf29ce484222325n;
  for (const byte of new TextEncoder().encode(normalizedAudioText(text))) {
    hash ^= BigInt(byte);
    hash = (hash * 0x100000001b3n) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, "0");
}

async function serviceRoleKey(): Promise<string> {
  const result = await new Deno.Command("supabase", {
    args: ["projects", "api-keys", "--project-ref", projectRef, "--reveal", "-o", "json"],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!result.success) {
    throw new Error("Unable to read the Kumusta service-role key (run `supabase login`)");
  }
  const parsed = JSON.parse(new TextDecoder().decode(result.stdout));
  const keys = Array.isArray(parsed) ? parsed : parsed.api_keys ?? parsed.keys;
  const key = keys?.find((candidate: { name: string }) => candidate.name === "service_role")
    ?.api_key;
  if (!key) throw new Error("Missing Kumusta service-role key");
  return key;
}

async function synthesize(text: string, key: string): Promise<Uint8Array> {
  for (let attempt = 1;; attempt += 1) {
    const response = await fetch(ttsEndpoint, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Accept: "audio/mpeg",
        "x-kumusta-operations-prewarm": "true",
      },
      body: JSON.stringify({ text, speed: "natural", purpose: "lesson" }),
    });
    if (response.ok && (response.headers.get("content-type") ?? "").startsWith("audio/")) {
      const data = new Uint8Array(await response.arrayBuffer());
      if (data.byteLength < 512) throw new Error(`Suspiciously small clip for "${text}"`);
      return data;
    }
    const body = await response.text();
    if (attempt >= 3 || (response.status < 500 && response.status !== 429)) {
      throw new Error(`TTS ${response.status} for "${text}": ${body.slice(0, 200)}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1500 * attempt));
  }
}

const lessons: Json[] = [];
for (const file of lessonFiles) {
  lessons.push(JSON.parse(await Deno.readTextFile(`${lessonsDirectory}/${file}`)));
}

const key = dryRun ? "" : await serviceRoleKey();
let generated = 0;
let reused = 0;
let characters = 0;
{
  const directory = `${lessonsDirectory}/audio`;
  await Deno.mkdir(directory, { recursive: true });
  const wanted = new Map<string, string>();
  for (const lesson of lessons) {
    for (const text of spokenTexts(lesson)) wanted.set(audioKey(text), text);
  }

  // Remove clips no lesson uses any more.
  for await (const entry of Deno.readDir(directory)) {
    const name = entry.name.replace(/\.mp3$/, "");
    if (entry.isFile && entry.name.endsWith(".mp3") && !wanted.has(name)) {
      if (!dryRun) await Deno.remove(`${directory}/${entry.name}`);
      console.log(`removed ${entry.name}`);
    }
  }

  const queue = [...wanted.entries()];
  const worker = async () => {
    while (queue.length > 0) {
      const [hash, text] = queue.shift()!;
      const path = `${directory}/${hash}.mp3`;
      const exists = await Deno.stat(path).then(() => true).catch(() => false);
      if (exists && !force) {
        reused += 1;
        continue;
      }
      characters += normalizedAudioText(text).length;
      if (dryRun) {
        console.log(`would generate ${hash} ${text}`);
        continue;
      }
      await Deno.writeFile(path, await synthesize(text, key));
      generated += 1;
      console.log(`${hash} ${text}`);
    }
  };
  await Promise.all([worker(), worker(), worker()]);
}
console.log(`\n${generated} generated, ${reused} reused, ${characters} characters sent.`);
