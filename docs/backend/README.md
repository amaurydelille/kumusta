# Kumusta backend

This directory documents the isolated Kumusta data model deployed to Supabase
project `vpitjvtfzpqfnqgzcpla`.

The project is dedicated to Kumusta. Every Kumusta table, index, trigger,
policy, and helper function is still prefixed `kumusta_`. No other Supabase
project may be targeted by a Kumusta command, config or script.

## Documents

- [Schema and data dictionary](schema.md)
- [Row-level security matrix](rls.md)
- [Deployment and operations runbook](runbook.md)
- [Lesson generation runbook](LESSON_GENERATION_RUNBOOK.md)

## Source of truth

Ordered migrations under `../../supabase/migrations/` are the source of truth.
Schema changes go in new migrations; applied migrations are never edited. The
history starts with one squashed baseline,
`20261024000000_kumusta_baseline.sql`, followed by smaller migrations for the
TTS storage bucket, XP rules, client-privilege resets, the Tagalog language
core, and the authored Tagalog roadmap seed.

The baseline includes the private service-role-only adaptive tables, the
project-quota table, bounded feedback/review/generation RPCs, user/project
quota scopes, generation leases, transactional batch persistence, and composite
ownership foreign keys. `20261025000000_tagalog_language_core` makes the schema
Tagalog-only: it drops the inherited language-variant columns and checks,
switches levels to beginner/intermediate/advanced and goals to include
`lifeInThePhilippines`,
renames the vocabulary columns to `tagalog`/`usage_example_tl`, and adds
`goal_tags` to roadmap lessons. Every migration that creates tables, views or
functions revokes client privileges explicitly; run
`supabase/tests/baseline_security.sql` after pushing.

## Security boundaries

- Mobile clients receive only the Supabase URL and a publishable key.
- ElevenLabs, Soniox, DashScope, Anthropic, RevenueCat webhook, and Supabase
  service-role secrets
  remain in Edge Function secrets.
- Anonymous Supabase Auth identities receive no private learner-table access;
  analytics permits only bounded, owner-scoped event inserts.
- Server-curated content is read-only and published-only for signed-in users.
- Billing projections, provider rate limits, and webhook payloads are written
  only by service-role code.
- Adaptive learner state, generation jobs/content, lesson queues, and generated
  vocabulary state are service-role-only and exposed solely through the
  authenticated lesson Edge Function.
- Aggregate provider budgets are service-role-only and contain no user data.
- Raw audio, transcripts, email addresses, and free-form PII are prohibited
  from analytics properties.

## Provider boundaries

Kumusta speaks with one Tagalog ElevenLabs voice, `qZLi51uuzx5jdu6q0ayz`,
configured server-side and overridable only through the `KUMUSTA_TTS_VOICE_ID`
Edge Function secret. Clients never send a voice ID. The TTS cache accepts any
well-formed ElevenLabs voice ID (`^[A-Za-z0-9]{16,40}$`) and includes the voice
in its cache key, so changing the voice never serves audio from the previous
one.
