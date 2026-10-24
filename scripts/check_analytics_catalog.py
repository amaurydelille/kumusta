#!/usr/bin/env python3
"""Fail when the Swift event/property catalogs drift from the database validator."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
swift = (ROOT / "Kumusta/Domain/LearningModels.swift").read_text()
events = set(re.findall(r'case \w+ = "([a-z_]+)"', swift.split("enum AnalyticsEvent:", 1)[1].split("\n}", 1)[0]))
repository = (ROOT / "Kumusta/Data/Supabase/SupabaseSignedInRepository.swift").read_text()
keys = set(re.findall(r'"([a-z_]+)"', repository.split("let allowedKeys = [", 1)[1].split("]", 1)[0]))
migrations = sorted((ROOT / "supabase/migrations").glob("*.sql"))
# Matches both hand-written migrations and `supabase db dump` output (quoted identifiers).
signature = re.compile(r'create or replace function "?public"?\."?kumusta_validate_analytics_event"?\(\)', re.IGNORECASE)
validator = [p for p in migrations if signature.search(p.read_text())][-1].read_text()
validator = validator[signature.search(validator).start():]
db_keys = set(re.findall(r"'([a-z_]+)'", validator.split("v_allowed_keys constant text[] := array[", 1)[1].split("];", 1)[0]))
db_events = set(re.findall(r"'([a-z_]+)'", validator.split("if new.event_name not in (", 1)[1].split(") then", 1)[0]))
assert events == db_events, f"Event drift: Swift-only={events-db_events}, SQL-only={db_events-events}"
assert keys == db_keys, f"Property drift: Swift-only={keys-db_keys}, SQL-only={db_keys-keys}"
mutation = repository.split("struct AnalyticsEventMutation:", 1)[1].split("struct CancellationFeedbackMutation:", 1)[0]
assert 'case clientSessionID = "client_session_id"' not in mutation, "Nonexistent database column reintroduced"
print(f"Analytics contract OK: {len(events)} events, {len(keys)} property keys")
