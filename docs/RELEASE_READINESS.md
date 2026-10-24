# Release readiness

## Required external configuration

- RevenueCat app, entitlement `kumusta_pro`, offerings, monthly and annual
  products, App Store Connect agreements, and sandbox testers
- Supabase anonymous/auth strategy and production CAPTCHA/rate controls
- ElevenLabs and Mistral secrets installed only on Edge Functions
- ElevenLabs key verified with `text_to_speech` and `speech_to_text` permissions
- RevenueCat webhook authorization and idempotency verification
- Privacy and terms URLs
- Support contact and account deletion workflow

## Implemented and verified in this workspace

- Native Swift 6 / SwiftUI app target plus unit and UI test targets
- Supabase schema target with 23 `kumusta_` tables, RLS, integrity
  triggers, idempotency keys, service-only provider quota accounting, and
  RevenueCat entitlement plus private adaptive-learning projections
- Supabase anonymous identity bootstrap before RevenueCat configuration
- Provider secrets confined to authenticated Edge Function source
- Southern and Northern female voice IDs enforced by a server-owned allowlist
- Offline system-voice fallback, local profile, local activity, and seeded
  learning content
- Bounded adaptive lesson queue with deterministic feedback/review state and an
  authored lesson fallback
- Durable idempotent adaptive mutation outbox, generation leases,
  transaction-owned lesson/queue persistence, composite ownership foreign keys,
  grounded/prohibited-subject validation, membership checks, and bounded
  provider response reads
- Hard paywall states for loading, purchase, pending, restore, and failure
- Dynamic Type, VoiceOver selection semantics, Reduce Motion, and large review
  controls

The real RevenueCat public/secret keys, provider keys, public legal pages,
App Store products, native-speaker content sign-off, and device sandbox
purchases remain operator gates—not code defaults.

The temporary Supabase project has Mistral and ElevenLabs secrets installed.
Live TTS succeeds for both approved voices. As of 2026-07-31, the installed
ElevenLabs key is TTS-only; Scribe correctly fails closed until its
`speech_to_text` permission is enabled.

## Current adaptive verification — 2026-07-31

- Swift Debug unit suite on iPhone 17 Pro simulator: passed
- Optimized Release simulator build: passed
- Deno format/lint and all six Edge entrypoint type checks: passed
- Edge/shared contract suite: 46 passed, 0 failed
- Remote migrations applied through composite ownership FK indexes: passed
- Supabase performance advisor: no unindexed Kumusta foreign keys
- Deployed fail-closed authentication smoke tests: passed for lesson,
  evaluation, TTS, and account-data endpoints
- The current Mistral v3/prompt-v5 lesson contract requires a full 5–12-round
  session, exact selected duration, distinct utterances, one shared topic key,
  exact ordered word glosses, and 8–18 grounded vocabulary items. A fresh
  authenticated production-provider smoke remains required after this contract change.
- The feedback sheet accepts an optional bounded next-topic label. The iOS and
  Edge boundaries normalize it, reject instruction-like content, and pass it to
  Mistral only as untrusted subject data.
- Authenticated completion smoke: `too_easy` moved challenge offset to `0.25`;
  `too_fast` moved persisted speech speed from natural to slow
- Authenticated ElevenLabs TTS smoke: Southern and Northern returned valid MP3
  audio from the exact allowlisted IDs
- Authenticated Scribe smoke: sanitized failure confirmed; direct provider check
  identified the remaining `speech_to_text` key permission gate
- Speech-transcript feedback: exact words with different ASR punctuation, plus
  accepted sentence-final ạ/à, final c/ch, and initial tr/ch variants, return
  deterministic perfect-match feedback with zero corrections; other output
  remains constrained to word-level coaching
- First-lesson UI journey: lesson-shape education, explicit repeat-not-answer
  instruction, and completion/adaptive check-in passed on iPhone 17 Pro simulator
- Generated choice-copy boundary: Vietnamese or transliterated utterances cannot
  become English situation answers; existing invalid queued lessons quarantined

## Historical automated verification

The following baseline was verified on 2026-07-31 before the adaptive-learning
migrations and fifth Edge Function were added:

- Debug iOS Simulator build: passed
- Release generic iOS Simulator build: passed
- Swift unit tests: passed
- Fresh-launch onboarding UI test: passed
- Deno format and lint: passed
- Four Edge Function entrypoints type-check: passed
- Edge Function contract tests: 13 passed, 0 failed
- Supabase remote verification: 15 Kumusta tables, 17 RLS policies, composite
  review/session ownership index present, provider quota RPC executable only by
  `service_role`

Do not treat that baseline as adaptive-learning release evidence. Before
rollout, re-run builds/tests plus Mistral contract, database/RPC idempotency,
23-table RLS/grant, regional-language sample, and provider-fallback gates from
`docs/backend/MISTRAL_RUNBOOK.md`.

Security-advisor notices for `kumusta_api_rate_limits` and
`kumusta_revenuecat_events` are expected informational notices: those tables
are RLS-enabled with no client policies because they are intentionally
service-only. New empty-table indexes are naturally reported as unused until
real traffic exists.

## Gate checklist

- Clean Swift 6 build with no warnings in app-owned code
- Unit and deterministic UI tests pass
- Fresh-install onboarding completes at largest supported Dynamic Type
- VoiceOver can complete demo, paywall restore, lesson, and review
- Reduce Motion removes travel and celebratory motion
- Southern and Northern audio are verified by native speakers
- Offline first lesson and cached entitlement paths are tested
- Sandbox annual/monthly purchase, cancellation, pending, failure, and restore
  paths are tested on device
- RLS security and performance advisors have no Kumusta warnings
- Both generated accents have a recorded native-speaker sample review for the
  exact production model and prompt version
- Empty/warm queue, duplicate completion/review, provider timeout, quota, and
  authored fallback paths are verified
- Durable outbox recreation, generation lease recovery, transactional rollback,
  vocabulary membership, composite ownership, and oversized provider responses
  are verified
- Empty-queue generation is asynchronous, Today/Practice render authored
  content immediately, and concurrent tab fetches are coalesced
- Expired generated-content cleanup is approved
- No provider or service-role secrets exist in Git history or built bundle
- App privacy answers match runtime collection
- Export and deletion cover all user-owned tables
- `KUMUSTA_DEVELOPMENT_BYPASS_ENTITLEMENT` is absent or false and
  `KUMUSTA_ENVIRONMENT=production`

## Build

Regenerate the project before CI:

```sh
xcodegen generate
xcodebuild -project kumusta.xcodeproj -scheme Kumusta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The generated project and `Package.resolved` are committed. CI should regenerate
and fail if the project changes, preventing hand-edited project drift.
