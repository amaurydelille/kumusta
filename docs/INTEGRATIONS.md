# Integrations

## Supabase

Project: `vpitjvtfzpqfnqgzcpla`

The iOS app uses the project URL and publishable key. All writes go through
repository adapters and are scoped by the authenticated user. Database
migrations live in `supabase/migrations`; Edge Functions live under
`supabase/functions`.

The app must treat network synchronization as retryable. A completed lesson is
saved locally even when the backend is unavailable.

## RevenueCat

Public iOS SDK configuration is injected through `REVENUECAT_PUBLIC_SDK_KEY`.
The entitlement identifier is `kumusta_pro`.

The purchase callback is not enough to unlock: the active entitlement must be
present in returned `CustomerInfo`. Server APIs rely on the Supabase entitlement
mirror updated by an authenticated, idempotent RevenueCat webhook.

The paywall renders prices, periods, and introductory offers from StoreKit via
RevenueCat. It never invents a discount, trial, crossed-out price, or claim that
payment is not due.

The onboarding paywall is a two-step app flow. Dismissing the current offering
transitions to the explicitly published `Fallback` offering, and dismissing that
second paywall transitions to the account exit screen. The `Fallback` offering
must be available in the RevenueCat dashboard and contain the promotional
pricing/packages intended for this second chance. A RevenueCat SDK-version
fallback is a compatibility fallback for older SDKs, not this dismissal flow.

## Ad attribution (AppsFlyer, TikTok, Meta)

AppsFlyer (`id6796837982`) is the MMP and the only owner of SKAN conversion
values. The TikTok Business SDK and Meta SDK run in hybrid mode with SKAN and
automatic payment tracking disabled. The app sets the same Supabase user ID as
AppsFlyer customer user ID, TikTok external ID, and Meta user ID.

### What the app sends

| Moment | AppsFlyer | TikTok SDK | Meta SDK |
|---|---|---|---|
| Free trial start | `af_start_trial`, no revenue | `StartTrial` | automatic (StoreKit) |
| Charged purchase (normal or intro price) | `af_purchase` with `af_revenue` + currency | `Purchase` with value + currency | automatic (StoreKit) |
| Renewal, trial conversion, refund, billing issue | nothing (happens off-device) | nothing | nothing |

Purchase and trial events are sent by `RevenueCatPurchaseService` for both the
custom and the RevenueCatUI paywall. Views must not send their own. The
on-device `af_purchase` stays because SKAN conversion values are computed by
the AppsFlyer SDK and ignore server-side events.

### RevenueCat → AppsFlyer (required for renewals)

The app sets the AppsFlyer ID and device identifiers on the RevenueCat
customer at login and again after the ATT prompt. For that to produce events:

1. RevenueCat dashboard → Integrations → AppsFlyer: enable it with the
   AppsFlyer dev key and iOS app ID.
2. Keep **initial purchase** and **trial started** off (or blank their event
   names). The app already sends those from the device; sending them twice
   double-counts revenue in AppsFlyer.
3. Keep renewal, trial conversion, trial cancelled, cancellation, uncancellation,
   expiration, billing issue, product change, and refund on.
4. Report revenue as gross (store commission is handled in AppsFlyer if needed).

### AppsFlyer → TikTok postbacks

AppsFlyer → Collaborate → Active Integrations → TikTok for Business:

- Partner active, TikTok App ID filled in, **In-app events postback** on.
- Map `af_purchase` → `Purchase` with values & revenue, `af_start_trial` →
  `StartTrial`, the RevenueCat renewal event → `Subscribe` with revenue, the
  trial-converted event → `Purchase` with revenue, `af_complete_registration`
  → `Registration`, `af_tutorial_completion` → `CompleteTutorial`.
- In TikTok Events Manager the same event name then arrives twice when it is
  both sent by the SDK and mapped here. Keep `Purchase` and `StartTrial` SDK-only
  **or** postback-only, never both. Renewal events can only come via postback.
- Settings → SKAN Conversion Studio: measurement on, revenue measured in
  window 1, `af_purchase` and `af_start_trial` as conversion events.

### Meta

Meta's SDK logs StoreKit purchases automatically. RevenueCat's Meta
integration (needs `$fbAnonId`, set at login) covers renewals. Do not add
manual purchase logging to `MetaAppEvents`.

## ElevenLabs

The mobile app calls `kumusta-elevenlabs-tts`, never ElevenLabs directly. The
request contains:

```json
{
  "text": "Cho mình một cà phê sữa đá, ít ngọt nha.",
  "accent": "southern",
  "speed": "natural",
  "purpose": "lesson"
}
```

The function validates authentication, entitlement/quota, text length, accent,
speed, and purpose. Purpose is restricted to `lesson` or `vocabulary` and
defaults to `lesson` for older clients. It selects only the configured female
voice ID and returns audio. Every Vietnamese TTS purpose—lesson, practice,
history, and Words-tab vocabulary playback—uses `eleven_v4`. All use language code `vi`, stability
`0.82`, similarity `0.80`, style `0`, speaker boost, and a stable best-effort
seed derived from voice/text/speed. These settings favor repeatable educational
speech over expressive variance. ElevenLabs does not guarantee byte-identical
determinism, so production audio still needs accent-specific listening QA.
Natural pace sends `speed: 1.0`; slower and faster send ElevenLabs' supported
extremes, `0.7` and `1.2`. Each pace is generated by ElevenLabs from the source
text and cached separately; the iOS client never time-stretches an existing MP3.
Responses are cached by normalized text, accent, speed, purpose, provider model,
and content version. The provider model and settings version are part of the
cache key, so old Flash responses are never served for new V3 requests.

When a lesson reaches iOS, the client warms the unique full-phrase utterances
at the learner's selected/default speed in the background, with at most three
provider requests in flight. The same gateway memory and disk caches are
populated by this work, and each request still uses the shared Supabase
Storage-backed cache above. Prewarming is best-effort and does not block the
lesson UI; a play request joins an identical in-flight request when necessary.
Hear & Respond also prewarms the short other-speaker prompt and reuses the
same cache, while answer grading and correct/wrong feedback remain on-device.
Slow and fast variants remain on demand so prewarming does not multiply TTS
usage for every lesson.

TTS is limited per user to 60 calls/minute and, by default, 500/day. A separate
project-wide circuit breaker defaults to 10,000/day across all paid identities.
The audio stream is byte-counted and rejected above 3,000,000 bytes; the
function does not trust `Content-Length` alone.

Short speaking checks call `kumusta-elevenlabs-stt`. The iOS recorder sends
an ephemeral mono AAC/M4A body with `Content-Type: audio/mp4`; it never sends the
authored answer as a keyterm or context hint. The function:

- accepts only authenticated sessions with an active entitlement;
- reads at most 1,500,000 request bytes and rejects other media types;
- selects `scribe_v2` and pins `language_code` to `vie`;
- disables diarization and audio-event tagging for a one-speaker phrase;
- sanitizes the response to a 500-character transcript and at most 100 word
  timestamps;
- never logs or persists audio, transcripts, or provider payloads.

STT is limited to 20 calls/minute and, by default, 300/user/day. Its separate
project circuit breaker defaults to 8,000/day. The ElevenLabs key must have both
Text to Speech and Speech to Text permissions. Batch Scribe is intentional;
realtime transcription is outside the current product scope.

## Mistral

The app has two authenticated server-side Mistral boundaries:

- `kumusta-mistral-lessons` creates validated, bounded lesson batches for a
  per-user queue used by Today, Practice, and Words;
- `kumusta-mistral-evaluate` gives structured explanation or hint feedback
  for an authored phrase and either an explicit text attempt or a sanitized
  Scribe transcript.

Both functions accept valid anonymous or registered Supabase sessions and
revalidate entitlement where provider access is needed. Prompts, provider keys,
model selection, exact JSON schemas, quotas, and safety policy live server-side.

Lesson generation is not an unbounded chat. Input is limited to profile enums,
numeric target/daily time, deterministic learner state, skill mastery, recent
scenario keys, and an optional 3–100-character real-life topic label. The topic
is normalized and screened server-side, treated as untrusted data in the system
prompt, and cannot change roles, policies, or output format. Output is one complete time-budgeted lesson containing
5–12 distinct rounds, with bounded chunks, vocabulary, difficulty, and accent.
The server deterministically expands every round into the three ordered
oral-practice stages before returning it to iOS.
The Edge Function locally validates output before storage and the app validates
it again before presentation.

Local validation proves normalized chunk order in each phrase, exact ordered
word-gloss coverage for every whitespace token, a shared topic key across all
rounds, vocabulary presence in a lesson phrase and its Vietnamese example, and
rejects the v1 prohibited-subject set. Persistence of the validated lesson batch and its queue
assignments is transactional. Composite ownership foreign keys prevent
cross-user generated relationships, and review actions accept only vocabulary
UUIDs deterministically presented for the owned lesson.

Mistral never chooses billing, entitlement state, learner-state mathematics,
review scheduling, queue ownership, or authored-curriculum publication.
Difficulty/pace feedback and generated-word ratings are enums applied by
service-role-only, idempotent Postgres RPCs. No audio is sent to Mistral. For a
Scribe transcript, the prompt restricts feedback to what the recognizer heard;
evaluation must not be presented as pronunciation, tone, or accent assessment.
Before calling Mistral, the evaluation boundary compares canonical spoken words
while preserving Vietnamese letters and ignoring speech-recognizer punctuation,
capitalization, and whitespace. An exact word match, or a word-aligned match
that differs only by sentence-final ạ/à, final c/ch, or initial tr/ch, receives
deterministic positive feedback with no provider call. Model output is also
sanitized so these accepted sound variants and transcript punctuation can never
become learner corrections.
The iOS client persists these mutations in a capped durable outbox and reuses
the same client event UUID until acknowledgement.

Model-generated lesson text has not passed the authored native-speaker
publication gate. Structural validation is not linguistic certification. See
[Adaptive learning](ADAPTIVE_LEARNING.md) and the
[Mistral production runbook](backend/MISTRAL_RUNBOOK.md).

## Failure behavior

| Dependency | User behavior |
|---|---|
| Supabase unavailable | Learn locally; sync later |
| ElevenLabs unavailable | Show retry; system voice is only a no-Supabase development fallback |
| ElevenLabs Scribe unavailable | Retry the short take or finish without feedback |
| Mistral lesson generation unavailable | Existing queued lesson, otherwise bundled authored lesson |
| Mistral text evaluation unavailable | Deterministic authored feedback with `fallback: true` |
| RevenueCat offerings unavailable | Retry/restore screen; never false-unlock |
| RevenueCat entitlement lookup offline | Honor SDK-cached active entitlement when available |
