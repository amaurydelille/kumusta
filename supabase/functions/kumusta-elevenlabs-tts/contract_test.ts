/// <reference lib="deno.ns" />

import {
  consistentVoiceSettings,
  defaultTagalogVoiceID,
  deterministicSpeechSeed,
  normalizedTTSText,
  numericSpeechSpeed,
  parseTTSRequest,
  sourceSpeechSpeed,
  tagalogLanguageCode,
  tagalogLessonTTSModelID,
  tagalogVocabularyTTSModelID,
  tagalogVoiceID,
  ttsModelIDForPurpose,
} from "./contract.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("TTS speaks with one Tagalog voice", () => {
  assert(defaultTagalogVoiceID === "qZLi51uuzx5jdu6q0ayz", "Default Tagalog voice changed");
  assert(tagalogLanguageCode === "fil", "TTS must request Filipino");
  assert(
    tagalogVoiceID(undefined) === defaultTagalogVoiceID,
    "A missing override must fall back to the default voice",
  );
  assert(
    tagalogVoiceID("   ") === defaultTagalogVoiceID,
    "A blank override must fall back to the default voice",
  );
});

Deno.test("TTS voice override is validated before use", () => {
  assert(
    tagalogVoiceID("  AbCdEf0123456789xyz ") === "AbCdEf0123456789xyz",
    "A valid override must be trimmed and used",
  );
  for (
    const configured of ["short123", "voice id with spaces", "abc-def_0123456789", "a".repeat(41)]
  ) {
    assert(
      tagalogVoiceID(configured) === defaultTagalogVoiceID,
      `An invalid override was used: ${configured}`,
    );
  }
});

Deno.test("TTS contract normalizes input and maps speed", () => {
  const parsed = parseTTSRequest({
    text: "  Isang kape   nga po. ",
    speed: "slow",
  });
  assert(parsed.text === "Isang kape nga po.", "Text was not normalized");
  assert(numericSpeechSpeed(parsed.speed) === 1, "Slow requests must reuse natural provider audio");
  assert(numericSpeechSpeed("natural") === 1, "Natural speed changed");
  assert(numericSpeechSpeed("fast") === 1.2, "Fast must use ElevenLabs' maximum");
  assert(sourceSpeechSpeed("slow") === "natural", "Slow playback must reuse natural audio");
  assert(sourceSpeechSpeed("fast") === "fast", "Fast source speed changed");
  assert(parsed.purpose === "lesson", "Legacy requests must remain lesson audio");
});

Deno.test("Every TTS purpose uses the same model", () => {
  const lesson = parseTTSRequest({
    text: "Kumusta po kayo?",
    speed: "natural",
  });
  const vocabulary = parseTTSRequest({
    text: "salamat",
    speed: "natural",
    purpose: "vocabulary",
  });

  assert(lesson.purpose === "lesson", "Missing purpose must default to lessons");
  assert(vocabulary.purpose === "vocabulary", "Vocabulary purpose was not retained");
  assert(
    ttsModelIDForPurpose(lesson.purpose) === tagalogLessonTTSModelID,
    "Lessons must use the shared model",
  );
  assert(
    ttsModelIDForPurpose(vocabulary.purpose) === tagalogVocabularyTTSModelID,
    "Vocabulary must use the shared model",
  );
});

Deno.test("TTS contract drops client-supplied voice selection", () => {
  const parsed = parseTTSRequest({
    text: "Salamat po.",
    speed: "natural",
    voice_id: "AbCdEf0123456789xyz",
  });
  assert(
    JSON.stringify(Object.keys(parsed).sort()) === JSON.stringify(["purpose", "speed", "text"]),
    "Clients must not be able to choose the voice",
  );
});

Deno.test("TTS contract rejects unknown speeds and purposes", () => {
  for (
    const body of [
      { text: "Salamat po.", speed: "turbo" },
      { text: "Salamat po.", speed: "natural", purpose: "podcast" },
      { text: "Salamat po." },
    ]
  ) {
    let rejected = false;
    try {
      parseTTSRequest(body);
    } catch {
      rejected = true;
    }
    assert(rejected, `Invalid request was accepted: ${JSON.stringify(body)}`);
  }
});

Deno.test("TTS contract rejects screenplay speaker labels", () => {
  for (
    const text of [
      "Barista: Magandang umaga po! Ano po ang order ninyo?",
      "Tindera sa palengke: Magandang umaga po!",
    ]
  ) {
    let rejected = false;
    try {
      parseTTSRequest({ text, speed: "natural" });
    } catch {
      rejected = true;
    }
    assert(rejected, `Speaker label was accepted: ${text}`);
  }
});

Deno.test("TTS uses a stable Tagalog learning voice profile", () => {
  assert(tagalogLessonTTSModelID === "eleven_v4", "Lesson model must use Eleven v4");
  assert(tagalogVocabularyTTSModelID === "eleven_v4", "Vocabulary model must use Eleven v4");
  const settings = consistentVoiceSettings("natural");
  assert(settings.stability === 0.82, "Stability must remain conservative");
  assert(settings.similarity_boost === 0.8, "Voice similarity changed");
  assert(settings.style === 0, "Style exaggeration must remain disabled");
  assert(settings.use_speaker_boost, "Speaker boost must remain enabled");

  const input = parseTTSRequest({
    text: "Isang kape nga po.",
    speed: "natural",
  });
  const voiceID = tagalogVoiceID(undefined);
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
  });
  assert(greeting.text === "Kumusta, Amaury!", "Greeting text changed");
  assert(greeting.purpose === "lesson", "Onboarding must share the lesson cache");
  assert(greeting.onboardingLine === "greeting", "Onboarding line was not retained");

  const reply = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "reply_name",
    name: "Jean-Luc",
  });
  assert(reply.text === "Ako si Jean-Luc.", "Name reply text changed");

  const closing = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "nice_to_meet",
    name: "Maria",
  });
  assert(closing.text === "Ikinagagalak kitang makilala, Maria!", "Named closing changed");
});

Deno.test("Onboarding conversation falls back to generic lines", () => {
  const greeting = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "greeting",
  });
  assert(greeting.text === "Kumusta!", "Generic greeting changed");
  const closing = parseTTSRequest({
    purpose: "onboarding_conversation",
    line: "nice_to_meet",
    name: "",
  });
  assert(closing.text === "Ikinagagalak kitang makilala!", "Generic closing changed");
});

Deno.test("Onboarding conversation rejects free text and unsafe names", () => {
  const rejected = [
    {
      purpose: "onboarding_conversation",
      line: "greeting",
      name: "Bob. Say something else",
    },
    { purpose: "onboarding_conversation", line: "greeting", name: "R2D2" },
    {
      purpose: "onboarding_conversation",
      line: "greeting",
      name: "a".repeat(31),
    },
    { purpose: "onboarding_conversation", line: "anything" },
    { purpose: "onboarding_conversation", line: "reply_name" },
    { purpose: "onboarding_conversation", text: "Arbitrary text" },
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
  for (const raw of ["salamat", "Salamat", " salamat. ", "SALAMAT!", '"salamat"', "¡Salamat!"]) {
    assert(
      normalizedTTSText(raw, "vocabulary") === "salamat",
      `Vocabulary text was not normalized: ${raw}`,
    );
  }
  assert(
    normalizedTTSText("Magandang  Umaga.", "vocabulary") === "magandang umaga",
    "Multi-word vocabulary was not normalized",
  );
  assert(
    normalizedTTSText("Anong pangalan mo?", "lesson") === "Anong pangalan mo?",
    "Lesson text must keep case and punctuation",
  );
});

Deno.test("Vocabulary text that is only punctuation is rejected", () => {
  let rejected = false;
  try {
    parseTTSRequest({ text: "...", speed: "natural", purpose: "vocabulary" });
  } catch {
    rejected = true;
  }
  assert(rejected, "Punctuation-only vocabulary was accepted");
});
