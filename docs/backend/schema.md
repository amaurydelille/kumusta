# Schema and data dictionary

All timestamps are `timestamptz`. User references point to `auth.users(id)` and
delete with the user unless noted otherwise. UUID event identifiers generated
on-device make retries idempotent.

## Identity and onboarding

### `kumusta_profiles`

One minimal application profile per authenticated user.

| Column | Meaning |
| --- | --- |
| `id` | Primary key and `auth.users` foreign key |
| `display_name` | Trimmed user-facing name, 1–60 characters |
| `locale` | BCP-47-shaped locale; defaults to English |
| `timezone` | IANA timezone identifier supplied by the client |
| `onboarding_completed_at` | Completion timestamp; null while incomplete |
| `created_at`, `updated_at` | Audit timestamps |

Authentication credentials and email addresses stay in Supabase Auth.

### `kumusta_onboarding_responses`

One resumable onboarding and value-demonstration state per user.

| Column | Meaning |
| --- | --- |
| `user_id` | Primary key and owner |
| `motivation` | Optional emotional investment statement, max 500 characters |
| `desired_outcome` | Optional concrete outcome, max 300 characters |
| `referral_source` | Optional acquisition channel |
| `current_step` | Resume cursor, 0–20 |
| `demo_completed` | Whether the pre-paywall value demo finished |
| `paywall_seen_at` | First/most recent paywall exposure timestamp |
| `completed_at` | Onboarding completion timestamp |
| `response_version` | Questionnaire schema version |
| `created_at`, `updated_at` | Audit timestamps |

No payment credentials or provider tokens belong in this table.

### `kumusta_learning_preferences`

The user’s generated learning-plan inputs.

| Column | Meaning |
| --- | --- |
| `user_id` | Primary key and owner |
| `goal` | `family`, `lifeInThePhilippines`, `travel`, `partner`, `work`, or `culture` |
| `self_assessed_level` | `beginner`, `intermediate`, or `advanced` |
| `target_level` | Learner-selected adaptive destination, integer 1–5; not a test score |
| `challenge_preference` | `gentle`, `balanced`, or `stretch` prompt preference |
| `daily_minutes` | 3, 5, 7, 10, or 15 minutes (3 is kept for older rows; the app offers 5–15) |
| `reminder_enabled` | Notification preference |
| `reminder_local_time` | Optional local reminder time |
| `created_at`, `updated_at` | Audit timestamps |

Preferences carry no voice choice: Kumusta speaks with one server-configured
Tagalog voice.

### `kumusta_user_state`

One portable, versioned JSON snapshot per authenticated user for client-owned
learning state that is richer than the normalized tables: completed lesson
records, resumable lesson progress, saved lesson words, streak details,
First Steps progress, badges, authored vocabulary review state, and UX
preferences. The row is limited to 2 MB and is readable/writable only by its
owner. Authentication tokens and provider secrets are never included.

## Curriculum

### `kumusta_lessons`

Server-curated lesson metadata. Slugs are stable API identifiers. Content is
visible to clients only when `is_published` is true.

Important fields are `level` (`beginner`, `intermediate`, or `advanced`),
`goal_tags`, `estimated_minutes`, `sort_order`, `content_version`, the roadmap
position (`roadmap_version`, `unit_order`, `lesson_order`), `review_status`, and
publish state. A row can be published only once `review_status` is `approved`;
the authored Tagalog roadmap is seeded as `native_speaker_review_required`. The
published-order partial index serves Today and lesson-list queries.

### `kumusta_vocabulary`

Server-curated Tagalog words and useful phrases (`tagalog`, unique), including
translation, pronunciation hint, part of speech, controlled audio path, and
bilingual usage example (`usage_example_tl`, `usage_example_en`). `content_version` supports cache invalidation. Only published rows are
client-visible.

### `kumusta_generated_lessons`

Private, per-user Qwen lesson candidates that have passed the structural
validator. Each row records its generation job, schema and prompt versions,
provider model, bounded difficulty, scenario key, content hash,
validation metadata, status, and 30-day serving expiry. `content` is capped at
64 KiB. `(user_id, content_hash)` prevents serving duplicate content to one
learner.

`ready` means contract-valid and eligible for the private queue; it does not
mean native-speaker-reviewed or linguistically certified. `quarantined` and
`archived` rows are never served. Expiry is enforced on read; a separate
automatic deletion job is not currently implemented.

The deterministic `quality_score` is `1` when every v1 validator gate passes;
it is not a human or pedagogical rating. Lesson/queue rows for one generated
batch are inserted by a single transactional RPC, so a malformed row or queue
failure rolls back the complete batch.

### `kumusta_user_lesson_queue`

Private per-user assignment rows for generated lessons. Status moves through
`ready`, `started`, and `completed`; invalid/expired backing lessons are marked
`skipped`. The oldest ready/started entry is the current lesson. Two ready
entries is the operating target. User/lesson uniqueness prevents duplicate
assignments.

### `kumusta_lesson_generation_jobs`

Idempotent, per-user generation audit records keyed by
`(user_id, client_request_id)`. A partial unique index permits only one active
`queued`/`generating` job per user. Rows hold the trigger, bounded requested
count, deterministic learner snapshot, prompt/model provenance, attempt count,
and a sanitized error code. They never store provider credentials or raw
provider responses.

Job acquisition is a 180-second database lease under the learner-state row
lock. An exact request retry may reclaim its expired job; a new request marks
other stale active work `superseded` before acquiring a lease.

## Learning state

### `kumusta_learner_states`

Private adaptive snapshot per user. It stores goal, self-assessment,
estimated and target level, challenge preference/offset, speech speed, bounded
skill-mastery JSON, completion/feedback counts, and a monotonic state version.
The initial estimate and all later mutations are deterministic; the lesson model cannot
write this table or choose the update values.

### `kumusta_difficulty_feedback`

Append-only, idempotent enum feedback keyed by `(user_id, client_event_id)`.
Rows capture question/lesson context, optional generated lesson and step,
difficulty rating, optional pace rating, and the previous/new challenge and
speed values. Raw free-form feedback is intentionally not collected.

### `kumusta_generated_vocabulary_progress`

Current spaced-review projection for vocabulary derived from generated lessons.
The key is `(user_id, vocabulary_id)`; the backing generated lesson is retained
for ownership and provenance. Mastery remains `0...1`, interval remains
`0...3650` days, and the due index serves the generated review queue.

### `kumusta_generated_vocabulary_review_events`

Append-only generated-word ratings (`again`, `almost`, `got_it`).
`(user_id, client_event_id)` makes retries idempotent. Generated lesson and
vocabulary UUIDs are required. Before the service-only review RPC runs, the Edge
Function verifies lesson ownership/readiness and matches the submitted UUID
against the lesson’s deterministic presented vocabulary IDs.

### `kumusta_user_vocabulary`

One spaced-repetition projection per user and vocabulary item.

| Column | Meaning |
| --- | --- |
| `state` | New, learning, review, mastered, or paused |
| `mastery` | Normalized 0–1 mastery estimate |
| `ease_factor` | Bounded scheduling multiplier |
| `interval_days` | Current interval, 0–3,650 days |
| `review_count`, `lapse_count` | Scheduling counters |
| `due_at`, `last_reviewed_at` | Review scheduling timestamps |

The `(user_id, due_at)` partial index serves the Practice queue. A reverse
`vocabulary_id` index makes curriculum deletion and joins efficient.

### `kumusta_learning_sessions`

Idempotent learning-session summaries for Today, lessons, Practice, and Words.
`client_session_id` is unique per user. `lesson_id` becomes null if authored
curriculum is removed; `generated_lesson_id` provides optional provenance for
adaptive sessions and becomes null if generated content is removed. Active
time is capped at four hours to reject corrupt telemetry.

### `kumusta_review_events`

Append-only review history. A `client_event_id` unique per user prevents
duplicate offline retries. Ratings map to the large UI actions `again`,
`almost`, and `got_it`. The event records scheduling input/output and optional
response latency.

### `kumusta_daily_progress`

One aggregate per user and calendar date: active seconds, completed lessons,
words learned/reviewed, XP, and daily-goal state. The app must calculate
`progress_date` in the profile timezone.

## Billing and operations

### `kumusta_entitlements`

Canonical per-user RevenueCat projection. Mobile clients may read their own
rows but cannot write them. Service code records active state, product,
environment, purchase/expiry state, renewal state, last webhook event, and
sync time.

### `kumusta_revenuecat_events`

Service-only, idempotent webhook inbox and audit log. `event_id` is the primary
key. The bounded JSON payload is retained for reconciliation. `processed_at`
and `processing_error` support safe retries and alerting.

### `kumusta_api_rate_limits`

Service-only per-user fixed-window counters for `elevenlabs_tts`,
`elevenlabs_tts_daily`, `elevenlabs_stt`, `elevenlabs_stt_daily` (the Soniox
speaking checks keep these scope names), `lessons`, `lessons_daily`,
`lessons_mutation`, `lessons_mutation_daily`, and `revenuecat_sync`. Edge Functions update
these rows with the service role; clients have no access.

### `kumusta_project_api_rate_limits`

Service-only aggregate provider circuit breakers with no user data. The scopes
`elevenlabs_tts_project_daily` and `elevenlabs_stt_project_daily` cap total
daily TTS and speech-to-text provider exposure across otherwise valid paid
identities. Clients have no access.

### `kumusta_analytics_events`

First-party, insert-only product events. `client_event_id` is unique per user.
Event names use lower snake case. Properties must be a JSON object no larger
than 16 KiB. Never include raw recordings, transcripts, email, or free-form
PII.

## Shared database helper

`kumusta_touch_updated_at()` is a `SECURITY INVOKER` trigger function with an
empty search path. Execute is revoked from public client roles. It updates the
mutable tables’ `updated_at` values without creating an RPC surface.

The provider/adaptive Edge Functions use six `SECURITY DEFINER` RPCs with fixed
`pg_catalog, public` search paths:

- `kumusta_consume_api_quota` atomically enforces approved fixed-window
  scopes and fails closed;
- `kumusta_consume_project_api_quota` atomically enforces the aggregate TTS
  and speech-to-text circuit breakers and fails closed;
- `kumusta_begin_lesson_generation_job` acquires/reclaims a bounded generation
  lease while serializing on learner state;
- `kumusta_persist_generated_lesson_batch` atomically persists validated
  generated lessons and their queue assignments;
- `kumusta_record_difficulty_feedback` atomically inserts an idempotent event,
  updates bounded learner state, and completes a generated queue entry;
- `kumusta_record_generated_vocabulary_review` atomically inserts an
  idempotent word-review event and updates its progress projection.

Only `service_role` has execute permission. All adaptive and project-quota
tables have RLS enabled with no `anon` or `authenticated` policies or table
grants; mobile clients reach them only through authenticated Edge Functions.

Composite ownership foreign keys pair generated object IDs with `user_id` from
generation job through lesson, queue, difficulty feedback, generated vocabulary
progress/reviews, and learning sessions. This prevents cross-account
relationships even if trusted service code supplies a mismatched tenant ID.
