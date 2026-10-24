# Kumusta analytics coverage

Updated 2026-10-08. Every app event goes through `AnalyticsTracking` to PostHog and the owner-scoped Supabase `kumusta_analytics_events` table. The source catalog has 81 events. Run `rtk proxy python3 scripts/check_analytics_catalog.py` from the iOS project to verify client/database catalog parity.

| Experience | Events and context |
| --- | --- |
| Onboarding | `onboarding_started`, `onboarding_step_viewed`, `onboarding_option_selected`, `onboarding_step_completed`, `onboarding_abandoned`, `onboarding_completed`, `onboarding_save_failed`. Steps: welcome, name, accent, goal, level, daily_plan, plan_building, first_lesson, then one step per welcome-lesson screen (see the funnel below). Each carries screen, step and position; choices use enum values, never the learner’s name. |
| Welcome lesson | Level- and accent-specific lesson before the paywall. Every screen emits `onboarding_step_viewed` and `onboarding_step_completed` (with `active_seconds`); answers, speaking and skips are `feature_action` events. All carry `screen_name=onboarding_first_lesson`, `lesson_id`, `level`, `accent`, `mode` and `entry_point=onboarding`. In-app replays and First Steps use `screen_name=first_lesson` and `entry_point=first_steps`, and never emit onboarding events. |
| Account | `screen_viewed` for create, sign-in and confirm-email modes; `account_action_started/completed/failed` for credential submission. Completion means the request succeeded; account creation can still require email confirmation. |
| Paywall | `paywall_viewed` after SDK/offering readiness, `paywall_dismissed` for user dismissal. `offering` identifies default/fallback. Hosted and custom purchases emit started, cancelled, completed and failed; actual trial entitlements emit `trial_started`. Restores emit started/completed/failed, including no-entitlement results. Filter `source=user_initiated` or `hosted_paywall` for user restore funnels; `account_recovery` is automatic access recovery. |
| Main navigation | `screen_viewed` for the visible Today, Practice, Words or Profile tab; `tab_selected` when selection changes. These are tracked by the parent TabView to avoid hidden-tab impressions. |
| Lessons | Open/start, each step viewed/completed, audio, phrase reveal, answers, recording, pronunciation, skipped speaking, vocabulary opened/saved, exercises complete, abandon/complete, feedback. |
| Practice | Mode selection, conversation catalog and selection, start, audio/replay, transcript reveal, question answer, abandon and complete. |
| Live practice | Open, start request, success/failure, mute changes and end. End includes duration/fragment counts and reason, never conversation text. |
| Words | Vocabulary open/save/remove/audio, flashcard start/present/answer/audio/abandon/complete, sort selection. Phrase-detail impressions no longer depend on autoplay being enabled. |
| Context practice | Screen/step viewed and explicit completion, scoped to vocabulary ID. |
| Review | Start, abandon, complete and ratings; app review prompt shown/requested/dismissed. |
| Profile | Profile editor viewed and successful update; playback speed, autoplay, appearance and reminder settings changed. Support/privacy/share and sign-out/delete/erase confirmation actions are explicit feature events. |
| First Steps | Offer viewed/start/skip, cheat sheet viewed and completed, reference audio playback, course/activity/completion screens and course exit. |
| Quick practice | Shadow/speed screens, recording state, listening note toggles and audio playback. |
| History / leaderboard | History open/audio; leaderboard screen viewed and period selection. |
| Subscription cancellation | Warning/reason step viewed, subscription kept, feedback saved/failed. Opening Apple subscription settings is not reported as a completed cancellation. |

## Delivery contract

- Both sinks share event names, bounded string properties, app version/build and iOS platform. Onboarding events also carry `onboarding_flow_version=first_lesson_v2` (`first_conversation_v1` before the welcome lessons).
- Property keys must be in both allowlists (`SupabaseSignedInRepository.validateAnalyticsProperties` and the database validator). One unknown key makes Supabase reject the whole event while PostHog still receives it. Lesson payloads are built in `FirstLessonAnalytics` and covered by a unit test.
- PostHog `client_event_id` matches the Supabase column. PostHog `$screen_name` mirrors the explicit screen name for readable Activity views. `client_session_id` is a property, not a nonexistent Supabase column; resolved owned learning sessions use `session_id`.
- Anonymous onboarding uses the Supabase anonymous user UUID in both services; upgrading an anonymous account retains its identity. Signed-in account restoration identifies the account UUID in PostHog.
- Supabase delivery uses a persisted outbox, one writer at a time, idempotent upserts and retries on later events/app launch. Events older than seven days expire; the queue is bounded to 500 events. Permanent validation failures are dropped and logged. Network/auth failures remain queued and log their category.
- PostHog has its own SDK queue. Both queues flush on app background. The two sinks are independent, so arrival times and provider-generated lifecycle events can differ.
- No passwords, names, emails, audio, transcripts or cancellation free text are added to these event payloads. Existing account identification is separate from events.

## Verification

- Five iOS regression tests pass (three analytics delivery tests and two hosted paywall routing tests). The delivery tests cover hosted paywall metadata, rejected private/oversized properties, session payload column compatibility, persisted queue recovery and a single writer including events enqueued during delivery.
- Swift/SQL contract check passes for 81 event names and 76 allowed property keys.
- Validator migration applied to Supabase project `vpitjvtfzpqfnqgzcpla` on 2026-10-08.
- Development iPhone recovered all 320 queued events; outbox reached zero. Live Supabase receipts included all eight onboarding steps, completed onboarding, five paywall views, lesson and flashcard events, conversations and live practice sessions.
- Supabase received new `screen_viewed` and `tab_selected` events for Today, Practice, Words and Profile with app build and matching event IDs.
- PostHog project 277114 Activity confirmed existing iOS onboarding, lesson, practice and live practice receipts. New custom tab events left the SDK delivery queue; final dashboard receipt confirmation remained pending while the Activity refresh was loading.

## Release note

The client changes require a new app build. The already uploaded TestFlight 1.2.3 (45) does not contain this audit’s changes. Old queued session events recover after upgrading; paywall events already dropped by older validators cannot be reconstructed.

## Onboarding funnel (flow `first_lesson_v2`)

`onboarding_step_viewed.position` is the funnel order, the same for every level:

| Position | `step` | Screen |
| --- | --- | --- |
| 0–6 | welcome, name, accent, goal, level, daily_plan, plan_building | Onboarding questions and plan building |
| 7 | first_lesson | Welcome lesson container |
| 8 | first_lesson_intro | Lesson intro |
| 9–14 | first_lesson_teach, _listen_pick, _meaning_pick, _natural_pick, _new_phrase, _speak, _build, _conversation | The six lesson screens; `step_id` names the exact screen, `level` tells which lesson |
| 15 | first_lesson_completion | Celebration |
| 16 | comparison | “On your own vs With Kumusta”, shown after the lesson whether it was finished or skipped |
| — | `onboarding_completed`, then `paywall_viewed` | Paywall |

A missed question reappears at the end with `is_replay=true` and its original position, so filter `is_replay = 'false'` for drop-off. `onboarding_abandoned` on a lesson screen carries that screen’s `step`, `step_id` and `position`; `source` holds the exit reason. Skipping the lesson from its exit sheet emits `feature_action` with `value=lesson_skipped` and goes straight to the paywall.

Per-screen drop-off by level, from Supabase:

```sql
with views as (
  select coalesce(user_id::text, install_id::text) as learner,
         (properties ->> 'position')::int as position,
         properties ->> 'step' as step,
         coalesce(properties ->> 'level', 'all') as level
  from kumusta_analytics_events
  where event_name = 'onboarding_step_viewed'
    and properties ->> 'onboarding_flow_version' = 'first_lesson_v2'
    and coalesce(properties ->> 'is_replay', 'false') = 'false'
)
select position, step, level, count(distinct learner) as learners,
       round(100.0 * count(distinct learner)
         / first_value(count(distinct learner)) over (partition by level order by position), 1) as pct_of_first
from views
group by position, step, level
order by level, position;
```

Steps before the lesson have no `level` property, so they appear under `all`; join on the learner’s `onboarding_option_selected` (step `level`) to split them. In PostHog, build a funnel on `onboarding_step_viewed` filtered by `step` (or ordered by `position`), breakdown `level`, ending with `paywall_viewed`.
