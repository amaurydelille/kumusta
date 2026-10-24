# Kumusta

Kumusta is a native SwiftUI app for learning spoken Tagalog (everyday Metro
Manila Tagalog), in English only. It is a fork of VietBuddy; see
[PLAN.md](PLAN.md) for what is done and what is next.

> **Status:** the app, backend and content are Tagalog. The authored roadmap
> (`supabase/catalog/tagalog-v1/`) has 10 lessons each for beginner,
> intermediate and advanced, all awaiting native-speaker review. Most files in
> `docs/` are still inherited from VietBuddy.

## Layout

| Path | What |
|---|---|
| `Kumusta/`, `KumustaTests/`, `KumustaUITests/` | iOS app (Swift 6, SwiftUI, iOS 17+) and tests |
| `project.yml` | XcodeGen spec; `kumusta.xcodeproj` is generated from it |
| `Config/` | xcconfigs; `Secrets.xcconfig` is local only (copy the `.example`) |
| `supabase/migrations/` | Database schema (one squashed baseline plus later migrations) |
| `supabase/functions/` | Edge Functions (`kumusta-*`) |
| `supabase/catalog/tagalog-v1/` | Authored Tagalog roadmap sources and builder (`build.ts`) |
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

Edge Function secrets:

| Secret | Used for |
|---|---|
| `KUMUSTA_TTS_API_KEY` | ElevenLabs text-to-speech for lessons (cached in the `kumusta-tts` bucket) and live conversation |
| `KUMUSTA_LESSON_STT_API_KEY` | Soniox speech-to-text for lesson pronunciation (`kumusta-lesson-stt`, `kumusta-lesson-stt-token`) |
| `KUMUSTA_LESSON_AGENT_API_KEY` | Soniox speech-to-text for live conversation (`kumusta-live-pipeline`) |
| `KUMUSTA_LLM_LIVE_CONVERSATION` | Anthropic key for live conversation (Claude Opus 5.5) |
| `KUMUSTA_TTS_VOICE_ID` | Optional voice override (default `qZLi51uuzx5jdu6q0ayz`) |

Not set yet: `DASHSCOPE_API_KEY` / `QWEN_LESSON_MODEL` (lesson generation), the RevenueCat
secrets, `EMAIL_WORKER_AUTHORIZATION`, `RESEND_API_KEY`, `EMAIL_FROM`, `KUMUSTA_ENTITLEMENT_ID`.
Without a provider's secret, its functions fail closed with 503.

## iOS

```sh
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig   # then fill it in
xcodegen generate && pod install
xcodebuild -workspace kumusta.xcworkspace -scheme Kumusta \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KumustaTests test
```

Bundle ID `com.kumusta.app`, entitlement `kumusta_pro`.

## Content

```sh
# Validate the authored roadmap and regenerate the catalog JSON, app seeds and seed migration
deno run --allow-read --allow-write supabase/catalog/tagalog-v1/build.ts
# Bundled audio for the welcome lessons (needs ELEVENLABS_API_KEY)
deno run --allow-read --allow-write --allow-net --allow-env scripts/generate-first-lesson-audio.ts
```

## Checks (also run in CI)

```sh
deno fmt --check supabase/functions && deno lint supabase/functions
deno check supabase/functions/*/index.ts
deno test --allow-env --allow-read supabase/functions
python3 scripts/check_analytics_catalog.py
python3 scripts/check-app-strings.py
```
