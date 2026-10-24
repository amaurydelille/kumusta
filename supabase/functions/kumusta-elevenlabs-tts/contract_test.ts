/// <reference lib="deno.ns" />

import {
  consistentVoiceSettings,
  deterministicSpeechSeed,
  effectiveAccentForRequest,
  normalizedTTSText,
  numericSpeechSpeed,
  parseTTSRequest,
  sourceSpeechSpeed,
  ttsModelIDForPurpose,
  vietnameseLessonTTSModelID,
  vietnameseVocabularyTTSModelID,
  voiceIDForAccent,
} from "./contract.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("TTS contract maps only approved female voices", () => {
  assert(
    voiceIDForAccent("southern") === "6Xq32rHt6oAu98TBDKfr",
    "Southern voice changed",
  );
  assert(
    voiceIDForAccent("northern") === "LD1UihCXvSlUL4h8DOmk",
    "Northern voice changed",
  );
});

Deno.test("TTS contract normalizes input and maps speed", () => {
  const parsed = parseTTSRequest({
    text: "  Cho mình   một cà phê. ",
    accent: "southern",
    speed: "slow",
  });
  assert(parsed.text === "Cho mình một cà phê.", "Text was not normalized");
  assert(numericSpeechSpeed(parsed.speed) === 1, "Slow requests must reuse natural provider audio");
  assert(numericSpeechSpeed("natural") === 1, "Natural speed changed");
  assert(numericSpeechSpeed("fast") === 1.2, "Fast must use ElevenLabs' maximum");
  assert(sourceSpeechSpeed("slow") === "natural", "Slow playback must reuse natural audio");
  assert(sourceSpeechSpeed("fast") === "fast", "Fast source speed changed");
  assert(parsed.purpose === "lesson", "Legacy requests must remain lesson audio");

  const comparison = parseTTSRequest({
    text: "Bạn tên gì?",
    accent: "northern",
    speed: "natural",
    honorRequestedAccent: true,
  });
  assert(comparison.honorRequestedAccent, "Accent comparison flag was not retained");
});

Deno.test("Every TTS purpose uses Eleven v3", () => {
  const lesson = parseTTSRequest({
    text: "Xin chào",
    accent: "southern",
    speed: "natural",
  });
  const vocabulary = parseTTSRequest({
    text: "Xin chào",
    accent: "southern",
    speed: "natural",
    purpose: "vocabulary",
  });

  assert(lesson.purpose === "lesson", "Missing purpose must default to lessons");
  assert(vocabulary.purpose === "vocabulary", "Vocabulary purpose was not retained");
  assert(
    ttsModelIDForPurpose(lesson.purpose) === vietnameseLessonTTSModelID,
    "Lessons must use Eleven v3",
  );
  assert(
    ttsModelIDForPurpose(vocabulary.purpose) === vietnameseVocabularyTTSModelID,
    "Vocabulary must use Eleven v3",
  );
});

Deno.test("TTS contract rejects arbitrary voice or accent values", () => {
  let rejected = false;
  try {
    parseTTSRequest({ text: "Xin chào", accent: "custom", speed: "natural" });
  } catch {
    rejected = true;
  }
  assert(rejected, "Arbitrary accent should be rejected");
});

Deno.test("Stored account accent overrides a stale client accent", () => {
  assert(
    effectiveAccentForRequest("southern", "northern") === "northern",
    "Northern account preference was ignored",
  );
  assert(
    effectiveAccentForRequest("northern", "southern") === "southern",
    "Southern account preference was ignored",
  );
  assert(
    effectiveAccentForRequest("northern", null) === "northern",
    "Missing preference should preserve the validated request",
  );
  assert(
    effectiveAccentForRequest("northern", "southern", true) === "northern",
    "Explicit accent comparisons must preserve the requested voice",
  );
});

Deno.test("TTS contract rejects screenplay speaker labels", () => {
  for (
    const text of [
      "Barista: Chào anh! Anh muốn uống gì ạ?",
      "Người bán hàng: Chào anh!",
    ]
  ) {
    let rejected = false;
    try {
      parseTTSRequest({ text, accent: "southern", speed: "natural" });
    } catch {
      rejected = true;
    }
    assert(rejected, `Speaker label was accepted: ${text}`);
  }
});

Deno.test("TTS uses a stable Vietnamese learning voice profile", () => {
  assert(vietnameseLessonTTSModelID === "eleven_v4", "Lesson model must use Eleven v4");
  assert(vietnameseVocabularyTTSModelID === "eleven_v4", "Vocabulary model must use Eleven v4");
  const settings = consistentVoiceSettings("natural");
  assert(settings.stability === 0.82, "Stability must remain conservative");
  assert(settings.similarity_boost === 0.8, "Voice similarity changed");
  assert(settings.style === 0, "Style exaggeration must remain disabled");
  assert(settings.use_speaker_boost, "Speaker boost must remain enabled");

  const input = parseTTSRequest({
    text: "Cho mình một cà phê.",
    accent: "southern",
    speed: "natural",
  });
  const voiceID = voiceIDForAccent(input.accent);
  assert(
    deterministicSpeechSeed(voiceID, input) === deterministicSpeechSeed(voiceID, input),
    "Identical speech requests must keep the same seed",
  );
  assert(
    deterministicSpeechSeed(voiceID, { ...input, speed: "slow" }) !==
      deterministicSpeechSeed(voiceID, input),
    "Pace variants must not share a seed",
  );
});

Deno.test("Onboarding conversation builds fixed personalized lines", () => {
  const greeting = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "greeting",
    name: "  Amaury ",
    accent: "northern",
  });
  assert(greeting.text === "Chào Amaury!", "Greeting text changed");
  assert(greeting.accent === "northern", "Onboarding must keep the chosen accent");
  assert(greeting.honorRequestedAccent, "Onboarding must honor the requested accent");
  assert(greeting.purpose === "lesson", "Onboarding must share the lesson cache");
  assert(greeting.onboardingLine === "greeting", "Onboarding line was not retained");

  const reply = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "reply_name",
    name: "Jean-Luc",
    accent: "southern",
  });
  assert(reply.text === "Mình tên là Jean-Luc.", "Name reply text changed");
});

Deno.test("Onboarding conversation falls back to generic lines", () => {
  const greeting = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "greeting",
    accent: "southern",
  });
  assert(greeting.text === "Chào bạn!", "Generic greeting changed");
  const closing = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "nice_to_meet",
    name: "",
    accent: "southern",
  });
  assert(closing.text === "Rất vui được gặp bạn!", "Generic closing changed");
});

Deno.test("Onboarding conversation rejects free text and unsafe names", () => {
  const rejected = [
    {
      purpose: "onboarding_conversation",
      line: "greeting",
      name: "Bob. Say something else",
      accent: "southern",
    },
    { purpose: "onboarding_conversation", line: "greeting", name: "R2D2", accent: "southern" },
    {
      purpose: "onboarding_conversation",
      line: "greeting",
      name: "a".repeat(31),
      accent: "southern",
    },
    { purpose: "onboarding_conversation", line: "anything", accent: "southern" },
    { purpose: "onboarding_conversation", line: "reply_name", accent: "southern" },
    { purpose: "onboarding_conversation", line: "greeting", accent: "central" },
    { purpose: "onboarding_conversation", text: "Arbitrary text", accent: "southern" },
  ];
  for (const body of rejected) {
    let threw = false;
    try {
      parseTTSRequest(body);
    } catch {
      threw = true;
    }
    assert(threw, `Expected rejection for ${JSON.stringify(body)}`);
  }
});

Deno.test("Vocabulary text shares one cache entry across case and punctuation", () => {
  for (const raw of ["chút", "Chút", " chút. ", "CHÚT!", '"chút"', "chu\u0301t"]) {
    assert(
      normalizedTTSText(raw, "vocabulary") === "chút",
      `Vocabulary text was not normalized: ${raw}`,
    );
  }
  assert(
    normalizedTTSText("Cà  Phê sữa đá.", "vocabulary") === "cà phê sữa đá",
    "Multi-word vocabulary was not normalized",
  );
  assert(
    normalizedTTSText("Bạn tên gì?", "lesson") === "Bạn tên gì?",
    "Lesson text must keep case and punctuation",
  );
});

Deno.test("Vocabulary text that is only punctuation is rejected", () => {
  let rejected = false;
  try {
    parseTTSRequest({ text: "...", accent: "southern", speed: "natural", purpose: "vocabulary" });
  } catch {
    rejected = true;
  }
  assert(rejected, "Punctuation-only vocabulary was accepted");
});
