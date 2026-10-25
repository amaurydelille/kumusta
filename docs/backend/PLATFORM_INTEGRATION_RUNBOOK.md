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
let speech = FallbackSpeechRecognitionService(
    primary: SupabaseSpeechRecognitionService(
        client: supabaseProvider.client,
        authSessionProvider: auth
    ),
    fallback: AppleSpeechRecognitionService()
)
let personalizedLearning = SupabaseAdaptiveLessonService(
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
The Tagalog learning voice is never silently replaced by Apple's synthesizer in
Release builds; provider failures stay visible and retryable.

## Edge Function gateway configuration

`supabase/config.toml` disables gateway JWT verification for the functions
whose handlers perform their own server-validated authentication; RevenueCat
uses external webhook credentials. For example:

```toml
[functions.kumusta-elevenlabs-tts]
verify_jwt = false

[functions.kumusta-lesson-stt]
verify_jwt = false

[functions.kumusta-lesson-stt-token]
verify_jwt = false

[functions.kumusta-lessons]
verify_jwt = false

[functions.kumusta-live-pipeline]
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
KUMUSTA_TTS_API_KEY
KUMUSTA_LESSON_STT_API_KEY
KUMUSTA_LESSON_AGENT_API_KEY
KUMUSTA_LLM_LIVE_CONVERSATION_API_KEY
DASHSCOPE_API_KEY
REVENUECAT_SECRET_API_KEY
REVENUECAT_WEBHOOK_AUTHORIZATION
```

Recommended or configurable values:

```text
REVENUECAT_WEBHOOK_SIGNING_SECRET
KUMUSTA_TTS_VOICE_ID=qZLi51uuzx5jdu6q0ayz
QWEN_LESSON_MODEL=qwen3.8-max-0902
KUMUSTA_ENTITLEMENT_ID=kumusta_pro
```

Supabase supplies its URL, publishable/anon key, and service-role key to deployed
Functions. Never add service-role, provider, RevenueCat secret, or
webhook credentials to the iOS target.

Before deployment, use `supabase secrets list` and confirm that every required
name exists. Do not print secret values. The function sources are safe to deploy
only after every migration in `supabase/migrations/` has been applied.

## Function contracts

### ElevenLabs

`kumusta-elevenlabs-tts` accepts `text`, `speed`, and the optional purpose
`lesson` or `vocabulary` (defaulting to `lesson` for older clients), or the
fixed `onboarding_conversation` lines. The client never sends a voice: the
server uses the one Tagalog voice `qZLi51uuzx5jdu6q0ayz` unless
`KUMUSTA_TTS_VOICE_ID` overrides it.

The handler verifies the Supabase session, active `kumusta_pro` entitlement
(except for the fixed onboarding lines before onboarding is complete), text
bounds, enum values, 60/minute user quota, configurable user-daily quota, and
configurable project-daily quota before calling ElevenLabs. All Tagalog TTS
audio uses `eleven_v4` with language code `fil`, including lessons and
vocabulary. Provider errors are redacted. The returned stream is capped at
3,000,000 bytes and successful audio is cached in the private `kumusta-tts`
Storage bucket, keyed by text, speed, purpose, voice and provider model.

### Soniox

`kumusta-lesson-stt-token` returns a single-use Soniox realtime key for a
speaking take; `kumusta-lesson-stt` transcribes an uploaded M4A take when
streaming failed and deletes it at the provider afterwards. Both share one
admission gate (entitlement, 20/minute and daily user quotas, project-daily
quota). The app grades the transcript on-device; no language model is called.

### Lesson generation

`kumusta-lessons` accepts exact-key `get_next`, `retry_generation`,
`request_generation`, `complete`, `feedback`, and `review_word` actions with
bounded profile enums (goal, level, target level, challenge preference, daily
minutes) and client-generated UUIDs. It maintains deterministic private learner
state and a target queue of two ready lessons. Only an entitled user can
fetch/generate lessons; authenticated completion and review writes remain
recordable when replenishment is deferred.

Generation requests one full lesson at a time from Qwen through strict
JSON-schema output and at most three provider attempts. Local validation
enforces exact duration and round count, distinct utterances, normalized chunk
order/containment, word-gloss coverage, vocabulary and usage-example
grounding, deterministic presented-word membership, prohibited subjects,
Latin-script Tagalog text, response size, and content limits before a row can
become ready. Generation uses a 180-second recoverable lease; the validated
lesson batch and queue entries persist transactionally with composite tenant
ownership foreign keys. The app performs a second contract check and uses
bundled authored content when no valid generated lesson is available. Contract
validation is not native-speaker certification. See
`docs/ADAPTIVE_LEARNING.md` and `docs/backend/LESSON_GENERATION_RUNBOOK.md`.

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
deno test --allow-env --allow-read supabase/functions
```

Type-check all entry points with a Deno environment that supports npm imports.
Before TestFlight, test:

- new install → Supabase anonymous UUID → same RevenueCat App User ID;
- purchase webhook → active mirror row → authenticated TTS succeeds;
- expired mirror → TTS, speech-to-text, and adaptive `get_next` provider access
  fail with `premium_required`;
- generated lesson completion remains accepted if later queue replenishment is
  unavailable or entitlement has just expired;
- repeated completion/word-review event UUID → one deterministic state change;
- process recreation with an offline mutation → same event UUID delivered once;
- expired generation lease → exact retry reclaims or new request supersedes;
- forced queue failure → no partial generated lesson batch;
- arbitrary generated-word UUID and cross-tenant composite relationship →
  rejected;
- oversized streamed lesson/transcript/audio response → bounded failure;
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
- Speaking takes go to Soniox only for a check the learner records; graded
  results are not persisted by Kumusta or included in analytics.
- Adaptive lesson generation sends only bounded profile/state fields and stores
  validated generated content privately with model/prompt/schema provenance.
- RevenueCat audit payloads discard subscriber attributes.
