/// <reference lib="deno.ns" />

import { realtimeConfig, realtimeSession, temporaryKeyRequest } from "./contract.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("Realtime grant carries a temporary Soniox key and the server-owned config", () => {
  const session = realtimeSession({
    api_key: "temp:abc123XYZ",
    expires_at: "2026-10-25T10:00:00Z",
  });
  assert(session.provider === "soniox", "Provider must be Soniox");
  assert(session.url === "wss://stt-rt.soniox.com/transcribe-websocket", "Wrong endpoint");
  assert(session.token === "temp:abc123XYZ", "Temporary key was not passed through");
  assert(session.sampleRate === 16_000, "Sample rate drifted from the recorder");
  const config = JSON.parse(session.config);
  assert(config.model === "stt-rt-v5", "Wrong realtime model");
  assert(config.audio_format === "pcm_s16le" && config.num_channels === 1, "Wrong audio format");
  assert(config.language_hints.join(",") === "tl,en", "Tagalog must be hinted");
  assert(!("api_key" in config) && !("context" in config), "Config must hold no key or target");
});

Deno.test("Temporary keys are single-use and short-lived", () => {
  const request = temporaryKeyRequest("request-1");
  assert(request.usage_type === "transcribe_websocket", "Wrong usage type");
  assert(
    request.single_use && request.expires_in_seconds <= 60,
    "Key must be single-use and short",
  );
  assert(Object.keys(realtimeConfig()).length > 0, "Config is empty");
});

Deno.test("Malformed provider keys are rejected", () => {
  let rejected = false;
  try {
    realtimeSession({ api_key: "bad key with spaces" });
  } catch {
    rejected = true;
  }
  assert(rejected, "Malformed key accepted");
});
