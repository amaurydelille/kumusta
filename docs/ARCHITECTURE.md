# Architecture

## Decision

Kumusta is one XcodeGen-generated SwiftUI application target with unit and UI
test targets. Feature and infrastructure boundaries are enforced with folders,
protocols, actors, and access control. Framework-per-feature modularization is
deferred until separate teams or measured build costs justify it.

## Stack

- Swift 6 with complete concurrency checking
- SwiftUI and Observation, iOS 17+
- Supabase Swift pinned to 2.54.1
- RevenueCat iOS pinned to 5.82.0
- AVFoundation for playback and system fallback
- XcodeGen 2.46.0

## Dependency direction

```text
SwiftUI View -> Feature Store -> Repository/Service Protocol -> Adapter
                                  |
                                  -> Domain value -> Store -> SwiftUI View
```

Views never import Supabase or RevenueCat. SDK models never reach views. Mutable
I/O implementations are actors. UI state is main-actor isolated.

## Runtime dependencies

`DependencyContainer` is constructed once by `KumustaApp` and injected through
the SwiftUI environment. Live, preview, and test implementations share the same
protocols. Missing external configuration activates bounded development
fallbacks; it never activates a production entitlement bypass.

## Local-first behavior

The app ships a versioned curriculum seed. Profile and onboarding data are
durable locally first. Review events and learning sessions are modeled as
append-only records with client-generated identifiers, enabling later
idempotent synchronization. Curriculum remains server-authoritative when a
newer published manifest is available.

## Identity order

1. Restore or establish a Supabase user session.
2. Use the Supabase user UUID as the RevenueCat app user ID.
3. Sync the local onboarding draft.
4. Load cached and then current entitlement.

The current MVP can operate locally before account setup. Anonymous production
auth must have CAPTCHA and rate protection enabled before launch.

## Configuration boundary

The Supabase URL, publishable client key, and RevenueCat public SDK key are
client configuration. Provider secrets and service-role keys are server-only.
ElevenLabs and Mistral requests go through authenticated Supabase Edge
Functions.

Adaptive Mistral lessons use a private server-owned pipeline: bounded profile
enums → deterministic learner state → per-user generation job → strict
structured-output validation → generated lesson store → per-user queue. The app
never reads those tables directly. It receives one validated lesson through the
Edge Function, validates the response contract again, and falls back to bundled
authored content when the adaptive path is unavailable.

Mistral supplies candidate lesson text only. Post-session challenge, level,
audio-pace, completion, and generated-vocabulary scheduling updates are
deterministic, idempotent Postgres RPC operations. Generated content and
authored/published curriculum remain separate trust classes.

Adaptive mutations use a bounded durable iOS outbox. Persisting the stable
client event UUID is the client success boundary; retries across process
termination are oldest-first and the event is removed only after server
acknowledgement. On the server, generation uses expiring database leases,
validated lesson/queue batches persist transactionally, and composite
`(object_id, user_id)` foreign keys enforce tenant ownership beneath the Edge
Function.

Today and Practice are stale-while-revalidate surfaces: bundled authored
content renders immediately, while a single coalesced request checks the
private generated queue. `get_next` only reads queue/state data. Empty or low
queues schedule Mistral generation as a Supabase background task, so provider
latency is never part of screen loading or completion acknowledgement.
