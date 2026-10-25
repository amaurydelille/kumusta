# Tagalog content guide

## Editorial standard

Every lesson begins with a real situation and a natural utterance. Content is
reviewed by at least one native Metro Manila Tagalog speaker and one learning
editor.

Kumusta teaches one language: everyday conversational Tagalog as spoken in
Metro Manila. There is no dialect or other Philippine language anywhere in the
content (never Cebuano or Ilocano), and never stiff textbook Filipino.

- Write in modern standard spelling (`ng`/`nang`, `din`/`rin`, `daw`/`raw`
  used correctly) without stress marks. English words keep English spelling.
- Use `po`/`opo` and the respectful `kayo` wherever the scene calls for
  respect: elders, strangers, service. Drop them between friends and peers.
- Use Taglish only where a Manila speaker would naturally switch, never as a
  shortcut for Tagalog the learner should learn.
- Use Spanish-derived numbers where locals use them, such as clock time and
  prices.

Naturalness is evaluated in context, including register, relationship, setting,
and who is speaking to whom.

Bundled seed copy is an authored editorial draft, not certified linguistic
material. AI assistance may be used to organize or check a draft, but it never
counts as language approval and must not be described to learners as
native-speaker-reviewed before the gate below is complete.

## Publication gate

Every new or changed phrase must remain marked
`native_speaker_review_required` until all of these checks are recorded:

1. A native Metro Manila Tagalog speaker reviews the Tagalog phrase, example,
   pragmatic force, use of `po`/`opo`, and likely social relationship between
   speakers.
2. A learning editor checks that the English meaning and note are clear without
   presenting particles such as `po`, `na`, `pa`, or `lang` as one-to-one
   translations.
3. The Tagalog voice audio is regenerated, then checked at natural and
   learner-controlled slow speed for rhythm, intelligibility, and consistency
   with the final text.
4. The reviewer records approval, date, content version, and any usage
   constraint in the editorial log before release.

The authored roadmap's reviewer notes live in
`supabase/catalog/tagalog-v1/REVIEW-*.md`; approved rows are then published
(`review_status = 'approved'`, `is_published = true`).

Emergency phrases receive an additional safety review: the English meaning
must describe the intended action precisely, the line must not promise that a
particular phone number or service is universally available, and the UI must
not imply that a language lesson replaces local emergency guidance.

The MVP seed covers ordering, transport, directions, shopping, conversational
repair, and basic help-seeking. Keep expansions bounded
and high-utility so the Words and Practice screens remain quick to scan.

## Lesson shape

One lesson contains several distinct oral rounds. Every round uses the same
three-move mental model:

1. **Listen:** cold listen at natural speed, then reveal the full line.
2. **Decode or Hear & Respond:** explore two to five useful chunks, or listen
   to the other person and choose the reply that fits the situation. One or
   two rounds per lesson use Hear & Respond so the session stays the same
   length while practicing real conversational turns.
3. **Speak:** repeat the displayed Tagalog line exactly, receive
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
and save any tapped word without another model call. Decode units are one
whitespace-delimited Tagalog word and may join exactly two adjacent words only
for a fixed expression such as `salamat po`; units of three or more words are
rejected.
Hear & Respond options are
generated with the round's learner utterance as the single correct reply;
grading is local and does not call Supabase or a model.

## Chunk standard

A chunk is reusable speech, not a grammar atom. Each stored chunk has:

- Tagalog in modern standard spelling, without stress marks;
- natural English meaning;
- at least one realistic context sentence;
- natural-speed audio;
- optional slower replay;
- pragmatic note only when useful.

Do not translate discourse particles mechanically. Explain what they do in the
social moment.

## Audio QA

- Use only the one server-configured Tagalog voice (`KUMUSTA_TTS_VOICE_ID`).
- Review pronunciation, rhythm, reductions, and intelligibility.
- Keep natural speed first; slow playback is a learner-controlled recovery.
- Do not label generated audio as a recording by a named human speaker.
- Keep speaker names and roles in display metadata only. Never prefix a TTS
  utterance or its translation with labels such as `Barista:` or `Lola:`.
- Do not label generated or AI-assisted text as linguistically certified.
- Cache versioned audio so editorial corrections invalidate old files.

## English copy

Copy is direct, warm, and adult. It may be funny through situation and mascot
reaction, not through ridicule, baby talk, or cultural caricature.
