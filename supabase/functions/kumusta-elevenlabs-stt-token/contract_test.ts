/// <reference lib="deno.ns" />

import { realtimeSession } from "./contract.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("Realtime session pins the server-owned configuration", () => {
  const session = realtimeSession({ token: "sutkn_1234567890", provider_internal: "x" });
  const url = new URL(session.url);
  assert(url.protocol === "wss:" && url.host === "api.elevenlabs.io", "Unexpected endpoint");
  assert(url.searchParams.get("model_id") === "scribe_v2_realtime", "Model not pinned");
  assert(url.searchParams.get("language_code") === "vie", "Language not pinned");
  assert(url.searchParams.get("audio_format") === "pcm_16000", "Format not pinned");
  assert(url.searchParams.get("commit_strategy") === "manual", "Commit strategy not pinned");
  assert(url.searchParams.get("token") === "sutkn_1234567890", "Token missing");
  assert(!url.searchParams.has("keyterms"), "Recognizer must not be biased");
  assert(session.sampleRate === 16_000, "Sample rate changed");
  assert(!("provider_internal" in session), "Provider payload leaked");
});

Deno.test("Realtime session rejects a malformed provider token", () => {
  for (const payload of [null, {}, { token: "" }, { token: "a b&c=d" }]) {
    let rejected = false;
    try {
      realtimeSession(payload);
    } catch {
      rejected = true;
    }
    assert(rejected, `Accepted ${JSON.stringify(payload)}`);
  }
});
