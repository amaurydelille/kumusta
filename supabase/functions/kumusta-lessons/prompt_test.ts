import { systemPrompt, userPrompt } from "./prompt.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("explicit topic remains verbatim and outranks the broad onboarding goal", () => {
  const requestedTopic =
    "I want to feel confident dating Vietnamese women and learn how to ask someone out";
  const value = JSON.parse(userPrompt({
    profile: {
      accent: "southern",
      goal: "family",
      selfAssessedLevel: "familiar",
      targetLevel: 4,
      challengePreference: "balanced",
      dailyMinutes: 7,
    },
    estimatedLevel: 2.4,
    challengeOffset: 0.5,
    skillMastery: {},
    recentScenarioKeys: [],
    familiarLanguage: { vocabulary: [], chunks: [] },
    nextTopicPreference: requestedTopic,
    count: 1,
  }));

  assert(
    value.constraints.untrusted_learner_topic_preference === requestedTopic,
    "the learner topic was rewritten",
  );
  assert(
    value.constraints.topic_preference_rule.includes("PRIMARY outcome"),
    "the explicit topic was not made primary",
  );
  assert(
    value.learner.broad_onboarding_goal.includes("secondary context only"),
    "the broad goal can still redirect the explicit request",
  );
});

Deno.test("prompt enforces natural social address and one connected story", () => {
  const prompt = systemPrompt();
  assert(prompt.includes("Never mechanically translate"), "mechanical pronouns were not rejected");
  assert(prompt.includes("relative age or generation"), "age hierarchy was not considered");
  assert(prompt.includes("tôi/bạn"), "the common unnatural default was not named");
  assert(prompt.includes("connected mini-story"), "connected stories were not required");
  assert(prompt.includes("consequence of the previous round"), "round causality was not required");
  assert(prompt.includes("điện thoại = phone"), "lexical compounds were not explained");
  assert(
    prompt.includes("Never merge three or more syllables"),
    "gloss group size was not bounded",
  );
});

Deno.test("prompt asks for lexical gloss units instead of whitespace tokens", () => {
  const value = JSON.parse(userPrompt({
    profile: {
      accent: "southern",
      goal: "lifeInVietnam",
      selfAssessedLevel: "new",
      targetLevel: 3,
      challengePreference: "gentle",
      dailyMinutes: 5,
    },
    estimatedLevel: 1,
    challengeOffset: 0,
    skillMastery: {},
    recentScenarioKeys: [],
    familiarLanguage: { vocabulary: [], chunks: [] },
    nextTopicPreference: null,
    count: 1,
  }));
  assert(
    value.constraints.word_glosses.includes("Vietnamese lexical meaning"),
    "word glosses were not made lexical",
  );
  assert(
    value.constraints.word_glosses.includes("điện thoại = phone"),
    "the compound example was not supplied",
  );
});

Deno.test("prompt treats a learner with no Vietnamese history as a total beginner", () => {
  const value = JSON.parse(userPrompt({
    profile: {
      accent: "southern",
      goal: "partner",
      selfAssessedLevel: "new",
      targetLevel: 5,
      challengePreference: "stretch",
      dailyMinutes: 5,
    },
    estimatedLevel: 1,
    challengeOffset: 0.5,
    skillMastery: {},
    recentScenarioKeys: [],
    familiarLanguage: { vocabulary: [], chunks: [] },
    nextTopicPreference: null,
    count: 1,
  }));

  assert(value.learner.desired_level_1_to_5 === 5, "the long-term target was lost");
  assert(value.learner.effective_difficulty_1_to_5 === 1.5, "effective level changed");
  assert(
    value.constraints.current_level_rule.includes("ceiling"),
    "current ability was not made the difficulty ceiling",
  );
  assert(
    value.constraints.current_level_rule.includes("future goal"),
    "the desired level can still override current ability",
  );
  assert(
    value.constraints.level_adaptation.includes("total beginner"),
    "the total-beginner adaptation was not selected",
  );
  assert(
    value.constraints.level_adaptation.includes("one short clause"),
    "beginner utterance complexity was not bounded",
  );
  assert(
    value.constraints.level_adaptation.includes("highly scaffolded"),
    "beginner speaking support was not required",
  );
  assert(
    value.constraints.vocabulary_items_per_lesson.startsWith("Exactly 8"),
    "beginner vocabulary load was not minimized",
  );
});

Deno.test("prompt increases independence only for a demonstrated higher level", () => {
  const value = JSON.parse(userPrompt({
    profile: {
      accent: "northern",
      goal: "work",
      selfAssessedLevel: "conversational",
      targetLevel: 5,
      challengePreference: "balanced",
      dailyMinutes: 7,
    },
    estimatedLevel: 3.5,
    challengeOffset: 0.25,
    skillMastery: { listening: 0.7 },
    recentScenarioKeys: [],
    familiarLanguage: { vocabulary: ["dạ"], chunks: ["dạ được ạ"] },
    nextTopicPreference: null,
    count: 1,
  }));

  assert(
    value.constraints.level_adaptation.includes("richer variation"),
    "higher-level adaptation was not selected from demonstrated ability",
  );
  assert(
    !value.constraints.level_adaptation.includes("total beginner"),
    "an experienced learner received beginner constraints",
  );
});

Deno.test("prompt supplies familiar language and requests balanced reuse", () => {
  const value = JSON.parse(userPrompt({
    profile: {
      accent: "northern",
      goal: "lifeInVietnam",
      selfAssessedLevel: "conversational",
      targetLevel: 4,
      challengePreference: "balanced",
      dailyMinutes: 10,
    },
    estimatedLevel: 3,
    challengeOffset: 0,
    skillMastery: {},
    recentScenarioKeys: [],
    familiarLanguage: {
      vocabulary: ["chị", "cho em"],
      chunks: ["chị cho em xem"],
    },
    nextTopicPreference: null,
    count: 1,
  }));

  assert(
    value.learner.familiar_language_from_completed_lessons.vocabulary[0] === "chị",
    "familiar vocabulary was not supplied",
  );
  assert(
    value.constraints.exploration_exploitation_balance.includes("50% exploitation"),
    "the familiar/new balance was not requested",
  );
  assert(
    value.constraints.vietnamese_social_address.includes("age hierarchy"),
    "social address hierarchy was not explicit",
  );
});
