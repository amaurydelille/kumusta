# Goal lessons

`kumusta_goal_lessons` holds a shared curriculum separate from personalized generated lessons and the existing roadmap. Version `goals-v1` contains 10 lessons for each of four goals (life in the Philippines, family, partner, travel) and four levels: 160 Tagalog lessons. The work and culture goals have no goal curriculum yet.

Levels are Beginner, Elementary, Intermediate, and Advanced. The Today screen selects the learner's existing goal, starts from their current proficiency, recommends the next unfinished lesson, and advances after all ten lessons in a level are complete. Every level and lesson remains manually accessible. This feature does not change onboarding. Completion IDs persist independently of the 100-entry activity history and travel with the existing cloud learning snapshot.

Each five-minute lesson has five rounds: five cold listens, three decode exercises, two hear-and-respond meaning choices, and five speaking steps. Scene context identifies the speaker's role. IDs are derived from each lesson UUID so saved progress cannot collide across goals or levels. Matching cached catalog data remains available offline after a successful load; audio uses the existing player and audio cache.

## Generate and verify

The operations endpoint uses the existing server-side `DASHSCOPE_API_KEY`. `QWEN_LESSON_MODEL` can override the default `qwen3.8-max-0902`. Only a verified Supabase service-role credential can invoke generation. Never include credentials in the app or exported catalog.

From the repo root (Kumusta project only):

```sh
rtk supabase functions deploy kumusta-curriculum-admin --project-ref vpitjvtfzpqfnqgzcpla
rtk deno run --allow-run=supabase --allow-net=vpitjvtfzpqfnqgzcpla.supabase.co scripts/generate-goal-curriculum.ts --concurrency=16
rtk deno run --allow-run=supabase --allow-net=vpitjvtfzpqfnqgzcpla.supabase.co --allow-write=supabase/catalog scripts/verify-goal-curriculum.ts --export=supabase/catalog/goal-tagalog-v1.json
```

The runner resumes existing accepted rows and retries failures. Invalid early drafts with placeholder glosses or incorrect speaking instructions are regenerated. The endpoint uses strict structured output, validates the existing lesson contract, and performs a second Qwen editorial review for natural spoken Metro Manila Tagalog, translations, roles, level, and options. Only passing lessons are saved as drafts. This is automated review, not native-speaker certification.

Before publishing, require 160 rows, all 16 goal/level groups with orders 1–10, zero verification issues, and a native-speaker pass. Publish the version in one database transaction. RLS grants authenticated learners read access to published rows only; client writes and anonymous reads are denied. The app validates all 40 rows for a goal before displaying them.

`usage` stores tokens for successful generation and review. These figures exclude failed attempts and must not be presented as total billing usage.

## Verification

- Deno syllabus coverage and existing lesson contract tests.
- Swift recommendation, goal isolation, exercise structure, identifier uniqueness, and durable progress tests.
- Simulator test changes levels and opens the existing lesson player.
- Exported catalog is decoded through the actual Swift models before publication.

The database catalog is remote. The Today screen integration requires distributing the updated iOS app.
