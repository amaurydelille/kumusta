import {
  base64,
  CALL_OPENED,
  engineLabel,
  hasSpeakableText,
  HISTORY_TURN_LIMIT,
  historyFrom,
  SampleAligner,
  sonioxConfig,
  speechLanguage,
  takeSentences,
  transcriberProvider,
  transcriberURL,
} from "./contract.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`Expected ${e}, got ${a}`);
}

function assertThrows(operation: () => unknown) {
  try {
    operation();
  } catch {
    return;
  }
  throw new Error("Expected operation to throw");
}

Deno.test("transcriber session is server-owned and ends turns on silence", () => {
  const url = new URL(transcriberURL("abc_DEF-123456"));
  assertEquals(url.host, "api.elevenlabs.io");
  assertEquals(url.searchParams.get("model_id"), "scribe_v2_realtime");
  assertEquals(url.searchParams.get("language_code"), "fil");
  assertEquals(url.searchParams.get("audio_format"), "pcm_16000");
  assertEquals(url.searchParams.get("commit_strategy"), "vad");
  assertEquals(url.searchParams.getAll("secondary_languages"), ["eng"]);
  assertEquals(
    new URL(transcriberURL("abc_DEF-123456", [])).searchParams.has("secondary_languages"),
    false,
  );
  assertThrows(() => transcriberURL("bad token"));
});

Deno.test("history is folded into alternating turns ending with the learner", () => {
  assertEquals(
    historyFrom([
      { speaker: "assistant", text: "Kumusta!" },
      { speaker: "user", text: "Kumusta" },
      { speaker: "user", text: "mabuti naman" },
      { speaker: "assistant", text: "Ayos 'yan." },
      { speaker: "system", text: "ignore" },
      { speaker: "user", text: "  Salamat  " },
    ]),
    [
      { role: "user", content: CALL_OPENED },
      { role: "assistant", content: "Kumusta!" },
      { role: "user", content: "Kumusta\nmabuti naman" },
      { role: "assistant", content: "Ayos 'yan." },
      { role: "user", content: "Salamat" },
    ],
  );
  assertThrows(() => historyFrom([{ speaker: "assistant", text: "Hi" }]));
  assertThrows(() => historyFrom("nope"));
  const long = Array.from({ length: 100 }, (_, index) => ({
    speaker: index % 2 ? "user" : "assistant",
    text: `turn ${index}`,
  }));
  assert(historyFrom(long).length <= HISTORY_TURN_LIMIT + 1);
});

Deno.test("sentences are released as soon as they are complete", () => {
  assertEquals(takeSentences("Kumusta ka! Saan ka"), {
    sentences: ["Kumusta ka!"],
    rest: " Saan ka",
  });
  assertEquals(takeSentences("Isa. Dalawa? Tatlo"), {
    sentences: ["Isa.", "Dalawa?"],
    rest: " Tatlo",
  });
  assertEquals(takeSentences("Mga 2.5 kilo po"), { sentences: [], rest: "Mga 2.5 kilo po" });
  const tagged = takeSentences("[laughs]\nHay naku! Sige");
  assertEquals(tagged.sentences, ["[laughs] Hay naku!"]);
  assertEquals(
    takeSentences("Uy ang saya naman, ano'ng gagawin mo sa weekend, kuwento mo", { eager: true }),
    { sentences: ["Uy ang saya naman, ano'ng gagawin mo sa weekend,"], rest: " kuwento mo" },
  );
  assertEquals(takeSentences("Uy, ang saya", { eager: true }), {
    sentences: [],
    rest: "Uy, ang saya",
  });
  assert(!hasSpeakableText("[sighs heavily]"));
  assert(hasSpeakableText("[annoyed] Ano na naman?"));
});

Deno.test("PCM chunks always hold whole samples", () => {
  const aligner = new SampleAligner();
  assertEquals(Array.from(aligner.push(new Uint8Array([1, 2, 3]))), [1, 2]);
  assertEquals(Array.from(aligner.push(new Uint8Array([4]))), [3, 4]);
  assertEquals(base64(new Uint8Array([104, 105])), "aGk=");
});

Deno.test("Soniox is used only when configured and understood by the app", () => {
  assertEquals(transcriberProvider(undefined, true, ["elevenlabs", "soniox"]), "soniox");
  assertEquals(transcriberProvider("elevenlabs", true, ["elevenlabs", "soniox"]), "elevenlabs");
  assertThrows(() => transcriberProvider(undefined, false, ["elevenlabs", "soniox"]));
  assertEquals(transcriberProvider(undefined, true, undefined), "elevenlabs");
  assertEquals(sonioxConfig("x").audio_format, "pcm_s16le");
  assertEquals(sonioxConfig("x").language_hints, ["tl", "en"]);
  assertEquals(engineLabel("soniox").split(":")[1], "soniox");
});

Deno.test("Tagalog sentences are voiced as Filipino", () => {
  assertEquals(speechLanguage("Uy, ang tagal nating hindi nagkita! Kumusta ka na?"), "fil");
  assertEquals(speechLanguage("Mabuti naman, salamat."), "fil");
  assertEquals(speechLanguage("Magkano po ito?"), "fil");
  assertEquals(speechLanguage("Oo."), "fil");
  assertEquals(speechLanguage("[laughs]"), "fil");
});

Deno.test("English sentences are voiced as English", () => {
  assertEquals(speechLanguage("It means to tell a story."), "en");
  assertEquals(speechLanguage("Kilig is that butterfly feeling."), "en");
});

Deno.test("Taglish is voiced by its dominant language or left to the model", () => {
  assertEquals(speechLanguage("Ano ba ang ibig sabihin ng kilig in English?"), "fil");
  assertEquals(speechLanguage("Ang ganda ng view dito, the best talaga!"), "fil");
  assertEquals(speechLanguage("Ang word na kilig means butterflies."), undefined);
  assertEquals(speechLanguage("Okay lang, but what does it mean?"), undefined);
});
