# Lesson Generation Improvements

The lesson-generation prompt is already unusually thoughtful: it protects natural Metro Manila register, `po`/`opo` and pronoun consistency, connected storytelling, useful chunks, adult-appropriate content, and structured output. The largest weakness is not Qwen or the wording of the prompt.

The app currently generates polished content, but it does not yet run a strong learning loop.

## The five biggest improvements

### 1. Measure learning, not lesson completion

Right now, completing a lesson automatically increases listening, speaking, vocabulary, and automaticity mastery—even if the learner:

- answered incorrectly,
- revealed every answer,
- skipped speaking,
- or was never understood correctly.

Those increments are in `kumusta_record_difficulty_feedback` in `supabase/migrations/20261024000000_kumusta_baseline.sql`.

That means the mastery values supplied to Qwen are activity counters, not reliable estimates of ability. The generator can’t adapt well from misleading evidence.

Record evidence for each skill:

- Whether the cold-listening answer was correct
- Response time
- Number of replays
- Whether text or translation was revealed
- Whether speaking was attempted or skipped
- Semantic correctness of the spoken response
- Pronunciation uncertainties
- Whether the same language was recalled tomorrow

Mastery should change only from relevant evidence. For example, completing a listening question should not automatically increase speaking mastery.

This is the most important change because it makes every later personalization decision better.

### 2. Replace some imitation with retrieval and interaction

The prompt promises “increasingly independent speaking,” but the Speak screen shows the Tagalog sentence and its translation while asking the learner to repeat it exactly. It can also be skipped. See `Kumusta/Features/Today/LessonFlowView.swift`.

Repetition is useful for rhythm and pronunciation, but it is much weaker than having to retrieve language from meaning. Research on adult L2 vocabulary training finds that retrieval—including picture-to-L2 oral production—often produces better learning than imitation or restudy, especially when failed retrieval receives corrective feedback. [Review of adult second-language vocabulary training](https://www.cambridge.org/core/journals/studies-in-second-language-acquisition/article/review-of-laboratory-studies-of-adult-second-language-vocabulary-training/18F0A5D1FFC829CE05931B2EEE83124A/share/9612bae4e131a6e3d9d0b0aacac044f5587eb6e0)

A stronger progression would be:

1. Hear the line without text.
2. Decode its meaning.
3. Study the line briefly.
4. Hide the Tagalog.
5. Give the learner an intention: “Ask whether this dish contains meat.”
6. Let them produce any acceptable Tagalog response.
7. Provide a cue only when needed.
8. Retrieve the same chunk later in a different scene.

Do not require exact wording for communicative speaking. Accept multiple natural answers while separately offering a model response.

### 3. Make pronunciation a real learning pillar

The current pronunciation system compares a speech-to-text transcript with an expected sentence, word by word. That tests whether speech recognition heard the intended words; it does not reliably measure stress placement, vowel quality, the glottal stop, or natural rhythm.

Add:

- Perception exercises in meaningful contexts
- Syllable-level feedback that goes beyond transcript matching
- Multiple native speakers, ages, and voices
- Perception followed by production
- Separate semantic success from pronunciation quality

High-variability perception training can improve production, although transfer and long-term retention are not automatic—so it should be combined with production and delayed testing. [High-variability phonetic-training meta-analysis](https://www.cambridge.org/core/journals/applied-psycholinguistics/article/does-perceptual-high-variability-phonetic-training-improve-l2-speech-production-a-metaanalysis-of-perceptionproduction-connection/E38D8F5CE65DC708137B0E95F97C6BC7)

### 4. Let the system plan the curriculum; let Qwen write it

Qwen is currently being asked to do too many jobs simultaneously:

- Decide what should be learned
- Judge difficulty
- Choose old versus new language
- Construct a story
- Handle Tagalog sociopragmatics (`po`/`opo`, `kayo` versus `ka`, address terms)
- Write alternatives and distractors
- Produce pedagogical metadata
- Satisfy the schema

The model should primarily be the lesson writer, not the curriculum authority.

Before calling Qwen, the application should construct a deterministic lesson blueprint containing something like:

```text
can_do_objective
learner_role
interlocutor_role
communicative_outcome
review_items_due
weak_items
new_items_allowed
phonetic_target
support_level
assessment_probe
```

Qwen then realizes that plan as natural Tagalog dialogue.

This gives you reproducibility, measurable progression, better spaced retrieval, and much more control when comparing model versions.

### 5. Add semantic quality evaluation, not only JSON validation

The current repair code can turn bad output into technically valid output by adding generic distractors such as “different topic,” forcing the first answer to be correct, or replacing a missing gloss with “contextual meaning.” See `supabase/functions/kumusta-lessons/provider.ts`.

That hides generation failures instead of fixing them.

A better pipeline is:

1. Curriculum planner produces the blueprint.
2. Qwen generates the lesson.
3. A separate critic evaluates each round against a fixed rubric.
4. Deterministic validators check the schema and grounding.
5. Only failing rounds are regenerated.
6. A native-speaker-reviewed evaluation set is run before every prompt or model release.

The critic should score:

- Naturalness for Metro Manila speakers
- Speaker-role and pronoun consistency
- Communicative usefulness
- Level appropriateness
- Story coherence
- Distractor ambiguity
- New-language load
- Translation faithfulness
- Whether more than one answer could reasonably be correct

Passing the JSON contract should not automatically mean `quality_score = 1`.

## Important contradictions

### “Hear & Respond” is not actually responding

The current exercise plays Tagalog and asks the learner to choose its English meaning. That is receptive translation matching.

However, the content guide describes hearing another person and choosing the reply that fits. Those are pedagogically different activities.

Either rename it “Hear & Match,” or redesign it as:

```text
interlocutor says something
learner chooses or speaks a Tagalog reply
conversation reacts to learner response
```

The second option is far more valuable.

### One sentence is being forced into incompatible roles

The same Tagalog sentence is used for cold listening, meaning recognition, and speaking. Sometimes it is logically something the learner hears from a driver, server, or shopkeeper—but the learner is subsequently asked to repeat it as themselves.

The schema needs explicit roles:

```text
interlocutor_turn
interlocutor_role
learner_role
learner_intent
acceptable_learner_responses
```

### “Adaptive” conflicts with fixed 50/50 novelty

The prompt asks for approximately half familiar and half new material. That ignores whether the familiar items are mastered, weak, overdue, or merely encountered once.

For beginners, 50% new language can create excessive comprehension load. L2 listening research often finds that roughly 95% lexical coverage supports adequate comprehension, although that evidence is largely English-based and should be validated rather than mechanically copied to Tagalog micro-lessons. [Lexical coverage and L2 listening](https://www.cambridge.org/core/journals/language-teaching/article/how-much-vocabulary-is-needed-to-use-english-replication-of-van-zeeland-schmitt-2012-nation-2006-and-cobb-2007/1D217A56A2E0056E67802A6A8360FDDE)

Start beginners with one to three new reusable chunks inside mostly understood language. Increase novelty only after successful delayed retrieval.

### Daily-duration settings contradict one another

The UI offers 5, 7, 10, and 15 minutes, but the backend repository supports 3, 5, 7, and 10. A selected 15-minute preference can therefore become 10 minutes. Compare `Kumusta/Features/Onboarding/OnboardingScreens.swift` with `Kumusta/Data/Supabase/SupabaseSignedInRepository.swift`.

That can directly distort generated lesson length.

## What “agentic” should mean here

Do not create a swarm of free-running agents. The strongest architecture is constrained and auditable:

- A deterministic curriculum scheduler chooses what must be learned.
- Qwen writes a natural lesson matching that plan.
- A critic call checks it against a strict rubric.
- Validators reject broken grounding and ambiguous questions.
- A targeted repair call rewrites only the defective round.
- Learner evidence updates the scheduler afterward.

The model can be creative inside the lesson, but it should not invent its own definition of mastery, progression, or difficulty.

Difficulty should also stop being a single number. Specify dimensions such as:

- Percentage of known language
- Number of new chunks
- Utterance length
- Syntactic complexity
- Speech rate
- Pronoun/pragmatic complexity
- Availability of text and translation
- Degree of response openness

## Recommended product direction

The best version of Kumusta would be organized around communicative “can-do” outcomes:

> “I can order a drink, clarify the size, and respond when something is unavailable.”

That aligns better with the CEFR’s action-oriented distinction between reception, production, interaction, and mediation. [Council of Europe CEFR](https://www.coe.int/en/web/portfolio/the-common-european-framework-of-reference-for-languages-learning-teaching-assessment-cefr-)

Each lesson should end with a small interactive task where the learner accomplishes something, not merely repeats the story. Corrective feedback has a meaningful, durable effect in second-language acquisition, so errors should trigger short contextual feedback and another attempt—not a grammar lecture. [Corrective-feedback meta-analysis](https://onlinelibrary.wiley.com/doi/10.1111/j.1467-9922.2010.00561.x)

Priority order:

1. Fix mastery measurement and capture actual learning evidence.
2. Add hidden-text retrieval and communicative speaking.
3. Separate interlocutor and learner turns.
4. Add pronunciation diagnostics beyond transcript matching.
5. Introduce deterministic lesson blueprints.
6. Replace placeholder repairs with generation-and-critique.
7. Build delayed retrieval across lessons.
8. Only then spend time further polishing the Qwen prompt.

In short: Qwen may improve the prose, but the largest leap will come from moving from “AI-generated lesson content” to an evidence-driven practice system that makes learners retrieve, interact, receive targeted correction, and demonstrate retention over time.
