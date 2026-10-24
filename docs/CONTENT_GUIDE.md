# Vietnamese content guide

## Editorial standard

Every lesson begins with a real situation and a natural utterance. Content is
reviewed by at least one native speaker of the target regional variety and one
learning editor. Avoid claiming that either Northern or Southern Vietnamese is
uniform.

Regional naturalness is evaluated in context, including register, relationship,
location, and intended voice. Do not implement automatic word-for-word dialect
substitutions in application code; accent boundaries are curriculum and review
concerns, not a hardcoded replacement dictionary.

Bundled seed copy is an authored editorial draft, not certified linguistic
material. AI assistance may be used to organize or check a draft, but it never
counts as language approval and must not be described to learners as
native-speaker-reviewed before the gate below is complete.

## Publication gate

Every new or changed phrase must remain marked
`native-speaker-review-required` until all of these checks are recorded:

1. A native speaker from the target region reviews the Vietnamese phrase,
   example, pragmatic force, and likely social relationship between speakers.
2. A different native speaker or regional language editor reviews any claimed
   North/South contrast. Shared phrases stay shared; do not invent regional
   differences merely to make the tracks look distinct.
3. A learning editor checks that the English meaning and note are clear without
   presenting particles such as `nha`, `nhé`, or `ạ` as one-to-one translations.
4. The approved regional voice audio is regenerated, then checked at natural
   and learner-controlled slow speed for tones, rhythm, intelligibility, and
   consistency with the final text.
5. The reviewer records approval, region, date, content version, and any usage
   constraint in the editorial log before release.

Emergency phrases receive an additional safety review: the English meaning
must describe the intended action precisely, the line must not promise that a
particular phone number or service is universally available, and the UI must
not imply that a language lesson replaces local emergency guidance.

The MVP seed covers ordering, transport, directions, shopping, conversational
repair, and basic help-seeking in both accent modes. Keep expansions bounded
and high-utility so the Words and Practice screens remain quick to scan.

## Lesson shape

One lesson contains several distinct oral rounds. Every round uses the same
three-move mental model:

1. **Listen:** cold listen at natural speed, then reveal the full line.
2. **Decode or Hear & Respond:** explore two to five useful chunks, or listen
   to the other person and choose the reply that fits the situation. One or
   two rounds per lesson use Hear & Respond so the session stays the same
   length while practicing real conversational turns.
3. **Speak:** repeat the displayed Vietnamese line exactly, receive
   meaning-first transcript feedback, and send weak chunks into review.

The initial speaking MVP is a shadowing/repetition task, not an open-response
question. The UI must state this even when the target line contains a question.

Each round should usually take about one minute when the learner listens,
explores the chunks, records, and checks feedback. The supported 5, 7, 10, and
15-minute plans contain 5, 7, 10, and 12 rounds; the longest plan relies on the
extra speaking and feedback time rather than filler utterances.

Every round in one generated lesson must advance one coherent situation. A
shared topic key is a structural gate; it does not replace native-speaker review
of whether the exchanges form a natural progression. Each generated line also
provides one contextual English gloss per lexical unit so Decode can explain
and save any tapped word without another model call. Decode units default to
one Vietnamese syllable and may join two adjacent syllables only when they form
one established dictionary word; units longer than two syllables are rejected.
Hear & Respond options are
generated with the round's learner utterance as the single correct reply;
grading is local and does not call Supabase or a model.

## Chunk standard

A chunk is reusable speech, not a grammar atom. Each stored chunk has:

- Vietnamese with correct diacritics;
- natural English meaning;
- accent metadata;
- at least one realistic context sentence;
- natural-speed audio;
- optional slower replay;
- pragmatic note only when useful.

Do not translate discourse particles mechanically. Explain what they do in the
social moment.

## Audio QA

- Use only the approved female voice for each primary accent.
- Review pronunciation, tone, rhythm, reductions, and intelligibility.
- Keep natural speed first; slow playback is a learner-controlled recovery.
- Do not label generated audio as a recording by a named human speaker.
- Keep speaker names and roles in display metadata only. Never prefix a TTS
  utterance or its translation with labels such as `Barista:` or `Linh:`.
- Do not label generated or AI-assisted text as linguistically certified.
- Cache versioned audio so editorial corrections invalidate old files.

## English copy

Copy is direct, warm, and adult. It may be funny through situation and mascot
reaction, not through ridicule, baby talk, or cultural caricature.
