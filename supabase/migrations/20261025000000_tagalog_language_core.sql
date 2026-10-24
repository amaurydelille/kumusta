-- Kumusta teaches one language, Tagalog. This removes VietBuddy's accent axis
-- (Southern/Northern Vietnamese) from every table, function and check, renames
-- the Vietnamese vocabulary columns, and switches levels and goals to the
-- Tagalog app's values. The content tables are empty when this runs; the old
-- Vietnamese authored rows are cleared defensively so the new unique keys hold.

delete from public.kumusta_lessons;
delete from public.kumusta_goal_lessons;
delete from public.kumusta_vocabulary;
delete from public.kumusta_foundation_item_progress;
delete from public.kumusta_foundation_item_variants;
delete from public.kumusta_tts_cache;

-- The reporting view reads live_sessions.accent; rebuild it without it.
drop view if exists public.kumusta_customer_learning_activity;

-- Levels and goals --------------------------------------------------------

update public.kumusta_learning_preferences set
  self_assessed_level = case self_assessed_level
    when 'new' then 'beginner' when 'familiar' then 'intermediate' else 'advanced' end,
  goal = case goal when 'lifeInVietnam' then 'lifeInThePhilippines' else goal end;
update public.kumusta_learner_states set
  self_assessed_level = case self_assessed_level
    when 'new' then 'beginner' when 'familiar' then 'intermediate' else 'advanced' end,
  goal = case goal when 'lifeInVietnam' then 'lifeInThePhilippines' else goal end;

alter table public.kumusta_learning_preferences
  drop constraint kumusta_learning_preferences_voice_accent_check,
  drop constraint kumusta_learning_preferences_accent_check,
  drop constraint kumusta_learning_preferences_goal_check,
  drop constraint kumusta_learning_preferences_self_assessed_level_check,
  drop column accent,
  drop column preferred_voice_id,
  add constraint kumusta_learning_preferences_goal_check check (goal in (
    'family', 'lifeInThePhilippines', 'travel', 'partner', 'work', 'culture'
  )),
  add constraint kumusta_learning_preferences_self_assessed_level_check
    check (self_assessed_level in ('beginner', 'intermediate', 'advanced'));

alter table public.kumusta_learner_states
  drop constraint kumusta_learner_states_accent_check,
  drop constraint kumusta_learner_states_goal_check,
  drop constraint kumusta_learner_states_self_assessed_level_check,
  drop column accent,
  add constraint kumusta_learner_states_goal_check check (goal in (
    'family', 'lifeInThePhilippines', 'travel', 'partner', 'work', 'culture'
  )),
  add constraint kumusta_learner_states_self_assessed_level_check
    check (self_assessed_level in ('beginner', 'intermediate', 'advanced'));

-- Roadmap lessons -----------------------------------------------------------

drop index public.kumusta_lessons_published_order_idx;
drop index public.kumusta_lessons_roadmap_accent_order_idx;
drop index public.kumusta_lessons_roadmap_fetch_idx;
alter table public.kumusta_lessons
  drop constraint kumusta_lessons_accent_check,
  drop constraint kumusta_lessons_level_check,
  drop column accent,
  add column goal_tags text[] not null default '{}',
  add constraint kumusta_lessons_level_check
    check (level in ('beginner', 'intermediate', 'advanced')),
  add constraint kumusta_lessons_goal_tags_check check (goal_tags <@ array[
    'family', 'lifeInThePhilippines', 'travel', 'partner', 'work', 'culture'
  ]::text[]);
create index kumusta_lessons_published_order_idx
  on public.kumusta_lessons (level, sort_order) where is_published;
create unique index kumusta_lessons_roadmap_order_idx
  on public.kumusta_lessons (roadmap_version, level, lesson_order)
  where roadmap_version is not null;
create index kumusta_lessons_roadmap_fetch_idx
  on public.kumusta_lessons (roadmap_version, level, unit_order, lesson_order)
  where is_published;

alter table public.kumusta_goal_lessons
  drop constraint kumusta_goal_lessons_curriculum_version_goal_stage_accent_le_ke,
  drop constraint kumusta_goal_lessons_accent_check,
  drop constraint kumusta_goal_lessons_goal_check,
  drop column accent,
  add constraint kumusta_goal_lessons_goal_check check (goal in (
    'lifeInThePhilippines', 'family', 'partner', 'travel'
  )),
  add constraint kumusta_goal_lessons_curriculum_version_goal_stage_lesson_key
    unique (curriculum_version, goal, stage, lesson_order);

-- Generated lessons, live practice and TTS ------------------------------------

alter table public.kumusta_generated_lessons
  drop constraint kumusta_generated_lessons_accent_check,
  drop column accent;
alter table public.kumusta_live_rounds
  drop constraint kumusta_live_rounds_accent_check,
  drop column accent;
alter table public.kumusta_live_sessions
  drop constraint kumusta_live_sessions_accent_check,
  drop column accent;
alter table public.kumusta_tts_cache
  drop constraint kumusta_tts_cache_accent_check,
  drop column accent;

-- Vocabulary ------------------------------------------------------------------

drop index public.kumusta_vocabulary_published_accent_idx;
drop index public.kumusta_vocabulary_accent_vietnamese_key;
alter table public.kumusta_vocabulary
  drop constraint kumusta_vocabulary_accent_check,
  drop column accent;
alter table public.kumusta_vocabulary rename column vietnamese to tagalog;
alter table public.kumusta_vocabulary rename column usage_example_vi to usage_example_tl;
alter table public.kumusta_vocabulary
  rename constraint kumusta_vocabulary_vietnamese_check to kumusta_vocabulary_tagalog_check;
alter table public.kumusta_vocabulary
  rename constraint kumusta_vocabulary_usage_example_vi_check
  to kumusta_vocabulary_usage_example_tl_check;
alter table public.kumusta_vocabulary
  add constraint kumusta_vocabulary_tagalog_key unique (tagalog);
create index kumusta_vocabulary_published_idx
  on public.kumusta_vocabulary (tagalog) where is_published;

-- Foundation basics (unused by the app today; kept schema-ready) ---------------

alter table public.kumusta_foundation_item_progress
  drop constraint kumusta_foundation_item_progress_pkey,
  drop constraint kumusta_foundation_item_progress_accent_check,
  drop column accent,
  add constraint kumusta_foundation_item_progress_pkey primary key (user_id, item_id);
drop index public.kumusta_foundation_variants_item_accent_idx;
alter table public.kumusta_foundation_item_variants
  drop constraint kumusta_foundation_item_variants_item_id_accent_key,
  drop constraint kumusta_foundation_item_variants_accent_check,
  drop column accent,
  add constraint kumusta_foundation_item_variants_item_id_key unique (item_id);
alter table public.kumusta_foundation_items
  drop constraint kumusta_foundation_items_kind_check,
  add constraint kumusta_foundation_items_kind_check
    check (kind in ('sound_map', 'relationship', 'numbers'));
alter table public.kumusta_foundation_units
  drop constraint kumusta_foundation_units_kind_check,
  add constraint kumusta_foundation_units_kind_check
    check (kind in ('sound_map', 'relationship', 'numbers'));

-- Functions -------------------------------------------------------------------

drop function public.kumusta_claim_tts_cache(
  text, text, text, text, text, text, text, text, text, uuid
);
create function public.kumusta_claim_tts_cache(
  p_cache_key text,
  p_text_value text,
  p_speed text,
  p_voice_id text,
  p_model_id text,
  p_output_format text,
  p_settings_version text,
  p_object_path text,
  p_generation_token uuid
) returns table (should_generate boolean, status text, object_path text)
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_status text;
  v_object_path text;
  v_generation_started_at timestamptz;
begin
  -- The voice is configured server-side (one Tagalog voice), so any
  -- well-formed ElevenLabs voice ID is accepted here.
  if p_cache_key is null
     or p_cache_key !~ '^[0-9a-f]{64}$'
     or p_text_value is null
     or char_length(p_text_value) not between 1 and 500
     or p_speed not in ('slow', 'natural', 'fast')
     or p_voice_id is null or p_voice_id !~ '^[A-Za-z0-9]{16,40}$'
     or p_model_id is null or char_length(p_model_id) not between 1 and 120
     or p_output_format is null or char_length(p_output_format) not between 1 and 80
     or p_settings_version is null or char_length(p_settings_version) not between 1 and 80
     or p_object_path is null or p_object_path !~ '^v[12]/[0-9a-f]{64}\.mp3$'
     or p_generation_token is null
  then
    raise exception using errcode = '22023', message = 'invalid TTS cache claim';
  end if;

  insert into public.kumusta_tts_cache (
    cache_key, text_value, speed, voice_id, model_id,
    output_format, settings_version, object_path, status,
    generation_token, generation_started_at, updated_at
  ) values (
    p_cache_key, p_text_value, p_speed, p_voice_id, p_model_id,
    p_output_format, p_settings_version, p_object_path, 'generating',
    p_generation_token, v_now, v_now
  )
  on conflict (cache_key) do nothing;

  select c.status, c.object_path, c.generation_started_at
  into v_status, v_object_path, v_generation_started_at
  from public.kumusta_tts_cache c
  where c.cache_key = p_cache_key
  for update;

  if v_status = 'ready' then
    return query select false, v_status, v_object_path;
    return;
  end if;

  if v_status = 'generating'
     and v_generation_started_at is not null
     and v_generation_started_at > v_now - interval '10 seconds'
  then
    return query select false, v_status, v_object_path;
    return;
  end if;

  update public.kumusta_tts_cache
  set status = 'generating', generation_token = p_generation_token,
      generation_started_at = v_now, updated_at = v_now
  where cache_key = p_cache_key;

  return query select true, 'generating'::text, v_object_path;
end;
$$;

drop function public.kumusta_persist_generated_lesson_batch(uuid, uuid, text, text, jsonb);
create function public.kumusta_persist_generated_lesson_batch(
  p_user_id uuid,
  p_job_id uuid,
  p_model text,
  p_lessons jsonb
) returns integer
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $$
declare
  v_lesson jsonb;
  v_generated_id uuid;
  v_inserted integer := 0;
begin
  if p_user_id is null or p_job_id is null
     or char_length(p_model) not between 1 and 120
     or jsonb_typeof(p_lessons) <> 'array'
     or jsonb_array_length(p_lessons) not between 1 and 3
     or octet_length(p_lessons::text) > 262144
  then
    raise exception using errcode = '22023', message = 'invalid generated lesson batch';
  end if;

  perform 1 from public.kumusta_lesson_generation_jobs
  where id = p_job_id and user_id = p_user_id and status = 'generating'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'active generation job not found';
  end if;

  for v_lesson in select value from jsonb_array_elements(p_lessons)
  loop
    if jsonb_typeof(v_lesson) <> 'object'
       or jsonb_typeof(v_lesson->'content') <> 'object'
       or jsonb_typeof(v_lesson->'validation') <> 'object'
    then
      raise exception using errcode = '22023', message = 'invalid generated lesson row';
    end if;
    v_generated_id := null;
    insert into public.kumusta_generated_lessons (
      user_id, generation_job_id, schema_version, prompt_version, model,
      difficulty, scenario_key, title, content, content_hash,
      status, quality_score, validation
    ) values (
      p_user_id,
      p_job_id,
      (v_lesson->>'schema_version')::integer,
      (v_lesson->>'prompt_version')::integer,
      p_model,
      (v_lesson->>'difficulty')::numeric,
      v_lesson->>'scenario_key',
      v_lesson->>'title',
      v_lesson->'content',
      v_lesson->>'content_hash',
      'ready',
      (v_lesson->>'quality_score')::numeric,
      v_lesson->'validation'
    )
    on conflict (user_id, content_hash) do nothing
    returning id into v_generated_id;

    if v_generated_id is not null then
      insert into public.kumusta_user_lesson_queue (
        user_id, generated_lesson_id, status
      ) values (p_user_id, v_generated_id, 'ready');
      v_inserted := v_inserted + 1;
    end if;
  end loop;

  if v_inserted > 0 then
    update public.kumusta_learner_states
    set last_generated_at = clock_timestamp()
    where user_id = p_user_id;
  end if;
  return v_inserted;
end;
$$;

CREATE OR REPLACE FUNCTION public.kumusta_validate_analytics_event() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $_$
declare
  v_allowed_keys constant text[] := array[
    'active_seconds', 'answer_id', 'app_build', 'app_version',
    'assistant_fragments', 'attempt', 'audio_duration_ms', 'autoplay',
    'availability', 'card_id', 'card_index', 'cards_answered',
    'cards_presented', 'catalog_count', 'category', 'choice_id',
    'client_session_id', 'content_kind', 'correct_count',
    'daily_limit_seconds', 'daily_minutes', 'difficulty_feedback',
    'end_reason', 'entitlement_found', 'entry_point', 'error_category',
    'feedback_requested', 'goal', 'got_it_count', 'has_topic_preference',
    'hint_revealed', 'hint_visible', 'is_correct', 'is_first_attempt',
    'is_replay', 'lesson_id', 'level', 'live_engine', 'matched_target', 'mode', 'muted',
    'offering', 'onboarding_flow_version', 'package_id', 'pace_feedback', 'personality',
    'platform',
    'playback_result', 'playback_source', 'playback_speed', 'position',
    'question_id', 'question_index',
    'recording_duration_ms', 'remaining_seconds', 'replay_count',
    'response_ms', 'reveal_type', 'round_count', 'score', 'screen_name',
    'skipped_reason', 'source', 'source_lesson_id', 'start_error', 'started', 'step',
    'step_count', 'step_id', 'step_index', 'step_kind', 'text_kind',
    'total_cards', 'user_fragments', 'value', 'vocabulary_id'
  ];
  v_key text;
  v_value text;
begin
  if new.event_name not in (
    'app_opened', 'screen_viewed', 'tab_selected',
    'account_action_started', 'account_action_completed', 'account_action_failed',
    'profile_updated', 'setting_changed', 'feature_action',
    'paywall_dismissed', 'purchase_started', 'purchase_cancelled',
    'restore_started', 'restore_failed',
    'onboarding_started', 'onboarding_step_viewed', 'onboarding_option_selected',
    'onboarding_step_completed', 'onboarding_abandoned', 'onboarding_completed',
    'onboarding_save_failed',
    'value_demo_completed',
    'paywall_viewed', 'trial_started', 'purchase_completed', 'purchase_failed',
    'restore_completed',
    'lesson_started', 'lesson_opened', 'lesson_step_viewed', 'lesson_step_completed',
    'lesson_audio_played', 'lesson_phrase_revealed', 'lesson_answer_submitted',
    'lesson_recording_started', 'lesson_recording_completed',
    'lesson_pronunciation_evaluated', 'lesson_speaking_skipped',
    'lesson_vocabulary_opened', 'lesson_vocabulary_saved',
    'lesson_exercises_completed', 'lesson_abandoned', 'lesson_completed',
    'session_feedback_submitted',
    'practice_opened', 'practice_mode_selected',
    'flashcard_session_started', 'flashcard_presented', 'flashcard_answered',
    'flashcard_audio_played', 'flashcard_session_abandoned',
    'flashcard_session_completed',
    'vocabulary_opened', 'vocabulary_saved', 'vocabulary_removed',
    'vocabulary_audio_played',
    'review_session_started', 'review_session_abandoned', 'review_session_completed',
    'app_review_prompt_shown', 'app_review_requested', 'app_review_prompt_dismissed',
    'review_rated',
    'live_practice_opened', 'live_practice_start_requested', 'live_practice_started',
    'live_practice_start_failed', 'live_practice_mute_changed', 'live_practice_ended',
    'lesson_history_opened', 'lesson_history_audio_played'
  ) then
    raise exception 'unsupported analytics event';
  end if;

  if new.occurred_at < now() - interval '7 days'
     or new.occurred_at > now() + interval '5 minutes'
  then
    raise exception 'analytics timestamp outside accepted window';
  end if;

  for v_key, v_value in
    select key, value #>> '{}'
    from jsonb_each(new.properties)
  loop
    if not (v_key = any(v_allowed_keys))
       or jsonb_typeof(new.properties -> v_key) <> 'string'
       or char_length(v_value) > 100
    then
      raise exception 'unsupported analytics property';
    end if;
  end loop;

  if new.event_name = 'onboarding_completed' and (
    new.properties ->> 'goal' not in (
      'family', 'lifeInThePhilippines', 'travel', 'partner', 'work', 'culture'
    )
    or new.properties ->> 'level' not in ('beginner', 'intermediate', 'advanced')
    -- The onboarding offers 5/7/10/15 minutes; 3 is kept for older builds.
    or new.properties ->> 'daily_minutes' not in ('3', '5', '7', '10', '15')
  ) then
    raise exception 'invalid onboarding analytics values';
  end if;

  if new.event_name = 'value_demo_completed'
     and new.properties ->> 'attempt' <> 'completed'
  then
    raise exception 'invalid demo analytics values';
  end if;

  if new.event_name = 'restore_completed'
     and new.properties ->> 'entitlement_found' not in ('true', 'false')
  then
    raise exception 'invalid restore analytics values';
  end if;

  if new.event_name in ('purchase_completed', 'purchase_failed')
     and exists (
       select 1
       from jsonb_each_text(new.properties) property
       where property.key not in ('app_version', 'app_build', 'onboarding_flow_version')
         and property.value !~ '^[A-Za-z0-9._$:-]{1,100}$'
     )
  then
    raise exception 'invalid purchase analytics value';
  end if;

  return new;
end;
$_$;


-- Reporting view, as before minus the accent detail.
create view public.kumusta_customer_learning_activity with (security_invoker = true) as
select
  sessions.user_id,
  case
    when sessions.content_id is not null then 'lesson'::text
    when sessions.session_kind = 'practice'::text then 'review'::text
    else sessions.session_kind
  end as activity_type,
  sessions.content_id,
  sessions.content_kind,
  sessions.client_session_id,
  sessions.started_at,
  sessions.ended_at,
  sessions.completed,
  sessions.active_seconds,
  sessions.score,
  jsonb_build_object(
    'session_kind', sessions.session_kind,
    'entry_point', sessions.entry_point,
    'is_replay', sessions.is_replay
  ) as details
from public.kumusta_learning_sessions sessions
union all
select
  flashcards.user_id,
  'flashcards'::text as activity_type,
  null::uuid as content_id,
  'vocabulary'::text as content_kind,
  flashcards.client_session_id,
  flashcards.started_at,
  flashcards.ended_at,
  flashcards.completed,
  flashcards.active_seconds,
  flashcards.score,
  jsonb_build_object(
    'total_cards', flashcards.total_cards,
    'cards_presented', flashcards.cards_presented,
    'cards_answered', flashcards.cards_answered,
    'correct_count', flashcards.correct_count
  ) as details
from public.kumusta_flashcard_sessions flashcards
union all
select
  live.user_id,
  'realtime_conversation'::text as activity_type,
  live.latest_lesson_id as content_id,
  case
    when live.latest_lesson_id is null then 'unspecified'::text
    else 'lesson_context'::text
  end as content_kind,
  coalesce(live.client_session_id, live.id) as client_session_id,
  min(live.created_at) as started_at,
  max(live.ended_at) as ended_at,
  bool_and(live.ended_at is not null) as completed,
  sum(live.charged_seconds)::integer as active_seconds,
  null::numeric as score,
  jsonb_build_object(
    'topic_source', max(live.topic_source),
    'end_reason', max(live.end_reason),
    'user_fragments', sum(live.user_fragments),
    'assistant_fragments', sum(live.assistant_fragments),
    'mute_count', sum(live.mute_count),
    'usage_confirmed', bool_and(live.usage_confirmed),
    'relay_segment_count', count(*)
  ) as details
from public.kumusta_live_sessions live
group by live.user_id, live.latest_lesson_id, coalesce(live.client_session_id, live.id);

comment on view public.kumusta_customer_learning_activity is
  'Service-role reporting view with one normalized row per customer learning activity.';

-- Privileges: the recreated functions and view are service-role only.
revoke all on public.kumusta_customer_learning_activity from public, anon, authenticated;
grant select on public.kumusta_customer_learning_activity to service_role;
revoke all on function public.kumusta_claim_tts_cache(
  text, text, text, text, text, text, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.kumusta_claim_tts_cache(
  text, text, text, text, text, text, text, text, uuid
) to service_role;
revoke all on function public.kumusta_persist_generated_lesson_batch(uuid, uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.kumusta_persist_generated_lesson_batch(uuid, uuid, text, jsonb)
  to service_role;
revoke all on function public.kumusta_validate_analytics_event() from public, anon, authenticated;
grant execute on function public.kumusta_validate_analytics_event() to service_role;
