# Kumusta

Kumusta is a native SwiftUI app for learning spoken Cantonese (Hong Kong,
Traditional characters, Jyutping), in English only. It is a fork of VietBuddy; see
[PLAN.md](PLAN.md) for the full port plan and its phases.

> **Status: Phase 1 (fork, strip, rename) is done.** The app still ships
> VietBuddy's Vietnamese content, which proves the rename end to end. The
> Cantonese language layer and content arrive in Phases 2–4. Most files in
> `docs/` are inherited from VietBuddy and are rewritten as each phase lands.

## Layout

| Path | What |
|---|---|
| `Kumusta/`, `KumustaTests/`, `KumustaUITests/` | iOS app (Swift 6, SwiftUI, iOS 17+) and tests |
| `project.yml` | XcodeGen spec; `kumusta.xcodeproj` is generated from it |
| `Config/` | xcconfigs; `Secrets.xcconfig` is local only (copy the `.example`) |
| `supabase/migrations/` | Database schema (one squashed baseline plus later migrations) |
| `supabase/functions/` | Edge Functions (`kumusta-*`) |
| `supabase/catalog/` | Offline roadmap builders (still Vietnamese until Phase 4) |
| `supabase/tests/` | SQL assertions (`baseline_security.sql`) |
| `supabase/ops/` | One-off operational SQL (e.g. the email-worker cron) |
| `scripts/` | Content, audio and parity scripts |
| `website/`, `marketing/` | Still VietBuddy-branded; rebuilt in Phase 9 |

## Supabase

Dev project: **Kumusta**, ref `vpitjvtfzpqfnqgzcpla`. This repo is linked to it
(`supabase/.temp/project-ref`). Never point any command, config or script at
the VietBuddy project — it is production for another app.

```sh
supabase db push --workdir .                     # apply new migrations
supabase db query --linked --workdir . -f supabase/tests/baseline_security.sql
supabase functions deploy --project-ref vpitjvtfzpqfnqgzcpla --use-api
```

Hosted Supabase grants `anon`/`authenticated` broad default privileges on new
objects. Every migration that creates a table, view or function must revoke
what clients should not have; `baseline_security.sql` fails otherwise.

Edge Function secrets (none are set yet): `DASHSCOPE_API_KEY`,
`QWEN_LESSON_MODEL`, `ANTHROPIC_API_KEY`, `KUMUSTA_LIVE_LLM_MODEL`,
`ELEVENLABS_API_KEY`, `SONIOX_API_KEY`, `REVENUECAT_WEBHOOK_AUTHORIZATION`,
`REVENUECAT_SECRET_API_KEY`, `REVENUECAT_PROJECT_ID`, `EMAIL_WORKER_AUTHORIZATION`,
`RESEND_API_KEY`, `EMAIL_FROM`, `KUMUSTA_ENTITLEMENT_ID`. See
`supabase/.env.example`. Without them, provider functions fail closed with 503.

## iOS

```sh
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig   # then fill it in
xcodegen generate && pod install
xcodebuild -workspace kumusta.xcworkspace -scheme Kumusta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KumustaTests test
```

Bundle ID `com.kumusta.app`, entitlement `kumusta_pro`.

## Checks (also run in CI)

```sh
deno fmt --check supabase/functions && deno lint supabase/functions
deno check supabase/functions/*/index.ts
deno test --allow-env --allow-read supabase/functions
python3 scripts/check_analytics_catalog.py
python3 scripts/check-app-strings.py
```
