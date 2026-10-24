import { HttpError, isPlainObject } from "../_shared/http.ts";

export const REALTIME_SAMPLE_RATE = 16_000;
const REALTIME_ENDPOINT = "wss://api.elevenlabs.io/v1/speech-to-text/realtime";

export interface RealtimeSessionResponse {
  version: 1;
  url: string;
  sampleRate: number;
}

/// The session configuration stays server-owned: the client connects to the
/// returned URL as-is and never chooses the model, language, or audio format.
/// The target phrase is deliberately not sent as a key term, since biasing the
/// recognizer towards it would hide the pronunciation mistakes the lesson grades.
export function realtimeSession(providerPayload: unknown): RealtimeSessionResponse {
  if (
    !isPlainObject(providerPayload) ||
    typeof providerPayload.token !== "string" ||
    !/^[A-Za-z0-9_-]{8,512}$/.test(providerPayload.token)
  ) {
    throw new HttpError(
      502,
      "transcription_unavailable",
      "Speech feedback is temporarily unavailable.",
    );
  }
  const url = new URL(REALTIME_ENDPOINT);
  url.searchParams.set("model_id", "scribe_v2_realtime");
  url.searchParams.set("language_code", "fil");
  url.searchParams.set("audio_format", `pcm_${REALTIME_SAMPLE_RATE}`);
  url.searchParams.set("commit_strategy", "manual");
  url.searchParams.set("token", providerPayload.token);
  return { version: 1, url: url.toString(), sampleRate: REALTIME_SAMPLE_RATE };
}
