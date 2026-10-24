# XP system

The XP system is intentionally ledger-first. The client never submits an XP
amount and never writes XP tables directly.

## Storage

- `kumusta_xp_rules` stores server-managed reason codes and award amounts.
- `kumusta_xp_events` is the append-only source of truth. Each event has a
  user, amount, reason, optional source, metadata, and idempotency key.
- `kumusta_user_xp_totals` stores the lifetime total for fast profile reads.
- `kumusta_xp_period_totals` stores UTC weekly, monthly, and all-time totals.
- `kumusta_xp_leaderboard` exposes only rank, display name, period, and XP.

The currently active rules are:

- `lesson_completed`: 30 XP
- `conversation_completed`: 20 XP
- `vocabulary_flashcard_session_completed`: 10 XP

The initial historical backfill reads completed lesson-queue rows, completed
conversation attempts, and completed `words` learning sessions. It records one
idempotent ledger event per source record, then rebuilds lifetime, weekly, and
monthly totals from the ledger.

## Award flow

`kumusta-award-xp` authenticates a registered user, validates the request,
and calls the service-role-only `kumusta_award_xp` database function. The
function:

1. Locks awards for that user for the duration of the transaction.
2. Returns the previous result for a repeated idempotency key.
3. Looks up the active reason in `kumusta_xp_rules`.
4. Inserts the XP ledger event.
5. Atomically updates lifetime, weekly, and monthly totals.
6. Returns the awarded amount and new totals.

The edge function accepts `POST` JSON shaped like:

```json
{
  "reason_code": "lesson_completed",
  "source_id": "lesson-session-id",
  "idempotency_key": "lesson-session-id-complete",
  "metadata": { "score": 0.8 }
}
```

The `reason_code` must already be active in `kumusta_xp_rules`; clients
cannot override the configured amount. The active exercise values are seeded
in a separate migration so future rule changes can preserve historical ledger
amounts.
