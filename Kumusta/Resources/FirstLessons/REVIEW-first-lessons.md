# First lessons: review notes

Four Tagalog lessons, written against the decoder in
`Kumusta/Features/FirstSteps/FirstLessonContent.swift`. All text is plain
strings, `tagalog` replaces `vietnamese`, every `contour` is `"level"`, and the
only personalized line is `Ako si {name}.`. None of this has had a native
speaker review yet.

Each onboarding lesson stays within the pre-paywall limit of three graded takes
(`FirstLessonSpeechBudget.prePaywallLimit`).

## onboarding-beginner.json

Steps: intro, teach, listenPick, meaningPick, build, newPhrase, conversation
(3 turns). 3 takes, about 2 minutes.

- The teach and listenPick contrast **Kumusta** with **Kumusta po**, so the
  first thing learned is po, not a tone. The footnote says Tuko is a friend,
  so the conversation itself has no po.
- meaningPick: *Anong pangalan mo?*. Build: *Hi / ako / si* for "Hi! I'm…".
- newPhrase: *Salamat po* (thank you). The tip says the stress falls on the last
  syllable (sa-la-MAT) and that plain *Salamat!* is fine with a friend.
- Conversation: *Kumusta!* → *Kumusta!*; *Anong pangalan mo?* → `Ako si {name}.`;
  *Ikinagagalak kitang makilala!* → *Salamat!* Closing: *Sige, ingat ka!*
- There is no standalone speak step because the three takes go to the
  conversation (the same pattern as the old `onboarding-familiar`).
- To confirm: is *Salamat!* a natural answer to *Ikinagagalak kitang
  makilala!*, or would a Manila speaker say *Ako rin!* or just "Nice to meet
  you too!" in English? The phrase itself sounds a bit formal next to a casual
  *Kumusta!*.

## onboarding-intermediate.json

Steps: intro, teach, meaningPick, newPhrase, meaningPick, build, conversation
(3 turns). 3 takes, about 2 minutes.

- The teach covers *Kuya / Ate* as the way to address a vendor, with po.
- meaningPick: the vendor's *Ano po sa inyo?* ("What would you like?").
- newPhrase: *Pabili po ng dalawang turon*. The tip covers ng said as "nang"
  and the linker on *dalawang*.
- The price meaningPick is *Kwarenta po lahat.* = ₱40 (two turon at ₱20 each),
  with the options ₱40 / ₱14 / ₱400.
- Build: *Heto po ang bayad ko* ("Here's my payment").
- Conversation: *Magandang hapon! Ano po sa inyo?* → *Kuya, pabili po ng
  dalawang turon.*; *May iba pa po?* → *Wala na po, salamat.*; *Kwarenta po
  lahat.* → *Heto po ang bayad ko.* Closing: *Salamat po! Balik po kayo!*
- To confirm:
  - The spelling **kwarenta** (rather than *kuwarenta*). The grader treats them
    as the same, but the displayed spelling should be the one locals expect.
  - Is ₱20 a turon still a realistic carinderia price in Manila?
  - Do people say *Heto* or *Eto* more often? Both are in `accepted`.
  - Is *Pabili po ng…* natural at a carinderia, where people also point and say
    *Kuya, dalawang turon nga po*?

## onboarding-advanced.json

Steps: intro, teach, meaningPick, naturalPick, speak, build, conversation
(2 turns). 3 takes, about 2 minutes.

- The teach covers the softening words *pa / naman / lang* through *Wala pa
  naman* and *Wala lang*.
- meaningPick: the Taglish *Uy, may lakad ka ba this weekend?*, where *lakad*
  means plans.
- naturalPick: the question is *Anong plano mo sa Sabado?*.
  - *Ako ay walang plano sa Sabado.* is marked textbook (the ay order).
  - *Wala pa naman. Bakit, may lakad ka?* is marked natural.
  - *Wala.* is marked too short.
- Speak: the natural reply. Build: *Tara / Anong / oras*.
- Conversation: the hook question → the natural reply; *Tara, kain tayo ng
  samgyup sa Sabado!* → *Tara! Anong oras?* The closing settles the time and
  place: *Alas siyete, sa Maginhawa. Kita-kits!*
- To confirm:
  - Does *Ako ay walang plano sa Sabado* read as clearly stiff and not as
    wrong?
  - Is *samgyup* (samgyupsal) the right everyday reference?
  - Is *sa Maginhawa* (a food street in Quezon City) clear to learners?
    *sa BGC* is an option if not.
  - The spelling **siyete** vs *syete*.

## first-lesson-beginner.json

Steps: intro, teach, listenPick, listenPick, newPhrase, speak, newPhrase, speak,
meaningPick, teach, meaningPick, build, speak, conversation (3 turns). 6 takes,
about 6 minutes. This mirrors `first-lesson-new.json` step for step.

- Teach + 2 listenPicks: *Salamat* vs *Salamat po*.
- newPhrase + speak: *Kumusta po!*, with `accepted` holding *Kamusta po* and
  *Kumusta*. The tip says where po goes.
- newPhrase + speak: *Mabuti po, salamat!*. The tip mentions *Ayos lang* as the
  casual option.
- meaningPick: *Opo.* = "Yes (with respect)". The note says to use *oo* with
  friends.
- Teach: *ka* vs *kayo*, through *Kumusta ka?* and *Kumusta po kayo?*.
- meaningPick: *Anong pangalan mo?*. Build: *Hi ako si*.
- Speak `speak-ako-si`: display and audio are `Ako si {name}.`, the target is
  `Ako si`, and only a `tipWithoutName` is set.
- Conversation: *Kumusta!* → *Kumusta!*; *Anong pangalan mo?* → `Ako si {name}.`;
  *Kumusta ka?* → *Mabuti, salamat!* Closing: *Ikinagagalak kitang makilala!
  Ingat!*
- To confirm:
  - Is the stress tip "ma-bu-TI, sa-la-MAT" right? I believe both words are
    stressed on the last syllable (mabuti, salamat).
  - Would friends really answer *Kumusta ka?* with *Mabuti*, or more often with
    *Okay lang* or *Ayos lang*? *Ayos lang salamat* is already accepted.

## Points for a native speaker

1. Stress: *salamat* and *mabuti* stressed on the last syllable, as the tips
   say.
2. Register: is *Ikinagagalak kitang makilala!* too formal for a friendly
   gecko, and is *Salamat!* a natural reply to it?
3. Spelling of the Spanish-derived numbers: *kwarenta* and *alas siyete*.
4. Carinderia ordering: *Pabili po ng dalawang turon* and *Heto po ang bayad
   ko*, against more casual options (*…nga po*, *Eto po bayad*).
5. naturalPick verdicts: *Ako ay walang plano…* as textbook, and *Wala pa naman.
   Bakit, may lakad ka?* as the natural answer.

## Engineering notes (not changed, outside this task)

- `KumustaTests/FirstLessonContentTests.swift` still refers to
  `VietnameseAccent`, `script.accent`, the step id `speak-ten-la` and
  Vietnamese name strings ("Mình tên là Linh."). The new name step is
  `speak-ako-si` and resolves to `Ako si Linh.`.
- `scripts/generate-first-lesson-audio.ts` still loops over southern/northern
  accents. The bundled `audio/` clips for these new lines have not been
  generated yet.
- `FirstLessonCatalog.allFiles` already points at these four new file names.
  The old Vietnamese JSON files are untouched.
