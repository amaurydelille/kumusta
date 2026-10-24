# Mistral production runbook

This runbook covers both Mistral Edge Functions:

- `kumusta-mistral-lessons` generates and queues bounded adaptive lessons;
- `kumusta-mistral-evaluate` returns bounded text feedback with an authored
  fallback.

Run all commands from `mobile-app/kumusta`. Use a local Supabase stack or a dedicated
development branch first. Do not use production learner data for migration or
quota experiments.

## Prerequisites and deployment order

1. Apply all migrations through
   `20260731122000_index_kumusta_composite_ownership_fks_v1.sql`.
2. Verify the adaptive tables, indexes, service-role-only RPC grants, and
   extended user/project quota scopes before deploying the lesson function.
3. Install Edge Function secrets without printing their values.
4. Deploy the two functions.
5. Run contract/type checks, authenticated smoke tests, and advisor checks.

Required secrets:

```text
MISTRAL_API_KEY
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY)
SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_SECRET_KEY)
```

Recommended configuration:

```text
MISTRAL_MODEL=mistral-small-latest
MISTRAL_LESSON_MODEL=mistral-medium-latest
KUMUSTA_ENTITLEMENT_ID=kumusta_pro
```

`MISTRAL_LESSON_MODEL` affects lesson generation only. If absent, lesson
generation uses `mistral-medium-latest`; evaluation remains on
`MISTRAL_MODEL`. Model changes require contract,
regional-language, latency, and cost validation; they do not require an iOS
release. Keep model names server-side.

Both functions have `verify_jwt = false` in `supabase/config.toml` because each
handler validates the bearer token through Supabase Auth itself. This setting
does not make them public. Do not deploy a handler that omits
`requireAuthenticatedUser`.

Example operator flow:

```sh
supabase db push --include-all
supabase secrets set --project-ref "$SUPABASE_PROJECT_REF" --env-file .env
supabase functions deploy kumusta-mistral-evaluate --project-ref "$SUPABASE_PROJECT_REF"
supabase functions deploy kumusta-mistral-lessons --project-ref "$SUPABASE_PROJECT_REF"
```

Keep `.env` untracked. Never place a service-role key or Mistral key in an
`xcconfig`, the app bundle, CI logs, screenshots, or this document.

## Pre-deploy gates

```sh
npx --yes deno fmt --check supabase/functions deno.json
npx --yes deno lint supabase/functions
npx --yes deno check \
  supabase/functions/kumusta-mistral-evaluate/index.ts \
  supabase/functions/kumusta-mistral-lessons/index.ts
npx --yes deno test \
  supabase/functions/_shared/http_test.ts \
  supabase/functions/kumusta-mistral-evaluate/contract_test.ts \
  supabase/functions/kumusta-mistral-lessons/contract_test.ts \
  supabase/functions/kumusta-mistral-lessons/repository_test.ts
```

The lesson contract tests must cover exact request keys, bounded profile enums,
step order, batch size, accent/location separation, duplicate scenarios,
ordered chunk containment, vocabulary/usage-example grounding, prohibited
subjects, Vietnamese text bounds, and rejection of prompt-shaped fields.
Repository tests cover deterministic vocabulary membership, and shared HTTP
tests cover early and streamed oversized provider responses. Database tests
must separately verify RPC idempotency, ownership, leases, transactional queue
persistence, transitions, bounds, and role grants; pure contract tests do not
exercise Postgres.

Before public rollout, have native speakers from both target regions review a
representative output sample from the exact production model and prompt version.
This review is a release gate for model/prompt changes, not a certification of
every generated lesson.

## Authenticated smoke tests

Use a disposable entitled development user and a short-lived Supabase access
token. Do not paste tokens into shell history on shared machines. Exercise:

1. `get_next` with each accent and every goal.
2. A repeated `get_next`, which must return the same started lesson ID until it
   is completed.
3. `complete` with a stable `client_event_id`, then replay the identical event;
   learner state must change only once.
4. `review_word` for a vocabulary UUID returned with that generated lesson,
   then replay the same event UUID. An arbitrary UUID paired with the same
   lesson must fail with `invalid_vocabulary_reference`.
5. A non-entitled user: `get_next` must return `premium_required`.
6. An invalid/expired JWT: both functions must reject it.
7. Unexpected fields, invalid enums, oversized bodies, and cross-user lesson
   IDs: all must fail without calling Mistral.
8. Mistral unavailable or invalid output: Today/Practice/Words must show authored
   content; text evaluation must return `fallback: true`.
9. Terminate a generation after lease acquisition, wait past 120 seconds, then
   verify an exact request retry reclaims its job and a different request
   supersedes stale work without creating concurrent live jobs.
10. Force a queue insert failure in a disposable database transaction and
    verify the whole generated batch rolls back.
11. Persist an adaptive mutation offline, recreate the iOS service, then verify
    the durable outbox retries the original client event UUID and removes it
    only after acknowledgement.

Never use a service-role token as the request bearer for a mobile smoke test.

## Database verification

The following checks are read-only. Run them through an approved administrator
session and retain counts, not lesson text, in deployment evidence.

```sql
select relname, relrowsecurity
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in (
    'kumusta_learner_states',
    'kumusta_lesson_generation_jobs',
    'kumusta_generated_lessons',
    'kumusta_user_lesson_queue',
    'kumusta_difficulty_feedback',
    'kumusta_generated_vocabulary_progress',
    'kumusta_generated_vocabulary_review_events'
  )
order by relname;

select grantee, routine_name, privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'kumusta_consume_api_quota',
    'kumusta_consume_project_api_quota',
    'kumusta_begin_lesson_generation_job',
    'kumusta_persist_generated_lesson_batch',
    'kumusta_record_difficulty_feedback',
    'kumusta_record_generated_vocabulary_review'
  )
order by routine_name, grantee;
```

All seven adaptive tables and `kumusta_project_api_rate_limits` must have RLS
enabled and no `anon` or `authenticated` table grants. Only `service_role` may
execute the adaptive and quota RPCs. Verify composite ownership foreign keys
from generation job → lesson and lesson → queue/feedback/generated-word/session
rows; a service-role write with mismatched `user_id` must fail.

## Normal operating behavior

- The ready-lesson target is three per user.
- At most one generation job may be queued/generating for a user. The atomic
  lease is 120 seconds and recovers or supersedes stale active work.
- Lesson generation quota is 4 jobs per 60 seconds and 30 jobs per 24 hours.
- Adaptive mutation quota is 120 calls per 60 seconds and 2,000 per 24 hours.
- Text evaluation quota is 20 calls per 60 seconds.
- A job requests at most three lessons and Mistral gets at most two attempts.
- Lesson response bodies are capped at 1 MiB and evaluation bodies at 256 KiB,
  with streamed byte accounting rather than trust in `Content-Length`.
- Validated lesson and queue rows are inserted in one database transaction.
- Mistral request timeout is 25 seconds per lesson attempt; the iOS next-content
  request timeout is 30 seconds. Watch the client timeout rate when queues are
  empty.
- A generated lesson is eligible to serve for 30 days. Expiry prevents serving
  but does not currently delete the database row.
- Queue replenishment failure after completion is logged and deferred; the
  completion response remains successful.

## Monitoring

Alert on rates and trends, not learner text. Recommended signals:

- generation jobs by `status`, `error_code`, prompt version, model, and attempt
  count;
- ready queue depth and percentage of entitled users at depth zero;
- generation latency, provider HTTP status class, timeout rate, invalid output,
  duplicate-content jobs, and lessons inserted per job;
- `rate_limited`, `quota_unavailable`, `premium_required`, `invalid_request`,
  and `internal_error` response counts;
- authored-fallback rate on Today/Practice/Words and `fallback: true` rate for
  text evaluation;
- generated lesson rejection during the app’s second validation layer;
- completion and review-event duplicate rates;
- mutation minute/daily rate limits, stale lease recovery, superseded jobs, and
  outbox depth/capacity failures;
- oversized provider-response rejection and transactional persistence errors;
- table growth, expired ready content, and oldest unfinished generation job.

Function logs may include request IDs, provider status codes, job IDs, and
sanitized error codes. They must not include access tokens, prompts, provider
responses, learner profile names, learner attempts, or generated lesson text.

## Triage

### Empty queue or authored fallback spike

1. Check entitlement mirror freshness and `premium_required` rate.
2. Check quota accounting and the two lesson quota scopes.
3. Inspect recent generation-job status/error code, model, prompt version, and
   attempt count without dumping `learner_snapshot` or lesson `content`.
4. Check provider status/latency and secret presence.
5. Confirm any active job younger than 120 seconds is legitimate. Older work
   should be reclaimed by an exact retry or superseded by the next request.
6. Confirm generated rows are `ready`, unexpired, and have a queue entry.

Do not manually mark unvalidated or quarantined content ready.

### Invalid model output

Keep the client on authored fallback. Reproduce against the same model and
prompt version in a non-production environment, then add a contract regression
test before changing prompt or validator behavior. Never weaken exact-key,
length, step-order, grounding, prohibited-subject, accent, response-size, or
schema checks just to raise acceptance rate.

### Quota or cost spike

Confirm generation jobs are deduplicated by client request UUID, mutation
retries preserve client event UUIDs, and only one leased job exists per user.
Preserve user/project rate-limit and job audit rows, then
reduce availability by disabling the lesson function or revoking the Mistral
secret if needed. Do not raise quota limits during an active abuse incident.

### Suspected unsafe or poor Vietnamese

Archive or quarantine affected generated rows, preserve model/prompt/schema
provenance, and route samples to the native-speaker review process. Prefer an
authored fallback while investigating. A schema-valid result is not proof of
linguistic or pragmatic correctness.

## Rollback and recovery

Provider and prompt changes are rolled back server-side. Restore the last known
good model/prompt/function version, leave existing audit and feedback rows
intact, and archive affected generated lessons rather than deleting evidence.
The mobile app will continue with authored content when the function is disabled
or returns no valid lesson.

Do not roll back by dropping adaptive tables or removing columns from populated
production tables. Use forward migrations. Rotate `MISTRAL_API_KEY` immediately
if exposed, review usage and logs, then redeploy with the replacement secret.

After recovery, verify both accents, queue replenishment, completion
idempotency, word-review idempotency, and authored fallback before restoring
normal traffic.

The remaining release gates are a native-speaker sample review for each exact
production model/prompt/accent combination and an approved cleanup job/policy
for expired generated rows. Empty-queue generation runs through
`EdgeRuntime.waitUntil`; `get_next` returns the authored fallback path without
waiting for either provider attempt.
