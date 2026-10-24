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

The two approved female voice identifiers are compiled into the server
allowlist; clients send only `southern` or `northern`, so arbitrary voice
selection is impossible.

`supabase/config.toml` sets `verify_jwt = false` at the gateway for the three
provider Functions (`kumusta-elevenlabs-tts`,
`kumusta-mistral-evaluate`, and `kumusta-mistral-lessons`) and the RevenueCat
webhook because their handlers perform stricter authentication themselves.
Provider handlers validate a refreshed Supabase session and enforce entitlement
and quota before provider access; completion/review writes remain authenticated
and owner-checked even when replenishment is not allowed. The RevenueCat webhook
validates its own authorization and optional signature. The account-data
function keeps gateway JWT verification enabled and repeats registered-user
validation inside the handler. Do not remove those checks.

LLM provider configuration belongs only in Edge Function secrets:

```text
MISTRAL_API_KEY=required
MISTRAL_MODEL=mistral-small-latest
DASHSCOPE_API_KEY=required
QWEN_LESSON_MODEL=qwen3.8-max-0902
KUMUSTA_LESSON_PROVIDER=qwen
ELEVENLABS_API_KEY=required-for-provider-audio
KUMUSTA_ENTITLEMENT_ID=kumusta_pro
```

`MISTRAL_MODEL` is used by frequent, bounded text evaluation.
`QWEN_LESSON_MODEL` controls adaptive lesson generation and defaults to the
pinned `qwen3.8-max-0902` snapshot when absent. `DASHSCOPE_API_KEY` is the
server-only QwenCloud credential. `KUMUSTA_LESSON_PROVIDER=qwen` promotes Qwen
behind the stable `kumusta-mistral-lessons` client endpoint, so existing app
versions switch without an App Store update. Set it to `mistral` to roll back;
the Mistral implementation and secret remain installed. The separate
`kumusta-qwen-lessons` preview function always selects Qwen regardless of the
project-wide rollback setting.
Changing either model requires the contract and regional-language gates in
`docs/backend/MISTRAL_RUNBOOK.md`; no model identifier belongs in iOS config.
Without `ELEVENLABS_API_KEY`, voice functions fail closed with a sanitized
`503`. The key must grant both Text to Speech and Speech to Text. A TTS-only key
plays lessons but Scribe returns `missing_permissions`; update or rotate it in
the ElevenLabs dashboard and reinstall the Edge Function secret.

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
