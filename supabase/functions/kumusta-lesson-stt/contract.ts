import { HttpError, isPlainObject } from "../_shared/http.ts";

export interface TranscriptionWord {
  text: string;
  start: number;
  end: number;
}

export interface TranscriptionResponse {
  version: 1;
  transcript: string;
  languageCode: "fil";
  languageProbability: number | null;
  words: TranscriptionWord[];
}

export function validateAudioContentType(value: string | null): string {
  const normalized = value?.split(";", 1)[0].trim().toLowerCase() ?? "";
  if (!["audio/mp4", "audio/x-m4a", "audio/m4a"].includes(normalized)) {
    throw new HttpError(415, "invalid_audio_type", "Send an M4A speaking recording.");
  }
  return normalized;
}

/// Soniox's async model, prompted for Tagalog with English for Taglish takes.
/// The target phrase is deliberately not sent as context: biasing the
/// recognizer towards it would hide the pronunciation mistakes the lesson grades.
export const sonioxAsyncModel = "stt-async-v5";
export const sonioxLanguageHints = ["tl", "en"];

export function sonioxTranscriptionRequest(fileID: string, requestID: string) {
  return {
    model: sonioxAsyncModel,
    file_id: fileID,
    language_hints: sonioxLanguageHints,
    client_reference_id: requestID.slice(0, 256),
  };
}

/**
 * Maps a Soniox transcript (`text` plus sub-word `tokens` in milliseconds) to
 * the public contract. A token that starts with whitespace begins a new word.
 */
export function sanitizeProviderTranscription(value: unknown): TranscriptionResponse {
  if (!isPlainObject(value) || typeof value.text !== "string") {
    throw new HttpError(
      502,
      "transcription_unavailable",
      "Speech feedback is temporarily unavailable.",
    );
  }
  const transcript = normalizeTranscript(value.text);
  if (transcript.length < 1) {
    throw new HttpError(422, "speech_not_detected", "We could not hear a phrase. Try once more.");
  }
  if (transcript.length > 500) {
    throw new HttpError(422, "speech_too_long", "Keep the speaking attempt to one short phrase.");
  }

  const words: TranscriptionWord[] = [];
  let current: { text: string; start: number; end: number } | null = null;
  const flush = () => {
    if (!current) return;
    const text = normalizeTranscript(current.text);
    if (text.length >= 1 && text.length <= 80 && words.length < 100) {
      words.push({ text, start: current.start, end: current.end });
    }
    current = null;
  };
  if (Array.isArray(value.tokens)) {
    for (const token of value.tokens.slice(0, 400)) {
      if (
        !isPlainObject(token) || typeof token.text !== "string" ||
        typeof token.start_ms !== "number" || !Number.isFinite(token.start_ms) ||
        typeof token.end_ms !== "number" || !Number.isFinite(token.end_ms) ||
        token.start_ms < 0 || token.end_ms < token.start_ms
      ) continue;
      const startsWord = current === null || /^\s/u.test(token.text);
      if (startsWord) flush();
      if (!token.text.trim()) continue;
      const piece = token.text;
      current = current
        ? { text: current.text + piece, start: current.start, end: token.end_ms / 1000 }
        : { text: piece, start: token.start_ms / 1000, end: token.end_ms / 1000 };
    }
    flush();
  }

  return {
    version: 1,
    transcript,
    languageCode: "fil",
    languageProbability: null,
    words,
  };
}

function normalizeTranscript(value: string): string {
  const normalized = value.normalize("NFC").trim().replace(/\s+/gu, " ");
  if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(normalized)) {
    throw new HttpError(
      502,
      "transcription_unavailable",
      "Speech feedback is temporarily unavailable.",
    );
  }
  return normalized;
}
