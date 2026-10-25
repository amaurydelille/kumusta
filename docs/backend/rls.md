# Row-level security matrix

Every Kumusta table has RLS enabled. Where client policies exist, they target
`authenticated` and test ownership with cached `(select auth.uid())`. Private
learner-data policies explicitly reject tokens whose `is_anonymous` claim is
true; the bounded, insert-only analytics policy is the intentional exception.
Service-only tables intentionally have no client policy.

`service_role` bypasses RLS and is allowed only inside trusted Supabase Edge
Functions or controlled administrative jobs.

| Table | Anonymous | Signed-in select | Signed-in write | Service role |
| --- | --- | --- | --- | --- |
| `kumusta_profiles` | None | Own row | Insert/update/delete own | Full |
| `kumusta_onboarding_responses` | None | Own row | Manage own | Full |
| `kumusta_learning_preferences` | None | Own row | Manage own | Full |
| `kumusta_user_state` | None | Own row | Manage own | Full |
| `kumusta_lessons` | None | Published rows | None | Full |
| `kumusta_vocabulary` | None | Published rows | None | Full |
| `kumusta_user_vocabulary` | None | Own rows | Manage own | Full |
| `kumusta_learning_sessions` | None | Own rows | Manage own | Full |
| `kumusta_review_events` | None | Own rows | Insert own only | Full |
| `kumusta_daily_progress` | None | Own rows | Manage own | Full |
| `kumusta_entitlements` | None | Own rows | None | Full |
| `kumusta_revenuecat_events` | None | None | None | Full |
| `kumusta_analytics_events` | Insert own only | None | Insert own only | Full |
| `kumusta_api_rate_limits` | None | None | None | Full |
| `kumusta_project_api_rate_limits` | None | None | None | Full |
| `kumusta_learner_states` | None | None | None | Full |
| `kumusta_lesson_generation_jobs` | None | None | None | Full |
| `kumusta_generated_lessons` | None | None | None | Full |
| `kumusta_user_lesson_queue` | None | None | None | Full |
| `kumusta_difficulty_feedback` | None | None | None | Full |
| `kumusta_generated_vocabulary_progress` | None | None | None | Full |
| `kumusta_generated_vocabulary_review_events` | None | None | None | Full |

## Why pre-paywall onboarding is local-first

The conversion flow can run before sign-in. Before authentication the app keeps
onboarding answers in local state, while the anonymous Supabase identity can
insert only bounded, owner-scoped analytics events. After the user signs in, it
upserts the profile, preferences, and onboarding state under the authenticated
user ID.

This choice avoids weakening user-data policies for a convenience path. The app
uses an anonymous Supabase identity for the provider/paywall boundary, but that
identity still has no direct learner-table access. Only analytics accepts its
JWT for a narrow insert path; provider Edge Functions apply service-side
entitlement, ownership, input, and quota controls.

## Append-only and write-only records

- `kumusta_review_events`: users can insert and read their own events, but
  cannot alter history.
- `kumusta_analytics_events`: users can insert their own bounded events but
  cannot query analytics through the mobile API.
- `kumusta_revenuecat_events`: no client policy or grant exists.
- `kumusta_api_rate_limits`: no client policy or grant exists.
- `kumusta_project_api_rate_limits`: no client policy or grant exists.
- All seven adaptive tables: no client policy or grant exists. The authenticated
  lesson Edge Function validates JWT, entitlement/ownership as appropriate, and
  uses service-role-only RPCs rather than exposing these tables to mobile SQL.

Tables with RLS and no policy intentionally produce Supabase advisor
`rls_enabled_no_policy` informational notices. For the ten service-only
tables, that notice documents the intended deny-by-default boundary rather than
a missing control.

## Verification queries

Run these as an administrator after migrations:

```sql
select tablename, policyname, cmd, roles
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename like 'kumusta\_%' escape '\'
order by tablename, policyname;
```

```sql
select
  bool_and(
    not has_table_privilege(
      'anon',
      format('public.%I', tablename),
      'SELECT,INSERT,UPDATE,DELETE'
    )
  ) as anon_has_no_kumusta_table_privileges
from pg_catalog.pg_tables
where schemaname = 'public'
  and tablename like 'kumusta\_%' escape '\';
```

The expected result is `true`.
