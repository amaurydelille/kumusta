/// <reference lib="deno.ns" />

import {
  sanitizeProviderTranscription,
  sonioxTranscriptionRequest,
  validateAudioContentType,
} from "./contract.ts";

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

Deno.test("STT strips the Soniox transcript to the public contract", () => {
  const output = sanitizeProviderTranscription({
    id: "19b6d61d-02db-4c25-bc71-b4094dc310c8",
    text: "  Isang   kape nga po.  ",
    tokens: [
      { text: "Is", start_ms: 100, end_ms: 180, confidence: 0.9 },
      { text: "ang", start_ms: 180, end_ms: 250, confidence: 0.9 },
      { text: " ka", start_ms: 300, end_ms: 360, confidence: 0.9 },
      { text: "pe", start_ms: 360, end_ms: 420, confidence: 0.9 },
      { text: " nga", start_ms: 450, end_ms: 520, confidence: 0.9 },
      { text: " po.", start_ms: 530, end_ms: 600, confidence: 0.9 },
      { text: " bad", start_ms: -1, end_ms: 5 },
    ],
    provider_internal: "must not leak",
  });
  assert(output.version === 1, "Version changed");
  assert(output.transcript === "Isang kape nga po.", "Transcript not normalized");
  assert(
    output.words.map((word) => word.text).join("|") === "Isang|kape|nga|po.",
    "Sub-word tokens were not joined into words",
  );
  assert(output.words[0].start === 0.1 && output.words[0].end === 0.25, "Timings not in seconds");
  assert(output.languageCode === "fil", "Language code must be Filipino");
  assert(!("provider_internal" in output), "Provider payload leaked");
});

Deno.test("STT asks Soniox for Tagalog with English, never the target phrase", () => {
  const request = sonioxTranscriptionRequest("file-1", "request-1");
  assert(request.model === "stt-async-v5", "Wrong async model");
  assert(request.language_hints.join(",") === "tl,en", "Tagalog must be hinted");
  assert(!("context" in request), "The target phrase must not bias the recognizer");
});

Deno.test("STT rejects empty speech", () => {
  let rejected = false;
  try {
    sanitizeProviderTranscription({ text: "   ", tokens: [] });
  } catch {
    rejected = true;
  }
  assert(rejected, "Empty transcription should be rejected");
});
