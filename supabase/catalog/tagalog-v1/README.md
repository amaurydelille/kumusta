# Tagalog roadmap v1 (authored lessons)

30 hand-authored lessons, 10 per level. Every lesson is
`native_speaker_review_required` and is seeded unpublished. The app ships
the same lessons as bundled seeds (`Kumusta/Resources/Seed/*-tagalog-v1.json`).

| Level | Difficulty | Units |
|---|---|---|
| beginner | 1.0 → 1.9 | Say hello · Eat and pay · Out and about |
| intermediate | 2.25 → 2.9 | The people you love · Plans and practicalities · Work, celebrations and fixes |
| advanced | 3.05 → 3.5 | Hold your own · Sound like a local · Life's big moments |

## Sources

- `beginner.ts`, `intermediate.ts`, `advanced.ts`: the lesson specs. Each lesson has 5 rounds
  forming one mini-story, and each round is built from 2–5 ordered segments.
- `lexicon-*.ts`: a contextual English gloss for every word. Two-word keys gloss fixed
  expressions together, such as "salamat po" and "bahala na".
- `catalog.ts`: turns specs into lessons and validates each one against the lesson contract in
  `supabase/functions/kumusta-lessons/contract.ts`. It derives the listening exercises
  (rounds 3 and 5), the vocabulary and the word glosses.
- `REVIEW-*.md`: points for the native reviewer, by lesson.

## Build

```sh
deno run --allow-read --allow-write supabase/catalog/tagalog-v1/build.ts            # all levels
deno run --allow-read --allow-write supabase/catalog/tagalog-v1/build.ts beginner   # one level
```

A full build writes `supabase/catalog/<level>-tagalog-v1.json` and the app seeds. It also
writes `supabase/migrations/20261025000100_seed_tagalog_roadmap_v1.sql`, which is already
applied. After content changes, put the new rows in a new migration rather than editing that
one.
