# Testing strategy

## Unit tests

Unit tests cover deterministic behavior:

- launch-state routing;
- onboarding validation and optional name handling;
- speech-to-text media-type, byte-limit, response-sanitization, and
  empty-speech contracts, plus streamed-versus-upload and on-device fallback
  selection;
- word-by-word speech grading that ignores case, punctuation and stress marks,
  treats everyday spelling variants (pwede/puwede, rin/din, ho/po) as the same
  word, matches digits with native and Spanish-derived number words, forgives a
  dropped sentence-final enclitic, and allows one vowel slip in a phrase of
  three or more words;
- scheduler intervals, mastery updates, and four-day authored-review persistence
  across repository recreation;
- generated-review progress hydration from the persisted Supabase projection;
- cold-listen autoplay default and an explicit natural-speed Play control;
- Hear & Respond rounds replacing the Decode middle stage in the 5/7/10/15
  minute plans, including local correct/wrong feedback, option audio, and
  progression into the existing Speak recorder;
- time-budget-to-round-count mapping, distinct authored rounds, and full
  multi-round lesson progression;
- search that ignores case and stress marks;
- profile persistence;
- purchase loading, success, cancellation, pending, failure, and restore;
- DTO decoding and repository idempotency;
- adaptive profile mapping and generated-lesson response rejection;
- bounded difficulty and one-step audio-pace adjustment;
- durable adaptive outbox persistence, stable event IDs, capacity, user
  separation, generated vocabulary review mapping, and authored fallback;
- analytics redaction rules.

Swift Testing is used for app/domain units. Test clocks and deterministic UUID
generators should replace real time and randomness in scheduling tests.

## UI tests

Use launch arguments for dependency fixtures:

```text
-UITestScenario firstLaunch
-UITestScenario returningFreeUser
-UITestScenario subscribedUser
-UITestScenario offlineWithPendingSync
-UITestScenario purchasePending
```

Required journeys:

1. Fresh install through demo and paywall.
2. Restore an active purchase.
3. Complete Today’s lesson.
4. Rate all three Practice outcomes.
5. Search and open a Word.
6. Change goal, level and daily time in Profile.
7. In a lesson’s Speak step, record the phrase, verify “Checking your
   Tagalog…” and then word-by-word feedback (“Nailed it. Tuko heard the full
   phrase.” on a clean take). Repeat with one deliberately missing word.
8. Verify the first lesson explains that Listen, Decode or Hear & Respond, and
   Speak form one complete short lesson. On a Hear & Respond round, verify the
   prompt is hidden until submission, the correct/wrong bundled cue plays,
   answer audio remains available, and the next action opens the existing Speak
   recorder. Speak must explicitly ask the learner to repeat the displayed line
   rather than answer it.

The speaking check must never label its result a pronunciation, native, or
fluency score. Test provider failure and airplane mode: the learner can retry
or finish without feedback, and the temporary file is removed on exit.
For an exact word match with different punctuation or capitalization, verify a
perfect match with zero corrections. Do the same for a match differing only by
an accepted spelling variant. Grading is on-device; no language model is
called.

## Accessibility matrix

Test the critical journeys with:

- VoiceOver
- Accessibility 3 and the largest practical Dynamic Type size
- Reduce Motion
- Increase Contrast
- Button Shapes
- Bold Text
- audio unavailable

Capture baseline screenshots at a standard iPhone width and the smallest
supported iPhone width. The rating labels and intervals are a permanent visual
regression target because previous concepts rendered them too small.

## Backend tests

Run RLS checks with two signed-in users and an anonymous/unauthenticated client.
Verify cross-user reads and writes fail, review updates/deletes fail, analytics
cannot be selected, and service-only tables expose no client policies. Re-run
Supabase security and performance advisors after every migration.

Adaptive database tests must additionally verify:

- only `service_role` can execute user/project quota, generation lease/batch,
  difficulty-feedback, and generated vocabulary-review RPCs;
- one leased generation job per user, stale-lease recovery/supersession, and
  idempotency by client request UUID;
- feedback/review idempotency by client event UUID, including concurrent replay;
- ownership rejection for cross-user generated lesson IDs;
- rejection of arbitrary generated-vocabulary UUIDs and acceptance of only IDs
  deterministically presented for the owned lesson;
- transaction rollback if any generated lesson or queue insert fails;
- composite ownership FK rejection for mismatched service-role tenant IDs;
- bounded challenge, estimated level, speech-speed transitions, mastery, and
  due intervals;
- generation, adaptive mutation, TTS minute/daily, and project TTS quota bounds;
- early and streamed oversized provider-body rejection for lesson and audio
  responses;
- ready → started → completed/skipped queue transitions and expired-content
  rejection;
- the lesson model cannot write learner state and clients cannot read
  adaptive tables.

Run the local Edge Function gates from the repository root (also run in CI):

```sh
deno fmt --check supabase/functions && deno lint supabase/functions
deno check supabase/functions/*/index.ts
deno test --allow-env --allow-read supabase/functions
```

`deno.lock` pins the resolved npm dependency graph.

`kumusta-lessons/contract_test.ts` is a contract gate, not a
provider-quality test. It covers ordered chunk containment, vocabulary/example
grounding, and prohibited subjects in addition to schema shape. Run a separate
release sample against the exact model and prompt version, route it through
native Metro Manila Tagalog speaker review, and record acceptance/rejection
rates. Never weaken schema, exact-key, grounding, prohibited-subject,
step-order, response-size, or bounded-text validation to make a model upgrade
pass.

Production smoke tests must cover a warm queue, an empty queue, concurrent
`get_next`, process recreation with pending outbox events, replayed
completion/review event IDs, expired entitlement, user/project rate-limiting,
lease expiry, transactional rollback, provider timeout/oversized or invalid
JSON, and authored fallback on Today, Practice, and Words. Do not include learner
or generated Tagalog text in CI logs or retained test evidence.
