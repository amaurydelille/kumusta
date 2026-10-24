import { HttpError } from "../_shared/http.ts";

export const PIPELINE_LLM_MODEL = "claude-opus-5-5";
export const PIPELINE_TTS_MODEL = "eleven_v4_turbo";
/** Stored in `kumusta_live_sessions.model` / `kumusta_live_rounds.model`. */
export const PIPELINE_ENGINE_LABEL = `pipeline:${PIPELINE_LLM_MODEL}:${PIPELINE_TTS_MODEL}`;
/** Microphone audio sent to Scribe. */
export const PIPELINE_SAMPLE_RATE = 16_000;
/**
 * Reply speech as uncompressed PCM. 24 kHz is the richest PCM the current
 * ElevenLabs plan allows; 44.1 kHz PCM needs the Pro tier.
 */
export const PLAYBACK_SAMPLE_RATE = 24_000;
export const HISTORY_TURN_LIMIT = 24;
export const HISTORY_TEXT_LIMIT = 1_000;
const TRANSCRIBER_ENDPOINT = "wss://api.elevenlabs.io/v1/speech-to-text/realtime";

/**
 * Appended after the agent prompt. The agent heard audio; this pipeline only
 * sees a transcript and its replies are spoken sentence by sentence.
 */
export const PIPELINE_VOICE_PROMPT = `VOICE PIPELINE
The learner's turns reach you as an automatic Tagalog speech transcript, not audio. You cannot hear stress or pronunciation directly: only comment on pronunciation when the transcript clearly shows a different word than the one the learner meant, and never blame the learner for an obvious transcription glitch.
Every reply is spoken aloud. Keep it short: one to three short sentences, then stop and let the learner talk. No markdown, lists, emojis, URLs or stage directions other than the square-bracket audio tags described above.`;

/**
 * Learners ask about Tagalog words in English ("what does kilig mean?") and
 * Manila speech mixes in English; without this, Scribe forces the whole turn
 * into one language and rewrites the other.
 */
export const DEFAULT_SECONDARY_LANGUAGES = ["eng"];

/**
 * Pipeline-only addition to the grumpy personality (the agent's shared prompt
 * in `kumusta-live` is unchanged): the learner chose this mood to hear real
 * street swearing.
 */
export const GRUMPY_VOCABULARY_PROMPT = `GRUMPY VOCABULARY (this session only)
The learner chose the grumpy mood to hear real street Tagalog. When you lose your temper, use these exasperated expressions naturally: "Hay naku!", "Ano ba 'yan!", "Bwisit!", "Lintik!", "Leche!", "Susmaryosep!", and a long exasperated "arghhhhhhhh". They are outbursts of frustration, the way a fed-up Manila tindera grumbles, not threats. For these expressions only, this overrides the family-friendly wording rules above.
Use at most one or two per reply and vary them; not every reply needs one. Everything else still applies: no slurs, no threats, no sexual content, no attacks on anyone's identity. If the learner asks you to stop swearing, stop for the rest of the session and stay grumpy through your tone. If the learner asks what one of them means, explain it honestly, including how vulgar it is and when Tagalog people actually say it.`;

// Frequent Tagalog words that never appear in English sentences. Tagalog is
// written in the same Latin letters as English, so words, not letters, tell
// the two apart.
const TAGALOG_WORDS =
  /(^|[^\p{L}])(ang|ng|mga|ako|ikaw|ka|siya|kami|tayo|kayo|sila|hindi|oo|opo|po|salamat|kumusta|ito|iyan|iyon|dito|doon|sa|na|ba|lang|naman|rin|din|nga|pa|ko|mo|niya|natin|ninyo|ano|saan|paano|bakit|gusto|wala|meron)(?=$|[^\p{L}])/giu;
const ENGLISH_WORDS =
  /(^|[^\p{L}])(the|is|are|you|your|it|it's|what|does|mean|means|this|that|and|with|for|say|word|yes|good|how|can)(?=$|[^\p{L}])/giu;

/**
 * The voice model's language for one sentence. Tagalog wins whenever the
 * sentence has more Tagalog than English function words; a balanced Taglish
 * sentence is left to the model's own detection, so neither language is read
 * with the other's pronunciation.
 */
export function speechLanguage(text: string): "fil" | "en" | undefined {
  const words = text.split(/\s+/).filter((word) => /\p{L}/u.test(word));
  if (words.length === 0) return "fil";
  const tagalog = text.match(TAGALOG_WORDS)?.length ?? 0;
  const english = text.match(ENGLISH_WORDS)?.length ?? 0;
  if (english === 0) return "fil";
  if (tagalog > english) return "fil";
  if (tagalog === 0) return "en";
  return undefined;
}

export type TranscriberProvider = "elevenlabs" | "soniox";

export const SONIOX_ENDPOINT = "wss://stt-rt.soniox.com/transcribe-websocket";

/**
 * Soniox's start request, sent by the app as the socket's first message. One
 * model handles Tagalog with English mixed in, and ends the turn from what was
 * said rather than a fixed silence.
 */
export function sonioxConfig(clientReferenceID: string) {
  return {
    model: "stt-rt-v5",
    audio_format: "pcm_s16le",
    sample_rate: PIPELINE_SAMPLE_RATE,
    num_channels: 1,
    language_hints: ["tl", "en"],
    enable_endpoint_detection: true,
    max_endpoint_delay_ms: 1000,
    client_reference_id: clientReferenceID.slice(0, 256),
  };
}

/**
 * Soniox, which Kumusta uses for Tagalog. ElevenLabs Scribe only when the
 * secret explicitly asks for it or for a build that cannot speak Soniox; a
 * missing Soniox key fails closed instead of switching provider.
 */
export function transcriberProvider(
  configured: string | undefined,
  sonioxAvailable: boolean,
  clientProviders: unknown,
): TranscriberProvider {
  const clientSupportsSoniox = Array.isArray(clientProviders) && clientProviders.includes("soniox");
  if (configured?.trim() === "elevenlabs" || !clientSupportsSoniox) return "elevenlabs";
  if (!sonioxAvailable) {
    throw new HttpError(503, "transcription_unavailable", "Live voice is unavailable.");
  }
  return "soniox";
}

/** Stored in `model`, so speed and quality can be compared per provider. */
export function engineLabel(provider: TranscriberProvider): string {
  return `pipeline:${provider}:${PIPELINE_LLM_MODEL}:${PIPELINE_TTS_MODEL}`;
}

/** The session configuration stays server-owned; the app connects as-is. */
export function transcriberURL(
  token: string,
  secondaryLanguages: string[] = DEFAULT_SECONDARY_LANGUAGES,
): string {
  if (!/^[A-Za-z0-9_-]{8,512}$/.test(token)) throw new Error("invalid_token");
  const url = new URL(TRANSCRIBER_ENDPOINT);
  url.searchParams.set("model_id", "scribe_v2_realtime");
  url.searchParams.set("language_code", "fil");
  url.searchParams.set("audio_format", `pcm_${PIPELINE_SAMPLE_RATE}`);
  // Learners pause mid-sentence while searching for a word, so the turn
  // ends after 0.8 s of silence. (scribe_v2_realtime rejects turn_prediction.)
  url.searchParams.set("commit_strategy", "vad");
  url.searchParams.set("vad_silence_threshold_secs", "0.8");
  for (const language of secondaryLanguages) {
    if (/^[a-z]{2,3}$/.test(language)) url.searchParams.append("secondary_languages", language);
  }
  url.searchParams.set("token", token);
  return url.toString();
}

export const CALL_OPENED = "(The learner opened the call.)";

export type ChatMessage = { role: "user" | "assistant"; content: string };

/**
 * The client's captions, bounded and folded into alternating turns that start
 * and end with the learner. Malformed entries are dropped, not trusted.
 */
export function historyFrom(value: unknown): ChatMessage[] {
  if (!Array.isArray(value)) throw new Error("invalid_history");
  const messages: ChatMessage[] = [];
  for (const item of value.slice(-HISTORY_TURN_LIMIT)) {
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    if (row.speaker !== "user" && row.speaker !== "assistant") continue;
    if (typeof row.text !== "string") continue;
    const text = row.text.normalize("NFC").trim().slice(0, HISTORY_TEXT_LIMIT);
    if (!text) continue;
    const role = row.speaker;
    const last = messages.at(-1);
    if (last?.role === role) last.content = `${last.content}\n${text}`;
    else messages.push({ role, content: text });
  }
  if (messages.at(-1)?.role !== "user") throw new Error("invalid_history");
  // The model's turns must start with the learner; the spoken greeting opens
  // the call, so it is kept after a neutral opening turn.
  if (messages[0]?.role === "assistant") messages.unshift({ role: "user", content: CALL_OPENED });
  return messages;
}

/**
 * Splits streamed text into speakable sentences so speech can start before
 * the reply is complete. Returns the complete sentences and the remainder.
 */
export function takeSentences(
  buffer: string,
  options: { eager?: boolean } = {},
): { sentences: string[]; rest: string } {
  const sentences: string[] = [];
  // The reply's first chunk may end at a clause so speech starts sooner.
  const boundary = options.eager
    ? /[.!?…]+["”’)\]]*(?=\s)|\n+|(?<=[^\n]{24,})[,;:—–](?=\s)/u
    : /[.!?…]+["”’)\]]*(?=\s)|\n+/u;
  let rest = buffer;
  let pending = "";
  let match: RegExpExecArray | null;
  while ((sentences.length === 0 || !options.eager) && (match = boundary.exec(rest))) {
    const end = match.index + match[0].length;
    const piece = rest.slice(0, end).trim();
    rest = rest.slice(end);
    if (!piece) continue;
    const sentence = pending ? `${pending} ${piece}` : piece;
    // A bare tag such as "[laughs]" belongs to the next sentence.
    if (hasSpeakableText(sentence)) {
      sentences.push(sentence);
      pending = "";
    } else {
      pending = sentence;
    }
  }
  return { sentences, rest: pending ? `${pending} ${rest.trimStart()}` : rest };
}

/** Audio tags are performed by the voice model; nothing else is spoken. */
export function hasSpeakableText(sentence: string): boolean {
  return /\p{L}|\p{N}/u.test(sentence.replace(/\[[^\]\n]{1,40}\]/gu, ""));
}

/** One NDJSON event of the reply stream. */
export type ReplyEvent =
  | { type: "text"; text: string }
  | { type: "audio"; data: string }
  | { type: "done" }
  | { type: "error"; code: string };

export function encodeEvent(event: ReplyEvent): Uint8Array {
  return new TextEncoder().encode(`${JSON.stringify(event)}\n`);
}

/**
 * Re-chunks provider PCM16 so every emitted chunk holds whole samples, since
 * network chunks can split a sample across two reads.
 */
export class SampleAligner {
  private carry: Uint8Array | null = null;

  push(chunk: Uint8Array): Uint8Array {
    let bytes = chunk;
    if (this.carry) {
      bytes = new Uint8Array(this.carry.length + chunk.length);
      bytes.set(this.carry);
      bytes.set(chunk, this.carry.length);
      this.carry = null;
    }
    if (bytes.length % 2 === 1) {
      this.carry = bytes.slice(-1);
      bytes = bytes.subarray(0, bytes.length - 1);
    }
    return bytes;
  }
}

export function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  }
  return btoa(binary);
}
