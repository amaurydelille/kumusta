# Kumusta — working rules

Kumusta is a Cantonese-learning iOS app forked from VietBuddy (`../viet-buddy`).
Read `PLAN.md` for the phases; `README.md` for commands.

## Hard rules

- **VietBuddy is read-only.** Read `../viet-buddy` freely, but never write
  there, and never run Supabase CLI commands from inside it. Never touch the
  VietBuddy Supabase project (`hjfuruunhhwkszdysyuo`) — it is production.
  The only database you may write to is Kumusta, `vpitjvtfzpqfnqgzcpla`.
  Pass `--workdir` pointing at this repo (or `--project-ref vpitjvtfzpqfnqgzcpla`)
  on every Supabase CLI call.
- **No secrets in git.** `Config/Secrets.xcconfig`, `.env*`, `*.p8` stay local.
  Provider keys live only in Edge Function secrets.
- **iOS only.** No Android work.
- **English only.** No French (or other) interface language or content translations.
- **Onboarding is mandatory.** No learner reaches account creation, the paywall
  or the app before completing onboarding (only an account that already
  completed it may sign in and skip it).
- **Just Cantonese.** No accent or dialect choice anywhere — not in onboarding,
  Profile, lessons, live practice, prompts or APIs.
- **Language rules for content:** Hong Kong Cantonese, Traditional characters,
  colloquial written Cantonese (佢/唔/嘅/咗/喺/冇), never Standard Written Chinese
  or Simplified characters; Jyutping with tone numbers.

## Database

- Schema changes go in new migrations; never edit the baseline.
- Each migration that creates tables, views or functions must explicitly revoke
  client privileges (hosted Supabase grants them by default) and grant only
  what the app needs. Run `supabase/tests/baseline_security.sql` after pushing.

## Code

- Match surrounding code; the iOS architecture is View → Store →
  protocol → adapter, with SDK types never reaching views.
- Keep the analytics enum, the Swift property allowlist and the SQL validator
  in sync (`scripts/check_analytics_catalog.py`).
