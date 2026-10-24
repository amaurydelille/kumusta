# Analytics

## Purpose

Analytics answers whether learners receive value and return. It does not create
surveillance data. Events use enumerated values and anonymous/session
identifiers; names, recordings, transcripts, and arbitrary free text are
prohibited.

## Onboarding funnel

The first-party event stream records the onboarding journey for anonymous and
registered users. Every event includes the stable `install_id`; once an
anonymous learner creates an account, queued events are attributed to that
account UUID by the server. PostHog receives the same events. The name screen
records `value=provided` when submitted; the entered name is saved to the
learner profile and is never included in analytics properties.

```text
onboarding_started
onboarding_step_viewed       (each screen, including revisits)
onboarding_option_selected   (final value submitted for a choice screen)
onboarding_step_completed    (forward navigation only)
lesson_pronunciation_evaluated (first lesson speaking result)
lesson_speaking_skipped       (first lesson speaking skipped)
lesson_answer_submitted       (first lesson meaning choice, no answer text)
onboarding_completed         (only after the profile save succeeds)
onboarding_save_failed
onboarding_abandoned         (app_backgrounded or flow_disappeared)
```

Every onboarding screen emits `onboarding_step_viewed`; forward movement emits
`onboarding_step_completed`. Screen names are `onboarding_<step>`. The current
positions are welcome (0), name (1), accent (2), goal (3), level (4),
daily_plan (5), plan_building (6), and first_lesson (7). The first lesson also emits
`lesson_pronunciation_evaluated` with `matched_target`,
`lesson_speaking_skipped` with a reason, and `lesson_answer_submitted` with a
stable answer ID and correctness. These action events carry
`screen_name=onboarding_first_lesson`, `step=first_lesson`, and
`source=onboarding_mini_lesson_v2`. The meaning choice is never sent as free
text. `onboarding_completed` records the saved profile before the paywall;
`paywall_viewed` and purchase events measure the next funnel stage.
Compare conversion from onboarding start to trial/purchase, not only conversion
among paywall viewers. The name is collected during onboarding;
notification permission is requested only after a completed lesson and an
explicit reminder opt-in.
PostHog events include `app_version`, `app_build`, and
`onboarding_flow_version=mini_lesson_v2` so reports can separate releases and
onboarding flows. In PostHog, build the onboarding funnel from
`onboarding_step_viewed` for every step, filter to
`onboarding_flow_version=mini_lesson_v2`, and add steps in `position` order:
welcome (0), name (1), accent (2), goal (3), level (4), daily_plan (5),
plan_building (6), first_lesson (7). Each funnel step uses the same event with
the matching `step` property value.
These events also fire on back-navigation, so use unique users rather than raw
event totals. With this flow filter, unique users at a later step should never
exceed the preceding step. The `step` and `position` properties provide the
same funnel position in a dashboard-friendly form. An `onboarding_abandoned` event with
`source=app_backgrounded` means the learner left the app while that screen was
visible; it is an exit signal, not proof that the learner never returned.
Define a final bounce as an exit with no `onboarding_completed` within the
chosen observation window (normally 24 hours or 7 days).

Example bounce query:

```sql
with exits as (
  select distinct on (install_id)
    install_id,
    occurred_at as exited_at,
    screen_name,
    properties ->> 'step' as step,
    properties ->> 'source' as exit_source
  from kumusta_analytics_events
  where event_name = 'onboarding_abandoned'
    and install_id is not null
  order by install_id, occurred_at desc
)
select exits.*
from exits
where not exists (
  select 1
  from kumusta_analytics_events completed
  where completed.install_id = exits.install_id
    and completed.event_name = 'onboarding_completed'
    and completed.occurred_at > exits.exited_at
    and completed.occurred_at <= exits.exited_at + interval '7 days'
);
```

## Common event properties

- `event_version`
- `session_id` when the activity has a matching learning-session row
- `client_session_id` for every correlated activity, including flashcards,
  Listen & Learn, and real-time conversation
- anonymous or authenticated user ID
- app version and build
- platform, locale, and timezone
- onboarding schema version
- stable experiment assignments

Lesson events also include `lesson_id`, `content_kind`, `entry_point`, and
`is_replay`. `content_kind` distinguishes authored, goal-curriculum, and
generated lessons without forcing non-catalog lesson UUIDs into the authored
lesson foreign key.

## Learning activity coverage

The first-party Supabase stream and PostHog receive the same validated event
taxonomy. Durable session summaries remain the source of truth for totals;
events explain what happened inside each session.

| Surface | Durable summary | Detailed events |
| --- | --- | --- |
| Today and Practice lessons | `kumusta_learning_sessions` | open/start, every viewed/completed step, audio, reveals, answers, recordings, pronunciation, skips, vocabulary, abandon, exercise completion, lesson completion, feedback |
| Flashcards | `kumusta_flashcard_sessions` and `kumusta_review_events` | session lifecycle, card impression/answer, audio result, source lesson attribution |
| Listen & Learn | `kumusta_conversation_attempts` and answers | catalog/selection, open/start, audio start/replay, transcript reveal, answers, abandon/complete |
| Real-time conversation | `kumusta_live_sessions`, rounds, and transcripts | open/request/start/failure, mute changes, end reason, duration and lesson context |
| Lesson history | existing lesson history | history open and provider/fallback audio result |

Audio properties contain only operational metadata such as source, result,
duration, and playback speed. Recordings and arbitrary text are never added to
analytics properties.

## Customer usage reporting

Two service-role-only views provide a stable reporting boundary:

- `kumusta_customer_learning_activity`: one normalized row for each lesson,
  review, flashcard, Listen & Learn, or real-time conversation session.
- `kumusta_customer_lesson_usage`: customer-by-lesson totals across authored,
  goal-curriculum, and generated lessons, including flashcard answers sourced
  from that lesson, history audio replays, and real-time starts using it as
  conversation context.

Example lesson usage query:

```sql
select
  user_id,
  content_id as lesson_id,
  content_kind,
  session_count,
  completion_count,
  replay_count,
  active_seconds,
  average_score,
  flashcard_answer_count,
  history_audio_play_count,
  realtime_start_count,
  last_started_at
from public.kumusta_customer_lesson_usage
order by last_started_at desc;
```

Example activity mix query:

```sql
select
  user_id,
  activity_type,
  count(*) as sessions,
  count(*) filter (where completed) as completed_sessions,
  sum(active_seconds) as active_seconds
from public.kumusta_customer_learning_activity
where started_at >= now() - interval '30 days'
group by user_id, activity_type;
```

## Business measures

- Demo completion and correct-first-try rate
- Verified entitlement conversion
- First lesson completion within 24 hours
- Day-1 and Day-7 lesson retention
- Review completion and phrase reappearance success
- Purchase error, refund, and trial cancellation rates

Revenue is sourced from RevenueCat lifecycle events, not localized client price
strings.

## Experiment guardrails

Run one material funnel test at a time. Guardrail demo completion, paid
activation, Day-7 retention, refund rate, accessibility completion gap, purchase
errors, and support complaints. Never test fake urgency, hidden monthly plans,
fabricated testimonials, confirm-shaming, or invented crossed-out prices.
