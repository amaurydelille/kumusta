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

  const languageProbability = typeof value.language_probability === "number" &&
      Number.isFinite(value.language_probability) && value.language_probability >= 0 &&
      value.language_probability <= 1
    ? value.language_probability
    : null;
  const words: TranscriptionWord[] = [];
  if (Array.isArray(value.words)) {
    for (const candidate of value.words.slice(0, 100)) {
      if (!isPlainObject(candidate) || candidate.type !== "word") continue;
      if (
        typeof candidate.text !== "string" ||
        typeof candidate.start !== "number" || !Number.isFinite(candidate.start) ||
        typeof candidate.end !== "number" || !Number.isFinite(candidate.end) ||
        candidate.start < 0 || candidate.end < candidate.start
      ) continue;
      const text = normalizeTranscript(candidate.text);
      if (text.length < 1 || text.length > 80) continue;
      words.push({ text, start: candidate.start, end: candidate.end });
    }
  }

  return {
    version: 1,
    transcript,
    languageCode: "fil",
    languageProbability,
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
