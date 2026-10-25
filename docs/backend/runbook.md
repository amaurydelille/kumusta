# Supabase deployment and operations runbook

## Project

- Project ref: `vpitjvtfzpqfnqgzcpla`
- API URL: `https://vpitjvtfzpqfnqgzcpla.supabase.co`
- Schema: `public`
- Migration directory: `supabase/migrations`

Use a current publishable key in the iOS configuration. Never commit the
service-role key or third-party provider secrets. Publishable keys can rotate,
so retrieve the current value from the Supabase dashboard or approved secrets
workflow instead of copying it into documentation.

## Local prerequisites

1. Install the Supabase CLI.
2. Authenticate with `supabase login`.
3. From the repository root, link only if not already configured
   (`supabase/.temp/project-ref` already points at Kumusta):

```bash
supabase link --project-ref vpitjvtfzpqfnqgzcpla --workdir .
```

Pass `--workdir .` (or `--project-ref vpitjvtfzpqfnqgzcpla`) on every Supabase
CLI call so no command can reach another project. Prefer a local stack or
Supabase development branch for new migrations.

## Apply

From the repository root:

```bash
supabase db push --workdir .
supabase db query --linked --workdir . -f supabase/tests/baseline_security.sql
```

Never paste service-role or provider secrets into a migration. Apply migrations
in timestamp order. Do not assume every migration can be replayed against an
already-migrated database; the migration ledger is authoritative. Triggers and
policies that are intentionally recreated use explicit drops where required.

## Validate

After deployment:

1. Confirm every `public.kumusta_%` table has RLS enabled and
   `supabase/tests/baseline_security.sql` passes.
2. Compare policy names/commands with `rls.md`.
3. Confirm `anon` has no Kumusta table privileges.
4. Confirm `authenticated` has no privileges on
   `kumusta_revenuecat_events` or `kumusta_api_rate_limits`.
5. Confirm `authenticated` has only `SELECT` on
   `kumusta_entitlements`.
6. Confirm all seven adaptive tables have no `anon` or `authenticated` grants,
   confirm the project-quota table has no client grants, and verify only
   `service_role` can execute adaptive and user/project quota RPCs.
7. Run Supabase security and performance advisors.
8. Treat new `WARN` or `ERROR` findings as release blockers.

Fresh indexes will appear as unused until representative traffic exists. That
informational result is expected; do not remove an index solely because a new
environment has no usage statistics.

## Provider quota RPC

Provider functions consume quota through
`public.kumusta_consume_api_quota(uuid, text, integer, integer)`. The function
uses an atomic fixed-window upsert, validates approved scopes and bounded
configuration, and returns `false` on invalid input or accounting failure. It
is `SECURITY DEFINER` with a fixed `pg_catalog, public` search path.

Only `service_role` has `EXECUTE`; `anon` and `authenticated` are explicitly
revoked. After applying the base quota migration and the adaptive-learning
migration, verify the function catalog, fixed search path, approved scopes
(`elevenlabs_tts`/`_daily`, `elevenlabs_stt`/`_daily` for Soniox speaking
checks, `lessons`/`_daily`, `lessons_mutation`/`_daily`, and
`revenuecat_sync`), and these three role privileges before deploying provider
functions. Also verify `kumusta_consume_project_api_quota` is service-role-only
and permits only `elevenlabs_tts_project_daily` and
`elevenlabs_stt_project_daily`.

The baseline includes a generation-lease RPC (the lesson function requests a
180-second lease),
transactional generated-lesson/queue persistence, and composite tenant
ownership foreign keys. Verify that a stale lease recovers, a forced queue
failure rolls back the full batch, and mismatched service-role `user_id` writes
fail before deploying the adaptive function.

## Edge Function contract

Every function is prefixed `kumusta-`:

- `kumusta-elevenlabs-tts` (lesson and vocabulary audio)
- `kumusta-lesson-stt` and `kumusta-lesson-stt-token` (Soniox speaking checks)
- `kumusta-lessons` (adaptive Tagalog lessons, Qwen)
- `kumusta-live-pipeline` (live practice)
- `kumusta-account-data`, `kumusta-award-xp`, `kumusta-curriculum-admin`
- `kumusta-revenuecat-webhook`, `kumusta-revenuecat-webhook-admin`
- `kumusta-email-worker`

Deploy with
`supabase functions deploy --project-ref vpitjvtfzpqfnqgzcpla --use-api`.

The provider functions must require a valid user JWT, enforce bounded
inputs, set request timeouts, and return structured errors without provider
details. Provider-consuming paths check active entitlement and consume a
service-side rate limit. Adaptive completion and review paths do not call the
provider; they remain authenticated, owner-checked, bounded, and idempotent so a
finished rep is not lost if entitlement just expired.

The ElevenLabs proxy never accepts a voice ID from the client. It uses the one
Tagalog voice, `qZLi51uuzx5jdu6q0ayz`, or the `KUMUSTA_TTS_VOICE_ID` override.

The RevenueCat webhook cannot use Supabase JWT verification because RevenueCat
is the caller. It must instead:

1. Require and constant-time compare a dedicated webhook authorization secret.
2. Reject oversized or malformed bodies.
3. Insert `kumusta_revenuecat_events` by immutable event ID.
4. Treat duplicate event IDs as successful idempotent delivery.
5. Project entitlement state in the same transaction where practical.
6. Mark processing completion/error without exposing the payload to clients.

Store these only as Supabase function secrets:

- `KUMUSTA_TTS_API_KEY` (ElevenLabs) and optional `KUMUSTA_TTS_VOICE_ID`
- `KUMUSTA_LESSON_STT_API_KEY` and `KUMUSTA_LESSON_AGENT_API_KEY` (Soniox)
- `KUMUSTA_LLM_LIVE_CONVERSATION_API_KEY` (Anthropic)
- `DASHSCOPE_API_KEY` and optional `QWEN_LESSON_MODEL` (Qwen)
- `REVENUECAT_WEBHOOK_AUTH`
- `REVENUECAT_SECRET_API_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` when the runtime does not inject it

Adaptive lesson deployment, monitoring, fallback, and incident procedures live
in `LESSON_GENERATION_RUNBOOK.md`.

## Rollback and incident response

Do not drop populated tables to roll back an app release. Ship a forward
migration that restores compatibility. For an authorization incident:

1. Disable the affected Edge Function or revoke its secret.
2. Rotate compromised provider/service credentials.
3. Revoke the narrowest affected grants/policies.
4. Preserve webhook and analytics audit evidence.
5. Assess affected user IDs and timestamps.
6. Deploy and validate a forward-only remediation.

Deleting a user cascades learning and billing projection rows. Provider-side
RevenueCat deletion or anonymization is a separate operation and must be
included in the account-deletion workflow.

## Catalog parity note

Use the ordered local migrations and `supabase/tests/baseline_security.sql` to
compare the target catalog. Never infer parity from migration filenames alone; verify table,
index, trigger, policy, function, search-path, and grant state after every
production push.
