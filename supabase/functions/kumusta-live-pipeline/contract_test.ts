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
  assertEquals(url.searchParams.get("language_code"), "vie");
  assertEquals(url.searchParams.get("audio_format"), "pcm_16000");
  assertEquals(url.searchParams.get("commit_strategy"), "vad");
  assertEquals(url.searchParams.getAll("secondary_languages"), ["eng", "fra"]);
  assertEquals(
    new URL(transcriberURL("abc_DEF-123456", [])).searchParams.has("secondary_languages"),
    false,
  );
  assertThrows(() => transcriberURL("bad token"));
});

Deno.test("history is folded into alternating turns ending with the learner", () => {
  assertEquals(
    historyFrom([
      { speaker: "assistant", text: "Chào bạn!" },
      { speaker: "user", text: "Chào" },
      { speaker: "user", text: "mình khỏe" },
      { speaker: "assistant", text: "Hay quá." },
      { speaker: "system", text: "ignore" },
      { speaker: "user", text: "  Cảm ơn  " },
    ]),
    [
      { role: "user", content: CALL_OPENED },
      { role: "assistant", content: "Chào bạn!" },
      { role: "user", content: "Chào\nmình khỏe" },
      { role: "assistant", content: "Hay quá." },
      { role: "user", content: "Cảm ơn" },
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
  assertEquals(takeSentences("Chào bạn! Hôm nay"), {
    sentences: ["Chào bạn!"],
    rest: " Hôm nay",
  });
  assertEquals(takeSentences("Một. Hai? Ba"), { sentences: ["Một.", "Hai?"], rest: " Ba" });
  assertEquals(takeSentences("Giá 3.5 nghìn"), { sentences: [], rest: "Giá 3.5 nghìn" });
  const tagged = takeSentences("[laughs]\nTrời ơi! Nói");
  assertEquals(tagged.sentences, ["[laughs] Trời ơi!"]);
  assertEquals(
    takeSentences("Ồ hay quá, cuối tuần này bạn định làm gì, kể mình nghe", { eager: true }),
    { sentences: ["Ồ hay quá, cuối tuần này bạn định làm gì,"], rest: " kể mình nghe" },
  );
  assertEquals(takeSentences("Ồ, hay quá", { eager: true }), {
    sentences: [],
    rest: "Ồ, hay quá",
  });
  assert(!hasSpeakableText("[sighs heavily]"));
  assert(hasSpeakableText("[annoyed] Gì nữa?"));
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
  assertEquals(transcriberProvider(undefined, false, ["elevenlabs", "soniox"]), "elevenlabs");
  assertEquals(transcriberProvider(undefined, true, undefined), "elevenlabs");
  assertEquals(sonioxConfig("x").audio_format, "pcm_s16le");
  assertEquals(engineLabel("soniox").split(":")[1], "soniox");
});

Deno.test("Each sentence is voiced in its own language", () => {
  assertEquals(speechLanguage("Ê, lâu quá hông gặp! Dạo này sao rồi?"), "vi");
  assertEquals(speechLanguage("Dạ, mình khỏe lắm nè."), "vi");
  assertEquals(speechLanguage("C'est un mot très courant pour parler d'un magasin."), "fr");
  assertEquals(speechLanguage("It means to tell a story."), "en");
  assertEquals(speechLanguage("Ça veut dire « raconter », comme dans kể chuyện."), undefined);
  assertEquals(speechLanguage("Tiệm means a small shop."), undefined);
  assertEquals(speechLanguage("Ừ."), "vi");
});
