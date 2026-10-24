/// <reference lib="deno.ns" />

import { sanitizeProviderTranscription, validateAudioContentType } from "./contract.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("STT accepts only the recorder's bounded media type", () => {
  assert(validateAudioContentType("audio/mp4") === "audio/mp4", "M4A container was rejected");
  let rejected = false;
  try {
    validateAudioContentType("application/octet-stream");
  } catch {
    rejected = true;
  }
  assert(rejected, "Arbitrary binary input should be rejected");
});

Deno.test("STT strips provider payload to the public contract", () => {
  const output = sanitizeProviderTranscription({
    language_code: "fil",
    language_probability: 0.97,
    text: "  Isang   kape nga po.  ",
    words: [
      { text: "Isang", start: 0.1, end: 0.25, type: "word", logprob: -0.01 },
      { text: "[noise]", start: 0.25, end: 0.3, type: "audio_event" },
    ],
    provider_internal: "must not leak",
  });
  assert(output.version === 1, "Version changed");
  assert(output.transcript === "Isang kape nga po.", "Transcript not normalized");
  assert(output.words.length === 1 && output.words[0].text === "Isang", "Words not sanitized");
  assert(output.languageCode === "fil", "Language code must be Filipino");
  assert(output.languageProbability === 0.97, "Language probability was dropped");
  assert(!("provider_internal" in output), "Provider payload leaked");
});

Deno.test("STT rejects empty speech", () => {
  let rejected = false;
  try {
    sanitizeProviderTranscription({ text: "   ", words: [] });
  } catch {
    rejected = true;
  }
  assert(rejected, "Empty transcription should be rejected");
});
