# Catalog parity verification

Historical baseline verified against Supabase project `vpitjvtfzpqfnqgzcpla`
after migrations `20260730233140` and `20260730233253`. The counts below do not
include later product-alignment, quota, integrity, or adaptive-learning
migrations and must not be used as current production evidence.

After applying migrations through `20260731114500`, the target contains 23
Kumusta tables. Re-run the inventory, grants, RLS, function search-path, and
advisor checks and replace this historical evidence before production rollout.

## Inventory

| Object kind | Remote count | Local migration source | Result |
| --- | ---: | --- | --- |
| Tables | 15 | 15 explicit `create table` statements | Match |
| RLS policies | 17 | 17 final policies in hardening migration | Match |
| Non-internal triggers | 10 | 10 prefixed update triggers | Match |
| Indexes | 38 | 17 explicit plus 21 PK/unique indexes | Match |

All 15 remote tables report `relrowsecurity = true`.

## Table and column parity

| Table | Columns |
| --- | ---: |
| `kumusta_analytics_events` | 9 |
| `kumusta_api_rate_limits` | 5 |
| `kumusta_daily_progress` | 10 |
| `kumusta_entitlements` | 10 |
| `kumusta_learning_preferences` | 10 |
| `kumusta_learning_sessions` | 13 |
| `kumusta_lesson_steps` | 13 |
| `kumusta_lesson_vocabulary` | 4 |
| `kumusta_lessons` | 12 |
| `kumusta_onboarding_responses` | 11 |
| `kumusta_profiles` | 7 |
| `kumusta_revenuecat_events` | 8 |
| `kumusta_review_events` | 11 |
| `kumusta_user_vocabulary` | 12 |
| `kumusta_vocabulary` | 13 |

Column names and ordering were compared with `information_schema.columns`.
Policy commands, roles, `qual`, and `with_check` expressions were compared with
`pg_policies`. The final policies use scalar subqueries for both `auth.uid()`
and `auth.jwt()`, matching the live performance-hardened definitions.

## Privilege verification

The live checks returned:

- anonymous has no `SELECT`, `INSERT`, `UPDATE`, or `DELETE` privilege on any
  Kumusta table;
- authenticated has no access to `kumusta_revenuecat_events`;
- authenticated has no access to `kumusta_api_rate_limits`;
- authenticated has read-only access to `kumusta_entitlements`;
- service role retains full access to billing projections, webhook events, and
  rate-limit counters.

The post-migration security advisor reports no Kumusta warning. It reports
only the intentional informational `RLS enabled, no policy` findings on the two
deny-by-default service-only tables. The performance advisor reports no
Kumusta warning or unindexed foreign key. Fresh explicit indexes appear as
unused informational findings until the app generates representative traffic.

## Intentional textual difference

The remote first migration was protected from duplicate execution by
Supabase’s migration ledger. The reconstructed local first migration also adds
`drop trigger if exists` and `drop policy if exists` immediately before
recreation so the SQL itself is safe to replay.

Whitespace, line wrapping, and explanatory comments are also normalized.
These differences do not change the final catalog. No semantic mismatch is
known.
