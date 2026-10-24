-- The app was renamed from NeiHou to Kumusta. Earlier migrations now use the
-- kumusta names, so on a fresh database this migration finds nothing to do; on
-- the database where the old names were applied it renames every object in
-- place, keeping rows and privileges.
do $$
declare
  object record;
begin
  -- Tables, views, materialized views and sequences.
  for object in
    select c.relname, c.relkind
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relname like '%neihou%'
      and c.relkind in ('r', 'p', 'v', 'm', 'S')
  loop
    execute format(
      'alter %s public.%I rename to %I',
      case object.relkind
        when 'v' then 'view'
        when 'm' then 'materialized view'
        when 'S' then 'sequence'
        else 'table'
      end,
      object.relname,
      replace(object.relname, 'neihou', 'kumusta')
    );
  end loop;

  -- Constraints (renaming a primary key or unique constraint renames its index).
  for object in
    select co.conrelid::regclass as relation, co.conname
    from pg_constraint co
    where co.connamespace = 'public'::regnamespace
      and co.conrelid <> 0
      and co.conname like '%neihou%'
  loop
    execute format(
      'alter table %s rename constraint %I to %I',
      object.relation,
      object.conname,
      replace(object.conname, 'neihou', 'kumusta')
    );
  end loop;

  -- Remaining indexes.
  for object in
    select c.relname
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relname like '%neihou%'
      and c.relkind in ('i', 'I')
  loop
    execute format(
      'alter index public.%I rename to %I',
      object.relname,
      replace(object.relname, 'neihou', 'kumusta')
    );
  end loop;

  -- Triggers.
  for object in
    select t.tgrelid::regclass as relation, t.tgname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    where c.relnamespace = 'public'::regnamespace
      and not t.tgisinternal
      and t.tgname like '%neihou%'
  loop
    execute format(
      'alter trigger %I on %s rename to %I',
      object.tgname,
      object.relation,
      replace(object.tgname, 'neihou', 'kumusta')
    );
  end loop;

  -- Row-level security policies.
  for object in
    select p.policyname, p.tablename
    from pg_policies p
    where p.schemaname = 'public'
      and p.policyname like '%neihou%'
  loop
    execute format(
      'alter policy %I on public.%I rename to %I',
      object.policyname,
      object.tablename,
      replace(object.policyname, 'neihou', 'kumusta')
    );
  end loop;

  -- Functions.
  for object in
    select p.oid::regprocedure as signature, p.proname
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname like '%neihou%'
  loop
    execute format(
      'alter function %s rename to %I',
      object.signature,
      replace(object.proname, 'neihou', 'kumusta')
    );
  end loop;

  -- Function bodies are stored as text, so table names and literals inside
  -- them are not updated by the renames above. CREATE OR REPLACE keeps grants.
  for object in
    select p.oid
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prokind = 'f'
      and p.prosrc ilike '%neihou%'
  loop
    execute replace(replace(replace(
      pg_get_functiondef(object.oid),
      'NEIHOU', 'KUMUSTA'), 'NeiHou', 'Kumusta'), 'neihou', 'kumusta');
  end loop;

  -- Check constraints holding neihou literals (audio object path prefixes).
  for object in
    select co.conrelid::regclass as relation, co.conname, pg_get_constraintdef(co.oid) as definition
    from pg_constraint co
    where co.connamespace = 'public'::regnamespace
      and co.contype = 'c'
      and pg_get_constraintdef(co.oid) ilike '%neihou%'
  loop
    execute format('alter table %s drop constraint %I', object.relation, object.conname);
    execute format(
      'alter table %s add constraint %I %s',
      object.relation,
      object.conname,
      replace(object.definition, 'neihou', 'kumusta')
    );
  end loop;

  -- Table and column comments.
  for object in
    select d.objoid::regclass as relation, a.attname, d.description
    from pg_description d
    join pg_class c on c.oid = d.objoid
    left join pg_attribute a on a.attrelid = d.objoid and a.attnum = d.objsubid and d.objsubid > 0
    where d.classoid = 'pg_class'::regclass
      and c.relnamespace = 'public'::regnamespace
      and d.description ilike '%neihou%'
  loop
    if object.attname is null then
      execute format(
        'comment on table %s is %L',
        object.relation,
        replace(replace(object.description, 'NeiHou', 'Kumusta'), 'neihou', 'kumusta')
      );
    else
      execute format(
        'comment on column %s.%I is %L',
        object.relation,
        object.attname,
        replace(replace(object.description, 'NeiHou', 'Kumusta'), 'neihou', 'kumusta')
      );
    end if;
  end loop;
end
$$;

-- Move the TTS cache bucket. It holds no objects yet, so the old bucket can be
-- removed directly (Storage blocks direct deletes unless explicitly allowed).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
select 'kumusta-tts', 'kumusta-tts', public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'neihou-tts'
on conflict (id) do nothing;

select set_config('storage.allow_delete_query', 'true', true);

delete from storage.buckets b
where b.id = 'neihou-tts'
  and not exists (select 1 from storage.objects o where o.bucket_id = b.id);

-- Re-assert the client privilege contract on the renamed functions.
do $$
declare
  object record;
begin
  for object in
    select p.oid::regprocedure as name
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname like 'kumusta\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', object.name);
    execute format('grant execute on function %s to service_role', object.name);
  end loop;
end
$$;
