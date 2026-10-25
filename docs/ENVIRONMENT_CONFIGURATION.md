# Environment configuration

## iOS configuration

Create `Config/Secrets.xcconfig` from the example:

```xcconfig
SUPABASE_PROJECT_URL = https:/$()/your-production-project.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_your_production_key
REVENUECAT_PUBLIC_SDK_KEY = appl_your_public_ios_key
KUMUSTA_ENTITLEMENT_ID = kumusta_pro
APPSFLYER_DEV_KEY = your_appsflyer_dev_key
APPSFLYER_APP_ID = your_apple_app_id
```

Debug builds use the supplied temporary Supabase project. Release builds have
no project by default and must receive a separate production URL and publishable
key through `Secrets.xcconfig`. A Release archive must never inherit the
temporary project reference. Publishable keys are safe to ship but should still
be rotated if abused; never replace one with a secret key.

## Supabase Edge Function secrets

Copy `.env.example` to an untracked local file, replace every placeholder, then
use the project secret manager:

```sh
supabase secrets set --project-ref vpitjvtfzpqfnqgzcpla \
  --env-file .env
```

The client never sends a voice ID. Kumusta speaks with one Tagalog voice,
`qZLi51uuzx5jdu6q0ayz` by default, which `KUMUSTA_TTS_VOICE_ID` overrides
server-side, so arbitrary voice selection by a client is impossible.

`supabase/config.toml` sets `verify_jwt = false` at the gateway for the
provider Functions (`kumusta-elevenlabs-tts`, `kumusta-lesson-stt`,
`kumusta-lesson-stt-token`, `kumusta-lessons`, and `kumusta-live-pipeline`),
`kumusta-award-xp`, the RevenueCat webhook and its admin function, and the
email worker, because their handlers perform stricter authentication
themselves. Provider handlers validate a refreshed Supabase session and enforce
entitlement and quota before provider access; completion/review writes remain
authenticated and owner-checked even when replenishment is not allowed. The
RevenueCat webhook validates its own authorization and optional signature. The
account-data and curriculum-admin functions keep gateway JWT verification
enabled and repeat validation inside the handler. Do not remove those checks.

Provider configuration belongs only in Edge Function secrets:

```text
KUMUSTA_TTS_API_KEY=required-for-provider-audio
KUMUSTA_TTS_VOICE_ID=optional-override
KUMUSTA_LESSON_STT_API_KEY=required-for-speaking-checks
KUMUSTA_LESSON_AGENT_API_KEY=required-for-live-practice-stt
KUMUSTA_LLM_LIVE_CONVERSATION_API_KEY=required-for-live-practice
DASHSCOPE_API_KEY=required-for-lesson-generation
QWEN_LESSON_MODEL=qwen3.8-max-0902
KUMUSTA_ENTITLEMENT_ID=kumusta_pro
```

`KUMUSTA_TTS_API_KEY` is the ElevenLabs key for lesson and live-conversation
audio. `KUMUSTA_LESSON_STT_API_KEY` and `KUMUSTA_LESSON_AGENT_API_KEY` are
Soniox keys for lesson speaking checks and live conversation respectively.
`KUMUSTA_LLM_LIVE_CONVERSATION_API_KEY` is the Anthropic key for live
conversation. `QWEN_LESSON_MODEL` controls adaptive lesson generation in
`kumusta-lessons` and defaults to the pinned `qwen3.8-max-0902` snapshot when
absent; `DASHSCOPE_API_KEY` is the server-only Qwen credential. Changing a
model requires the contract and native-speaker sample gates in
`docs/backend/LESSON_GENERATION_RUNBOOK.md`; no model identifier belongs in iOS config.
Without a provider's secret, its functions fail closed with a sanitized `503`.

Optional bounded TTS budgets are also Edge Function configuration:

```text
KUMUSTA_TTS_USER_DAILY_REQUEST_LIMIT=500
KUMUSTA_TTS_PROJECT_DAILY_REQUEST_LIMIT=10000
KUMUSTA_STT_USER_DAILY_REQUEST_LIMIT=300
KUMUSTA_STT_PROJECT_DAILY_REQUEST_LIMIT=8000
```

The user limit must be `1...10000`; the project limit must be `1...1000000`.
Invalid values fail closed as service misconfiguration. Keep the default or a
lower reviewed budget until production demand and provider spend justify a
change.

The isolated simulator project may set both values below so the debug paywall
bypass can exercise real providers without fabricating a RevenueCat webhook:

```text
KUMUSTA_ENVIRONMENT=development
KUMUSTA_DEVELOPMENT_BYPASS_ENTITLEMENT=true
```

The switch is server-owned, defaults closed, and refuses to activate unless
the environment is exactly `development`. It must be absent or false in staging
and production.

## Environments

At minimum maintain separate development and production Supabase/RevenueCat
projects before public TestFlight. Never test destructive migrations, webhook
replays, or provider quota changes against a database that holds production
learner data.

## Secret scanning

Release CI must scan:

- repository contents and history;
- generated Xcode build settings;
- archived app bundle strings;
- Edge Function source maps and deployment logs.

Any leaked provider or service key is rotated immediately, then logs are
reviewed for misuse.
