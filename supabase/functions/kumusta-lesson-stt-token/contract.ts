import { HttpError, isPlainObject } from "../_shared/http.ts";

export const REALTIME_SAMPLE_RATE = 16_000;
export const SONIOX_REALTIME_ENDPOINT = "wss://stt-rt.soniox.com/transcribe-websocket";

export interface RealtimeSessionResponse {
  version: 1;
  provider: "soniox";
  url: string;
  /// A short-lived, single-use Soniox key; the real key never leaves the server.
  token: string;
  /// The start request the app sends as the socket's first message, as JSON text.
  config: string;
  sampleRate: number;
}

/// The temporary key the app may use for one lesson take.
export function temporaryKeyRequest(requestID: string) {
  return {
    usage_type: "transcribe_websocket",
    expires_in_seconds: 60,
    single_use: true,
    max_session_duration_seconds: 120,
    client_reference_id: requestID.slice(0, 256),
  };
}

/// The session configuration stays server-owned: the app sends this start
/// request as-is and never chooses the model, language, or audio format.
/// The target phrase is deliberately not sent as context, since biasing the
/// recognizer towards it would hide the pronunciation mistakes the lesson grades.
export function realtimeConfig(): Record<string, unknown> {
  return {
    model: "stt-rt-v5",
    audio_format: "pcm_s16le",
    sample_rate: REALTIME_SAMPLE_RATE,
    num_channels: 1,
    language_hints: ["tl", "en"],
  };
}

export function realtimeSession(providerPayload: unknown): RealtimeSessionResponse {
  if (
    !isPlainObject(providerPayload) ||
    typeof providerPayload.api_key !== "string" ||
    !/^[A-Za-z0-9_.:-]{8,512}$/.test(providerPayload.api_key)
  ) {
    throw new HttpError(
      502,
      "transcription_unavailable",
      "Speech feedback is temporarily unavailable.",
    );
  }
  return {
    version: 1,
    provider: "soniox",
    url: SONIOX_REALTIME_ENDPOINT,
    token: providerPayload.api_key,
    config: JSON.stringify(realtimeConfig()),
    sampleRate: REALTIME_SAMPLE_RATE,
  };
}
