# Security and privacy

## Client trust boundary

The iOS bundle may contain only:

- Supabase project URL
- Supabase publishable key
- RevenueCat public iOS SDK key
- Non-secret product and entitlement identifiers

It must never contain Supabase secret/service-role keys, RevenueCat secret keys,
ElevenLabs keys, Mistral keys, or webhook secrets.

## Provider calls

The client sends a normalized accent enum to the TTS Edge Function. The server
maps that enum to the approved female voice:

- Southern: `6Xq32rHt6oAu98TBDKfr`
- Northern: `LD1UihCXvSlUL4h8DOmk`

Arbitrary voice identifiers are rejected. Provider calls require a valid user
session, entitlement checks where appropriate, input length limits, timeouts,
rate limits, and safe error responses.

Adaptive lesson generation sends Mistral bounded learner-profile enums,
numeric adaptive state, skill-mastery values, recent scenario keys, an optional
bounded next-topic label, and the server-owned curriculum prompt. The topic is
normalized, character-limited, screened for instruction-like content, and
delimited as untrusted data. It does not send the learner’s display name,
email, audio recording, raw analytics, entitlement record, or payment data.
Difficulty, pace, and generated-word feedback are stored as enums. The optional
topic label is retained in the device outbox only until server acknowledgement
and is not written to analytics or adaptive database tables.

The separate text-evaluation action sends an authored phrase and the learner’s
explicit text attempt. It is never invoked for passive typing or audio, and
Kumusta does not persist that free-form attempt in adaptive tables, analytics,
or function logs. Provider retention remains governed by the approved Mistral
account/data-processing configuration and must be reviewed before production
use or a region change.

Generated lesson text is stored for queue delivery with per-user ownership,
model/prompt/schema provenance, a 30-day serving expiry, and service-role-only
access. Expiry alone does not delete rows; operations must monitor retention and
use an approved cleanup policy. Logs contain request/job identifiers and
sanitized codes, never prompts, provider payloads, access tokens, or lesson text.

Generated relationships have composite object/user foreign keys so even
service-role mistakes cannot associate another learner’s job, lesson, queue,
feedback, vocabulary state, or session. Generated-word reviews must match a
deterministic UUID presented for the owned lesson. Provider bodies are streamed
through hard byte ceilings before parsing or returning: 1 MiB for generated
lessons, 256 KiB for text evaluation/Scribe JSON, and 3,000,000 bytes for TTS
audio. Speaking uploads have a separate 1,500,000-byte ceiling.

For an explicit speaking check, one temporary M4A recording is sent to the
authenticated `kumusta-elevenlabs-stt` boundary and then to ElevenLabs Scribe
v2. Kumusta deletes the device file as soon as the bounded upload is loaded
into memory. The function does not persist audio or transcripts and logs only a
request ID, status, and sanitized error category. Provider-side retention is
governed by the approved ElevenLabs account configuration and must be reviewed
before App Store release.

Pending adaptive mutations are stored in a 200-event UserDefaults outbox with
the Supabase user UUID and bounded enum/profile payload. Acknowledged events are
removed, and events for one identity are never delivered under another identity.

## Database rules

Every Kumusta table begins with `kumusta_` and has row-level security.
User-owned rows require `auth.uid() = user_id`. Curriculum is published/read
only. Reviews are append-only. Analytics is insert-only. Entitlements and
RevenueCat audit events are server-written.

See `docs/backend/RLS_POLICY_MATRIX.md` for the exact policy contract.

## Data minimization

- Names never enter analytics.
- Raw speech is uploaded only after the learner taps “Check my Vietnamese”; it
  is never included in analytics or Kumusta database rows.
- Temporary recordings are file-protected, randomly named, scrubbed on launch,
  and deleted after upload, retry reset, completion, or dismissal.
- Transcripts and free text are excluded from general analytics.
- Response duration uses coarse buckets when needed.
- Audio cache is disposable and excluded from backup.
- Account export and deletion must include every user-owned `kumusta_` row.

## Privacy manifest

`PrivacyInfo.xcprivacy` declares the UserDefaults accessed API. The manifest
must be reviewed again after final analytics, crash reporting, and attribution
SDK selection.
