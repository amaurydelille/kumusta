# Release readiness

## Required external configuration

- RevenueCat app, entitlement `kumusta_pro`, offerings, monthly and annual
  products, App Store Connect agreements, and sandbox testers
- Supabase anonymous/auth strategy and production CAPTCHA/rate controls
- ElevenLabs, Soniox, DashScope (Qwen) and Anthropic secrets installed only on
  Edge Functions
- RevenueCat webhook authorization and idempotency verification
- Privacy and terms URLs
- Support contact and account deletion workflow

## Implemented and verified in this workspace

- Native Swift 6 / SwiftUI app target plus unit and UI test targets
- Supabase schema with `kumusta_` tables, RLS, integrity
  triggers, idempotency keys, service-only provider quota accounting, and
  RevenueCat entitlement plus private adaptive-learning projections
- Supabase anonymous identity bootstrap before RevenueCat configuration
- Provider secrets confined to authenticated Edge Function source
- One server-configured Tagalog voice; clients never send a voice ID
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

The Kumusta development project (`vpitjvtfzpqfnqgzcpla`) has the ElevenLabs,
Soniox and Anthropic secrets installed. `DASHSCOPE_API_KEY`, the RevenueCat
secrets and the email secrets are not set yet, so lesson generation, purchases
and email fail closed until they are.

Release evidence must be recorded against this project and the Tagalog
content. Before rollout, run builds/tests plus the lesson contract,
database/RPC idempotency, RLS/grant (`supabase/tests/baseline_security.sql`),
native-speaker sample, and provider-fallback gates from
`docs/backend/LESSON_GENERATION_RUNBOOK.md`.

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
- Tagalog lesson audio is verified by a native Metro Manila Tagalog speaker
- Offline first lesson and cached entitlement paths are tested
- Sandbox annual/monthly purchase, cancellation, pending, failure, and restore
  paths are tested on device
- RLS security and performance advisors have no Kumusta warnings
- Generated lessons have a recorded native-speaker sample review for the exact
  production model and prompt version
- The authored roadmap and welcome lessons are approved by a native speaker
  (`review_status = 'approved'`) before they are published
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
xcodegen generate && pod install
xcodebuild -workspace kumusta.xcworkspace -scheme Kumusta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The generated project and `Package.resolved` are committed. CI should regenerate
and fail if the project changes, preventing hand-edited project drift.
