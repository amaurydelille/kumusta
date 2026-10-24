# Kumusta backend

This directory documents the isolated Kumusta data model deployed to Supabase
project `vpitjvtfzpqfnqgzcpla`.

Kumusta shares that project with another application. Every Kumusta table,
index, trigger, policy, and helper function is therefore prefixed
`kumusta_`. Existing non-Kumusta objects must not be modified as part of a
Kumusta deployment.

## Documents

- [Schema and data dictionary](schema.md)
- [Row-level security matrix](rls.md)
- [Deployment and operations runbook](runbook.md)
- [Mistral production runbook](MISTRAL_RUNBOOK.md)
- [Catalog parity verification](catalog-verification.md)

## Source of truth

Ordered migrations under `../../supabase/migrations/` are the source of truth.
The current remote versions are:

1. `20260730233140_create_kumusta_core_schema_v1`
2. `20260730233253_harden_kumusta_rls_initplans_v1`
3. `20260731000200_add_kumusta_api_quota_rpc_v1`
4. `20260731000500_align_kumusta_product_contract_v1`
5. `20260731001000_harden_kumusta_event_integrity_v1`
6. `20260731022000_index_kumusta_review_session_owner_v1`
7. `20260731093000_add_kumusta_adaptive_learning_v1`
8. `20260731101500_index_kumusta_adaptive_foreign_keys_v1`
9. `20260731114500_harden_kumusta_adaptive_runtime_v1`

The adaptive migrations add seven private service-role-only tables, one private
project-quota table, bounded feedback/review/generation RPCs, user/project quota
scopes, generation leases, transactional batch persistence, composite ownership
foreign keys, and reverse indexes found by the database advisor.

## Security boundaries

- Mobile clients receive only the Supabase URL and a publishable key.
- ElevenLabs, Mistral, RevenueCat webhook, and Supabase service-role secrets
  remain in Edge Function secrets.
- Anonymous Supabase Auth identities receive no private learner-table access;
  analytics permits only bounded, owner-scoped event inserts.
- Server-curated content is read-only and published-only for signed-in users.
- Billing projections, provider rate limits, and webhook payloads are written
  only by service-role code.
- Adaptive learner state, generation jobs/content, lesson queues, and generated
  vocabulary state are service-role-only and exposed solely through the
  authenticated lesson Edge Function.
- Aggregate provider budgets are service-role-only and contain no user data.
- Raw audio, transcripts, email addresses, and free-form PII are prohibited
  from analytics properties.

## Provider boundaries

Only the following female ElevenLabs voices are valid:

| Accent | Voice ID |
| --- | --- |
| Southern | `6Xq32rHt6oAu98TBDKfr` |
| Northern | `LD1UihCXvSlUL4h8DOmk` |

The database enforces this allowlist and accent compatibility in
`kumusta_learning_preferences`. An Edge Function must enforce the same
allowlist before contacting ElevenLabs.
