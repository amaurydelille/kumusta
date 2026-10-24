-- Hosted Supabase grants anon/authenticated broad default privileges on new
-- objects, which the dumped baseline does not undo. Reset client access to the
-- intended contract (VietBuddy's migrations): no client executes any Kumusta
-- function, anon has no table access, and authenticated keeps only the table
-- privileges below (rows are still filtered by RLS).
do $$
declare
  object record;
begin
  for object in
    select c.oid::regclass as name
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relname like 'kumusta\_%'
      and c.relkind in ('r', 'v', 'm', 'S')
  loop
    execute format('revoke all on %s from public, anon, authenticated', object.name);
  end loop;

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

grant insert on public.kumusta_analytics_events to authenticated;
grant select, insert, update, delete on public.kumusta_app_sessions to authenticated;
grant select, insert, update, delete on public.kumusta_daily_progress to authenticated;
grant select on public.kumusta_entitlements to authenticated;
grant select, insert, update, delete on public.kumusta_flashcard_sessions to authenticated;
grant select, insert, update, delete on public.kumusta_foundation_course_progress to authenticated;
grant select on public.kumusta_foundation_courses to authenticated;
grant select, insert, update, delete on public.kumusta_foundation_item_progress to authenticated;
grant select on public.kumusta_foundation_item_variants to authenticated;
grant select on public.kumusta_foundation_items to authenticated;
grant select on public.kumusta_foundation_units to authenticated;
grant select on public.kumusta_goal_lesson_translations to authenticated;
grant select on public.kumusta_goal_lessons to authenticated;
grant select, insert, update, delete on public.kumusta_learning_preferences to authenticated;
grant select, insert, update, delete on public.kumusta_learning_sessions to authenticated;
grant select on public.kumusta_lessons to authenticated;
grant select on public.kumusta_live_rounds to authenticated;
grant select on public.kumusta_live_sessions to authenticated;
grant select on public.kumusta_live_transcripts to authenticated;
grant select, insert, update, delete on public.kumusta_onboarding_responses to authenticated;
grant select, insert, update, delete on public.kumusta_profiles to authenticated;
grant select, insert on public.kumusta_review_events to authenticated;
grant insert on public.kumusta_subscription_cancellation_feedback to authenticated;
grant select, insert, update, delete on public.kumusta_user_state to authenticated;
grant select, insert, update, delete on public.kumusta_user_vocabulary to authenticated;
grant select on public.kumusta_user_xp_totals to authenticated;
grant select on public.kumusta_vocabulary to authenticated;
grant select on public.kumusta_xp_events to authenticated;
grant select on public.kumusta_xp_leaderboard to authenticated;
grant select on public.kumusta_xp_leaderboard_signal to authenticated;
