# Platform integration runbook

This document covers the production boundaries implemented for Supabase project
`vpitjvtfzpqfnqgzcpla`. It is intentionally explicit about the steps that still
require operator-owned credentials.

## Identity and conversion flow

Kumusta creates a background Supabase anonymous Auth session before RevenueCat
is configured. This does not add an account screen before the paywall. Its UUID
is the stable RevenueCat App User ID and the key used by the entitlement mirror.

The ordering is a security and data-integrity requirement:

1. Construct the single `SupabaseClientProvider`.
2. Construct `SupabaseAuthSessionProvider`.
3. Await `bootstrapAnonymousSession()`.
4. Configure RevenueCat with `appUserID: identity.id.uuidString`.
5. Present onboarding and the paywall only after that bootstrap succeeds.

Do not let RevenueCat generate a `$RCAnonymousID`; the webhook cannot safely map
that value to `auth.users`.

When the learner later chooses Sign in with Apple,
`signInWithApple(identityToken:rawNonce:)` links Apple to the anonymous Supabase
user in place. The UUID, RevenueCat customer, and entitlement remain stable.
Identity linking must be enabled in the Supabase Auth provider settings.

Email/password sign-in can replace the UUID. If that UI is shipped, immediately
call RevenueCat `logIn(newSupabaseUUID)` after the auth state change and verify
the returned CustomerInfo before trusting the new mapping.

Anonymous Auth must be enabled in Supabase. Anonymous users remain blocked from
all learner tables by RLS. Only the provider Edge Functions accept their valid
JWT, and only after a service-role active-entitlement check.

## iOS wiring

`DependencyContainer` should create these objects once:

```swift
let supabaseProvider = try SupabaseClientProvider(configuration: configuration)
let auth = SupabaseAuthSessionProvider(client: supabaseProvider.client)
let sync = SupabaseSignedInRepository(
    client: supabaseProvider.client,
    authSessionProvider: auth
)
let ttsGateway = SupabaseElevenLabsTTSGateway(
    client: supabaseProvider.client,
    authSessionProvider: auth
)
let audio = AuthenticatedElevenLabsAudioService(gateway: ttsGateway)
let ai = SupabaseMistralEvaluationService(
    client: supabaseProvider.client,
    authSessionProvider: auth
)
let personalizedLearning = SupabaseMistralLearningService(
    client: supabaseProvider.client,
    authSessionProvider: auth
)
```

The old `ElevenLabsAudioService` must not be used in production. It sends the
publishable key as a bearer token; publishable keys are client identifiers, not
user JWTs. `AuthenticatedElevenLabsAudioService` invokes Functions through the
Supabase SDK, which supplies the refreshed session JWT.

Pre-paywall onboarding remains local. Call profile, onboarding, preference,
session, review, and analytics sync only after
`currentAuthenticatedUser()` succeeds. That method deliberately rejects
anonymous sessions. Provider audio/AI use `currentBackendIdentity()` because
their Edge Functions enforce entitlement and quota server-side.

## Edge Function gateway configuration

Add the following to `supabase/config.toml`. Each handler performs its own
server-validated authentication; RevenueCat uses external webhook credentials.

```toml
[functions.kumusta-elevenlabs-tts]
verify_jwt = false

[functions.kumusta-mistral-evaluate]
verify_jwt = false

[functions.kumusta-mistral-lessons]
verify_jwt = false

[functions.kumusta-revenuecat-webhook]
verify_jwt = false
```

Disabling the gateway check does not make the provider functions public:
`requireAuthenticatedUser` validates the bearer token through Supabase Auth.
The webhook uses constant-time authorization comparison and, when configured,
RevenueCat HMAC verification over the exact raw body.

Required secrets:

```text
ELEVENLABS_API_KEY
MISTRAL_API_KEY
REVENUECAT_SECRET_API_KEY
REVENUECAT_WEBHOOK_AUTHORIZATION
```

Recommended or configurable values:

```text
REVENUECAT_WEBHOOK_SIGNING_SECRET
MISTRAL_MODEL=mistral-small-latest
MISTRAL_LESSON_MODEL=mistral-medium-latest
KUMUSTA_ENTITLEMENT_ID=kumusta_pro
```

Supabase supplies its URL, publishable/anon key, and service-role key to deployed
Functions. Never add service-role, ElevenLabs, Mistral, RevenueCat secret, or
webhook credentials to the iOS target.

Before deployment, use `supabase secrets list` and confirm that every required
name exists. Do not print secret values. The function sources are safe to deploy
only after migrations through
`20260731114500_harden_kumusta_adaptive_runtime_v1.sql` have been applied.

## Function contracts

### ElevenLabs

`kumusta-elevenlabs-tts` accepts `text`, `accent`, `speed`, and the optional
purpose `lesson` or `vocabulary` (defaulting to `lesson` for older clients).
Accent is mapped in source to one of these female voices:

- Southern: `6Xq32rHt6oAu98TBDKfr`
- Northern: `LD1UihCXvSlUL4h8DOmk`

The handler verifies the Supabase session, active `kumusta_pro` entitlement,
text bounds, enum values, 60/minute user quota, configurable user-daily quota,
and configurable project-daily quota before calling ElevenLabs. All Vietnamese
TTS audio uses Eleven v3, including lessons and vocabulary. Provider errors are
redacted. The
returned stream is capped at 3,000,000 bytes and successful audio is cached in
the private Supabase Storage-backed cache by purpose and provider model.

### Mistral

`kumusta-mistral-evaluate` accepts an authored phrase, a text learner attempt,
and `explanation` or `hint`. It does not accept audio. Output is constrained to
the v1 JSON schema with at most two corrections. Malformed, unavailable, or
misconfigured provider responses return authored deterministic feedback with
`fallback: true`; authentication, entitlement, validation, and quota failures
do not fall back.

`kumusta-mistral-lessons` accepts exact-key `get_next`, `complete`, `feedback`,
and `review_word` actions with bounded profile enums and client-generated UUIDs.
It maintains deterministic private learner state and a target queue of two
ready lessons. Only an entitled user can fetch/generate lessons; authenticated
completion and review writes remain recordable when replenishment is deferred.

Generation requests one full lesson at a time through strict JSON-schema output
and at most two provider attempts. Local validation enforces requested accent
metadata plus basic opposite-region location checks, exact duration and round
count, distinct utterances, normalized chunk order/containment, vocabulary and
usage-example grounding, deterministic presented-word membership, prohibited
subjects, Vietnamese text, response size, and content limits before a row can
become ready. Generation uses a 120-second recoverable lease; the validated
lesson batch and queue entries persist transactionally with composite tenant
ownership foreign keys. The app performs a second
contract check and uses bundled authored content when no valid generated lesson
is available. Contract validation is not native-speaker certification. See
`docs/ADAPTIVE_LEARNING.md` and `docs/backend/MISTRAL_RUNBOOK.md`.

Completion and word-review calls enter a capped durable iOS outbox before
delivery. Retries preserve the client event UUID across app termination; the
server independently caps mutations at 120/minute and 2,000/day per user.

### RevenueCat

`kumusta-revenuecat-webhook` requires the exact dashboard Authorization value.
If HMAC signing is enabled it also verifies
`X-RevenueCat-Webhook-Signature` with a five-minute replay window.

The handler:

1. writes an idempotent, PII-minimized event audit row;
2. resolves only a UUID App User ID or alias;
3. fetches authoritative CustomerInfo with the RevenueCat secret API;
4. mirrors active, expired, grace-period, and lifetime entitlement state;
5. deactivates mirror rows absent from the authoritative response;
6. marks the event processed.

Retries remain safe. A duplicate that is already processed returns `200`.
Provider/storage failures remain unprocessed and return a retryable response.

## Verification

Pure contract tests:

```sh
npx -y deno test \
  supabase/functions/_shared/http_test.ts \
  supabase/functions/kumusta-elevenlabs-tts/contract_test.ts \
  supabase/functions/kumusta-mistral-evaluate/contract_test.ts \
  supabase/functions/kumusta-mistral-lessons/contract_test.ts \
  supabase/functions/kumusta-mistral-lessons/repository_test.ts \
  supabase/functions/kumusta-revenuecat-webhook/contract_test.ts
```

Type-check all entry points with a Deno environment that supports npm imports.
Before TestFlight, test:

- new install → Supabase anonymous UUID → same RevenueCat App User ID;
- purchase webhook → active mirror row → authenticated TTS succeeds;
- expired mirror → TTS, text evaluation, and adaptive `get_next` provider access
  fail with `premium_required`;
- generated lesson completion remains accepted if later queue replenishment is
  unavailable or entitlement has just expired;
- repeated completion/word-review event UUID → one deterministic state change;
- process recreation with an offline mutation → same event UUID delivered once;
- expired generation lease → exact retry reclaims or new request supersedes;
- forced queue failure → no partial generated lesson batch;
- arbitrary generated-word UUID and cross-tenant composite relationship →
  rejected;
- oversized streamed lesson/evaluation/audio response → bounded failure;
- replayed webhook → no duplicate entitlement mutation;
- Apple link → unchanged Supabase UUID and RevenueCat customer;
- offline lesson completion → local success and later signed-in sync;
- raw text, audio, names, and email absent from analytics and function logs.

## Security assumptions

- The hard paywall gates app navigation, but provider access is independently
  enforced by the Edge Functions.
- The entitlement mirror is server-writable only. Mobile SDK CustomerInfo is
  useful for UX, not provider authorization.
- Review scheduling remains local-first. Remote review event and vocabulary
  state writes are idempotent but not a substitute for the on-device queue.
- Free-form learner text is sent to Mistral only on an explicit feedback action.
  It is not persisted by Kumusta or included in analytics.
- Adaptive lesson generation sends only bounded profile/state fields and stores
  validated generated content privately with model/prompt/schema provenance.
- RevenueCat audit payloads discard subscriber attributes.
