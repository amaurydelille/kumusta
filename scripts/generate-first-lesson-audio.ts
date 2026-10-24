// Generates the bundled clips for the first lessons (the onboarding welcome
// lessons and the First Steps lesson) in both accents. Onboarding runs before
// the paywall, where the TTS Edge Function only speaks fixed templates, so
// every fixed line ships with the app. Lines with the learner's name still use
// the server's `reply_name` template at runtime.
//
// The clips use the exact voice, model, settings, and seed as the TTS Edge
// Function, so they sound identical to lesson audio. Each file is named by the
// 64-bit FNV-1a hash of its normalized text, the same key the app computes in
// `FirstLessonScript.audioKey(for:)`.
//
// Usage (from mobile-app/kumusta, with ELEVENLABS_API_KEY in .env):
//   deno run --allow-read --allow-write --allow-net --allow-env \
//     scripts/generate-first-lesson-audio.ts [--force] [--dry-run]
import {
  consistentVoiceSettings,
  deterministicSpeechSeed,
  normalizedTTSText,
  type TTSRequest,
  vietnameseTTSModelID,
  voiceIDForAccent,
} from "../supabase/functions/kumusta-elevenlabs-tts/contract.ts";

type Accent = "southern" | "northern";
type AccentText = string | { southern: string; northern: string };
// deno-lint-ignore no-explicit-any
type Json = any;

const lessonsDirectory = "Kumusta/Resources/FirstLessons";
const outputFormat = "mp3_44100_96";
const accents: Accent[] = ["southern", "northern"];
const force = Deno.args.includes("--force");
const dryRun = Deno.args.includes("--dry-run");

function resolve(value: AccentText | undefined, accent: Accent): string | null {
  if (value === undefined || value === null) return null;
  return typeof value === "string" ? value : value[accent];
}

/// Mirrors `FirstLessonScript.audioTexts`: every line the app can play.
/// Lines holding `{name}` are personalized at runtime and skipped here.
function spokenTexts(lesson: Json, accent: Accent): string[] {
  const texts: (string | null)[] = [resolve(lesson.intro.hook, accent)];
  for (const step of lesson.steps) {
    switch (step.kind) {
      case "teach":
        for (const sample of step.samples ?? []) texts.push(resolve(sample.text, accent));
        break;
      case "listenPick":
        for (const option of step.options ?? []) texts.push(resolve(option.text, accent));
        break;
      case "newPhrase":
        texts.push(resolve(step.vietnamese, accent));
        for (const chunk of step.chunks ?? []) texts.push(resolve(chunk.vietnamese, accent));
        break;
      case "speak":
        texts.push(resolve(step.target, accent));
        texts.push(resolve(step.audio, accent));
        break;
      case "meaningPick":
        texts.push(resolve(step.audio, accent));
        break;
      case "naturalPick":
        texts.push(resolve(step.context, accent));
        for (const option of step.options ?? []) texts.push(resolve(option.text, accent));
        break;
      case "build": {
        const answer = (step.answer ?? []).map((tile: Json) => resolve(tile.text, accent));
        for (const tile of [...(step.answer ?? []), ...(step.distractors ?? [])]) {
          texts.push(resolve(tile.text, accent));
        }
        texts.push(answer.join(" "));
        break;
      }
      case "conversation":
        for (const turn of step.turns ?? []) texts.push(resolve(turn.buddy, accent));
        if (step.closing) texts.push(resolve(step.closing.text, accent));
        break;
      default:
        throw new Error(`Unknown step kind ${step.kind} in ${lesson.id}`);
    }
  }
  for (const phrase of lesson.completion.phrases ?? []) {
    const text = resolve(phrase.vietnamese, accent);
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

async function apiKey(): Promise<string> {
  const fromEnv = Deno.env.get("ELEVENLABS_API_KEY")?.trim();
  if (fromEnv) return fromEnv;
  const dotenv = await Deno.readTextFile(".env").catch(() => "");
  const match = /^\s*ELEVENLABS_API_KEY\s*=\s*(.+?)\s*$/m.exec(dotenv);
  if (match) return match[1].replace(/^["']|["']$/g, "");
  throw new Error("ELEVENLABS_API_KEY is required (environment or .env)");
}

async function synthesize(text: string, accent: Accent, key: string): Promise<Uint8Array> {
  const request: TTSRequest = {
    text: normalizedTTSText(text, "lesson"),
    accent,
    speed: "natural",
    purpose: "lesson",
    honorRequestedAccent: true,
  };
  const voiceID = voiceIDForAccent(accent);
  const endpoint = new URL(`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceID)}`);
  endpoint.searchParams.set("output_format", outputFormat);
  for (let attempt = 1; ; attempt += 1) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "audio/mpeg", "xi-api-key": key },
      body: JSON.stringify({
        text: request.text,
        model_id: vietnameseTTSModelID,
        language_code: "vi",
        seed: deterministicSpeechSeed(voiceID, request),
        apply_text_normalization: "auto",
        voice_settings: consistentVoiceSettings("natural"),
      }),
    });
    if (response.ok) {
      const data = new Uint8Array(await response.arrayBuffer());
      if (data.byteLength < 512) throw new Error(`Suspiciously small clip for "${text}"`);
      return data;
    }
    const body = await response.text();
    if (attempt >= 3 || (response.status < 500 && response.status !== 429)) {
      throw new Error(`ElevenLabs ${response.status} for "${text}": ${body.slice(0, 200)}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1500 * attempt));
  }
}

const lessons: Json[] = [];
for await (const entry of Deno.readDir(lessonsDirectory)) {
  if (entry.isFile && entry.name.endsWith(".json")) {
    lessons.push(JSON.parse(await Deno.readTextFile(`${lessonsDirectory}/${entry.name}`)));
  }
}

const key = dryRun ? "" : await apiKey();
let generated = 0;
let reused = 0;
let characters = 0;
for (const accent of accents) {
  const directory = `${lessonsDirectory}/audio/${accent}`;
  await Deno.mkdir(directory, { recursive: true });
  const wanted = new Map<string, string>();
  for (const lesson of lessons) {
    for (const text of spokenTexts(lesson, accent)) wanted.set(audioKey(text), text);
  }

  // Remove clips no lesson uses any more.
  for await (const entry of Deno.readDir(directory)) {
    const name = entry.name.replace(/\.mp3$/, "");
    if (entry.isFile && entry.name.endsWith(".mp3") && !wanted.has(name)) {
      if (!dryRun) await Deno.remove(`${directory}/${entry.name}`);
      console.log(`removed ${accent} ${entry.name}`);
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
        console.log(`would generate ${accent.padEnd(8)} ${hash} ${text}`);
        continue;
      }
      await Deno.writeFile(path, await synthesize(text, accent, key));
      generated += 1;
      console.log(`${accent.padEnd(8)} ${hash} ${text}`);
    }
  };
  await Promise.all([worker(), worker(), worker()]);
}
console.log(`\n${generated} generated, ${reused} reused, ${characters} characters sent.`);
