# ADR 0003: Server-side AI providers

Status: accepted

## Context

ElevenLabs and Mistral require secret credentials, usage controls, and a stable
product policy independent of mobile release cadence.

## Decision

All provider traffic passes through authenticated Supabase Edge Functions.
Clients send enums and bounded content, not provider-specific model or voice
identifiers. The server owns allowlists, prompts, quotas, and logging.

Mistral may produce bounded lesson candidates and text feedback only. Generated
lessons pass a strict provider JSON schema, a local server validator, and a
second app-side contract check before presentation. Adaptation mathematics,
queue ownership, review scheduling, IDs, entitlements, and billing remain
deterministic application/database concerns. Generated copy is not promoted
into the authored curriculum and must not be labeled native-speaker-reviewed or
linguistically certified.

The server validates chunk order, vocabulary/example grounding, prohibited
subjects, ownership, and presented vocabulary membership. It uses expiring
generation leases, transactional lesson/queue persistence, composite tenant
foreign keys, user/project quotas, and bounded provider-body reads. Adaptive
client mutations use a durable stable-ID outbox so retries remain idempotent
across app termination.

## Consequences

Secrets remain outside the app and provider changes do not force an App Store
release. The backend becomes a latency and availability dependency, so audio is
cached and core learning retains authored fallbacks. The system also gains
private learner-state, generation-audit, generated-content, queue, and feedback
data that require service-role-only access, retention monitoring, and model/
prompt provenance. Strict structural validation reduces malformed output risk
but does not replace native-speaker quality review.
