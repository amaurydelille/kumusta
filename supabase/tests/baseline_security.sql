-- Schema-wide security assertions. Read-only; run with
--   supabase db query --linked -f supabase/tests/baseline_security.sql
do $$
declare
  offenders text;
begin
  select string_agg(c.relname, ', ') into offenders
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'kumusta\_%'
    and not c.relrowsecurity;
  if offenders is not null then
    raise exception 'RLS disabled on: %', offenders;
  end if;

  -- Kumusta functions are service-role only (hosted default privileges grant
  -- clients EXECUTE unless each migration revokes it).
  select string_agg(p.proname, ', ') into offenders
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like 'kumusta\_%'
    and (has_function_privilege('anon', p.oid, 'execute')
      or has_function_privilege('authenticated', p.oid, 'execute'));
  if offenders is not null then
    raise exception 'Client-executable functions: %', offenders;
  end if;

  -- The anon role never touches Kumusta tables or views directly.
  select string_agg(c.relname, ', ') into offenders
  from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relname like 'kumusta\_%'
    and c.relkind in ('r', 'v', 'm')
    and (has_table_privilege('anon', c.oid, 'select') or has_table_privilege('anon', c.oid, 'insert')
      or has_table_privilege('anon', c.oid, 'update') or has_table_privilege('anon', c.oid, 'delete'));
  if offenders is not null then
    raise exception 'anon has table privileges on: %', offenders;
  end if;

  -- Reporting views stay service-role only.
  if has_table_privilege('authenticated', 'public.kumusta_customer_learning_activity', 'select')
     or has_table_privilege('anon', 'public.kumusta_customer_lesson_usage', 'select') then
    raise exception 'Reporting views are readable by clients';
  end if;

  -- Removed VietBuddy features must not come back.
  if to_regclass('public.kumusta_conversation_exercises') is not null
     or to_regprocedure('public.kumusta_live_reserve(uuid,text,text)') is not null then
    raise exception 'Removed dialogue/agent objects are present';
  end if;
end
$$;
select 'baseline security OK' as result;
