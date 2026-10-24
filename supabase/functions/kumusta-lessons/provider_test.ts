/// <reference lib="deno.ns" />

import {
  defaultQwenLessonModel,
  maximumLessonGenerationAttempts,
  qwenLessonAPIURL,
  repairGeneratedBatchStructure,
} from "./provider.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("lesson generation has bounded exceptional recovery", () => {
  assert(maximumLessonGenerationAttempts === 3, "the provider retry bound changed unexpectedly");
});

Deno.test("lesson generation is pinned to the preview Qwen snapshot", () => {
  assert(defaultQwenLessonModel === "qwen3.8-max-0902", "the Qwen model snapshot changed");
  assert(
    qwenLessonAPIURL ===
      "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
    "the international QwenCloud endpoint changed",
  );
});

Deno.test("grounded chunks are reordered deterministically before validation", () => {
  const repaired = repairGeneratedBatchStructure({
    lessons: [{
      scenario_key: "order_coffee",
      rounds: [{
        topic_key: "wrong_key",
        tagalog: "Pabili po ng kape, Ate.",
        chunks: [
          { tagalog: "ng kape" },
          { tagalog: "Pabili po" },
          { tagalog: "Ate." },
        ],
      }],
    }],
  }) as {
    lessons: Array<{
      rounds: Array<{ topic_key: string; chunks: Array<{ tagalog: string }> }>;
    }>;
  };
  const round = repaired.lessons[0].rounds[0];

  assert(round.topic_key === "order_coffee", "topic key was not canonicalized");
  assert(
    round.chunks.map((chunk) => chunk.tagalog).join("|") ===
      "Pabili po|ng kape|Ate.",
    "grounded chunks remained out of utterance order",
  );
});

Deno.test("multi-word model glosses remain one tappable lexical unit", () => {
  const repaired = repairGeneratedBatchStructure({
    lessons: [{
      scenario_key: "order_coffee",
      rounds: [{
        topic_key: "order_coffee",
        tagalog: "Pabili po ng kapeng barako.",
        chunks: [],
        word_glosses: [
          { token: "Pabili", english: "may I buy" },
          { token: "po", english: "(respect)" },
          { token: "ng", english: "some" },
          { token: "kapeng barako", english: "barako coffee" },
        ],
      }],
    }],
  }) as {
    lessons: Array<{
      rounds: Array<{ word_glosses: Array<{ token: string; english: string }> }>;
    }>;
  };
  const glosses = repaired.lessons[0].rounds[0].word_glosses;

  assert(
    glosses.map((gloss) => gloss.token).join("|") === "Pabili|po|ng|kapeng barako.",
    "compound glosses were not preserved as lexical units",
  );
  assert(
    glosses[3].english === "barako coffee",
    "the compound's contextual meaning was not preserved",
  );
});

Deno.test("missing model glosses are filled from the source phrase", () => {
  const repaired = repairGeneratedBatchStructure({
    lessons: [{
      scenario_key: "order_coffee",
      rounds: [{
        tagalog: "Pabili po ng kapeng barako.",
        word_glosses: [
          { token: "Pabili", english: "may I buy" },
          { token: "ng", english: "some" },
          { token: "kapeng barako.", english: "barako coffee" },
        ],
      }],
    }],
  }) as {
    lessons: Array<{
      rounds: Array<{ word_glosses: Array<{ token: string; english: string }> }>;
    }>;
  };
  const glosses = repaired.lessons[0].rounds[0].word_glosses;

  assert(
    glosses.map((gloss) => gloss.token).join("|") === "Pabili|po|ng|kapeng barako.",
    "missing source tokens were not restored in order",
  );
  assert(
    glosses[1].english === "contextual meaning",
    "the missing gloss did not receive a safe fallback",
  );
});

Deno.test("missing hear/respond exercises are grounded in their round", () => {
  const repaired = repairGeneratedBatchStructure({
    lessons: [{
      scenario_key: "order_coffee",
      rounds: Array.from({ length: 5 }, (_, index) => ({
        tagalog: `Linya ${index + 1} po.`,
        translation: `Meaning ${index + 1}.`,
      })),
    }],
  }) as {
    lessons: Array<{
      rounds: Array<{
        tagalog: string;
        translation: string;
        response_exercise?: {
          prompt_tagalog: string;
          prompt_translation: string;
          options: Array<{ english_translation: string }>;
          correct_option_index: number;
        };
      }>;
    }>;
  };
  const round = repaired.lessons[0].rounds[2];
  const exercise = round.response_exercise;

  assert(exercise !== undefined, "the selected round did not receive an exercise");
  assert(exercise.prompt_tagalog === round.tagalog, "exercise phrase was not grounded");
  assert(
    exercise.prompt_translation === round.translation,
    "exercise translation was not grounded",
  );
  assert(exercise.options.length === 3, "exercise did not receive three options");
  assert(
    exercise.options[exercise.correct_option_index].english_translation === round.translation,
    "correct answer was not grounded",
  );
});

Deno.test("non-selected hear/respond exercises are removed before validation", () => {
  const repaired = repairGeneratedBatchStructure({
    lessons: [{
      scenario_key: "order_coffee",
      rounds: Array.from({ length: 5 }, (_, index) => ({
        response_exercise: { marker: index },
      })),
    }],
  }) as {
    lessons: Array<{
      rounds: Array<{ response_exercise?: { marker: number } }>;
    }>;
  };
  const rounds = repaired.lessons[0].rounds;

  assert(rounds[0].response_exercise === undefined, "round 1 kept an unexpected exercise");
  assert(rounds[1].response_exercise === undefined, "round 2 kept an unexpected exercise");
  assert(rounds[2].response_exercise?.marker === 2, "the first selected exercise was removed");
  assert(rounds[3].response_exercise === undefined, "round 4 kept an unexpected exercise");
  assert(rounds[4].response_exercise?.marker === 4, "the second selected exercise was removed");
});
