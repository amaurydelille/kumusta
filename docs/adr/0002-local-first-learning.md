# ADR 0002: Local-first learning state

Status: accepted

## Context

Learning sessions often occur on transport or unreliable mobile networks.
Failure to reach a backend must not discard practice or block the daily lesson.

## Decision

Bundle starter curriculum, commit progress locally first, and synchronize
append-only events idempotently. Server-published curriculum remains canonical.

## Consequences

The app remains useful offline and sync can recover safely. It requires explicit
schema versioning, an outbox, conflict rules, and tests for duplicate delivery.
