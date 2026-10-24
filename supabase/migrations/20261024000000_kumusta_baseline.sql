-- Kumusta baseline schema.
--
-- Squashed from VietBuddy's 67 migrations (renamed vietbuddy_ -> kumusta_) and
-- then trimmed for Kumusta: the dialogue / Listening Quest tables, the
-- ElevenLabs-agent live RPCs, the Android platform and the Mistral quota scopes
-- were removed. Generated with `supabase db dump` from a local database.
-- Later schema changes go in new migrations; never edit this file.




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."kumusta_award_xp"("p_user_id" "uuid", "p_reason_code" "text", "p_source_id" "text", "p_idempotency_key" "text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS TABLE("event_id" "uuid", "amount" integer, "lifetime_xp" bigint, "week_xp" bigint, "month_xp" bigint, "was_duplicate" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  v_now timestamptz := clock_timestamp();
  v_reason_code text := pg_catalog.lower(pg_catalog.btrim(p_reason_code));
  v_idempotency_key text := pg_catalog.btrim(p_idempotency_key);
  v_source_id text := case
    when p_source_id is null then null
    else pg_catalog.btrim(p_source_id)
  end;
  v_amount integer;
  v_daily_cap integer;
  v_event_id uuid;
  v_existing_amount integer;
  v_lifetime_xp bigint;
  v_week_xp bigint;
  v_month_xp bigint;
  v_week_key text := pg_catalog.to_char(
    pg_catalog.date_trunc('week', v_now at time zone 'UTC'),
    'YYYY-MM-DD'
  );
  v_month_key text := pg_catalog.to_char(
    pg_catalog.date_trunc('month', v_now at time zone 'UTC'),
    'YYYY-MM'
  );
  v_today_xp bigint;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'XP awards are server-side only';
  end if;

  if p_user_id is null
     or not exists (
       select 1 from auth.users where id = p_user_id
     )
  then
    raise exception using errcode = '22023', message = 'Invalid XP user';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  if v_reason_code is null
     or v_reason_code !~ '^[a-z][a-z0-9_]{2,79}$'
  then
    raise exception using errcode = '22023', message = 'Invalid XP reason code';
  end if;

  if v_idempotency_key is null
     or pg_catalog.char_length(v_idempotency_key) > 200
  then
    raise exception using errcode = '22023', message = 'Invalid XP idempotency key';
  end if;

  if v_source_id is not null and pg_catalog.char_length(v_source_id) > 200 then
    raise exception using errcode = '22023', message = 'Invalid XP source ID';
  end if;

  if p_metadata is null
     or pg_catalog.jsonb_typeof(p_metadata) <> 'object'
     or pg_catalog.octet_length(p_metadata::text) > 8000
  then
    raise exception using errcode = '22023', message = 'Invalid XP metadata';
  end if;

  select event_row.id, event_row.amount
    into v_event_id, v_existing_amount
  from public.kumusta_xp_events as event_row
  where event_row.user_id = p_user_id
    and event_row.idempotency_key = v_idempotency_key;

  if found then
    select totals.lifetime_xp
      into v_lifetime_xp
    from public.kumusta_user_xp_totals as totals
    where totals.user_id = p_user_id;

    select coalesce(period.xp, 0)
      into v_week_xp
    from public.kumusta_xp_period_totals as period
    where period.user_id = p_user_id
      and period.period_kind = 'weekly'
      and period.period_key = v_week_key;

    select coalesce(period.xp, 0)
      into v_month_xp
    from public.kumusta_xp_period_totals as period
    where period.user_id = p_user_id
      and period.period_kind = 'monthly'
      and period.period_key = v_month_key;

    return query select
      v_event_id,
      v_existing_amount,
      coalesce(v_lifetime_xp, 0),
      coalesce(v_week_xp, 0),
      coalesce(v_month_xp, 0),
      true;
    return;
  end if;

  select rules.xp_amount, rules.daily_cap
    into v_amount, v_daily_cap
  from public.kumusta_xp_rules as rules
  where rules.code = v_reason_code
    and rules.is_active
    and rules.effective_from <= v_now
    and (rules.effective_until is null or rules.effective_until > v_now);

  if not found then
    raise exception using errcode = '22023', message = 'XP reason is not configured';
  end if;

  if v_daily_cap is not null then
    select coalesce(sum(event_row.amount), 0)
      into v_today_xp
    from public.kumusta_xp_events as event_row
    where event_row.user_id = p_user_id
      and event_row.occurred_at >= pg_catalog.date_trunc('day', v_now at time zone 'UTC') at time zone 'UTC'
      and event_row.occurred_at < (pg_catalog.date_trunc('day', v_now at time zone 'UTC') + interval '1 day') at time zone 'UTC';

    if v_today_xp + v_amount > v_daily_cap then
      raise exception using errcode = '22003', message = 'Daily XP cap reached';
    end if;
  end if;

  insert into public.kumusta_xp_events (
    user_id,
    amount,
    reason_code,
    source_id,
    idempotency_key,
    metadata,
    occurred_at
  )
  values (
    p_user_id,
    v_amount,
    v_reason_code,
    v_source_id,
    v_idempotency_key,
    p_metadata,
    v_now
  )
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    select event_row.id, event_row.amount
      into v_event_id, v_existing_amount
    from public.kumusta_xp_events as event_row
    where event_row.user_id = p_user_id
      and event_row.idempotency_key = v_idempotency_key;

    select totals.lifetime_xp
      into v_lifetime_xp
    from public.kumusta_user_xp_totals as totals
    where totals.user_id = p_user_id;

    select coalesce(period.xp, 0)
      into v_week_xp
    from public.kumusta_xp_period_totals as period
    where period.user_id = p_user_id
      and period.period_kind = 'weekly'
      and period.period_key = v_week_key;

    select coalesce(period.xp, 0)
      into v_month_xp
    from public.kumusta_xp_period_totals as period
    where period.user_id = p_user_id
      and period.period_kind = 'monthly'
      and period.period_key = v_month_key;

    return query select
      v_event_id,
      v_existing_amount,
      coalesce(v_lifetime_xp, 0),
      coalesce(v_week_xp, 0),
      coalesce(v_month_xp, 0),
      true;
    return;
  end if;

  insert into public.kumusta_user_xp_totals (user_id, lifetime_xp)
  values (p_user_id, v_amount)
  on conflict (user_id) do update
    set lifetime_xp = public.kumusta_user_xp_totals.lifetime_xp + excluded.lifetime_xp,
        updated_at = v_now
  returning public.kumusta_user_xp_totals.lifetime_xp into v_lifetime_xp;

  insert into public.kumusta_xp_period_totals (user_id, period_kind, period_key, xp)
  values (p_user_id, 'all_time', 'all_time', v_amount)
  on conflict (user_id, period_kind, period_key) do update
    set xp = public.kumusta_xp_period_totals.xp + excluded.xp,
        updated_at = v_now;

  insert into public.kumusta_xp_period_totals (user_id, period_kind, period_key, xp)
  values (p_user_id, 'weekly', v_week_key, v_amount)
  on conflict (user_id, period_kind, period_key) do update
    set xp = public.kumusta_xp_period_totals.xp + excluded.xp,
        updated_at = v_now;

  insert into public.kumusta_xp_period_totals (user_id, period_kind, period_key, xp)
  values (p_user_id, 'monthly', v_month_key, v_amount)
  on conflict (user_id, period_kind, period_key) do update
    set xp = public.kumusta_xp_period_totals.xp + excluded.xp,
        updated_at = v_now;

  select period.xp
    into v_week_xp
  from public.kumusta_xp_period_totals as period
  where period.user_id = p_user_id
    and period.period_kind = 'weekly'
    and period.period_key = v_week_key;

  select period.xp
    into v_month_xp
  from public.kumusta_xp_period_totals as period
  where period.user_id = p_user_id
    and period.period_kind = 'monthly'
    and period.period_key = v_month_key;

  return query select
    v_event_id,
    v_amount,
    v_lifetime_xp,
    coalesce(v_week_xp, 0),
    coalesce(v_month_xp, 0),
    false;
end;
$_$;


ALTER FUNCTION "public"."kumusta_award_xp"("p_user_id" "uuid", "p_reason_code" "text", "p_source_id" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."kumusta_award_xp"("p_user_id" "uuid", "p_reason_code" "text", "p_source_id" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") IS 'Atomically awards configured XP, records an idempotent ledger event, updates totals, and returns the new summary. Service-role only.';



CREATE OR REPLACE FUNCTION "public"."kumusta_begin_lesson_generation_job"("p_user_id" "uuid", "p_client_request_id" "uuid", "p_trigger" "text", "p_requested_count" integer, "p_learner_snapshot" "jsonb", "p_prompt_version" integer, "p_lease_seconds" integer) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_now timestamptz := clock_timestamp();
  v_job_id uuid;
begin
  if p_user_id is null or p_client_request_id is null
     or p_trigger not in ('initial', 'queue_low', 'lesson_completed', 'manual_refresh')
     or p_requested_count not between 1 and 3
     or jsonb_typeof(p_learner_snapshot) <> 'object'
     or octet_length(p_learner_snapshot::text) > 16384
     or p_prompt_version is null or p_prompt_version < 1
     or p_lease_seconds not between 60 and 600
  then
    raise exception using errcode = '22023', message = 'invalid generation lease';
  end if;

  perform 1 from public.kumusta_learner_states
  where user_id = p_user_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'learner state not found';
  end if;

  update public.kumusta_lesson_generation_jobs
  set
    trigger = p_trigger,
    status = 'generating',
    requested_count = p_requested_count,
    learner_snapshot = p_learner_snapshot,
    prompt_version = p_prompt_version,
    attempt_count = 0,
    error_code = null,
    model = null,
    started_at = v_now,
    finished_at = null
  where user_id = p_user_id
    and client_request_id = p_client_request_id
    and status in ('queued', 'generating')
    and coalesce(started_at, created_at) <=
      v_now - make_interval(secs => p_lease_seconds)
  returning id into v_job_id;
  if v_job_id is not null then
    return v_job_id;
  end if;

  update public.kumusta_lesson_generation_jobs
  set
    status = 'superseded',
    error_code = 'stale_generation_lease',
    finished_at = v_now
  where user_id = p_user_id
    and status in ('queued', 'generating')
    and coalesce(started_at, created_at) <=
      v_now - make_interval(secs => p_lease_seconds);

  insert into public.kumusta_lesson_generation_jobs (
    user_id, client_request_id, trigger, status, requested_count,
    learner_snapshot, prompt_version, started_at
  ) values (
    p_user_id, p_client_request_id, p_trigger, 'generating',
    p_requested_count, p_learner_snapshot, p_prompt_version, v_now
  )
  on conflict do nothing
  returning id into v_job_id;

  return v_job_id;
end;
$$;


ALTER FUNCTION "public"."kumusta_begin_lesson_generation_job"("p_user_id" "uuid", "p_client_request_id" "uuid", "p_trigger" "text", "p_requested_count" integer, "p_learner_snapshot" "jsonb", "p_prompt_version" integer, "p_lease_seconds" integer) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."kumusta_email_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "email_type" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "next_attempt_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "locked_at" timestamp with time zone,
    "provider_message_id" "text",
    "last_error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sent_at" timestamp with time zone,
    CONSTRAINT "kumusta_email_jobs_attempts_check" CHECK (("attempts" >= 0)),
    CONSTRAINT "kumusta_email_jobs_email_type_check" CHECK (("email_type" = ANY (ARRAY['subscription_welcome'::"text", 'subscription_cancellation_feedback'::"text", 'subscription_refund'::"text"]))),
    CONSTRAINT "kumusta_email_jobs_last_error_check" CHECK ((("last_error" IS NULL) OR ("char_length"("last_error") <= 2000))),
    CONSTRAINT "kumusta_email_jobs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sending'::"text", 'sent'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."kumusta_email_jobs" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_email_jobs" IS 'Service-only transactional email outbox. RevenueCat events enqueue at most one job per email type.';



CREATE OR REPLACE FUNCTION "public"."kumusta_claim_email_jobs"("p_limit" integer DEFAULT 10) RETURNS SETOF "public"."kumusta_email_jobs"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'Email jobs are server-side only';
  end if;

  return query
  with candidates as (
    select id
    from public.kumusta_email_jobs
    where (
      (status = 'pending' and next_attempt_at <= clock_timestamp())
      or (
        status = 'sending'
        and locked_at is not null
        and locked_at < clock_timestamp() - interval '10 minutes'
      )
    )
    order by created_at asc
    limit greatest(1, least(coalesce(p_limit, 10), 50))
    for update skip locked
  )
  update public.kumusta_email_jobs as jobs
  set status = 'sending',
      attempts = jobs.attempts + 1,
      locked_at = clock_timestamp(),
      updated_at = clock_timestamp()
  from candidates
  where jobs.id = candidates.id
  returning jobs.*;
end;
$$;


ALTER FUNCTION "public"."kumusta_claim_email_jobs"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_claim_tts_cache"("p_cache_key" "text", "p_text_value" "text", "p_accent" "text", "p_speed" "text", "p_voice_id" "text", "p_model_id" "text", "p_output_format" "text", "p_settings_version" "text", "p_object_path" "text", "p_generation_token" "uuid") RETURNS TABLE("should_generate" boolean, "status" "text", "object_path" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $_$
declare
  v_now timestamptz := clock_timestamp();
  v_status text;
  v_object_path text;
  v_generation_started_at timestamptz;
begin
  if p_cache_key is null
     or p_cache_key !~ '^[0-9a-f]{64}$'
     or p_text_value is null
     or char_length(p_text_value) not between 1 and 500
     or p_accent not in ('southern', 'northern')
     or p_speed not in ('slow', 'natural', 'fast')
     or p_voice_id not in (
       '6Xq32rHt6oAu98TBDKfr',
       'LD1UihCXvSlUL4h8DOmk'
     )
     or p_model_id is null or char_length(p_model_id) not between 1 and 120
     or p_output_format is null or char_length(p_output_format) not between 1 and 80
     or p_settings_version is null or char_length(p_settings_version) not between 1 and 80
     or p_object_path is null or p_object_path !~ '^v[12]/[0-9a-f]{64}\.mp3$'
     or p_generation_token is null
  then
    raise exception using errcode = '22023', message = 'invalid TTS cache claim';
  end if;

  insert into public.kumusta_tts_cache (
    cache_key, text_value, accent, speed, voice_id, model_id,
    output_format, settings_version, object_path, status,
    generation_token, generation_started_at, updated_at
  ) values (
    p_cache_key, p_text_value, p_accent, p_speed, p_voice_id, p_model_id,
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
$_$;


ALTER FUNCTION "public"."kumusta_claim_tts_cache"("p_cache_key" "text", "p_text_value" "text", "p_accent" "text", "p_speed" "text", "p_voice_id" "text", "p_model_id" "text", "p_output_format" "text", "p_settings_version" "text", "p_object_path" "text", "p_generation_token" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_complete_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid", "p_byte_size" bigint) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $_$
begin
  if p_cache_key is null
     or p_cache_key !~ '^[0-9a-f]{64}$'
     or p_generation_token is null
     or p_byte_size is null
     or p_byte_size not between 129 and 3000000
  then
    return false;
  end if;

  update public.kumusta_tts_cache
  set
    status = 'ready',
    generation_token = null,
    generation_started_at = null,
    byte_size = p_byte_size,
    updated_at = clock_timestamp()
  where cache_key = p_cache_key
    and status = 'generating'
    and generation_token = p_generation_token;

  return found;
end;
$_$;


ALTER FUNCTION "public"."kumusta_complete_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid", "p_byte_size" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_consume_api_quota"("p_user_id" "uuid", "p_scope" "text", "p_limit" integer, "p_window_seconds" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_now timestamptz := clock_timestamp();
  v_request_count integer;
begin
  if p_user_id is null
     or p_scope is null
     or p_scope not in (
       'elevenlabs_tts', 'elevenlabs_tts_daily',
       'elevenlabs_stt', 'elevenlabs_stt_daily',
       'lessons', 'lessons_daily', 'lessons_mutation', 'lessons_mutation_daily',
       'revenuecat_sync'
     )
     or p_limit is null or p_limit < 1 or p_limit > 10000000
     or p_window_seconds is null or p_window_seconds < 1 or p_window_seconds > 86400
     or not exists (select 1 from auth.users where id = p_user_id)
  then
    return false;
  end if;

  insert into public.kumusta_api_rate_limits (
    user_id, scope, window_started_at, request_count, updated_at
  ) values (p_user_id, p_scope, v_now, 1, v_now)
  on conflict (user_id, scope) do update
  set
    window_started_at = case
      when kumusta_api_rate_limits.window_started_at <= v_now - make_interval(secs => p_window_seconds)
      then v_now else kumusta_api_rate_limits.window_started_at end,
    request_count = case
      when kumusta_api_rate_limits.window_started_at <= v_now - make_interval(secs => p_window_seconds)
      then 1 else kumusta_api_rate_limits.request_count + 1 end,
    updated_at = v_now
  returning request_count into v_request_count;

  return v_request_count <= p_limit;
exception when others then
  return false;
end;
$$;


ALTER FUNCTION "public"."kumusta_consume_api_quota"("p_user_id" "uuid", "p_scope" "text", "p_limit" integer, "p_window_seconds" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."kumusta_consume_api_quota"("p_user_id" "uuid", "p_scope" "text", "p_limit" integer, "p_window_seconds" integer) IS 'Atomically consumes a fixed-window provider quota. Service-role only; invalid input or accounting errors fail closed.';



CREATE OR REPLACE FUNCTION "public"."kumusta_consume_project_api_quota"("p_scope" "text", "p_limit" integer, "p_window_seconds" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_now timestamptz := clock_timestamp();
  v_request_count integer;
begin
  if p_scope not in ('elevenlabs_tts_project_daily', 'elevenlabs_stt_project_daily')
     or p_limit is null or p_limit < 1 or p_limit > 10000000
     or p_window_seconds is null or p_window_seconds < 1 or p_window_seconds > 86400
  then
    return false;
  end if;

  insert into public.kumusta_project_api_rate_limits (
    scope, window_started_at, request_count, updated_at
  ) values (p_scope, v_now, 1, v_now)
  on conflict (scope) do update
  set
    window_started_at = case
      when kumusta_project_api_rate_limits.window_started_at <=
        v_now - make_interval(secs => p_window_seconds)
      then v_now else kumusta_project_api_rate_limits.window_started_at end,
    request_count = case
      when kumusta_project_api_rate_limits.window_started_at <=
        v_now - make_interval(secs => p_window_seconds)
      then 1 else kumusta_project_api_rate_limits.request_count + 1 end,
    updated_at = v_now
  returning request_count into v_request_count;

  return v_request_count <= p_limit;
exception when others then
  return false;
end;
$$;


ALTER FUNCTION "public"."kumusta_consume_project_api_quota"("p_scope" "text", "p_limit" integer, "p_window_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_curriculum_admin_authorized"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$ select current_user = 'service_role' $$;


ALTER FUNCTION "public"."kumusta_curriculum_admin_authorized"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_fail_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $_$
begin
  if p_cache_key is null
     or p_cache_key !~ '^[0-9a-f]{64}$'
     or p_generation_token is null
  then
    return false;
  end if;

  update public.kumusta_tts_cache
  set
    status = 'failed',
    generation_token = null,
    generation_started_at = null,
    updated_at = clock_timestamp()
  where cache_key = p_cache_key
    and status = 'generating'
    and generation_token = p_generation_token;

  return found;
end;
$_$;


ALTER FUNCTION "public"."kumusta_fail_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_persist_generated_lesson_batch"("p_user_id" "uuid", "p_job_id" "uuid", "p_accent" "text", "p_model" "text", "p_lessons" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_lesson jsonb;
  v_generated_id uuid;
  v_inserted integer := 0;
begin
  if p_user_id is null or p_job_id is null
     or p_accent not in ('southern', 'northern')
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
      accent, difficulty, scenario_key, title, content, content_hash,
      status, quality_score, validation
    ) values (
      p_user_id,
      p_job_id,
      (v_lesson->>'schema_version')::integer,
      (v_lesson->>'prompt_version')::integer,
      p_model,
      p_accent,
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


ALTER FUNCTION "public"."kumusta_persist_generated_lesson_batch"("p_user_id" "uuid", "p_job_id" "uuid", "p_accent" "text", "p_model" "text", "p_lessons" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_record_difficulty_feedback"("p_user_id" "uuid", "p_client_event_id" "uuid", "p_generated_lesson_id" "uuid", "p_context" "text", "p_rating" "text", "p_step_kind" "text", "p_pace_rating" "text", "p_mark_complete" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_state public.kumusta_learner_states%rowtype;
  v_previous numeric(3,2);
  v_next numeric(3,2);
  v_inserted boolean := false;
  v_completed boolean := false;
  v_row_count integer := 0;
  v_next_speed text;
begin
  if p_user_id is null
     or p_client_event_id is null
     or p_context not in ('question', 'lesson')
     or p_rating not in ('too_easy', 'just_right', 'too_hard')
     or (p_step_kind is not null and p_step_kind not in ('coldListen', 'decode', 'speak'))
     or (p_pace_rating is not null and p_pace_rating not in ('too_slow', 'pace_right', 'too_fast'))
     or (p_mark_complete and p_pace_rating is null)
     or p_mark_complete is null
     or (p_generated_lesson_id is not null and not exists (
       select 1 from public.kumusta_generated_lessons
       where id = p_generated_lesson_id and user_id = p_user_id and status = 'ready'
     ))
     or (p_mark_complete and p_generated_lesson_id is not null and not exists (
       select 1 from public.kumusta_user_lesson_queue
       where generated_lesson_id = p_generated_lesson_id
         and user_id = p_user_id
         and status in ('ready', 'started')
     ))
  then
    raise exception using errcode = '22023', message = 'invalid adaptive feedback';
  end if;

  select * into v_state
  from public.kumusta_learner_states
  where user_id = p_user_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'learner state not found';
  end if;

  v_previous := v_state.challenge_offset;
  v_next := case p_rating
    when 'too_easy' then least(1.5, v_previous + 0.25)
    when 'too_hard' then greatest(-1.5, v_previous - 0.25)
    else round((v_previous * 0.85)::numeric, 2)
  end;
  v_next_speed := case p_pace_rating
    when 'too_slow' then case v_state.speech_speed
      when 'slow' then 'natural' else 'fast' end
    when 'too_fast' then case v_state.speech_speed
      when 'fast' then 'natural' else 'slow' end
    else v_state.speech_speed
  end;

  insert into public.kumusta_difficulty_feedback (
    user_id, generated_lesson_id, client_event_id, context, rating,
    step_kind, pace_rating, previous_speech_speed, new_speech_speed,
    previous_challenge_offset, new_challenge_offset
  ) values (
    p_user_id, p_generated_lesson_id, p_client_event_id, p_context, p_rating,
    p_step_kind, p_pace_rating, v_state.speech_speed,
    case when p_pace_rating is null then null else v_next_speed end,
    v_previous, v_next
  )
  on conflict (user_id, client_event_id) do nothing;
  get diagnostics v_row_count = row_count;
  v_inserted := v_row_count > 0;

  if v_inserted then
    if p_mark_complete and p_generated_lesson_id is not null then
      update public.kumusta_user_lesson_queue
      set status = 'completed', completed_at = coalesce(completed_at, now())
      where user_id = p_user_id
        and generated_lesson_id = p_generated_lesson_id
        and status in ('ready', 'started');
      get diagnostics v_row_count = row_count;
      v_completed := v_row_count > 0;
    end if;

    update public.kumusta_learner_states
    set
      challenge_offset = v_next,
      speech_speed = v_next_speed,
      estimated_level = least(
        target_level::numeric,
        greatest(
          1::numeric,
          estimated_level + case p_rating
            when 'too_easy' then 0.08
            when 'too_hard' then -0.04
            else case when v_completed then 0.03 else 0 end
          end
        )
      ),
      skill_mastery = case when v_completed then jsonb_build_object(
        'listening', least(1, coalesce((skill_mastery->>'listening')::numeric, 0) + 0.04),
        'speaking', least(1, coalesce((skill_mastery->>'speaking')::numeric, 0) + 0.04),
        'vocabulary', least(1, coalesce((skill_mastery->>'vocabulary')::numeric, 0) + 0.03),
        'automaticity', least(1, coalesce((skill_mastery->>'automaticity')::numeric, 0) + 0.025)
      ) else skill_mastery end,
      completed_lessons = completed_lessons + case when v_completed then 1 else 0 end,
      feedback_count = feedback_count + 1,
      state_version = state_version + 1,
      last_completed_at = case when v_completed then now() else last_completed_at end
    where user_id = p_user_id;
  end if;

  select * into v_state
  from public.kumusta_learner_states
  where user_id = p_user_id;

  return jsonb_build_object(
    'accepted', true,
    'duplicate', not v_inserted,
    'estimated_level', v_state.estimated_level,
    'target_level', v_state.target_level,
    'challenge_offset', v_state.challenge_offset,
    'speech_speed', v_state.speech_speed,
    'skill_mastery', v_state.skill_mastery,
    'completed_lessons', v_state.completed_lessons,
    'state_version', v_state.state_version
  );
end;
$$;


ALTER FUNCTION "public"."kumusta_record_difficulty_feedback"("p_user_id" "uuid", "p_client_event_id" "uuid", "p_generated_lesson_id" "uuid", "p_context" "text", "p_rating" "text", "p_step_kind" "text", "p_pace_rating" "text", "p_mark_complete" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."kumusta_record_difficulty_feedback"("p_user_id" "uuid", "p_client_event_id" "uuid", "p_generated_lesson_id" "uuid", "p_context" "text", "p_rating" "text", "p_step_kind" "text", "p_pace_rating" "text", "p_mark_complete" boolean) IS 'Atomically records idempotent difficulty feedback and updates deterministic learner state. Service-role only.';



CREATE OR REPLACE FUNCTION "public"."kumusta_record_generated_vocabulary_review"("p_user_id" "uuid", "p_generated_lesson_id" "uuid", "p_vocabulary_id" "uuid", "p_client_event_id" "uuid", "p_rating" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_inserted integer := 0;
  v_mastery numeric(4,3);
  v_interval integer;
  v_due_at timestamptz;
begin
  if p_user_id is null or p_generated_lesson_id is null or p_vocabulary_id is null
     or p_client_event_id is null or p_rating not in ('again', 'almost', 'got_it')
     or not exists (
       select 1 from public.kumusta_generated_lessons
       where id = p_generated_lesson_id and user_id = p_user_id and status = 'ready'
     )
  then
    raise exception using errcode = '22023', message = 'invalid generated vocabulary review';
  end if;

  insert into public.kumusta_generated_vocabulary_review_events (
    user_id, generated_lesson_id, vocabulary_id, client_event_id, rating
  ) values (
    p_user_id, p_generated_lesson_id, p_vocabulary_id, p_client_event_id, p_rating
  ) on conflict (user_id, client_event_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    insert into public.kumusta_generated_vocabulary_progress (
      user_id, generated_lesson_id, vocabulary_id, mastery, interval_days,
      due_at, review_count, last_reviewed_at
    ) values (
      p_user_id, p_generated_lesson_id, p_vocabulary_id,
      case p_rating when 'got_it' then 0.12 when 'almost' then 0.03 else 0 end,
      case p_rating when 'got_it' then 4 when 'almost' then 1 else 0 end,
      case p_rating
        when 'got_it' then now() + interval '4 days'
        when 'almost' then now() + interval '1 day'
        else now() + interval '30 seconds'
      end,
      1, now()
    )
    on conflict (user_id, vocabulary_id) do update set
      generated_lesson_id = excluded.generated_lesson_id,
      mastery = least(1, greatest(0,
        kumusta_generated_vocabulary_progress.mastery + case p_rating
          when 'got_it' then 0.12 when 'almost' then 0.03 else -0.08 end
      )),
      interval_days = excluded.interval_days,
      due_at = excluded.due_at,
      review_count = kumusta_generated_vocabulary_progress.review_count + 1,
      last_reviewed_at = now();
  end if;

  select mastery, interval_days, due_at
  into v_mastery, v_interval, v_due_at
  from public.kumusta_generated_vocabulary_progress
  where user_id = p_user_id and vocabulary_id = p_vocabulary_id;

  return jsonb_build_object(
    'accepted', true,
    'duplicate', v_inserted = 0,
    'mastery', v_mastery,
    'interval_days', v_interval,
    'due_at', v_due_at
  );
end;
$$;


ALTER FUNCTION "public"."kumusta_record_generated_vocabulary_review"("p_user_id" "uuid", "p_generated_lesson_id" "uuid", "p_vocabulary_id" "uuid", "p_client_event_id" "uuid", "p_rating" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_touch_leaderboard_signal"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.kumusta_xp_leaderboard_signal (id, all_time_updated_at)
  values (true, new.updated_at)
  on conflict (id) do update
    set all_time_updated_at = excluded.all_time_updated_at;
  return new;
end;
$$;


ALTER FUNCTION "public"."kumusta_touch_leaderboard_signal"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."kumusta_touch_leaderboard_signal"() IS 'Publishes a safe Realtime invalidation signal after all-time XP changes.';



CREATE OR REPLACE FUNCTION "public"."kumusta_touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."kumusta_touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kumusta_validate_analytics_event"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $_$
declare
  v_allowed_keys constant text[] := array[
    'accent', 'active_seconds', 'answer_id', 'app_build', 'app_version',
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
    new.properties ->> 'accent' not in ('southern', 'northern')
    or new.properties ->> 'goal' not in (
      'family', 'lifeInVietnam', 'travel', 'partner', 'work', 'culture'
    )
    or new.properties ->> 'level' not in (
      'new', 'familiar', 'conversational', 'rusty'
    )
    -- The onboarding offers 5/7/10/15 minutes; 3 is kept for older builds.
    or new.properties ->> 'daily_minutes' not in ('3', '5', '7', '10', '15')
  ) then
    raise exception 'invalid onboarding analytics values';
  end if;

  if new.event_name = 'value_demo_completed' and (
    new.properties ->> 'accent' not in ('southern', 'northern')
    or new.properties ->> 'attempt' <> 'completed'
  ) then
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


ALTER FUNCTION "public"."kumusta_validate_analytics_event"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."kumusta_validate_analytics_event"() IS 'Rejects unsupported analytics names, keys, value shapes, and stale/future timestamps before storage.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_analytics_events" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "event_name" "text" NOT NULL,
    "event_version" smallint DEFAULT 1 NOT NULL,
    "session_id" "uuid",
    "properties" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "occurred_at" timestamp with time zone NOT NULL,
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "client_event_id" "uuid" NOT NULL,
    "screen_name" "text",
    "app_version" "text",
    "platform" "text" DEFAULT 'ios'::"text" NOT NULL,
    "install_id" "uuid",
    "client_session_id" "uuid",
    CONSTRAINT "kumusta_analytics_events_app_version_check" CHECK ((("app_version" IS NULL) OR (("char_length"("btrim"("app_version")) >= 1) AND ("char_length"("btrim"("app_version")) <= 40)))),
    CONSTRAINT "kumusta_analytics_events_event_name_check" CHECK (("event_name" ~ '^[a-z][a-z0-9_]{1,79}$'::"text")),
    CONSTRAINT "kumusta_analytics_events_event_version_check" CHECK (("event_version" > 0)),
    CONSTRAINT "kumusta_analytics_events_platform_check" CHECK (("platform" = 'ios'::"text")),
    CONSTRAINT "kumusta_analytics_events_properties_check" CHECK ((("jsonb_typeof"("properties") = 'object'::"text") AND ("octet_length"(("properties")::"text") <= 16384))),
    CONSTRAINT "kumusta_analytics_events_screen_name_check" CHECK ((("screen_name" IS NULL) OR (("char_length"("btrim"("screen_name")) >= 1) AND ("char_length"("btrim"("screen_name")) <= 120))))
);


ALTER TABLE "public"."kumusta_analytics_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_analytics_events" IS 'First-party product analytics. Authenticated clients may insert their own rows and can select only their own idempotency columns because PostgREST ON CONFLICT requires conflict-key visibility; event payload columns remain unreadable.';



COMMENT ON COLUMN "public"."kumusta_analytics_events"."client_session_id" IS 'Client-owned activity correlation id, retained for every product surface.';



ALTER TABLE "public"."kumusta_analytics_events" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."kumusta_analytics_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."kumusta_api_rate_limits" (
    "user_id" "uuid" NOT NULL,
    "scope" "text" NOT NULL,
    "window_started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "request_count" integer DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_api_rate_limits_request_count_check" CHECK (("request_count" > 0)),
    CONSTRAINT "kumusta_api_rate_limits_scope_check" CHECK (("scope" = ANY (ARRAY['elevenlabs_tts'::"text", 'elevenlabs_tts_daily'::"text", 'elevenlabs_stt'::"text", 'elevenlabs_stt_daily'::"text", 'lessons'::"text", 'lessons_daily'::"text", 'lessons_mutation'::"text", 'lessons_mutation_daily'::"text", 'revenuecat_sync'::"text"])))
);


ALTER TABLE "public"."kumusta_api_rate_limits" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_api_rate_limits" IS 'Service-only rate limit counters for provider proxy Edge Functions.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_app_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_session_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "active_seconds" integer DEFAULT 0 NOT NULL,
    "app_version" "text",
    "platform" "text" DEFAULT 'ios'::"text" NOT NULL,
    "install_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_app_sessions_active_seconds_check" CHECK ((("active_seconds" >= 0) AND ("active_seconds" <= 86400))),
    CONSTRAINT "kumusta_app_sessions_app_version_check" CHECK ((("app_version" IS NULL) OR ("char_length"("app_version") <= 40))),
    CONSTRAINT "kumusta_app_sessions_end_check" CHECK ((("ended_at" IS NULL) OR ("ended_at" >= "started_at"))),
    CONSTRAINT "kumusta_app_sessions_platform_check" CHECK (("platform" = 'ios'::"text"))
);


ALTER TABLE "public"."kumusta_app_sessions" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_app_sessions" IS 'Idempotent first-party app lifecycle sessions used for retention and active-time reporting.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_flashcard_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_session_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "completed" boolean DEFAULT false NOT NULL,
    "total_cards" smallint DEFAULT 0 NOT NULL,
    "cards_presented" smallint DEFAULT 0 NOT NULL,
    "cards_answered" smallint DEFAULT 0 NOT NULL,
    "correct_count" smallint DEFAULT 0 NOT NULL,
    "active_seconds" integer DEFAULT 0 NOT NULL,
    "score" numeric(5,4),
    "app_version" "text",
    "platform" "text" DEFAULT 'ios'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_flashcard_sessions_active_seconds_check" CHECK ((("active_seconds" >= 0) AND ("active_seconds" <= 14400))),
    CONSTRAINT "kumusta_flashcard_sessions_app_version_check" CHECK ((("app_version" IS NULL) OR ("char_length"("app_version") <= 40))),
    CONSTRAINT "kumusta_flashcard_sessions_cards_answered_check" CHECK ((("cards_answered" >= 0) AND ("cards_answered" <= 100))),
    CONSTRAINT "kumusta_flashcard_sessions_cards_presented_check" CHECK ((("cards_presented" >= 0) AND ("cards_presented" <= 100))),
    CONSTRAINT "kumusta_flashcard_sessions_correct_count_check" CHECK ((("correct_count" >= 0) AND ("correct_count" <= 100))),
    CONSTRAINT "kumusta_flashcard_sessions_counts_check" CHECK ((("cards_presented" <= "total_cards") AND ("cards_answered" <= "cards_presented") AND ("correct_count" <= "cards_answered"))),
    CONSTRAINT "kumusta_flashcard_sessions_end_check" CHECK ((("ended_at" IS NULL) OR ("ended_at" >= "started_at"))),
    CONSTRAINT "kumusta_flashcard_sessions_platform_check" CHECK (("platform" = 'ios'::"text")),
    CONSTRAINT "kumusta_flashcard_sessions_score_check" CHECK ((("score" IS NULL) OR (("score" >= (0)::numeric) AND ("score" <= (1)::numeric)))),
    CONSTRAINT "kumusta_flashcard_sessions_total_cards_check" CHECK ((("total_cards" >= 0) AND ("total_cards" <= 100)))
);


ALTER TABLE "public"."kumusta_flashcard_sessions" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_flashcard_sessions" IS 'Session-level flashcard telemetry. Individual ratings remain in review_events.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_learning_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "lesson_id" "uuid",
    "session_kind" "text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "active_seconds" integer DEFAULT 0 NOT NULL,
    "completed" boolean DEFAULT false NOT NULL,
    "score" numeric(5,4),
    "client_session_id" "uuid" NOT NULL,
    "app_version" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "generated_lesson_id" "uuid",
    "content_id" "uuid",
    "content_kind" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "entry_point" "text",
    "is_replay" boolean DEFAULT false NOT NULL,
    CONSTRAINT "kumusta_learning_sessions_active_seconds_check" CHECK ((("active_seconds" >= 0) AND ("active_seconds" <= 14400))),
    CONSTRAINT "kumusta_learning_sessions_app_version_check" CHECK ((("app_version" IS NULL) OR ("char_length"("app_version") <= 40))),
    CONSTRAINT "kumusta_learning_sessions_content_kind_check" CHECK (("content_kind" = ANY (ARRAY['authored'::"text", 'goal'::"text", 'generated'::"text", 'unknown'::"text"]))),
    CONSTRAINT "kumusta_learning_sessions_end_check" CHECK ((("ended_at" IS NULL) OR ("ended_at" >= "started_at"))),
    CONSTRAINT "kumusta_learning_sessions_entry_point_check" CHECK ((("entry_point" IS NULL) OR ("entry_point" = ANY (ARRAY['today'::"text", 'practice'::"text", 'history'::"text", 'unknown'::"text"])))),
    CONSTRAINT "kumusta_learning_sessions_score_check" CHECK ((("score" IS NULL) OR (("score" >= (0)::numeric) AND ("score" <= (1)::numeric)))),
    CONSTRAINT "kumusta_learning_sessions_session_kind_check" CHECK (("session_kind" = ANY (ARRAY['today'::"text", 'lesson'::"text", 'practice'::"text", 'words'::"text"])))
);


ALTER TABLE "public"."kumusta_learning_sessions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."kumusta_learning_sessions"."content_id" IS 'Stable content UUID across authored, goal-curriculum, and generated lessons.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_live_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "usage_day" "date" DEFAULT (("now"() AT TIME ZONE 'UTC'::"text"))::"date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "ended_at" timestamp with time zone,
    "reserved_seconds" integer NOT NULL,
    "charged_seconds" integer NOT NULL,
    "provider_seconds" numeric DEFAULT 0 NOT NULL,
    "usage_confirmed" boolean DEFAULT false NOT NULL,
    "accent" "text" NOT NULL,
    "topic_source" "text" NOT NULL,
    "model" "text" DEFAULT 'pipeline'::"text" NOT NULL,
    "end_reason" "text",
    "user_fragments" integer DEFAULT 0 NOT NULL,
    "assistant_fragments" integer DEFAULT 0 NOT NULL,
    "mute_count" integer DEFAULT 0 NOT NULL,
    "safety_stops" integer DEFAULT 0 NOT NULL,
    "round_id" "uuid",
    "topic" "text" DEFAULT ''::"text" NOT NULL,
    "latest_lesson" "text" DEFAULT ''::"text" NOT NULL,
    "latest_lesson_id" "uuid",
    "client_session_id" "uuid",
    "started_at" timestamp with time zone,
    "provider_conversation_id" "text",
    CONSTRAINT "live_charge_within_reservation" CHECK (("charged_seconds" <= "reserved_seconds")),
    CONSTRAINT "kumusta_live_sessions_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text", 'both'::"text"]))),
    CONSTRAINT "kumusta_live_sessions_charged_seconds_check" CHECK ((("charged_seconds" >= 0) AND ("charged_seconds" <= 3600))),
    CONSTRAINT "kumusta_live_sessions_latest_lesson_check" CHECK (("char_length"("latest_lesson") <= 600)),
    CONSTRAINT "kumusta_live_sessions_provider_conversation_id_check" CHECK ((("provider_conversation_id" IS NULL) OR ("char_length"("provider_conversation_id") <= 120))),
    CONSTRAINT "kumusta_live_sessions_provider_seconds_check" CHECK (("provider_seconds" >= (0)::numeric)),
    CONSTRAINT "kumusta_live_sessions_reserved_seconds_check" CHECK ((("reserved_seconds" >= 1) AND ("reserved_seconds" <= 3600))),
    CONSTRAINT "kumusta_live_sessions_topic_check" CHECK (("char_length"("topic") <= 200)),
    CONSTRAINT "kumusta_live_sessions_topic_source_check" CHECK (("topic_source" = ANY (ARRAY['chosen'::"text", 'latest_lesson'::"text", 'starter'::"text"])))
);


ALTER TABLE "public"."kumusta_live_sessions" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_live_sessions" IS 'Server-observed live practice usage and interaction counts. No audio or transcript text. UTC daily budget; unfinished reservations fail closed.';



COMMENT ON COLUMN "public"."kumusta_live_sessions"."client_session_id" IS 'Client-owned correlation id shared by every relay segment in one real-time practice attempt.';



CREATE OR REPLACE VIEW "public"."kumusta_customer_learning_activity" WITH ("security_invoker"='true') AS
 SELECT "sessions"."user_id",
        CASE
            WHEN ("sessions"."content_id" IS NOT NULL) THEN 'lesson'::"text"
            WHEN ("sessions"."session_kind" = 'practice'::"text") THEN 'review'::"text"
            ELSE "sessions"."session_kind"
        END AS "activity_type",
    "sessions"."content_id",
    "sessions"."content_kind",
    "sessions"."client_session_id",
    "sessions"."started_at",
    "sessions"."ended_at",
    "sessions"."completed",
    "sessions"."active_seconds",
    "sessions"."score",
    "jsonb_build_object"('session_kind', "sessions"."session_kind", 'entry_point', "sessions"."entry_point", 'is_replay', "sessions"."is_replay") AS "details"
   FROM "public"."kumusta_learning_sessions" "sessions"
UNION ALL
 SELECT "flashcards"."user_id",
    'flashcards'::"text" AS "activity_type",
    NULL::"uuid" AS "content_id",
    'vocabulary'::"text" AS "content_kind",
    "flashcards"."client_session_id",
    "flashcards"."started_at",
    "flashcards"."ended_at",
    "flashcards"."completed",
    "flashcards"."active_seconds",
    "flashcards"."score",
    "jsonb_build_object"('total_cards', "flashcards"."total_cards", 'cards_presented', "flashcards"."cards_presented", 'cards_answered', "flashcards"."cards_answered", 'correct_count', "flashcards"."correct_count") AS "details"
   FROM "public"."kumusta_flashcard_sessions" "flashcards"
UNION ALL
 SELECT "live"."user_id",
    'realtime_conversation'::"text" AS "activity_type",
    "live"."latest_lesson_id" AS "content_id",
        CASE
            WHEN ("live"."latest_lesson_id" IS NULL) THEN 'unspecified'::"text"
            ELSE 'lesson_context'::"text"
        END AS "content_kind",
    COALESCE("live"."client_session_id", "live"."id") AS "client_session_id",
    "min"("live"."created_at") AS "started_at",
    "max"("live"."ended_at") AS "ended_at",
    "bool_and"(("live"."ended_at" IS NOT NULL)) AS "completed",
    ("sum"("live"."charged_seconds"))::integer AS "active_seconds",
    NULL::numeric AS "score",
    "jsonb_build_object"('accent', "max"("live"."accent"), 'topic_source', "max"("live"."topic_source"), 'end_reason', "max"("live"."end_reason"), 'user_fragments', "sum"("live"."user_fragments"), 'assistant_fragments', "sum"("live"."assistant_fragments"), 'mute_count', "sum"("live"."mute_count"), 'usage_confirmed', "bool_and"("live"."usage_confirmed"), 'relay_segment_count', "count"(*)) AS "details"
   FROM "public"."kumusta_live_sessions" "live"
  GROUP BY "live"."user_id", "live"."latest_lesson_id", COALESCE("live"."client_session_id", "live"."id");


ALTER VIEW "public"."kumusta_customer_learning_activity" OWNER TO "postgres";


COMMENT ON VIEW "public"."kumusta_customer_learning_activity" IS 'Service-role reporting view with one normalized row per customer learning activity.';



CREATE OR REPLACE VIEW "public"."kumusta_customer_lesson_usage" WITH ("security_invoker"='true') AS
 WITH "session_usage" AS (
         SELECT "sessions_1"."user_id",
            "sessions_1"."content_id",
            "sessions_1"."content_kind",
            "count"(*) AS "session_count",
            "count"(*) FILTER (WHERE "sessions_1"."completed") AS "completion_count",
            "count"(*) FILTER (WHERE "sessions_1"."is_replay") AS "replay_count",
            COALESCE("sum"("sessions_1"."active_seconds"), (0)::bigint) AS "active_seconds",
            "avg"("sessions_1"."score") FILTER (WHERE ("sessions_1"."score" IS NOT NULL)) AS "average_score",
            "min"("sessions_1"."started_at") AS "first_started_at",
            "max"("sessions_1"."started_at") AS "last_started_at",
            "max"("sessions_1"."ended_at") FILTER (WHERE "sessions_1"."completed") AS "last_completed_at"
           FROM "public"."kumusta_learning_sessions" "sessions_1"
          WHERE ("sessions_1"."content_id" IS NOT NULL)
          GROUP BY "sessions_1"."user_id", "sessions_1"."content_id", "sessions_1"."content_kind"
        ), "attributed_events" AS (
         SELECT "events_1"."user_id",
                CASE
                    WHEN ("lesson_ids"."lesson_id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::"text") THEN ("lesson_ids"."lesson_id")::"uuid"
                    ELSE NULL::"uuid"
                END AS "content_id",
            NULLIF(("events_1"."properties" ->> 'content_kind'::"text"), ''::"text") AS "content_kind",
            "events_1"."event_name",
            "events_1"."occurred_at"
           FROM ("public"."kumusta_analytics_events" "events_1"
             CROSS JOIN LATERAL ( SELECT COALESCE(NULLIF(("events_1"."properties" ->> 'source_lesson_id'::"text"), ''::"text"), NULLIF(("events_1"."properties" ->> 'lesson_id'::"text"), ''::"text")) AS "lesson_id") "lesson_ids")
          WHERE ("lesson_ids"."lesson_id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'::"text")
        ), "event_usage" AS (
         SELECT "events_1"."user_id",
            "events_1"."content_id",
            COALESCE("max"("events_1"."content_kind"), 'unknown'::"text") AS "content_kind",
            "count"(*) AS "interaction_event_count",
            "count"(*) FILTER (WHERE ("events_1"."event_name" = 'flashcard_answered'::"text")) AS "flashcard_answer_count",
            "count"(*) FILTER (WHERE ("events_1"."event_name" = 'lesson_history_audio_played'::"text")) AS "history_audio_play_count",
            "count"(*) FILTER (WHERE ("events_1"."event_name" = 'live_practice_started'::"text")) AS "realtime_start_count",
            "min"("events_1"."occurred_at") AS "first_interaction_at",
            "max"("events_1"."occurred_at") AS "last_interaction_at"
           FROM "attributed_events" "events_1"
          GROUP BY "events_1"."user_id", "events_1"."content_id"
        )
 SELECT COALESCE("sessions"."user_id", "events"."user_id") AS "user_id",
    COALESCE("sessions"."content_id", "events"."content_id") AS "content_id",
    COALESCE("sessions"."content_kind", "events"."content_kind", 'unknown'::"text") AS "content_kind",
    COALESCE("sessions"."session_count", (0)::bigint) AS "session_count",
    COALESCE("sessions"."completion_count", (0)::bigint) AS "completion_count",
    COALESCE("sessions"."replay_count", (0)::bigint) AS "replay_count",
    COALESCE("sessions"."active_seconds", (0)::bigint) AS "active_seconds",
    "sessions"."average_score",
    COALESCE("events"."interaction_event_count", (0)::bigint) AS "interaction_event_count",
    COALESCE("events"."flashcard_answer_count", (0)::bigint) AS "flashcard_answer_count",
    COALESCE("events"."history_audio_play_count", (0)::bigint) AS "history_audio_play_count",
    COALESCE("events"."realtime_start_count", (0)::bigint) AS "realtime_start_count",
    LEAST("sessions"."first_started_at", "events"."first_interaction_at") AS "first_started_at",
    GREATEST("sessions"."last_started_at", "events"."last_interaction_at") AS "last_started_at",
    "sessions"."last_completed_at"
   FROM ("session_usage" "sessions"
     FULL JOIN "event_usage" "events" ON ((("events"."user_id" = "sessions"."user_id") AND ("events"."content_id" = "sessions"."content_id"))));


ALTER VIEW "public"."kumusta_customer_lesson_usage" OWNER TO "postgres";


COMMENT ON VIEW "public"."kumusta_customer_lesson_usage" IS 'Service-role customer-by-lesson usage rollup across authored, goal, and generated lessons.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_daily_progress" (
    "user_id" "uuid" NOT NULL,
    "progress_date" "date" NOT NULL,
    "active_seconds" integer DEFAULT 0 NOT NULL,
    "lessons_completed" integer DEFAULT 0 NOT NULL,
    "words_learned" integer DEFAULT 0 NOT NULL,
    "words_reviewed" integer DEFAULT 0 NOT NULL,
    "xp" integer DEFAULT 0 NOT NULL,
    "daily_goal_met" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_daily_progress_active_seconds_check" CHECK ((("active_seconds" >= 0) AND ("active_seconds" <= 86400))),
    CONSTRAINT "kumusta_daily_progress_lessons_completed_check" CHECK (("lessons_completed" >= 0)),
    CONSTRAINT "kumusta_daily_progress_words_learned_check" CHECK (("words_learned" >= 0)),
    CONSTRAINT "kumusta_daily_progress_words_reviewed_check" CHECK (("words_reviewed" >= 0)),
    CONSTRAINT "kumusta_daily_progress_xp_check" CHECK (("xp" >= 0))
);


ALTER TABLE "public"."kumusta_daily_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kumusta_difficulty_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "generated_lesson_id" "uuid",
    "client_event_id" "uuid" NOT NULL,
    "context" "text" NOT NULL,
    "rating" "text" NOT NULL,
    "step_kind" "text",
    "pace_rating" "text",
    "previous_speech_speed" "text",
    "new_speech_speed" "text",
    "previous_challenge_offset" numeric(3,2) NOT NULL,
    "new_challenge_offset" numeric(3,2) NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_difficulty_feedback_context_check" CHECK (("context" = ANY (ARRAY['question'::"text", 'lesson'::"text"]))),
    CONSTRAINT "kumusta_difficulty_feedback_new_challenge_offset_check" CHECK ((("new_challenge_offset" >= '-1.5'::numeric) AND ("new_challenge_offset" <= 1.5))),
    CONSTRAINT "kumusta_difficulty_feedback_new_speech_speed_check" CHECK ((("new_speech_speed" IS NULL) OR ("new_speech_speed" = ANY (ARRAY['slow'::"text", 'natural'::"text", 'fast'::"text"])))),
    CONSTRAINT "kumusta_difficulty_feedback_pace_rating_check" CHECK ((("pace_rating" IS NULL) OR ("pace_rating" = ANY (ARRAY['too_slow'::"text", 'pace_right'::"text", 'too_fast'::"text"])))),
    CONSTRAINT "kumusta_difficulty_feedback_previous_challenge_offset_check" CHECK ((("previous_challenge_offset" >= '-1.5'::numeric) AND ("previous_challenge_offset" <= 1.5))),
    CONSTRAINT "kumusta_difficulty_feedback_previous_speech_speed_check" CHECK ((("previous_speech_speed" IS NULL) OR ("previous_speech_speed" = ANY (ARRAY['slow'::"text", 'natural'::"text", 'fast'::"text"])))),
    CONSTRAINT "kumusta_difficulty_feedback_rating_check" CHECK (("rating" = ANY (ARRAY['too_easy'::"text", 'just_right'::"text", 'too_hard'::"text"]))),
    CONSTRAINT "kumusta_difficulty_feedback_step_kind_check" CHECK ((("step_kind" IS NULL) OR ("step_kind" = ANY (ARRAY['coldListen'::"text", 'decode'::"text", 'speak'::"text"]))))
);


ALTER TABLE "public"."kumusta_difficulty_feedback" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_difficulty_feedback" IS 'Idempotent explicit learner feedback. Raw free-form text is intentionally not collected.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_entitlements" (
    "user_id" "uuid" NOT NULL,
    "entitlement_id" "text" NOT NULL,
    "is_active" boolean DEFAULT false NOT NULL,
    "product_id" "text",
    "environment" "text",
    "purchased_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "will_renew" boolean,
    "last_revenuecat_event_id" "text",
    "last_synced_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_entitlements_entitlement_id_check" CHECK ((("char_length"("entitlement_id") >= 1) AND ("char_length"("entitlement_id") <= 120))),
    CONSTRAINT "kumusta_entitlements_environment_check" CHECK ((("environment" IS NULL) OR ("environment" = ANY (ARRAY['sandbox'::"text", 'production'::"text"])))),
    CONSTRAINT "kumusta_entitlements_product_id_check" CHECK ((("product_id" IS NULL) OR ("char_length"("product_id") <= 200)))
);


ALTER TABLE "public"."kumusta_entitlements" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_entitlements" IS 'Canonical RevenueCat entitlement projection. Only server-side service-role code may write.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_course_progress" (
    "user_id" "uuid" NOT NULL,
    "course_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'not_started'::"text" NOT NULL,
    "offer_seen_at" timestamp with time zone,
    "current_item_id" "uuid",
    "completed_item_count" integer DEFAULT 0 NOT NULL,
    "points" integer DEFAULT 0 NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "last_accessed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_course_progress_completed_item_count_check" CHECK (("completed_item_count" >= 0)),
    CONSTRAINT "kumusta_foundation_course_progress_dates_check" CHECK ((("completed_at" IS NULL) OR ("started_at" IS NULL) OR ("completed_at" >= "started_at"))),
    CONSTRAINT "kumusta_foundation_course_progress_points_check" CHECK (("points" >= 0)),
    CONSTRAINT "kumusta_foundation_course_progress_status_check" CHECK (("status" = ANY (ARRAY['not_started'::"text", 'in_progress'::"text", 'skipped'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."kumusta_foundation_course_progress" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_course_progress" IS 'One resumable course state per learner. Only the owner can read or write it.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "estimated_minutes" smallint NOT NULL,
    "content_version" integer DEFAULT 1 NOT NULL,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_courses_content_version_check" CHECK (("content_version" > 0)),
    CONSTRAINT "kumusta_foundation_courses_estimated_minutes_check" CHECK ((("estimated_minutes" >= 1) AND ("estimated_minutes" <= 60))),
    CONSTRAINT "kumusta_foundation_courses_slug_check" CHECK ((("slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND ("char_length"("slug") <= 100))),
    CONSTRAINT "kumusta_foundation_courses_summary_check" CHECK ((("char_length"("btrim"("summary")) >= 1) AND ("char_length"("btrim"("summary")) <= 500))),
    CONSTRAINT "kumusta_foundation_courses_title_check" CHECK ((("char_length"("btrim"("title")) >= 1) AND ("char_length"("btrim"("title")) <= 120)))
);


ALTER TABLE "public"."kumusta_foundation_courses" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_courses" IS 'Server-curated introductory courses available after onboarding and premium access.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_item_progress" (
    "user_id" "uuid" NOT NULL,
    "item_id" "uuid" NOT NULL,
    "accent" "text" NOT NULL,
    "attempt_count" integer DEFAULT 0 NOT NULL,
    "completed" boolean DEFAULT false NOT NULL,
    "best_score" numeric(5,4),
    "last_attempt_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_item_progress_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_foundation_item_progress_attempt_count_check" CHECK (("attempt_count" >= 0)),
    CONSTRAINT "kumusta_foundation_item_progress_best_score_check" CHECK ((("best_score" IS NULL) OR (("best_score" >= (0)::numeric) AND ("best_score" <= (1)::numeric))))
);


ALTER TABLE "public"."kumusta_foundation_item_progress" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_item_progress" IS 'Per-rep speaking attempts and optional pronunciation scores for review and analytics.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_item_variants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "item_id" "uuid" NOT NULL,
    "accent" "text" NOT NULL,
    "target_text" "text" NOT NULL,
    "translation" "text" NOT NULL,
    "pronunciation_hint" "text",
    "audio_object_path" "text",
    "audio_duration_ms" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_item_variants_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_foundation_item_variants_audio_duration_ms_check" CHECK ((("audio_duration_ms" IS NULL) OR (("audio_duration_ms" >= 100) AND ("audio_duration_ms" <= 120000)))),
    CONSTRAINT "kumusta_foundation_item_variants_audio_object_path_check" CHECK ((("audio_object_path" IS NULL) OR (("audio_object_path" ~ '^kumusta-audio/[a-zA-Z0-9/_-]+\\.(mp3|m4a|wav)$'::"text") AND ("char_length"("audio_object_path") <= 500)))),
    CONSTRAINT "kumusta_foundation_item_variants_pronunciation_hint_check" CHECK ((("pronunciation_hint" IS NULL) OR ("char_length"("pronunciation_hint") <= 500))),
    CONSTRAINT "kumusta_foundation_item_variants_target_text_check" CHECK ((("char_length"("btrim"("target_text")) >= 1) AND ("char_length"("btrim"("target_text")) <= 500))),
    CONSTRAINT "kumusta_foundation_item_variants_translation_check" CHECK ((("char_length"("btrim"("translation")) >= 1) AND ("char_length"("btrim"("translation")) <= 500)))
);


ALTER TABLE "public"."kumusta_foundation_item_variants" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_item_variants" IS 'Accent-specific text and audio metadata. Provider credentials and raw recordings never live here.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "position" smallint NOT NULL,
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "instruction" "text" NOT NULL,
    "note" "text" NOT NULL,
    "required_speaking" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_items_instruction_check" CHECK ((("char_length"("btrim"("instruction")) >= 1) AND ("char_length"("btrim"("instruction")) <= 500))),
    CONSTRAINT "kumusta_foundation_items_kind_check" CHECK (("kind" = ANY (ARRAY['sound_map'::"text", 'accent_compare'::"text", 'final_sound'::"text", 'tone'::"text", 'relationship'::"text", 'numbers'::"text"]))),
    CONSTRAINT "kumusta_foundation_items_note_check" CHECK ((("char_length"("btrim"("note")) >= 1) AND ("char_length"("btrim"("note")) <= 700))),
    CONSTRAINT "kumusta_foundation_items_position_check" CHECK (("position" >= 0)),
    CONSTRAINT "kumusta_foundation_items_slug_check" CHECK ((("slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND ("char_length"("slug") <= 100))),
    CONSTRAINT "kumusta_foundation_items_title_check" CHECK ((("char_length"("btrim"("title")) >= 1) AND ("char_length"("btrim"("title")) <= 160)))
);


ALTER TABLE "public"."kumusta_foundation_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_items" IS 'One spoken foundation rep. The client may require a recording before advancing.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_foundation_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "position" smallint NOT NULL,
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_foundation_units_kind_check" CHECK (("kind" = ANY (ARRAY['sound_map'::"text", 'accent_compare'::"text", 'final_sound'::"text", 'tone'::"text", 'relationship'::"text", 'numbers'::"text"]))),
    CONSTRAINT "kumusta_foundation_units_position_check" CHECK (("position" >= 0)),
    CONSTRAINT "kumusta_foundation_units_slug_check" CHECK ((("slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND ("char_length"("slug") <= 100))),
    CONSTRAINT "kumusta_foundation_units_summary_check" CHECK ((("char_length"("btrim"("summary")) >= 1) AND ("char_length"("btrim"("summary")) <= 500))),
    CONSTRAINT "kumusta_foundation_units_symbol_check" CHECK ((("char_length"("btrim"("symbol")) >= 1) AND ("char_length"("btrim"("symbol")) <= 80))),
    CONSTRAINT "kumusta_foundation_units_title_check" CHECK ((("char_length"("btrim"("title")) >= 1) AND ("char_length"("btrim"("title")) <= 160)))
);


ALTER TABLE "public"."kumusta_foundation_units" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_foundation_units" IS 'Ordered chapters inside an introductory foundation course.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_generated_lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "generation_job_id" "uuid" NOT NULL,
    "schema_version" integer NOT NULL,
    "prompt_version" integer NOT NULL,
    "model" "text" NOT NULL,
    "accent" "text" NOT NULL,
    "difficulty" numeric(3,2) NOT NULL,
    "scenario_key" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "jsonb" NOT NULL,
    "content_hash" "text" NOT NULL,
    "status" "text" DEFAULT 'ready'::"text" NOT NULL,
    "quality_score" numeric(4,3) NOT NULL,
    "validation" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '30 days'::interval) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_generated_lessons_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_generated_lessons_content_check" CHECK ((("jsonb_typeof"("content") = 'object'::"text") AND ("octet_length"(("content")::"text") <= 65536))),
    CONSTRAINT "kumusta_generated_lessons_content_hash_check" CHECK (("content_hash" ~ '^[a-f0-9]{64}$'::"text")),
    CONSTRAINT "kumusta_generated_lessons_difficulty_check" CHECK ((("difficulty" >= (1)::numeric) AND ("difficulty" <= (5)::numeric))),
    CONSTRAINT "kumusta_generated_lessons_model_check" CHECK ((("char_length"("model") >= 1) AND ("char_length"("model") <= 120))),
    CONSTRAINT "kumusta_generated_lessons_prompt_version_check" CHECK (("prompt_version" > 0)),
    CONSTRAINT "kumusta_generated_lessons_quality_score_check" CHECK ((("quality_score" >= (0)::numeric) AND ("quality_score" <= (1)::numeric))),
    CONSTRAINT "kumusta_generated_lessons_scenario_key_check" CHECK ((("scenario_key" ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'::"text") AND ("char_length"("scenario_key") <= 80))),
    CONSTRAINT "kumusta_generated_lessons_schema_version_check" CHECK (("schema_version" > 0)),
    CONSTRAINT "kumusta_generated_lessons_status_check" CHECK (("status" = ANY (ARRAY['ready'::"text", 'quarantined'::"text", 'archived'::"text"]))),
    CONSTRAINT "kumusta_generated_lessons_title_check" CHECK ((("char_length"("btrim"("title")) >= 1) AND ("char_length"("btrim"("title")) <= 100))),
    CONSTRAINT "kumusta_generated_lessons_validation_check" CHECK ((("jsonb_typeof"("validation") = 'object'::"text") AND ("octet_length"(("validation")::"text") <= 8192)))
);


ALTER TABLE "public"."kumusta_generated_lessons" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_generated_lessons" IS 'Validated, immutable-at-delivery Mistral lesson payloads. Quarantined output is never served.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_generated_vocabulary_progress" (
    "user_id" "uuid" NOT NULL,
    "generated_lesson_id" "uuid" NOT NULL,
    "vocabulary_id" "uuid" NOT NULL,
    "mastery" numeric(4,3) DEFAULT 0 NOT NULL,
    "interval_days" integer DEFAULT 0 NOT NULL,
    "due_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "review_count" integer DEFAULT 0 NOT NULL,
    "last_reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_generated_vocabulary_progress_interval_days_check" CHECK ((("interval_days" >= 0) AND ("interval_days" <= 3650))),
    CONSTRAINT "kumusta_generated_vocabulary_progress_mastery_check" CHECK ((("mastery" >= (0)::numeric) AND ("mastery" <= (1)::numeric))),
    CONSTRAINT "kumusta_generated_vocabulary_progress_review_count_check" CHECK (("review_count" >= 0))
);


ALTER TABLE "public"."kumusta_generated_vocabulary_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kumusta_generated_vocabulary_review_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "generated_lesson_id" "uuid" NOT NULL,
    "vocabulary_id" "uuid" NOT NULL,
    "client_event_id" "uuid" NOT NULL,
    "rating" "text" NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_generated_vocabulary_review_events_rating_check" CHECK (("rating" = ANY (ARRAY['again'::"text", 'almost'::"text", 'got_it'::"text"])))
);


ALTER TABLE "public"."kumusta_generated_vocabulary_review_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kumusta_goal_lesson_translations" (
    "lesson_id" "uuid" NOT NULL,
    "locale" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "content" "jsonb" NOT NULL,
    "source_content_md5" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_goal_lesson_translations_content_check" CHECK (("jsonb_typeof"("content") = 'object'::"text")),
    CONSTRAINT "kumusta_goal_lesson_translations_locale_check" CHECK (("locale" = 'fr'::"text"))
);


ALTER TABLE "public"."kumusta_goal_lesson_translations" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_goal_lesson_translations" IS 'Translated learner-facing text for kumusta_goal_lessons (same rounds, Vietnamese and tokens). The app uses a row only when it lines up exactly with the English lesson; otherwise it shows English.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_goal_lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "curriculum_version" "text" DEFAULT 'goals-v1'::"text" NOT NULL,
    "goal" "text" NOT NULL,
    "stage" smallint NOT NULL,
    "accent" "text" NOT NULL,
    "lesson_order" smallint NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "content" "jsonb" NOT NULL,
    "model" "text" NOT NULL,
    "usage" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "review" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_goal_lessons_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_goal_lessons_content_check" CHECK (("jsonb_typeof"("content") = 'object'::"text")),
    CONSTRAINT "kumusta_goal_lessons_goal_check" CHECK (("goal" = ANY (ARRAY['lifeInVietnam'::"text", 'family'::"text", 'partner'::"text", 'travel'::"text"]))),
    CONSTRAINT "kumusta_goal_lessons_lesson_order_check" CHECK ((("lesson_order" >= 1) AND ("lesson_order" <= 10))),
    CONSTRAINT "kumusta_goal_lessons_stage_check" CHECK ((("stage" >= 1) AND ("stage" <= 4)))
);


ALTER TABLE "public"."kumusta_goal_lessons" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_goal_lessons" IS 'Qwen-authored goal curriculum. Four progressive stages, ten lessons each, with regional versions. Automated review is recorded honestly; it is not native-speaker certification.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_learner_states" (
    "user_id" "uuid" NOT NULL,
    "accent" "text" NOT NULL,
    "goal" "text" NOT NULL,
    "self_assessed_level" "text" NOT NULL,
    "estimated_level" numeric(3,2) NOT NULL,
    "target_level" smallint NOT NULL,
    "challenge_preference" "text" DEFAULT 'balanced'::"text" NOT NULL,
    "challenge_offset" numeric(3,2) DEFAULT 0 NOT NULL,
    "speech_speed" "text" DEFAULT 'natural'::"text" NOT NULL,
    "skill_mastery" "jsonb" DEFAULT '{"speaking": 0, "listening": 0, "vocabulary": 0, "automaticity": 0}'::"jsonb" NOT NULL,
    "completed_lessons" integer DEFAULT 0 NOT NULL,
    "feedback_count" integer DEFAULT 0 NOT NULL,
    "state_version" integer DEFAULT 1 NOT NULL,
    "last_generated_at" timestamp with time zone,
    "last_completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "next_topic_preference" "text",
    "next_topic_requested_at" timestamp with time zone,
    CONSTRAINT "kumusta_learner_states_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_learner_states_challenge_offset_check" CHECK ((("challenge_offset" >= '-1.5'::numeric) AND ("challenge_offset" <= 1.5))),
    CONSTRAINT "kumusta_learner_states_challenge_preference_check" CHECK (("challenge_preference" = ANY (ARRAY['gentle'::"text", 'balanced'::"text", 'stretch'::"text"]))),
    CONSTRAINT "kumusta_learner_states_completed_lessons_check" CHECK (("completed_lessons" >= 0)),
    CONSTRAINT "kumusta_learner_states_estimated_level_check" CHECK ((("estimated_level" >= (1)::numeric) AND ("estimated_level" <= (5)::numeric))),
    CONSTRAINT "kumusta_learner_states_feedback_count_check" CHECK (("feedback_count" >= 0)),
    CONSTRAINT "kumusta_learner_states_goal_check" CHECK (("goal" = ANY (ARRAY['family'::"text", 'lifeInVietnam'::"text", 'travel'::"text", 'partner'::"text", 'work'::"text", 'culture'::"text"]))),
    CONSTRAINT "kumusta_learner_states_next_topic_preference_check" CHECK ((("next_topic_preference" IS NULL) OR ((("char_length"("btrim"("next_topic_preference")) >= 3) AND ("char_length"("btrim"("next_topic_preference")) <= 200)) AND ("next_topic_preference" = "btrim"("next_topic_preference"))))),
    CONSTRAINT "kumusta_learner_states_self_assessed_level_check" CHECK (("self_assessed_level" = ANY (ARRAY['new'::"text", 'familiar'::"text", 'conversational'::"text", 'rusty'::"text"]))),
    CONSTRAINT "kumusta_learner_states_skill_mastery_check" CHECK ((("jsonb_typeof"("skill_mastery") = 'object'::"text") AND ("octet_length"(("skill_mastery")::"text") <= 4096))),
    CONSTRAINT "kumusta_learner_states_speech_speed_check" CHECK (("speech_speed" = ANY (ARRAY['slow'::"text", 'natural'::"text", 'fast'::"text"]))),
    CONSTRAINT "kumusta_learner_states_state_version_check" CHECK (("state_version" > 0)),
    CONSTRAINT "kumusta_learner_states_target_level_check" CHECK ((("target_level" >= 1) AND ("target_level" <= 5)))
);


ALTER TABLE "public"."kumusta_learner_states" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_learner_states" IS 'Private adaptive-learning snapshot. Updated deterministically; never replaced by unvalidated model output.';



COMMENT ON COLUMN "public"."kumusta_learner_states"."next_topic_preference" IS 'Optional untrusted learner topic request, normalized and bounded to the iOS 200-character limit.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_learning_preferences" (
    "user_id" "uuid" NOT NULL,
    "accent" "text" NOT NULL,
    "preferred_voice_id" "text" NOT NULL,
    "goal" "text" NOT NULL,
    "self_assessed_level" "text" NOT NULL,
    "daily_minutes" smallint NOT NULL,
    "reminder_enabled" boolean DEFAULT false NOT NULL,
    "reminder_local_time" time without time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target_level" smallint DEFAULT 4 NOT NULL,
    "challenge_preference" "text" DEFAULT 'balanced'::"text" NOT NULL,
    CONSTRAINT "kumusta_learning_preferences_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text", 'both'::"text"]))),
    CONSTRAINT "kumusta_learning_preferences_challenge_preference_check" CHECK (("challenge_preference" = ANY (ARRAY['gentle'::"text", 'balanced'::"text", 'stretch'::"text"]))),
    CONSTRAINT "kumusta_learning_preferences_daily_minutes_check" CHECK (("daily_minutes" = ANY (ARRAY[3, 5, 7, 10]))),
    CONSTRAINT "kumusta_learning_preferences_goal_check" CHECK (("goal" = ANY (ARRAY['family'::"text", 'lifeInVietnam'::"text", 'travel'::"text", 'partner'::"text", 'work'::"text", 'culture'::"text"]))),
    CONSTRAINT "kumusta_learning_preferences_preferred_voice_id_check" CHECK (("preferred_voice_id" = ANY (ARRAY['6Xq32rHt6oAu98TBDKfr'::"text", 'LD1UihCXvSlUL4h8DOmk'::"text"]))),
    CONSTRAINT "kumusta_learning_preferences_self_assessed_level_check" CHECK (("self_assessed_level" = ANY (ARRAY['new'::"text", 'familiar'::"text", 'conversational'::"text", 'rusty'::"text"]))),
    CONSTRAINT "kumusta_learning_preferences_target_level_check" CHECK ((("target_level" >= 1) AND ("target_level" <= 5))),
    CONSTRAINT "kumusta_learning_preferences_voice_accent_check" CHECK (((("accent" = 'southern'::"text") AND ("preferred_voice_id" = '6Xq32rHt6oAu98TBDKfr'::"text")) OR (("accent" = 'northern'::"text") AND ("preferred_voice_id" = 'LD1UihCXvSlUL4h8DOmk'::"text")) OR ("accent" = 'both'::"text")))
);


ALTER TABLE "public"."kumusta_learning_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_learning_preferences" IS 'Learning-plan settings. Voice IDs are restricted to the approved female Southern and Northern voices.';



COMMENT ON COLUMN "public"."kumusta_learning_preferences"."goal" IS 'Stable client goal enum shared with the English v1 onboarding flow.';



COMMENT ON COLUMN "public"."kumusta_learning_preferences"."self_assessed_level" IS 'Stable client level enum; controls pacing and hint behavior.';



COMMENT ON COLUMN "public"."kumusta_learning_preferences"."daily_minutes" IS 'Daily ear-time plan: 3, 5, 7, or 10 minutes.';



COMMENT ON COLUMN "public"."kumusta_learning_preferences"."target_level" IS 'Learner-selected destination used by the adaptive curriculum, not a test score.';



COMMENT ON COLUMN "public"."kumusta_learning_preferences"."challenge_preference" IS 'Baseline preference; explicit post-session feedback continuously adjusts the effective challenge.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_lesson_generation_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_request_id" "uuid" NOT NULL,
    "trigger" "text" NOT NULL,
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "requested_count" smallint NOT NULL,
    "learner_snapshot" "jsonb" NOT NULL,
    "model" "text",
    "prompt_version" integer NOT NULL,
    "attempt_count" smallint DEFAULT 0 NOT NULL,
    "error_code" "text",
    "started_at" timestamp with time zone,
    "finished_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_lesson_generation_jobs_attempt_count_check" CHECK ((("attempt_count" >= 0) AND ("attempt_count" <= 3))),
    CONSTRAINT "kumusta_lesson_generation_jobs_error_code_check" CHECK ((("error_code" IS NULL) OR ("error_code" ~ '^[a-z][a-z0-9_]{1,79}$'::"text"))),
    CONSTRAINT "kumusta_lesson_generation_jobs_learner_snapshot_check" CHECK ((("jsonb_typeof"("learner_snapshot") = 'object'::"text") AND ("octet_length"(("learner_snapshot")::"text") <= 16384))),
    CONSTRAINT "kumusta_lesson_generation_jobs_model_check" CHECK ((("model" IS NULL) OR (("char_length"("model") >= 1) AND ("char_length"("model") <= 120)))),
    CONSTRAINT "kumusta_lesson_generation_jobs_prompt_version_check" CHECK (("prompt_version" > 0)),
    CONSTRAINT "kumusta_lesson_generation_jobs_requested_count_check" CHECK ((("requested_count" >= 1) AND ("requested_count" <= 3))),
    CONSTRAINT "kumusta_lesson_generation_jobs_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'generating'::"text", 'completed'::"text", 'failed'::"text", 'superseded'::"text"]))),
    CONSTRAINT "kumusta_lesson_generation_jobs_trigger_check" CHECK (("trigger" = ANY (ARRAY['initial'::"text", 'queue_low'::"text", 'lesson_completed'::"text", 'difficulty_changed'::"text", 'manual_refresh'::"text"])))
);


ALTER TABLE "public"."kumusta_lesson_generation_jobs" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_lesson_generation_jobs" IS 'Idempotent generation audit records. Stores sanitized error codes, never provider payloads or secrets.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_lesson_generation_quota_overrides" (
    "user_id" "uuid" NOT NULL,
    "minute_limit" integer NOT NULL,
    "daily_limit" integer NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_lesson_generation_quota_overrides_daily_limit_check" CHECK ((("daily_limit" >= 1) AND ("daily_limit" <= 10000000))),
    CONSTRAINT "kumusta_lesson_generation_quota_overrides_minute_limit_check" CHECK ((("minute_limit" >= 1) AND ("minute_limit" <= 10000000)))
);


ALTER TABLE "public"."kumusta_lesson_generation_quota_overrides" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_lesson_generation_quota_overrides" IS 'Temporary service-only lesson generation limits for explicitly authorized development accounts.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "level" "text" NOT NULL,
    "accent" "text" NOT NULL,
    "estimated_minutes" smallint NOT NULL,
    "sort_order" integer NOT NULL,
    "is_published" boolean DEFAULT false NOT NULL,
    "content_version" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "roadmap_version" "text",
    "unit_slug" "text",
    "unit_title" "text",
    "unit_order" smallint,
    "lesson_order" smallint,
    "schema_version" integer,
    "prompt_version" integer,
    "difficulty" numeric(3,2),
    "content_source" "text",
    "review_status" "text" DEFAULT 'native_speaker_review_required'::"text" NOT NULL,
    "editorial_review" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "content" "jsonb",
    "content_hash" "text",
    "validation" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "kumusta_lessons_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text", 'both'::"text"]))),
    CONSTRAINT "kumusta_lessons_content_version_check" CHECK (("content_version" > 0)),
    CONSTRAINT "kumusta_lessons_estimated_minutes_check" CHECK ((("estimated_minutes" >= 1) AND ("estimated_minutes" <= 30))),
    CONSTRAINT "kumusta_lessons_level_check" CHECK (("level" = ANY (ARRAY['new'::"text", 'familiar'::"text", 'conversational'::"text", 'rusty'::"text"]))),
    CONSTRAINT "kumusta_lessons_roadmap_shape_check" CHECK ((("roadmap_version" IS NULL) OR (("roadmap_version" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND ("unit_slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND (("char_length"("btrim"("unit_title")) >= 1) AND ("char_length"("btrim"("unit_title")) <= 120)) AND (("unit_order" >= 1) AND ("unit_order" <= 50)) AND (("lesson_order" >= 1) AND ("lesson_order" <= 500)) AND ("schema_version" > 0) AND ("prompt_version" > 0) AND (("difficulty" >= (1)::numeric) AND ("difficulty" <= (5)::numeric)) AND ("content_source" = 'authored_roadmap'::"text") AND ("jsonb_typeof"("content") = 'object'::"text") AND ("octet_length"(("content")::"text") <= 65536) AND ("content_hash" ~ '^[a-f0-9]{64}$'::"text") AND ("review_status" = ANY (ARRAY['native_speaker_review_required'::"text", 'approved'::"text", 'rejected'::"text"])) AND ("jsonb_typeof"("editorial_review") = 'object'::"text") AND ("jsonb_typeof"("validation") = 'object'::"text") AND ((NOT "is_published") OR ("review_status" = 'approved'::"text"))))),
    CONSTRAINT "kumusta_lessons_slug_check" CHECK ((("slug" ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::"text") AND ("char_length"("slug") <= 100))),
    CONSTRAINT "kumusta_lessons_sort_order_check" CHECK (("sort_order" >= 0)),
    CONSTRAINT "kumusta_lessons_summary_check" CHECK ((("char_length"("btrim"("summary")) >= 1) AND ("char_length"("btrim"("summary")) <= 500))),
    CONSTRAINT "kumusta_lessons_title_check" CHECK ((("char_length"("btrim"("title")) >= 1) AND ("char_length"("btrim"("title")) <= 120)))
);


ALTER TABLE "public"."kumusta_lessons" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_lessons" IS 'Server-curated lesson metadata; client roles have read-only access to published rows.';



COMMENT ON COLUMN "public"."kumusta_lessons"."review_status" IS 'Editorial publication gate. AI-authored curriculum remains unpublished until regional native-speaker approval.';



COMMENT ON COLUMN "public"."kumusta_lessons"."content" IS 'Normalized Kumusta lesson engine v3 JSON. Roadmap rows use the same content contract as generated lessons.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_live_account_overrides" (
    "user_id" "uuid" NOT NULL,
    "daily_limit_seconds" integer NOT NULL,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_live_account_overrides_daily_limit_seconds_check" CHECK ((("daily_limit_seconds" >= 300) AND ("daily_limit_seconds" <= 3600)))
);


ALTER TABLE "public"."kumusta_live_account_overrides" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kumusta_live_rounds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "usage_day" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accent" "text" NOT NULL,
    "topic_source" "text" NOT NULL,
    "topic" "text" DEFAULT ''::"text" NOT NULL,
    "latest_lesson" "text" DEFAULT ''::"text" NOT NULL,
    "model" "text" DEFAULT 'pipeline'::"text" NOT NULL,
    "used_seconds" integer DEFAULT 0 NOT NULL,
    "provider_seconds" numeric DEFAULT 0 NOT NULL,
    "session_count" integer DEFAULT 0 NOT NULL,
    "user_fragments" integer DEFAULT 0 NOT NULL,
    "assistant_fragments" integer DEFAULT 0 NOT NULL,
    "mute_count" integer DEFAULT 0 NOT NULL,
    "safety_stops" integer DEFAULT 0 NOT NULL,
    "bonus_seconds" integer DEFAULT 0 NOT NULL,
    "daily_limit_seconds" integer DEFAULT 300 NOT NULL,
    "latest_lesson_id" "uuid",
    CONSTRAINT "kumusta_live_rounds_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text", 'both'::"text"]))),
    CONSTRAINT "kumusta_live_rounds_assistant_fragments_check" CHECK (("assistant_fragments" >= 0)),
    CONSTRAINT "kumusta_live_rounds_bonus_seconds_check" CHECK ((("bonus_seconds" >= 0) AND ("bonus_seconds" <= 600))),
    CONSTRAINT "kumusta_live_rounds_daily_limit_seconds_check" CHECK ((("daily_limit_seconds" >= 300) AND ("daily_limit_seconds" <= 3600))),
    CONSTRAINT "kumusta_live_rounds_latest_lesson_check" CHECK (("char_length"("latest_lesson") <= 600)),
    CONSTRAINT "kumusta_live_rounds_mute_count_check" CHECK (("mute_count" >= 0)),
    CONSTRAINT "kumusta_live_rounds_provider_seconds_check" CHECK (("provider_seconds" >= (0)::numeric)),
    CONSTRAINT "kumusta_live_rounds_safety_stops_check" CHECK (("safety_stops" >= 0)),
    CONSTRAINT "kumusta_live_rounds_session_count_check" CHECK (("session_count" >= 0)),
    CONSTRAINT "kumusta_live_rounds_topic_check" CHECK (("char_length"("topic") <= 200)),
    CONSTRAINT "kumusta_live_rounds_topic_source_check" CHECK (("topic_source" = ANY (ARRAY['chosen'::"text", 'latest_lesson'::"text", 'starter'::"text"]))),
    CONSTRAINT "kumusta_live_rounds_used_seconds_check" CHECK ((("used_seconds" >= 0) AND ("used_seconds" <= 3600))),
    CONSTRAINT "kumusta_live_rounds_user_fragments_check" CHECK (("user_fragments" >= 0))
);


ALTER TABLE "public"."kumusta_live_rounds" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_live_rounds" IS 'One server-owned five-minute UTC daily live-practice round per user. Contains usage and interaction metadata, never audio.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_live_transcripts" (
    "id" bigint NOT NULL,
    "round_id" "uuid" NOT NULL,
    "session_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "speaker" "text" NOT NULL,
    "text" "text" NOT NULL,
    "start_ms" integer,
    "end_ms" integer,
    CONSTRAINT "kumusta_live_transcripts_end_ms_check" CHECK ((("end_ms" IS NULL) OR ("end_ms" >= 0))),
    CONSTRAINT "kumusta_live_transcripts_speaker_check" CHECK (("speaker" = ANY (ARRAY['user'::"text", 'assistant'::"text"]))),
    CONSTRAINT "kumusta_live_transcripts_start_ms_check" CHECK ((("start_ms" IS NULL) OR ("start_ms" >= 0))),
    CONSTRAINT "kumusta_live_transcripts_text_check" CHECK ((("char_length"("text") >= 1) AND ("char_length"("text") <= 4000)))
);


ALTER TABLE "public"."kumusta_live_transcripts" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_live_transcripts" IS 'Server-owned ordered live-practice transcript text for daily rounds. Contains no raw audio.';



ALTER TABLE "public"."kumusta_live_transcripts" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."kumusta_live_transcripts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."kumusta_onboarding_responses" (
    "user_id" "uuid" NOT NULL,
    "motivation" "text",
    "desired_outcome" "text",
    "referral_source" "text",
    "current_step" smallint DEFAULT 0 NOT NULL,
    "demo_completed" boolean DEFAULT false NOT NULL,
    "paywall_seen_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "response_version" smallint DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_onboarding_responses_current_step_check" CHECK ((("current_step" >= 0) AND ("current_step" <= 20))),
    CONSTRAINT "kumusta_onboarding_responses_desired_outcome_check" CHECK ((("desired_outcome" IS NULL) OR (("char_length"("btrim"("desired_outcome")) >= 1) AND ("char_length"("btrim"("desired_outcome")) <= 300)))),
    CONSTRAINT "kumusta_onboarding_responses_motivation_check" CHECK ((("motivation" IS NULL) OR (("char_length"("btrim"("motivation")) >= 1) AND ("char_length"("btrim"("motivation")) <= 500)))),
    CONSTRAINT "kumusta_onboarding_responses_referral_source_check" CHECK ((("referral_source" IS NULL) OR ("char_length"("referral_source") <= 80))),
    CONSTRAINT "kumusta_onboarding_responses_response_version_check" CHECK (("response_version" > 0))
);


ALTER TABLE "public"."kumusta_onboarding_responses" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_onboarding_responses" IS 'Conversion and learning-plan inputs; never stores payment credentials.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "locale" "text" DEFAULT 'en'::"text" NOT NULL,
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "onboarding_completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "avatar_seed" "text",
    CONSTRAINT "kumusta_profiles_avatar_seed_check" CHECK ((("avatar_seed" IS NULL) OR (("char_length"("btrim"("avatar_seed")) >= 1) AND ("char_length"("btrim"("avatar_seed")) <= 200)))),
    CONSTRAINT "kumusta_profiles_display_name_check" CHECK ((("display_name" IS NULL) OR (("char_length"("btrim"("display_name")) >= 1) AND ("char_length"("btrim"("display_name")) <= 60)))),
    CONSTRAINT "kumusta_profiles_locale_check" CHECK (("locale" ~ '^[a-z]{2}(-[A-Z]{2})?$'::"text")),
    CONSTRAINT "kumusta_profiles_timezone_check" CHECK ((("char_length"("timezone") >= 1) AND ("char_length"("timezone") <= 80)))
);


ALTER TABLE "public"."kumusta_profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_profiles" IS 'Minimal Kumusta user profile. Authentication credentials remain in auth.users.';



COMMENT ON COLUMN "public"."kumusta_profiles"."display_name" IS 'Optional preferred name. Empty strings are rejected and names never enter analytics.';



COMMENT ON COLUMN "public"."kumusta_profiles"."avatar_seed" IS 'Persisted DiceBear Big Ears seed. It must not contain personal profile data.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_project_api_rate_limits" (
    "scope" "text" NOT NULL,
    "window_started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "request_count" integer DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_project_api_rate_limits_request_count_check" CHECK (("request_count" > 0)),
    CONSTRAINT "kumusta_project_api_rate_limits_scope_check" CHECK (("scope" = ANY (ARRAY['elevenlabs_tts_project_daily'::"text", 'elevenlabs_stt_project_daily'::"text"])))
);


ALTER TABLE "public"."kumusta_project_api_rate_limits" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_project_api_rate_limits" IS 'Aggregate provider circuit breakers. Service-role only; contains no user data.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_revenuecat_events" (
    "event_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "app_user_id" "text" NOT NULL,
    "environment" "text",
    "payload" "jsonb" NOT NULL,
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "processing_error" "text",
    CONSTRAINT "kumusta_revenuecat_events_app_user_id_check" CHECK ((("char_length"("app_user_id") >= 1) AND ("char_length"("app_user_id") <= 200))),
    CONSTRAINT "kumusta_revenuecat_events_environment_check" CHECK ((("environment" IS NULL) OR ("environment" = ANY (ARRAY['SANDBOX'::"text", 'PRODUCTION'::"text"])))),
    CONSTRAINT "kumusta_revenuecat_events_event_id_check" CHECK ((("char_length"("event_id") >= 1) AND ("char_length"("event_id") <= 200))),
    CONSTRAINT "kumusta_revenuecat_events_event_type_check" CHECK ((("char_length"("event_type") >= 1) AND ("char_length"("event_type") <= 100))),
    CONSTRAINT "kumusta_revenuecat_events_payload_check" CHECK ((("jsonb_typeof"("payload") = 'object'::"text") AND ("octet_length"(("payload")::"text") <= 524288))),
    CONSTRAINT "kumusta_revenuecat_events_processing_error_check" CHECK ((("processing_error" IS NULL) OR ("char_length"("processing_error") <= 2000)))
);


ALTER TABLE "public"."kumusta_revenuecat_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_revenuecat_events" IS 'Idempotent service-only RevenueCat webhook audit log. Never exposed to mobile clients.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_review_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "vocabulary_id" "uuid" NOT NULL,
    "session_id" "uuid",
    "rating" "text" NOT NULL,
    "response_ms" integer,
    "previous_due_at" timestamp with time zone,
    "next_due_at" timestamp with time zone NOT NULL,
    "interval_days" integer NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "client_event_id" "uuid" NOT NULL,
    CONSTRAINT "kumusta_review_events_interval_days_check" CHECK ((("interval_days" >= 0) AND ("interval_days" <= 3650))),
    CONSTRAINT "kumusta_review_events_rating_check" CHECK (("rating" = ANY (ARRAY['again'::"text", 'almost'::"text", 'got_it'::"text"]))),
    CONSTRAINT "kumusta_review_events_response_ms_check" CHECK ((("response_ms" IS NULL) OR (("response_ms" >= 0) AND ("response_ms" <= 600000))))
);


ALTER TABLE "public"."kumusta_review_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_review_events" IS 'Append-only review history used to audit and tune spaced repetition.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_subscription_cancellation_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_subscription_cancellation_feedback_reason_check" CHECK ((("char_length"("btrim"("reason")) >= 1) AND ("char_length"("btrim"("reason")) <= 500)))
);


ALTER TABLE "public"."kumusta_subscription_cancellation_feedback" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_subscription_cancellation_feedback" IS 'Cancellation feedback submitted by registered or anonymous authenticated users before opening Apple subscription settings.';



COMMENT ON COLUMN "public"."kumusta_subscription_cancellation_feedback"."reason" IS 'User-provided cancellation explanation, limited to 500 characters.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_tts_cache" (
    "cache_key" "text" NOT NULL,
    "text_value" "text" NOT NULL,
    "accent" "text" NOT NULL,
    "speed" "text" NOT NULL,
    "voice_id" "text" NOT NULL,
    "model_id" "text" NOT NULL,
    "output_format" "text" NOT NULL,
    "settings_version" "text" NOT NULL,
    "object_path" "text" NOT NULL,
    "status" "text" DEFAULT 'generating'::"text" NOT NULL,
    "generation_token" "uuid",
    "generation_started_at" timestamp with time zone,
    "byte_size" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_tts_cache_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text"]))),
    CONSTRAINT "kumusta_tts_cache_byte_size_check" CHECK ((("byte_size" IS NULL) OR (("byte_size" >= 129) AND ("byte_size" <= 3000000)))),
    CONSTRAINT "kumusta_tts_cache_cache_key_check" CHECK (("cache_key" ~ '^[0-9a-f]{64}$'::"text")),
    CONSTRAINT "kumusta_tts_cache_object_path_check" CHECK (("object_path" ~ '^v[12]/[0-9a-f]{64}\.mp3$'::"text")),
    CONSTRAINT "kumusta_tts_cache_speed_check" CHECK (("speed" = ANY (ARRAY['slow'::"text", 'natural'::"text", 'fast'::"text"]))),
    CONSTRAINT "kumusta_tts_cache_status_check" CHECK (("status" = ANY (ARRAY['generating'::"text", 'ready'::"text", 'failed'::"text"]))),
    CONSTRAINT "kumusta_tts_cache_text_value_check" CHECK ((("char_length"("text_value") >= 1) AND ("char_length"("text_value") <= 500))),
    CONSTRAINT "kumusta_tts_cache_voice_id_check" CHECK (("voice_id" = ANY (ARRAY['BfchfKCM67ImGdaJ1smU'::"text", 'BlZK9tHPU6XXjwOSIiYA'::"text", '6Xq32rHt6oAu98TBDKfr'::"text", 'LD1UihCXvSlUL4h8DOmk'::"text"])))
);


ALTER TABLE "public"."kumusta_tts_cache" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_tts_cache" IS 'Shared, accent-aware Vietnamese TTS audio cache. Audio bytes live in Supabase Storage.';



COMMENT ON COLUMN "public"."kumusta_tts_cache"."cache_key" IS 'SHA-256 of the versioned text, accent, voice, speed, model, format, and settings.';



COMMENT ON COLUMN "public"."kumusta_tts_cache"."object_path" IS 'Private kumusta-tts bucket path for the immutable MP3 object.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_user_lesson_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "generated_lesson_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'ready'::"text" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "priority" smallint DEFAULT 0 NOT NULL,
    CONSTRAINT "kumusta_queue_completed_check" CHECK ((("completed_at" IS NULL) OR ("completed_at" >= "assigned_at"))),
    CONSTRAINT "kumusta_queue_started_check" CHECK ((("started_at" IS NULL) OR ("started_at" >= "assigned_at"))),
    CONSTRAINT "kumusta_user_lesson_queue_priority_check" CHECK ((("priority" >= 0) AND ("priority" <= 100))),
    CONSTRAINT "kumusta_user_lesson_queue_status_check" CHECK (("status" = ANY (ARRAY['ready'::"text", 'started'::"text", 'completed'::"text", 'skipped'::"text"])))
);


ALTER TABLE "public"."kumusta_user_lesson_queue" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_user_lesson_queue" IS 'Per-user pre-generated lesson queue. Three ready lessons is the operating target.';



COMMENT ON COLUMN "public"."kumusta_user_lesson_queue"."priority" IS 'Delivery priority. Explicit learner topic requests outrank the generic pre-generated queue without discarding it.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_user_state" (
    "user_id" "uuid" NOT NULL,
    "schema_version" integer DEFAULT 1 NOT NULL,
    "state" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_user_state_schema_version_check" CHECK (("schema_version" > 0)),
    CONSTRAINT "kumusta_user_state_state_check" CHECK ((("jsonb_typeof"("state") = 'object'::"text") AND ("octet_length"(("state")::"text") <= 2000000)))
);


ALTER TABLE "public"."kumusta_user_state" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_user_state" IS 'Portable account state for client-owned learning progress that does not yet have a normalized relation.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_user_vocabulary" (
    "user_id" "uuid" NOT NULL,
    "vocabulary_id" "uuid" NOT NULL,
    "state" "text" DEFAULT 'learning'::"text" NOT NULL,
    "mastery" numeric(4,3) DEFAULT 0 NOT NULL,
    "ease_factor" numeric(4,2) DEFAULT 2.50 NOT NULL,
    "interval_days" integer DEFAULT 0 NOT NULL,
    "review_count" integer DEFAULT 0 NOT NULL,
    "lapse_count" integer DEFAULT 0 NOT NULL,
    "due_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_user_vocabulary_ease_factor_check" CHECK ((("ease_factor" >= 1.30) AND ("ease_factor" <= 3.50))),
    CONSTRAINT "kumusta_user_vocabulary_interval_days_check" CHECK ((("interval_days" >= 0) AND ("interval_days" <= 3650))),
    CONSTRAINT "kumusta_user_vocabulary_lapse_count_check" CHECK (("lapse_count" >= 0)),
    CONSTRAINT "kumusta_user_vocabulary_mastery_check" CHECK ((("mastery" >= (0)::numeric) AND ("mastery" <= (1)::numeric))),
    CONSTRAINT "kumusta_user_vocabulary_review_count_check" CHECK (("review_count" >= 0)),
    CONSTRAINT "kumusta_user_vocabulary_state_check" CHECK (("state" = ANY (ARRAY['new'::"text", 'learning'::"text", 'review'::"text", 'mastered'::"text", 'paused'::"text"])))
);


ALTER TABLE "public"."kumusta_user_vocabulary" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_user_vocabulary" IS 'Per-user spaced-repetition state; the client can sync only its own rows.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_user_xp_totals" (
    "user_id" "uuid" NOT NULL,
    "lifetime_xp" bigint DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_user_xp_totals_lifetime_xp_check" CHECK (("lifetime_xp" >= 0))
);


ALTER TABLE "public"."kumusta_user_xp_totals" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_user_xp_totals" IS 'Materialized lifetime XP total for fast profile reads and award responses.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_vocabulary" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vietnamese" "text" NOT NULL,
    "english" "text" NOT NULL,
    "pronunciation_hint" "text",
    "part_of_speech" "text",
    "accent" "text" NOT NULL,
    "audio_object_path" "text",
    "usage_example_vi" "text",
    "usage_example_en" "text",
    "is_published" boolean DEFAULT false NOT NULL,
    "content_version" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_vocabulary_accent_check" CHECK (("accent" = ANY (ARRAY['southern'::"text", 'northern'::"text", 'both'::"text"]))),
    CONSTRAINT "kumusta_vocabulary_audio_object_path_check" CHECK ((("audio_object_path" IS NULL) OR (("audio_object_path" ~ '^kumusta-audio/[a-zA-Z0-9/_-]+\.(mp3|m4a|wav)$'::"text") AND ("char_length"("audio_object_path") <= 500)))),
    CONSTRAINT "kumusta_vocabulary_content_version_check" CHECK (("content_version" > 0)),
    CONSTRAINT "kumusta_vocabulary_english_check" CHECK ((("char_length"("btrim"("english")) >= 1) AND ("char_length"("btrim"("english")) <= 300))),
    CONSTRAINT "kumusta_vocabulary_part_of_speech_check" CHECK ((("part_of_speech" IS NULL) OR ("part_of_speech" = ANY (ARRAY['noun'::"text", 'verb'::"text", 'adjective'::"text", 'adverb'::"text", 'pronoun'::"text", 'classifier'::"text", 'particle'::"text", 'phrase'::"text", 'other'::"text"])))),
    CONSTRAINT "kumusta_vocabulary_pronunciation_hint_check" CHECK ((("pronunciation_hint" IS NULL) OR ("char_length"("pronunciation_hint") <= 400))),
    CONSTRAINT "kumusta_vocabulary_usage_example_en_check" CHECK ((("usage_example_en" IS NULL) OR ("char_length"("usage_example_en") <= 500))),
    CONSTRAINT "kumusta_vocabulary_usage_example_vi_check" CHECK ((("usage_example_vi" IS NULL) OR ("char_length"("usage_example_vi") <= 500))),
    CONSTRAINT "kumusta_vocabulary_vietnamese_check" CHECK ((("char_length"("btrim"("vietnamese")) >= 1) AND ("char_length"("btrim"("vietnamese")) <= 200)))
);


ALTER TABLE "public"."kumusta_vocabulary" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_vocabulary" IS 'Server-curated Vietnamese vocabulary and phrases.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_xp_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "amount" integer NOT NULL,
    "reason_code" "text" NOT NULL,
    "source_id" "text",
    "idempotency_key" "text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_xp_events_amount_check" CHECK ((("amount" >= 1) AND ("amount" <= 10000))),
    CONSTRAINT "kumusta_xp_events_idempotency_key_check" CHECK ((("char_length"("btrim"("idempotency_key")) >= 1) AND ("char_length"("btrim"("idempotency_key")) <= 200))),
    CONSTRAINT "kumusta_xp_events_metadata_check" CHECK ((("jsonb_typeof"("metadata") = 'object'::"text") AND ("octet_length"(("metadata")::"text") <= 8000))),
    CONSTRAINT "kumusta_xp_events_reason_code_check" CHECK (("reason_code" ~ '^[a-z][a-z0-9_]{2,79}$'::"text")),
    CONSTRAINT "kumusta_xp_events_source_id_check" CHECK ((("source_id" IS NULL) OR (("char_length"("btrim"("source_id")) >= 1) AND ("char_length"("btrim"("source_id")) <= 200))))
);


ALTER TABLE "public"."kumusta_xp_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_xp_events" IS 'Append-only XP ledger. Historical completions were backfilled from lesson queue and completed vocabulary sessions.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_xp_period_totals" (
    "user_id" "uuid" NOT NULL,
    "period_kind" "text" NOT NULL,
    "period_key" "text" NOT NULL,
    "xp" bigint DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_xp_period_totals_check" CHECK (((("period_kind" = 'all_time'::"text") AND ("period_key" = 'all_time'::"text")) OR (("period_kind" = 'weekly'::"text") AND ("period_key" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'::"text")) OR (("period_kind" = 'monthly'::"text") AND ("period_key" ~ '^[0-9]{4}-[0-9]{2}$'::"text")))),
    CONSTRAINT "kumusta_xp_period_totals_period_kind_check" CHECK (("period_kind" = ANY (ARRAY['weekly'::"text", 'monthly'::"text", 'all_time'::"text"]))),
    CONSTRAINT "kumusta_xp_period_totals_xp_check" CHECK (("xp" >= 0))
);


ALTER TABLE "public"."kumusta_xp_period_totals" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_xp_period_totals" IS 'Materialized UTC weekly, monthly, and lifetime XP totals used by leaderboard queries.';



CREATE OR REPLACE VIEW "public"."kumusta_xp_leaderboard" AS
 SELECT "totals"."period_kind",
    "totals"."period_key",
    "rank"() OVER (PARTITION BY "totals"."period_kind", "totals"."period_key" ORDER BY "totals"."xp" DESC, "totals"."user_id") AS "leaderboard_rank",
    "totals"."user_id",
    "profiles"."display_name",
    "profiles"."avatar_seed",
    "totals"."xp",
    "totals"."updated_at"
   FROM ("public"."kumusta_xp_period_totals" "totals"
     JOIN "public"."kumusta_profiles" "profiles" ON (("profiles"."id" = "totals"."user_id")))
  WHERE ("profiles"."onboarding_completed_at" IS NOT NULL);


ALTER VIEW "public"."kumusta_xp_leaderboard" OWNER TO "postgres";


COMMENT ON VIEW "public"."kumusta_xp_leaderboard" IS 'Safe leaderboard projection with display names, persisted avatar seeds, and XP only.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_xp_leaderboard_signal" (
    "id" boolean DEFAULT true NOT NULL,
    "all_time_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_xp_leaderboard_signal_id_check" CHECK ("id")
);


ALTER TABLE "public"."kumusta_xp_leaderboard_signal" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_xp_leaderboard_signal" IS 'Privacy-safe Realtime signal for refreshing the all-time XP leaderboard view.';



CREATE TABLE IF NOT EXISTS "public"."kumusta_xp_rules" (
    "code" "text" NOT NULL,
    "xp_amount" integer NOT NULL,
    "daily_cap" integer,
    "is_active" boolean DEFAULT false NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_until" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kumusta_xp_rules_code_check" CHECK (("code" ~ '^[a-z][a-z0-9_]{2,79}$'::"text")),
    CONSTRAINT "kumusta_xp_rules_daily_cap_check" CHECK ((("daily_cap" IS NULL) OR (("daily_cap" >= 1) AND ("daily_cap" <= 100000)))),
    CONSTRAINT "kumusta_xp_rules_effective_window_check" CHECK ((("effective_until" IS NULL) OR ("effective_until" > "effective_from"))),
    CONSTRAINT "kumusta_xp_rules_metadata_check" CHECK ((("jsonb_typeof"("metadata") = 'object'::"text") AND ("octet_length"(("metadata")::"text") <= 4000))),
    CONSTRAINT "kumusta_xp_rules_xp_amount_check" CHECK ((("xp_amount" >= 1) AND ("xp_amount" <= 10000)))
);


ALTER TABLE "public"."kumusta_xp_rules" OWNER TO "postgres";


COMMENT ON TABLE "public"."kumusta_xp_rules" IS 'Server-managed XP award rules. Badge and activity values are configured separately from the XP ledger.';



ALTER TABLE ONLY "public"."kumusta_analytics_events"
    ADD CONSTRAINT "kumusta_analytics_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_analytics_events"
    ADD CONSTRAINT "kumusta_analytics_events_user_id_client_event_id_key" UNIQUE ("user_id", "client_event_id");



ALTER TABLE ONLY "public"."kumusta_api_rate_limits"
    ADD CONSTRAINT "kumusta_api_rate_limits_pkey" PRIMARY KEY ("user_id", "scope");



ALTER TABLE ONLY "public"."kumusta_app_sessions"
    ADD CONSTRAINT "kumusta_app_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_app_sessions"
    ADD CONSTRAINT "kumusta_app_sessions_user_id_client_session_id_key" UNIQUE ("user_id", "client_session_id");



ALTER TABLE ONLY "public"."kumusta_daily_progress"
    ADD CONSTRAINT "kumusta_daily_progress_pkey" PRIMARY KEY ("user_id", "progress_date");



ALTER TABLE ONLY "public"."kumusta_difficulty_feedback"
    ADD CONSTRAINT "kumusta_difficulty_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_difficulty_feedback"
    ADD CONSTRAINT "kumusta_difficulty_feedback_user_id_client_event_id_key" UNIQUE ("user_id", "client_event_id");



ALTER TABLE ONLY "public"."kumusta_email_jobs"
    ADD CONSTRAINT "kumusta_email_jobs_event_id_email_type_key" UNIQUE ("event_id", "email_type");



ALTER TABLE ONLY "public"."kumusta_email_jobs"
    ADD CONSTRAINT "kumusta_email_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_entitlements"
    ADD CONSTRAINT "kumusta_entitlements_pkey" PRIMARY KEY ("user_id", "entitlement_id");



ALTER TABLE ONLY "public"."kumusta_flashcard_sessions"
    ADD CONSTRAINT "kumusta_flashcard_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_flashcard_sessions"
    ADD CONSTRAINT "kumusta_flashcard_sessions_user_id_client_session_id_key" UNIQUE ("user_id", "client_session_id");



ALTER TABLE ONLY "public"."kumusta_foundation_course_progress"
    ADD CONSTRAINT "kumusta_foundation_course_progress_pkey" PRIMARY KEY ("user_id", "course_id");



ALTER TABLE ONLY "public"."kumusta_foundation_courses"
    ADD CONSTRAINT "kumusta_foundation_courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_foundation_courses"
    ADD CONSTRAINT "kumusta_foundation_courses_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."kumusta_foundation_item_progress"
    ADD CONSTRAINT "kumusta_foundation_item_progress_pkey" PRIMARY KEY ("user_id", "item_id", "accent");



ALTER TABLE ONLY "public"."kumusta_foundation_item_variants"
    ADD CONSTRAINT "kumusta_foundation_item_variants_item_id_accent_key" UNIQUE ("item_id", "accent");



ALTER TABLE ONLY "public"."kumusta_foundation_item_variants"
    ADD CONSTRAINT "kumusta_foundation_item_variants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_foundation_items"
    ADD CONSTRAINT "kumusta_foundation_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_foundation_items"
    ADD CONSTRAINT "kumusta_foundation_items_unit_id_position_key" UNIQUE ("unit_id", "position");



ALTER TABLE ONLY "public"."kumusta_foundation_items"
    ADD CONSTRAINT "kumusta_foundation_items_unit_id_slug_key" UNIQUE ("unit_id", "slug");



ALTER TABLE ONLY "public"."kumusta_foundation_units"
    ADD CONSTRAINT "kumusta_foundation_units_course_id_position_key" UNIQUE ("course_id", "position");



ALTER TABLE ONLY "public"."kumusta_foundation_units"
    ADD CONSTRAINT "kumusta_foundation_units_course_id_slug_key" UNIQUE ("course_id", "slug");



ALTER TABLE ONLY "public"."kumusta_foundation_units"
    ADD CONSTRAINT "kumusta_foundation_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_id_user_unique" UNIQUE ("id", "user_id");



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_user_id_content_hash_key" UNIQUE ("user_id", "content_hash");



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_progress"
    ADD CONSTRAINT "kumusta_generated_vocabulary_progress_pkey" PRIMARY KEY ("user_id", "vocabulary_id");



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_review_events"
    ADD CONSTRAINT "kumusta_generated_vocabulary_review__user_id_client_event_id_key" UNIQUE ("user_id", "client_event_id");



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_review_events"
    ADD CONSTRAINT "kumusta_generated_vocabulary_review_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_lesson_generation_jobs"
    ADD CONSTRAINT "kumusta_generation_jobs_id_user_unique" UNIQUE ("id", "user_id");



ALTER TABLE ONLY "public"."kumusta_goal_lesson_translations"
    ADD CONSTRAINT "kumusta_goal_lesson_translations_pkey" PRIMARY KEY ("lesson_id", "locale");



ALTER TABLE ONLY "public"."kumusta_goal_lessons"
    ADD CONSTRAINT "kumusta_goal_lessons_curriculum_version_goal_stage_accent_le_key" UNIQUE ("curriculum_version", "goal", "stage", "accent", "lesson_order");



ALTER TABLE ONLY "public"."kumusta_goal_lessons"
    ADD CONSTRAINT "kumusta_goal_lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_learner_states"
    ADD CONSTRAINT "kumusta_learner_states_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_learning_preferences"
    ADD CONSTRAINT "kumusta_learning_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_id_user_key" UNIQUE ("id", "user_id");



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_user_id_client_session_id_key" UNIQUE ("user_id", "client_session_id");



ALTER TABLE ONLY "public"."kumusta_lesson_generation_jobs"
    ADD CONSTRAINT "kumusta_lesson_generation_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_lesson_generation_jobs"
    ADD CONSTRAINT "kumusta_lesson_generation_jobs_user_id_client_request_id_key" UNIQUE ("user_id", "client_request_id");



ALTER TABLE ONLY "public"."kumusta_lesson_generation_quota_overrides"
    ADD CONSTRAINT "kumusta_lesson_generation_quota_overrides_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_lessons"
    ADD CONSTRAINT "kumusta_lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_lessons"
    ADD CONSTRAINT "kumusta_lessons_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."kumusta_live_account_overrides"
    ADD CONSTRAINT "kumusta_live_account_overrides_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_live_rounds"
    ADD CONSTRAINT "kumusta_live_rounds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_live_rounds"
    ADD CONSTRAINT "kumusta_live_rounds_user_id_usage_day_key" UNIQUE ("user_id", "usage_day");



ALTER TABLE ONLY "public"."kumusta_live_sessions"
    ADD CONSTRAINT "kumusta_live_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_live_transcripts"
    ADD CONSTRAINT "kumusta_live_transcripts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_onboarding_responses"
    ADD CONSTRAINT "kumusta_onboarding_responses_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_profiles"
    ADD CONSTRAINT "kumusta_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_project_api_rate_limits"
    ADD CONSTRAINT "kumusta_project_api_rate_limits_pkey" PRIMARY KEY ("scope");



ALTER TABLE ONLY "public"."kumusta_revenuecat_events"
    ADD CONSTRAINT "kumusta_revenuecat_events_pkey" PRIMARY KEY ("event_id");



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_user_id_client_event_id_key" UNIQUE ("user_id", "client_event_id");



ALTER TABLE ONLY "public"."kumusta_subscription_cancellation_feedback"
    ADD CONSTRAINT "kumusta_subscription_cancellation_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_tts_cache"
    ADD CONSTRAINT "kumusta_tts_cache_object_path_key" UNIQUE ("object_path");



ALTER TABLE ONLY "public"."kumusta_tts_cache"
    ADD CONSTRAINT "kumusta_tts_cache_pkey" PRIMARY KEY ("cache_key");



ALTER TABLE ONLY "public"."kumusta_user_lesson_queue"
    ADD CONSTRAINT "kumusta_user_lesson_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_user_lesson_queue"
    ADD CONSTRAINT "kumusta_user_lesson_queue_user_id_generated_lesson_id_key" UNIQUE ("user_id", "generated_lesson_id");



ALTER TABLE ONLY "public"."kumusta_user_state"
    ADD CONSTRAINT "kumusta_user_state_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_user_vocabulary"
    ADD CONSTRAINT "kumusta_user_vocabulary_pkey" PRIMARY KEY ("user_id", "vocabulary_id");



ALTER TABLE ONLY "public"."kumusta_user_xp_totals"
    ADD CONSTRAINT "kumusta_user_xp_totals_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."kumusta_vocabulary"
    ADD CONSTRAINT "kumusta_vocabulary_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_xp_events"
    ADD CONSTRAINT "kumusta_xp_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_xp_events"
    ADD CONSTRAINT "kumusta_xp_events_user_id_idempotency_key_key" UNIQUE ("user_id", "idempotency_key");



ALTER TABLE ONLY "public"."kumusta_xp_leaderboard_signal"
    ADD CONSTRAINT "kumusta_xp_leaderboard_signal_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kumusta_xp_period_totals"
    ADD CONSTRAINT "kumusta_xp_period_totals_pkey" PRIMARY KEY ("user_id", "period_kind", "period_key");



ALTER TABLE ONLY "public"."kumusta_xp_rules"
    ADD CONSTRAINT "kumusta_xp_rules_pkey" PRIMARY KEY ("code");



CREATE INDEX "kumusta_analytics_events_client_session_idx" ON "public"."kumusta_analytics_events" USING "btree" ("user_id", "client_session_id", "occurred_at") WHERE ("client_session_id" IS NOT NULL);



CREATE INDEX "kumusta_analytics_events_name_occurred_idx" ON "public"."kumusta_analytics_events" USING "btree" ("event_name", "occurred_at" DESC);



CREATE INDEX "kumusta_analytics_events_name_received_idx" ON "public"."kumusta_analytics_events" USING "btree" ("event_name", "received_at" DESC);



CREATE INDEX "kumusta_analytics_events_session_idx" ON "public"."kumusta_analytics_events" USING "btree" ("session_id", "occurred_at") WHERE ("session_id" IS NOT NULL);



CREATE INDEX "kumusta_analytics_events_user_occurred_idx" ON "public"."kumusta_analytics_events" USING "btree" ("user_id", "occurred_at" DESC);



CREATE INDEX "kumusta_api_rate_limits_updated_idx" ON "public"."kumusta_api_rate_limits" USING "btree" ("updated_at");



CREATE INDEX "kumusta_app_sessions_user_started_idx" ON "public"."kumusta_app_sessions" USING "btree" ("user_id", "started_at" DESC);



CREATE INDEX "kumusta_cancellation_feedback_submitted_idx" ON "public"."kumusta_subscription_cancellation_feedback" USING "btree" ("submitted_at" DESC);



CREATE INDEX "kumusta_daily_progress_user_date_idx" ON "public"."kumusta_daily_progress" USING "btree" ("user_id", "progress_date" DESC);



CREATE INDEX "kumusta_difficulty_feedback_lesson_idx" ON "public"."kumusta_difficulty_feedback" USING "btree" ("generated_lesson_id") WHERE ("generated_lesson_id" IS NOT NULL);



CREATE INDEX "kumusta_difficulty_feedback_lesson_owner_idx" ON "public"."kumusta_difficulty_feedback" USING "btree" ("generated_lesson_id", "user_id");



CREATE INDEX "kumusta_difficulty_feedback_user_occurred_idx" ON "public"."kumusta_difficulty_feedback" USING "btree" ("user_id", "occurred_at" DESC);



CREATE INDEX "kumusta_email_jobs_pending_idx" ON "public"."kumusta_email_jobs" USING "btree" ("next_attempt_at", "created_at") WHERE ("status" = ANY (ARRAY['pending'::"text", 'sending'::"text"]));



CREATE INDEX "kumusta_entitlements_active_idx" ON "public"."kumusta_entitlements" USING "btree" ("user_id", "expires_at") WHERE "is_active";



CREATE INDEX "kumusta_flashcard_sessions_user_started_idx" ON "public"."kumusta_flashcard_sessions" USING "btree" ("user_id", "started_at" DESC);



CREATE INDEX "kumusta_foundation_course_progress_user_idx" ON "public"."kumusta_foundation_course_progress" USING "btree" ("user_id", "last_accessed_at" DESC);



CREATE INDEX "kumusta_foundation_item_progress_user_idx" ON "public"."kumusta_foundation_item_progress" USING "btree" ("user_id", "updated_at" DESC);



CREATE INDEX "kumusta_foundation_items_unit_position_idx" ON "public"."kumusta_foundation_items" USING "btree" ("unit_id", "position");



CREATE INDEX "kumusta_foundation_units_course_position_idx" ON "public"."kumusta_foundation_units" USING "btree" ("course_id", "position");



CREATE INDEX "kumusta_foundation_variants_item_accent_idx" ON "public"."kumusta_foundation_item_variants" USING "btree" ("item_id", "accent");



CREATE INDEX "kumusta_generated_lessons_expiry_idx" ON "public"."kumusta_generated_lessons" USING "btree" ("expires_at") WHERE ("status" = 'ready'::"text");



CREATE INDEX "kumusta_generated_lessons_job_idx" ON "public"."kumusta_generated_lessons" USING "btree" ("generation_job_id");



CREATE INDEX "kumusta_generated_lessons_job_owner_idx" ON "public"."kumusta_generated_lessons" USING "btree" ("generation_job_id", "user_id");



CREATE INDEX "kumusta_generated_lessons_user_created_idx" ON "public"."kumusta_generated_lessons" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "kumusta_generated_vocabulary_progress_due_idx" ON "public"."kumusta_generated_vocabulary_progress" USING "btree" ("user_id", "due_at");



CREATE INDEX "kumusta_generated_vocabulary_progress_lesson_idx" ON "public"."kumusta_generated_vocabulary_progress" USING "btree" ("generated_lesson_id");



CREATE INDEX "kumusta_generated_vocabulary_progress_lesson_owner_idx" ON "public"."kumusta_generated_vocabulary_progress" USING "btree" ("generated_lesson_id", "user_id");



CREATE INDEX "kumusta_generated_vocabulary_reviews_lesson_idx" ON "public"."kumusta_generated_vocabulary_review_events" USING "btree" ("generated_lesson_id");



CREATE INDEX "kumusta_generated_vocabulary_reviews_lesson_owner_idx" ON "public"."kumusta_generated_vocabulary_review_events" USING "btree" ("generated_lesson_id", "user_id");



CREATE INDEX "kumusta_generated_vocabulary_reviews_user_idx" ON "public"."kumusta_generated_vocabulary_review_events" USING "btree" ("user_id", "occurred_at" DESC);



CREATE UNIQUE INDEX "kumusta_generation_jobs_one_active_per_user_idx" ON "public"."kumusta_lesson_generation_jobs" USING "btree" ("user_id") WHERE ("status" = ANY (ARRAY['queued'::"text", 'generating'::"text"]));



CREATE INDEX "kumusta_generation_jobs_user_created_idx" ON "public"."kumusta_lesson_generation_jobs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "kumusta_learning_sessions_content_idx" ON "public"."kumusta_learning_sessions" USING "btree" ("user_id", "content_kind", "content_id", "started_at" DESC) WHERE ("content_id" IS NOT NULL);



CREATE INDEX "kumusta_learning_sessions_generated_lesson_idx" ON "public"."kumusta_learning_sessions" USING "btree" ("generated_lesson_id") WHERE ("generated_lesson_id" IS NOT NULL);



CREATE INDEX "kumusta_learning_sessions_generated_lesson_owner_idx" ON "public"."kumusta_learning_sessions" USING "btree" ("generated_lesson_id", "user_id");



CREATE INDEX "kumusta_learning_sessions_lesson_idx" ON "public"."kumusta_learning_sessions" USING "btree" ("lesson_id") WHERE ("lesson_id" IS NOT NULL);



CREATE INDEX "kumusta_learning_sessions_user_started_idx" ON "public"."kumusta_learning_sessions" USING "btree" ("user_id", "started_at" DESC);



CREATE INDEX "kumusta_lesson_generation_quota_overrides_expiry_idx" ON "public"."kumusta_lesson_generation_quota_overrides" USING "btree" ("expires_at");



CREATE INDEX "kumusta_lesson_queue_delivery_priority_idx" ON "public"."kumusta_user_lesson_queue" USING "btree" ("user_id", "status", "priority" DESC, "assigned_at") WHERE ("status" = ANY (ARRAY['ready'::"text", 'started'::"text"]));



CREATE INDEX "kumusta_lesson_queue_generated_lesson_idx" ON "public"."kumusta_user_lesson_queue" USING "btree" ("generated_lesson_id");



CREATE INDEX "kumusta_lesson_queue_lesson_owner_idx" ON "public"."kumusta_user_lesson_queue" USING "btree" ("generated_lesson_id", "user_id");



CREATE INDEX "kumusta_lessons_published_order_idx" ON "public"."kumusta_lessons" USING "btree" ("level", "accent", "sort_order") WHERE "is_published";



CREATE UNIQUE INDEX "kumusta_lessons_roadmap_accent_order_idx" ON "public"."kumusta_lessons" USING "btree" ("roadmap_version", "level", "accent", "lesson_order") WHERE ("roadmap_version" IS NOT NULL);



CREATE INDEX "kumusta_lessons_roadmap_fetch_idx" ON "public"."kumusta_lessons" USING "btree" ("roadmap_version", "level", "accent", "unit_order", "lesson_order") WHERE "is_published";



CREATE INDEX "kumusta_live_account_overrides_expiry" ON "public"."kumusta_live_account_overrides" USING "btree" ("expires_at");



CREATE INDEX "kumusta_live_rounds_user_day" ON "public"."kumusta_live_rounds" USING "btree" ("user_id", "usage_day");



CREATE INDEX "kumusta_live_sessions_client_session_idx" ON "public"."kumusta_live_sessions" USING "btree" ("user_id", "client_session_id", "created_at") WHERE ("client_session_id" IS NOT NULL);



CREATE INDEX "kumusta_live_sessions_lesson_idx" ON "public"."kumusta_live_sessions" USING "btree" ("user_id", "latest_lesson_id", "created_at" DESC) WHERE ("latest_lesson_id" IS NOT NULL);



CREATE INDEX "kumusta_live_sessions_open_started_idx" ON "public"."kumusta_live_sessions" USING "btree" ("user_id") WHERE (("ended_at" IS NULL) AND ("started_at" IS NOT NULL));



CREATE INDEX "kumusta_live_sessions_round" ON "public"."kumusta_live_sessions" USING "btree" ("round_id", "created_at");



CREATE INDEX "kumusta_live_sessions_user_day" ON "public"."kumusta_live_sessions" USING "btree" ("user_id", "usage_day");



CREATE INDEX "kumusta_live_transcripts_round_order" ON "public"."kumusta_live_transcripts" USING "btree" ("round_id", "created_at", "id");



CREATE INDEX "kumusta_live_transcripts_session" ON "public"."kumusta_live_transcripts" USING "btree" ("session_id", "created_at");



CREATE INDEX "kumusta_revenuecat_events_unprocessed_idx" ON "public"."kumusta_revenuecat_events" USING "btree" ("received_at") WHERE ("processed_at" IS NULL);



CREATE INDEX "kumusta_review_events_session_idx" ON "public"."kumusta_review_events" USING "btree" ("session_id") WHERE ("session_id" IS NOT NULL);



CREATE INDEX "kumusta_review_events_session_owner_idx" ON "public"."kumusta_review_events" USING "btree" ("session_id", "user_id");



CREATE INDEX "kumusta_review_events_user_occurred_idx" ON "public"."kumusta_review_events" USING "btree" ("user_id", "occurred_at" DESC);



CREATE INDEX "kumusta_review_events_vocabulary_idx" ON "public"."kumusta_review_events" USING "btree" ("vocabulary_id");



CREATE INDEX "kumusta_tts_cache_status_idx" ON "public"."kumusta_tts_cache" USING "btree" ("status", "updated_at");



CREATE INDEX "kumusta_user_lesson_queue_ready_idx" ON "public"."kumusta_user_lesson_queue" USING "btree" ("user_id", "assigned_at", "id") WHERE ("status" = ANY (ARRAY['ready'::"text", 'started'::"text"]));



CREATE INDEX "kumusta_user_vocabulary_due_idx" ON "public"."kumusta_user_vocabulary" USING "btree" ("user_id", "due_at") WHERE ("state" = ANY (ARRAY['new'::"text", 'learning'::"text", 'review'::"text"]));



CREATE INDEX "kumusta_user_vocabulary_vocabulary_idx" ON "public"."kumusta_user_vocabulary" USING "btree" ("vocabulary_id");



CREATE UNIQUE INDEX "kumusta_vocabulary_accent_vietnamese_key" ON "public"."kumusta_vocabulary" USING "btree" ("accent", "vietnamese");



CREATE INDEX "kumusta_vocabulary_published_accent_idx" ON "public"."kumusta_vocabulary" USING "btree" ("accent", "vietnamese") WHERE "is_published";



CREATE INDEX "kumusta_xp_events_user_occurred_idx" ON "public"."kumusta_xp_events" USING "btree" ("user_id", "occurred_at" DESC);



CREATE INDEX "kumusta_xp_period_totals_rank_idx" ON "public"."kumusta_xp_period_totals" USING "btree" ("period_kind", "period_key", "xp" DESC, "user_id");



CREATE OR REPLACE TRIGGER "kumusta_analytics_validate_event" BEFORE INSERT ON "public"."kumusta_analytics_events" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_validate_analytics_event"();



CREATE OR REPLACE TRIGGER "kumusta_app_sessions_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_app_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_flashcard_sessions_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_flashcard_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_course_progress_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_course_progress" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_courses_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_courses" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_item_progress_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_item_progress" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_items_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_items" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_units_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_units" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_foundation_variants_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_foundation_item_variants" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_generated_lessons_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_generated_lessons" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_generated_vocabulary_progress_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_generated_vocabulary_progress" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_generation_jobs_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_lesson_generation_jobs" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_learner_states_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_learner_states" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_lesson_queue_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_user_lesson_queue" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_lessons_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_lessons" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_onboarding_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_onboarding_responses" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_preferences_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_learning_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_profiles_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_progress_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_daily_progress" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_rate_limits_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_api_rate_limits" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_sessions_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_learning_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_user_state_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_user_state" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_user_vocabulary_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_user_vocabulary" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_vocabulary_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_vocabulary" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



CREATE OR REPLACE TRIGGER "kumusta_xp_period_totals_leaderboard_signal" AFTER INSERT OR UPDATE ON "public"."kumusta_xp_period_totals" FOR EACH ROW WHEN ((("new"."period_kind" = 'all_time'::"text") AND ("new"."period_key" = 'all_time'::"text"))) EXECUTE FUNCTION "public"."kumusta_touch_leaderboard_signal"();



CREATE OR REPLACE TRIGGER "kumusta_xp_rules_touch_updated_at" BEFORE UPDATE ON "public"."kumusta_xp_rules" FOR EACH ROW EXECUTE FUNCTION "public"."kumusta_touch_updated_at"();



ALTER TABLE ONLY "public"."kumusta_analytics_events"
    ADD CONSTRAINT "kumusta_analytics_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_api_rate_limits"
    ADD CONSTRAINT "kumusta_api_rate_limits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_app_sessions"
    ADD CONSTRAINT "kumusta_app_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_daily_progress"
    ADD CONSTRAINT "kumusta_daily_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_difficulty_feedback"
    ADD CONSTRAINT "kumusta_difficulty_feedback_generated_lesson_id_fkey" FOREIGN KEY ("generated_lesson_id") REFERENCES "public"."kumusta_generated_lessons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_difficulty_feedback"
    ADD CONSTRAINT "kumusta_difficulty_feedback_lesson_owner_fk" FOREIGN KEY ("generated_lesson_id", "user_id") REFERENCES "public"."kumusta_generated_lessons"("id", "user_id") ON DELETE SET NULL ("generated_lesson_id");



ALTER TABLE ONLY "public"."kumusta_difficulty_feedback"
    ADD CONSTRAINT "kumusta_difficulty_feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_email_jobs"
    ADD CONSTRAINT "kumusta_email_jobs_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."kumusta_revenuecat_events"("event_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_email_jobs"
    ADD CONSTRAINT "kumusta_email_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_entitlements"
    ADD CONSTRAINT "kumusta_entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_flashcard_sessions"
    ADD CONSTRAINT "kumusta_flashcard_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_course_progress"
    ADD CONSTRAINT "kumusta_foundation_course_progress_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."kumusta_foundation_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_course_progress"
    ADD CONSTRAINT "kumusta_foundation_course_progress_current_item_id_fkey" FOREIGN KEY ("current_item_id") REFERENCES "public"."kumusta_foundation_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_foundation_course_progress"
    ADD CONSTRAINT "kumusta_foundation_course_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_item_progress"
    ADD CONSTRAINT "kumusta_foundation_item_progress_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."kumusta_foundation_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_item_progress"
    ADD CONSTRAINT "kumusta_foundation_item_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_item_variants"
    ADD CONSTRAINT "kumusta_foundation_item_variants_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."kumusta_foundation_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_items"
    ADD CONSTRAINT "kumusta_foundation_items_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."kumusta_foundation_units"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_foundation_units"
    ADD CONSTRAINT "kumusta_foundation_units_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."kumusta_foundation_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_generation_job_id_fkey" FOREIGN KEY ("generation_job_id") REFERENCES "public"."kumusta_lesson_generation_jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_job_owner_fk" FOREIGN KEY ("generation_job_id", "user_id") REFERENCES "public"."kumusta_lesson_generation_jobs"("id", "user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_lessons"
    ADD CONSTRAINT "kumusta_generated_lessons_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_progress"
    ADD CONSTRAINT "kumusta_generated_vocabulary_progress_generated_lesson_id_fkey" FOREIGN KEY ("generated_lesson_id") REFERENCES "public"."kumusta_generated_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_progress"
    ADD CONSTRAINT "kumusta_generated_vocabulary_progress_lesson_owner_fk" FOREIGN KEY ("generated_lesson_id", "user_id") REFERENCES "public"."kumusta_generated_lessons"("id", "user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_progress"
    ADD CONSTRAINT "kumusta_generated_vocabulary_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_review_events"
    ADD CONSTRAINT "kumusta_generated_vocabulary_review_eve_generated_lesson_id_fkey" FOREIGN KEY ("generated_lesson_id") REFERENCES "public"."kumusta_generated_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_review_events"
    ADD CONSTRAINT "kumusta_generated_vocabulary_review_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_generated_vocabulary_review_events"
    ADD CONSTRAINT "kumusta_generated_vocabulary_reviews_lesson_owner_fk" FOREIGN KEY ("generated_lesson_id", "user_id") REFERENCES "public"."kumusta_generated_lessons"("id", "user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_goal_lesson_translations"
    ADD CONSTRAINT "kumusta_goal_lesson_translations_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "public"."kumusta_goal_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_learner_states"
    ADD CONSTRAINT "kumusta_learner_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_learning_preferences"
    ADD CONSTRAINT "kumusta_learning_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_generated_lesson_id_fkey" FOREIGN KEY ("generated_lesson_id") REFERENCES "public"."kumusta_generated_lessons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_generated_lesson_owner_fk" FOREIGN KEY ("generated_lesson_id", "user_id") REFERENCES "public"."kumusta_generated_lessons"("id", "user_id") ON DELETE SET NULL ("generated_lesson_id");



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "public"."kumusta_lessons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_learning_sessions"
    ADD CONSTRAINT "kumusta_learning_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_lesson_generation_jobs"
    ADD CONSTRAINT "kumusta_lesson_generation_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_lesson_generation_quota_overrides"
    ADD CONSTRAINT "kumusta_lesson_generation_quota_overrides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_lesson_queue"
    ADD CONSTRAINT "kumusta_lesson_queue_lesson_owner_fk" FOREIGN KEY ("generated_lesson_id", "user_id") REFERENCES "public"."kumusta_generated_lessons"("id", "user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_live_account_overrides"
    ADD CONSTRAINT "kumusta_live_account_overrides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_live_rounds"
    ADD CONSTRAINT "kumusta_live_rounds_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_live_sessions"
    ADD CONSTRAINT "kumusta_live_sessions_round_id_fkey" FOREIGN KEY ("round_id") REFERENCES "public"."kumusta_live_rounds"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_live_sessions"
    ADD CONSTRAINT "kumusta_live_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_live_transcripts"
    ADD CONSTRAINT "kumusta_live_transcripts_round_id_fkey" FOREIGN KEY ("round_id") REFERENCES "public"."kumusta_live_rounds"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_live_transcripts"
    ADD CONSTRAINT "kumusta_live_transcripts_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."kumusta_live_sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_onboarding_responses"
    ADD CONSTRAINT "kumusta_onboarding_responses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_profiles"
    ADD CONSTRAINT "kumusta_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."kumusta_learning_sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_session_owner_fkey" FOREIGN KEY ("session_id", "user_id") REFERENCES "public"."kumusta_learning_sessions"("id", "user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_review_events"
    ADD CONSTRAINT "kumusta_review_events_vocabulary_id_fkey" FOREIGN KEY ("vocabulary_id") REFERENCES "public"."kumusta_vocabulary"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_subscription_cancellation_feedback"
    ADD CONSTRAINT "kumusta_subscription_cancellation_feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_lesson_queue"
    ADD CONSTRAINT "kumusta_user_lesson_queue_generated_lesson_id_fkey" FOREIGN KEY ("generated_lesson_id") REFERENCES "public"."kumusta_generated_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_lesson_queue"
    ADD CONSTRAINT "kumusta_user_lesson_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_state"
    ADD CONSTRAINT "kumusta_user_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_vocabulary"
    ADD CONSTRAINT "kumusta_user_vocabulary_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_vocabulary"
    ADD CONSTRAINT "kumusta_user_vocabulary_vocabulary_id_fkey" FOREIGN KEY ("vocabulary_id") REFERENCES "public"."kumusta_vocabulary"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_user_xp_totals"
    ADD CONSTRAINT "kumusta_user_xp_totals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_xp_events"
    ADD CONSTRAINT "kumusta_xp_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kumusta_xp_period_totals"
    ADD CONSTRAINT "kumusta_xp_period_totals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "goal_lesson_translations_read_published" ON "public"."kumusta_goal_lesson_translations" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kumusta_goal_lessons" "lesson"
  WHERE (("lesson"."id" = "kumusta_goal_lesson_translations"."lesson_id") AND "lesson"."is_published"))));



CREATE POLICY "goal_lessons_read_published" ON "public"."kumusta_goal_lessons" FOR SELECT TO "authenticated" USING ("is_published");



CREATE POLICY "live_rounds_read_own" ON "public"."kumusta_live_rounds" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "live_sessions_read_own" ON "public"."kumusta_live_sessions" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "live_transcripts_read_own" ON "public"."kumusta_live_transcripts" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = ( SELECT "round"."user_id"
   FROM "public"."kumusta_live_rounds" "round"
  WHERE ("round"."id" = "kumusta_live_transcripts"."round_id"))));



CREATE POLICY "kumusta_analytics_conflict_check_own" ON "public"."kumusta_analytics_events" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."kumusta_analytics_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_analytics_insert_own" ON "public"."kumusta_analytics_events" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."kumusta_api_rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_app_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_app_sessions_manage_own" ON "public"."kumusta_app_sessions" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



CREATE POLICY "kumusta_cancellation_feedback_insert_own" ON "public"."kumusta_subscription_cancellation_feedback" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."kumusta_daily_progress" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_daily_progress_manage_own" ON "public"."kumusta_daily_progress" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_difficulty_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_email_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_entitlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_entitlements_read_own" ON "public"."kumusta_entitlements" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_flashcard_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_flashcard_sessions_manage_own" ON "public"."kumusta_flashcard_sessions" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_foundation_course_progress" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_foundation_course_progress_manage_own" ON "public"."kumusta_foundation_course_progress" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_foundation_courses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_foundation_courses_read_published" ON "public"."kumusta_foundation_courses" FOR SELECT TO "authenticated" USING (("is_published" AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_foundation_item_progress" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_foundation_item_progress_manage_own" ON "public"."kumusta_foundation_item_progress" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_foundation_item_variants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_foundation_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_foundation_items_read_published" ON "public"."kumusta_foundation_items" FOR SELECT TO "authenticated" USING (((( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false) AND (EXISTS ( SELECT 1
   FROM ("public"."kumusta_foundation_units" "u"
     JOIN "public"."kumusta_foundation_courses" "c" ON (("c"."id" = "u"."course_id")))
  WHERE (("u"."id" = "kumusta_foundation_items"."unit_id") AND "c"."is_published")))));



ALTER TABLE "public"."kumusta_foundation_units" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_foundation_units_read_published" ON "public"."kumusta_foundation_units" FOR SELECT TO "authenticated" USING (((( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false) AND (EXISTS ( SELECT 1
   FROM "public"."kumusta_foundation_courses" "c"
  WHERE (("c"."id" = "kumusta_foundation_units"."course_id") AND "c"."is_published")))));



CREATE POLICY "kumusta_foundation_variants_read_published" ON "public"."kumusta_foundation_item_variants" FOR SELECT TO "authenticated" USING (((( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false) AND (EXISTS ( SELECT 1
   FROM (("public"."kumusta_foundation_items" "i"
     JOIN "public"."kumusta_foundation_units" "u" ON (("u"."id" = "i"."unit_id")))
     JOIN "public"."kumusta_foundation_courses" "c" ON (("c"."id" = "u"."course_id")))
  WHERE (("i"."id" = "kumusta_foundation_item_variants"."item_id") AND "c"."is_published")))));



ALTER TABLE "public"."kumusta_generated_lessons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_generated_vocabulary_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_generated_vocabulary_review_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_goal_lesson_translations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_goal_lessons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_learner_states" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_learning_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_learning_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_lesson_generation_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_lesson_generation_quota_overrides" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_lessons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_lessons_read_published" ON "public"."kumusta_lessons" FOR SELECT TO "authenticated" USING (("is_published" AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_live_account_overrides" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_live_rounds" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_live_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_live_transcripts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_onboarding_manage_own" ON "public"."kumusta_onboarding_responses" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_onboarding_responses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_preferences_manage_own" ON "public"."kumusta_learning_preferences" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_profiles_delete_own" ON "public"."kumusta_profiles" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



CREATE POLICY "kumusta_profiles_insert_own" ON "public"."kumusta_profiles" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



CREATE POLICY "kumusta_profiles_select_own" ON "public"."kumusta_profiles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



CREATE POLICY "kumusta_profiles_update_own" ON "public"."kumusta_profiles" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_project_api_rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_revenuecat_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_review_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_review_events_insert_own" ON "public"."kumusta_review_events" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



CREATE POLICY "kumusta_review_events_read_own" ON "public"."kumusta_review_events" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



CREATE POLICY "kumusta_sessions_manage_own" ON "public"."kumusta_learning_sessions" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_subscription_cancellation_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_tts_cache" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_user_lesson_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_user_state" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_user_state_manage_own" ON "public"."kumusta_user_state" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_user_vocabulary" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_user_vocabulary_manage_own" ON "public"."kumusta_user_vocabulary" TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_user_xp_totals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_user_xp_totals_read_own" ON "public"."kumusta_user_xp_totals" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_vocabulary" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_vocabulary_read_published" ON "public"."kumusta_vocabulary" FOR SELECT TO "authenticated" USING (("is_published" AND (COALESCE(((( SELECT "auth"."jwt"() AS "jwt") ->> 'is_anonymous'::"text"))::boolean, false) = false)));



ALTER TABLE "public"."kumusta_xp_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_xp_events_read_own" ON "public"."kumusta_xp_events" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND (( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false)));



ALTER TABLE "public"."kumusta_xp_leaderboard_signal" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kumusta_xp_leaderboard_signal_read_authenticated" ON "public"."kumusta_xp_leaderboard_signal" FOR SELECT TO "authenticated" USING ((( SELECT COALESCE((("auth"."jwt"() ->> 'is_anonymous'::"text"))::boolean, false) AS "coalesce") = false));



ALTER TABLE "public"."kumusta_xp_period_totals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kumusta_xp_rules" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kumusta_xp_leaderboard_signal";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

















































































































































































REVOKE ALL ON FUNCTION "public"."kumusta_award_xp"("p_user_id" "uuid", "p_reason_code" "text", "p_source_id" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_award_xp"("p_user_id" "uuid", "p_reason_code" "text", "p_source_id" "text", "p_idempotency_key" "text", "p_metadata" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_begin_lesson_generation_job"("p_user_id" "uuid", "p_client_request_id" "uuid", "p_trigger" "text", "p_requested_count" integer, "p_learner_snapshot" "jsonb", "p_prompt_version" integer, "p_lease_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_begin_lesson_generation_job"("p_user_id" "uuid", "p_client_request_id" "uuid", "p_trigger" "text", "p_requested_count" integer, "p_learner_snapshot" "jsonb", "p_prompt_version" integer, "p_lease_seconds" integer) TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_email_jobs" TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_claim_email_jobs"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_claim_email_jobs"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_claim_tts_cache"("p_cache_key" "text", "p_text_value" "text", "p_accent" "text", "p_speed" "text", "p_voice_id" "text", "p_model_id" "text", "p_output_format" "text", "p_settings_version" "text", "p_object_path" "text", "p_generation_token" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_claim_tts_cache"("p_cache_key" "text", "p_text_value" "text", "p_accent" "text", "p_speed" "text", "p_voice_id" "text", "p_model_id" "text", "p_output_format" "text", "p_settings_version" "text", "p_object_path" "text", "p_generation_token" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_complete_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid", "p_byte_size" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_complete_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid", "p_byte_size" bigint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_consume_api_quota"("p_user_id" "uuid", "p_scope" "text", "p_limit" integer, "p_window_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_consume_api_quota"("p_user_id" "uuid", "p_scope" "text", "p_limit" integer, "p_window_seconds" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_consume_project_api_quota"("p_scope" "text", "p_limit" integer, "p_window_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_consume_project_api_quota"("p_scope" "text", "p_limit" integer, "p_window_seconds" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_curriculum_admin_authorized"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_curriculum_admin_authorized"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_fail_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_fail_tts_cache"("p_cache_key" "text", "p_generation_token" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_persist_generated_lesson_batch"("p_user_id" "uuid", "p_job_id" "uuid", "p_accent" "text", "p_model" "text", "p_lessons" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_persist_generated_lesson_batch"("p_user_id" "uuid", "p_job_id" "uuid", "p_accent" "text", "p_model" "text", "p_lessons" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_record_difficulty_feedback"("p_user_id" "uuid", "p_client_event_id" "uuid", "p_generated_lesson_id" "uuid", "p_context" "text", "p_rating" "text", "p_step_kind" "text", "p_pace_rating" "text", "p_mark_complete" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_record_difficulty_feedback"("p_user_id" "uuid", "p_client_event_id" "uuid", "p_generated_lesson_id" "uuid", "p_context" "text", "p_rating" "text", "p_step_kind" "text", "p_pace_rating" "text", "p_mark_complete" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_record_generated_vocabulary_review"("p_user_id" "uuid", "p_generated_lesson_id" "uuid", "p_vocabulary_id" "uuid", "p_client_event_id" "uuid", "p_rating" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kumusta_record_generated_vocabulary_review"("p_user_id" "uuid", "p_generated_lesson_id" "uuid", "p_vocabulary_id" "uuid", "p_client_event_id" "uuid", "p_rating" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kumusta_touch_updated_at"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."kumusta_validate_analytics_event"() FROM PUBLIC;
























GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_analytics_events" TO "service_role";
GRANT INSERT ON TABLE "public"."kumusta_analytics_events" TO "authenticated";



GRANT SELECT("user_id") ON TABLE "public"."kumusta_analytics_events" TO "authenticated";



GRANT SELECT("client_event_id") ON TABLE "public"."kumusta_analytics_events" TO "authenticated";



GRANT UPDATE ON SEQUENCE "public"."kumusta_analytics_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."kumusta_analytics_events_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."kumusta_analytics_events_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_api_rate_limits" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_app_sessions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_app_sessions" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_flashcard_sessions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_flashcard_sessions" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_learning_sessions" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_learning_sessions" TO "authenticated";



GRANT ALL ON TABLE "public"."kumusta_live_sessions" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_live_sessions" TO "authenticated";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_customer_learning_activity" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_customer_lesson_usage" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_daily_progress" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_daily_progress" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_difficulty_feedback" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_entitlements" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_entitlements" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_course_progress" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_foundation_course_progress" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_courses" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_foundation_courses" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_item_progress" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_foundation_item_progress" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_item_variants" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_foundation_item_variants" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_items" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_foundation_items" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_foundation_units" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_foundation_units" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_generated_lessons" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_generated_vocabulary_progress" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_generated_vocabulary_review_events" TO "service_role";



GRANT ALL ON TABLE "public"."kumusta_goal_lesson_translations" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_goal_lesson_translations" TO "authenticated";



GRANT ALL ON TABLE "public"."kumusta_goal_lessons" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_goal_lessons" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_learner_states" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_learning_preferences" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_learning_preferences" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_lesson_generation_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."kumusta_lesson_generation_quota_overrides" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_lessons" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_lessons" TO "authenticated";



GRANT ALL ON TABLE "public"."kumusta_live_account_overrides" TO "service_role";



GRANT ALL ON TABLE "public"."kumusta_live_rounds" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_live_rounds" TO "authenticated";



GRANT ALL ON TABLE "public"."kumusta_live_transcripts" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_live_transcripts" TO "authenticated";



GRANT UPDATE ON SEQUENCE "public"."kumusta_live_transcripts_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."kumusta_live_transcripts_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."kumusta_live_transcripts_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_onboarding_responses" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_onboarding_responses" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_profiles" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_profiles" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_project_api_rate_limits" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_revenuecat_events" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_review_events" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."kumusta_review_events" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_subscription_cancellation_feedback" TO "service_role";
GRANT INSERT ON TABLE "public"."kumusta_subscription_cancellation_feedback" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_tts_cache" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_user_lesson_queue" TO "service_role";



GRANT ALL ON TABLE "public"."kumusta_user_state" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_user_state" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_user_vocabulary" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."kumusta_user_vocabulary" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_user_xp_totals" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_user_xp_totals" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_vocabulary" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_vocabulary" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_xp_events" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_xp_events" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_xp_period_totals" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_xp_leaderboard" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_xp_leaderboard" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_xp_leaderboard_signal" TO "service_role";
GRANT SELECT ON TABLE "public"."kumusta_xp_leaderboard_signal" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kumusta_xp_rules" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";































