# Adaptive learning

## Production status and scope

Kumusta has an optional server-backed adaptive path in addition to the
bundled authored curriculum. `SupabaseAdaptiveLessonService` asks the
`kumusta-lessons` Edge Function for a queued lesson, which the server generates
with Qwen (DashScope). The model is selected server-side
(`QWEN_LESSON_MODEL`), so it can change without an app release. Today, Practice,
and Words use the generated material when it is available and fall back to the
authored seed when the service returns no lesson or a request fails.

The adaptive system changes lesson difficulty, scenario selection, audio pace,
and generated-vocabulary review state. It does not change entitlements, billing,
account state, analytics policy, or the authored-curriculum publication gate.

Generated Tagalog is model output. Passing the JSON and local validators
does not mean a native speaker reviewed it, and the product must not describe
it as certified, teacher-approved, or equivalent to published authored content.

## Request and delivery flow

1. The app sends a bounded learner profile: goal, self-assessed level,
   target level, challenge preference, and daily minutes. It never sends a
   provider model name or prompt.
2. The Edge Function validates the refreshed Supabase JWT. Anonymous Supabase
   users are allowed because access is separately gated by the server-side
   `kumusta_pro` entitlement mirror.
3. The server creates or refreshes private `kumusta_learner_states` data.
4. `get_next` returns the highest-priority `started` or `ready` unexpired
   lesson, then the oldest assignment within that priority. A ready lesson
   becomes started before delivery, so repeated calls return the same lesson
   until completion.
5. If the queue is empty or below its target, the function returns immediately
   and registers one idempotent background generation job with
   `EdgeRuntime.waitUntil`. It never waits for Qwen in `get_next`.
6. Today and Practice paint bundled authored content first. The app swaps in a
   ready queue entry after validation, caches it for five minutes for the same
   user/profile signature, and coalesces concurrent tab requests into one
   in-flight fetch. Step and vocabulary UUIDs are derived
   deterministically from the stored generated-lesson UUID.
7. Completion records enum-only difficulty and pace feedback and marks the
   queue entry complete before responding. Replenishment then runs as a
   background task. A completed rep remains accepted if entitlement has just
   expired or replenishment fails.
8. When completion includes an optional topic, the server first persists that
   topic as the learner's pending next-lesson intent. While it remains pending,
   `get_next` withholds generic queue entries and returns `generation_pending`.
   A validated lesson generated for that request receives delivery priority
   `100`; only then is the pending intent cleared. The app polls that durable
   state, replaces Today and Practice as soon as the lesson arrives, and offers
   an explicit retry after the foreground polling window.

Every completed lesson is also written atomically to the app's protected
Application Support directory and appears in Profile > Lesson history. The
library stores the full lesson for offline reading and can replay each round
through the server-configured Tagalog voice. Generated queue rows remain marked
completed on the backend as the server-side learning audit; the current Profile
library is installation-local and does not claim cross-device sync.

Completion and generated-word review mutations first enter a durable on-device
outbox. The event UUID, learner identity, enum payload, and bounded profile
snapshot survive process termination. Delivery is oldest-first, removes an
event only after an accepted server response, and retries the same event UUID at
the next adaptive network opportunity. The store is capped at 200 events.

The Edge Function owns the lesson prompt, provider model, retries, quotas,
validation, persistence, and queue. The app owns presentation and its authored
fallback.

## Deterministic adaptation

The LLM does not calculate or write learner state. The service-role-only
`kumusta_record_difficulty_feedback` RPC applies bounded, idempotent rules:

| Signal | Challenge offset | Estimated level | Audio speed |
| --- | --- | --- | --- |
| Too easy | `+0.25`, capped at `1.5` | `+0.08`, capped at target | unchanged unless pace also submitted |
| Just right | multiply by `0.85`, rounded to 2 decimals | `+0.03` on completion | unchanged for `pace_right` |
| Too hard | `-0.25`, floored at `-1.5` | `-0.04`, floored at `1` | unchanged unless pace also submitted |
| Pace too slow | unchanged | unchanged | one step toward `fast` |
| Pace too fast | unchanged | unchanged | one step toward `slow` |

The initial estimated levels are `1` for beginner, `2.25` for intermediate, and
`3.25` for advanced. Effective prompt difficulty is estimated
level plus challenge offset, clamped to `1...5`. The selected target is a
destination, not a test result, and the stored target is never set below the
ceiling of the current estimate.

A newly completed lesson adds `0.04` listening mastery, `0.04` speaking,
`0.03` vocabulary, and `0.025` automaticity, each capped at `1`. The RPC uses
`(user_id, client_event_id)` uniqueness so replaying the same event does not
apply the adjustment twice. Clients must reuse the same client event UUID when
retrying one logical completion or feedback event.

Challenge preference (`gentle`, `balanced`, or `stretch`) is prompt context.
It does not directly mutate the numeric challenge offset; explicit feedback is
the deterministic adjustment signal.

## Generated vocabulary review

Generated vocabulary IDs are deterministic within a generated lesson. The
`review_word` action accepts only `again`, `almost`, or `got_it` and calls the
service-role-only `kumusta_record_generated_vocabulary_review` RPC.

| Rating | Initial mastery change | Due interval |
| --- | --- | --- |
| Again | `0`, then `-0.08` on later reviews | 30 seconds |
| Almost | `+0.03` | 1 day |
| Got it | `+0.12` | 4 days |

Mastery remains within `0...1`. Review events are append-only and idempotent by
client event UUID; the progress row is the current projection. This generated
vocabulary state is separate from the server-curated vocabulary tables.

Word Gym presents only items whose `due_at`/`nextReviewAt` is at or before the
current time. A rating removes the item from the current due queue immediately.
Generated-item schedules are read back from Supabase when the lesson is loaded;
pending offline review mutations are overlaid on that response until sync
succeeds. Authored fallback items use the same 30-second, one-day, and four-day
intervals and persist in app-local storage, so their schedule survives an app
relaunch on that installation. Authored fallback state is not a cross-device
sync claim.

Before the review RPC runs, the server loads the caller-owned ready generated
lesson and verifies that the submitted UUID equals one of the deterministic
vocabulary IDs that can be presented for that lesson. Arbitrary and cross-user
UUIDs are rejected.

## Generation contract

One generation job requests one complete lesson at a time. The provider uses
strict JSON-schema output, the existing server-owned prompt, a fixed random seed per
attempt, and at most three attempts. Each candidate must pass local validation
before persistence:

- schema version `3` and prompt version `14`;
- requested batch count and distinct snake-case scenario keys;
- 5–15 minutes and difficulty `1...5`;
- exactly 5, 7, 10, or 12 distinct rounds for the supported daily plans;
- one situation, utterance, translation, speaking prompt, and 2–5 ordered chunks
  per round; the server expands each round into `coldListen → decode → speak`;
- one exact, ordered contextual English gloss for every whitespace-delimited
  Tagalog word (two-word units only for fixed expressions such as
  `salamat po`), preserving source punctuation;
- one shared `topic_key` copied from the lesson scenario key across every round;
- 8–18 unique vocabulary items, each grounded in a round utterance and in its own
  Tagalog example;
- bounded text, Latin-script Tagalog in phrases/examples, and no URLs, script
  markup, control characters, or prompt-injection marker;
- prohibited-subject rejection across lesson and vocabulary copy;
- English prompts, translations, meanings, and notes.

The validator is a contract and safety boundary, not a full linguistic review.
It does not prove spelling or register accuracy, naturalness, pragmatic suitability,
or that every grounded chunk and vocabulary item is semantically ideal. The
stored `quality_score` of `1` is a deterministic marker that every v1 contract
gate passed; it is not a calibrated human or pedagogical quality score and must
not be presented as one.

Validated content is deduplicated per user by SHA-256 content hash, stored with
model/prompt/schema provenance, and expires for serving after 30 days. Expired
rows are skipped by delivery, but the current implementation does not include
an automatic deletion job.

The complete generated batch is persisted through one service-role-only RPC.
Lesson and queue inserts commit together; malformed input or a queue failure
rolls back the batch. Composite `(id, user_id)` foreign keys enforce ownership
between generation jobs, generated lessons, queue entries, feedback, generated
vocabulary state, and learning-session provenance even for service-role writes.

## Queue, quota, and failure behavior

The queue targets two ready lessons behind the current started lesson.
Generation creates one full lesson per job and is limited to one active job
per user and deduplicated by client request UUID. Job acquisition is an atomic
180-second lease under the learner-state row lock. An exact retry can reclaim
its expired job; other stale active jobs are marked `superseded` so a crashed
runtime cannot block the learner indefinitely.

Generation polling first checks for a healthy active lease, so repeated
`get_next` calls do not consume provider quota or duplicate work. New work is
then quota-checked before an audit job is created: four jobs per rolling 60
seconds and 30 per 24 hours. One job may contain up to three lessons;
up to three provider attempts still consume one job quota unit. Non-`get_next`
mutations are separately limited to 120 per minute and 2,000 per day per user.
All quota RPCs fail closed.

If a queued lesson exists, delivery does not call the provider. If generation fails,
returns invalid output, produces only duplicates, times out, or is rate-limited,
the job records a sanitized failure code and no candidate is served. The mobile
surfaces then use authored content. Completion itself succeeds before queue
replenishment, so provider downtime does not erase completed work.

Provider response streams are byte-counted before decoding and capped at
1 MiB. The model never receives audio; speaking checks are graded on-device
from a speech-to-text transcript (see [Integrations](INTEGRATIONS.md)).

## Privacy and operations

Adaptive generation requests contain bounded profile enums and deterministic
state; generated lesson content is provider output stored for private queue
delivery. Difficulty, pace, and word-review feedback are enums. An optional
next-topic preference is first stored in the device-local durable outbox and
then in the private learner-state row until a priority lesson is successfully
persisted; it is normalized and bounded by both client and server. Provider
payloads and secrets are not
written to generation-job logs. Tables are service-role-only with RLS enabled
and no client policies.

Use [the lesson generation runbook](backend/LESSON_GENERATION_RUNBOOK.md) for deployment, smoke
tests, monitoring, incident response, and rollback. Use
[the content guide](CONTENT_GUIDE.md) for the separate authored-content review
gate.

Remaining production gates are native-speaker sampling for each production
model/prompt combination and an approved deletion policy for expired
generated rows. Empty-queue generation is asynchronous and no longer part of
the learner-facing request latency.
