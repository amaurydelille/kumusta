# Cantonese roadmap v1 (authored lessons)

30 hand-authored lessons, 10 per level, ready to integrate into the app and the
`kumusta_lessons` catalog. Status: **`native_speaker_review_required`** on every
lesson — do not publish before a native Hong Kong speaker signs off.

| File | Level | Difficulty | Units |
|---|---|---|---|
| `beginner-cantonese-v1.json` | beginner | 1.0 → 1.9 | Say hello · Eat and pay · Out and about |
| `intermediate-cantonese-v1.json` | intermediate | 2.25 → 2.9 | Talk with people you love · Plans and practicalities · Work, festivals and fixes |
| `advanced-cantonese-v1.json` | advanced | 3.05 → 3.5 | Hold your own · Sound like a local · Life's big moments |

## Levels

Three levels: beginner / intermediate / advanced (owner decision,
2026-10-24; `PLAN.md` follows it).

## Shape

Same as VietBuddy's bundled roadmap seeds (`Kumusta/Resources/Seed/*-vietnamese-v1.json`,
camelCase), with these changes:

- No `accent` field (CLAUDE.md: just Cantonese).
- `vietnamese` → `cantonese`, plus a `jyutping` field next to every Cantonese
  string: round utterance, chunks, word glosses, vocabulary and examples.
- `responseExercise.promptVietnamese` → `promptCantonese` + `promptJyutping`.
- New lesson-level `goalTags` (subset of `family`, `partner`, `travel`,
  `lifeInHongKong`, `work`, `culture`) for reordering by onboarding goal.
- `schemaVersion: 1`, `promptVersion: 1`, `contentSource: "authored_roadmap"`.
- IDs: `43000000-0000-4000-81LL-0000000000NN` (LL = 01 beginner, 02
  intermediate, 03 advanced; NN = lesson 01–10).

Kept from VietBuddy: 5 rounds per lesson forming one mini-story;
`responseExercise` on rounds 3 and 5 only (3 English options, one equals the
round translation); 8–10 vocabulary items, each inside its `example`, which is
an exact round utterance.

## Text conventions

- Hong Kong colloquial Cantonese, Traditional characters, no Standard Written
  Chinese, no Simplified.
- Jyutping: lowercase, tone digits 1–6, syllables separated by single spaces,
  punctuation omitted, exactly one syllable per Han character. Colloquial
  changed tones are deliberate (檸茶 ning2 caa4, 今晚 gam1 maan1).
- English code-mixing (`cafe`, `book`, `check`, `send`, `email`, `project`,
  `update`, `meeting`, `weekend`, `TVB`, `BB`, `hea`, the name `Alex`) appears
  verbatim in both the text and the Jyutping string. TTS, the segmenter and
  the ruby renderer must handle Latin runs inside a line.
- `wordGlosses` tokens contain no punctuation; concatenated they rebuild the
  utterance with punctuation removed.
- Chunk `note`s may contain Han characters (they explain the line being shown);
  titles, scenarios, translations and options never do.

## Validation

```sh
python3 -m venv .venv && .venv/bin/pip install pycantonese opencc-python-reimplemented
.venv/bin/python -W ignore content/roadmap/validate_lessons.py content/roadmap/*-cantonese-v1.json
```

Current result: 0 errors, 82 warnings. **Errors** are structural (schema,
syllable counts, chunk order, gloss rebuild, exercise rules, Simplified
characters). **Warnings** are Jyutping readings that differ from the
PyCantonese lexicon (mostly particles 呀 aa3 / 啦 laa1 / 喇 laa3 / 㗎 gaa3,
嚟 lai4, 畀 bei2, and colloquial changed tones) — each was reviewed and kept on
purpose, but the native reviewer should skim them.

## For the native reviewer

- Beginner 02: `我叫Alex` uses an English placeholder name.
- Beginner 06 r1/r3 and 10 r2/r4 are lines spoken by staff; the speaking
  prompt asks the learner to say them in role.
- Beginner 07: `前面有落` (the minibus phrase) used in a taxi.
- Beginner: 普洱 pou2 lei2, 識到你 sik1 dou2, 呢個 ni1 go3, the bargain
  `二十蚊七個啦`.
- Intermediate: 嘅話 ge3 waa2 vs waa6; 碟 dip6 vs dip2; 間房 gaan1 fong2 vs
  fong4; naturalness of `我諗緊下個禮拜再去` and `等咗廿分鐘，可唔可以快啲呀`.
- Intermediate 09: 姑媽 glossed as father's older sister; visiting the
  mother's side on 初二 varies by family; the red-packet joke.
- Advanced: 伯父 baak3 fu2, 伯母 mou5 vs mou2, 一個人 jan1, 嗰陣時 si4,
  `今晚` gam1 maan1 consistency across levels.
- Advanced 01: `唔使客氣，我除咗鞋先入嚟` register and 入嚟 vs 入去.
- Advanced 04: `食咗檸檬` (rejected after asking someone out) and `走寶`.
- Advanced 07: code-mixing in `傾吓個project`, `check吓`, `send個email畀大家`.
- Advanced 08: `BB` pet name (read bi4 bi1), kept in Latin letters.
