# Kumusta — working rules

Kumusta is a Tagalog-learning iOS app forked from VietBuddy (`../viet-buddy`).
Read `PLAN.md` for the phases; `README.md` for commands.

## Hard rules

- **Never touch VietBuddy.** It is the owner's main startup, in production.
  Do not write to, run commands in, or deploy from `../viet-buddy`, and never
  touch its Supabase project (`hjfuruunhhwkszdysyuo`). Port from the code
  already copied into this repo.
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
- **Just Tagalog.** No accent, dialect or other Philippine language anywhere —
  not in onboarding, Profile, lessons, live practice, prompts or APIs.
- **Language rules for content:** everyday conversational Tagalog as spoken in
  Metro Manila, in modern standard spelling (`ng`/`nang`, `din`/`rin`,
  `daw`/`raw` used correctly) and without stress marks. Use `po`/`opo` wherever
  the scene calls for respect (elders, strangers, service). Taglish only where a
  Manila speaker would naturally switch; English words keep English spelling.
  Spanish-derived numbers where locals use them (time, prices). Never Cebuano,
  Ilocano or other languages, and never stiff textbook Filipino.

## Database

- Schema changes go in new migrations; never edit applied migrations.
- Each migration that creates tables, views or functions must explicitly revoke
  client privileges (hosted Supabase grants them by default) and grant only
  what the app needs. Run `supabase/tests/baseline_security.sql` after pushing.

## Code

- Match surrounding code; the iOS architecture is View → Store →
  protocol → adapter, with SDK types never reaching views.
- Keep the analytics enum, the Swift property allowlist and the SQL validator
  in sync (`scripts/check_analytics_catalog.py`).
