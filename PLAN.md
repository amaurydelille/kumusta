# Kumusta — Cantonese clone of VietBuddy: execution plan

_Written 2026-10-24 from an analysis of `../viet-buddy` (iOS app, Supabase backend, content pipeline, website, docs). Implementation has not started._

**Scope:**
- Recreate VietBuddy's product and playbook for **Cantonese** (Hong Kong, Traditional characters, Jyutping).
- iOS only. **Android is out of scope.**
- The two-speaker dialogue feature ("Listening Quest" / Listen & learn conversations) is **removed**.

**Paths:**
- `VB/` = `../viet-buddy/mobile-app/vietbuddy/`
- `S/` = `VB/supabase/`

---

## 0. Executive summary

VietBuddy is a native SwiftUI app (iOS 17+, Swift 6) on Supabase:
- 18 Edge Functions and 67 migrations.
- A Qwen lesson-generation queue.
- ElevenLabs TTS and STT.
- A live STT → Claude → TTS conversation pipeline.
- RevenueCat with a hard paywall.
- An FSRS-5 spaced-repetition deck.
- XP, streaks and a realtime leaderboard.
- A puppet-rigged mascot lip-synced to audio features.

About 70% of the code does not depend on the language. Six areas are deeply Vietnamese and must be redesigned for Cantonese, not renamed:

1. **The written form.** There are no spaces between words, the script is Han characters, and learners need a romanization (Jyutping). Every validator, tokenizer, gloss rule, tile bank and matcher that does `split(/\s+/)` or checks diacritics breaks.
2. **Tones.** Cantonese has 6 tones (9 with checked tones), not 6 diacritic tones. Tone look-alike distractors, the teaching contours, pronunciation coaching and accepted "sound variants" (懶音, lazy sounds) all need new rules.
3. **Spoken vs written.** Lessons must be written colloquial Cantonese (佢 / 唔 / 嘅 / 咗 / 喺 / 冇), never Standard Written Chinese (他 / 不 / 的 / 了 / 在 / 沒有), and never Simplified characters.
4. **The accent axis.** Southern/Northern goes away **completely**. Kumusta teaches one Cantonese (Hong Kong). No accent is offered or mentioned anywhere: not in onboarding, Profile, lessons, live practice, or the API (owner decision, 2026-10-24).
5. **Speech providers.** Cantonese STT and TTS quality varies far more between vendors than Vietnamese. A provider bake-off is the first real task.
6. **Content.** All curricula, first lessons, the First Steps basics course, the flashcard seed, prompts and personalities are rewritten.

**Strategy:**
- Fork VietBuddy into this repo.
- Strip the dead code, the dialogue feature, Android, the legacy live paths and Mistral.
- Rename `vietbuddy` → `kumusta` everywhere.
- Put the language behind a small `Cantonese` domain layer on the client and the server.
- Rebuild the content pipeline for Cantonese.
- Squash the 67 migrations into one clean baseline in a new Supabase project.

---

## 1. Decisions needed from the owner (blockers marked ⛔)

| # | Decision | Recommendation |
|---|---|---|
| D1 ⛔ | Product name, bundle ID, domain | Working name **Kumusta** (你好, nei5 hou2). Bundle `com.kumusta.app`; entitlement `kumusta_pro` |
| D2 ✅ | Variant / script | **Decided: just Cantonese, no accent choice anywhere.** Hong Kong Cantonese, **Traditional characters (HK standard)**, **Jyutping** romanization. The accent dimension is removed from the data model, not hidden |
| D3 ⛔ | Mascot character | Pick an HK-native character: e.g. a **milk-tea cup** (奶茶), a **har gow / dim sum** buddy, a **lion-dance cub** (醒獅), or a **Chinese white dolphin**. The rig pipeline is the same whichever you pick (§9) |
| D4 ⛔ | STT provider | Decided by the bake-off (§3). Soniox is already integrated in the live pipeline and is the first candidate |
| D5 ⛔ | TTS provider and voice(s) | Decided by the bake-off (§3). ElevenLabs is preferred for code reuse, but only if its Cantonese is genuinely Cantonese (not Mandarin-accented) |
| D6 | Live LLM | **Claude Opus 5.5** (`claude-opus-5-5`) as you asked. Keep `KUMUSTA_LIVE_LLM_MODEL` as an env switch. Measure first-token latency against the current Haiku 5.5 baseline (§10) |
| D7 ✅ | UI language | **Decided: English only, no French version** (owner, 2026-10-24). French UI, French content overlays, the language picker and the translation tooling were removed in Phase 1; only the English `L()` string catalog remains |
| D8 | Jyutping display default | Show Jyutping above the characters by default, with a Profile toggle: Always / On tap / Never. Beginners need it; heritage learners may hide it |
| D9 | Markets / ICP | Diaspora: US, Canada, UK, Australia. Heritage learners plus partners of Cantonese speakers. This mirrors the VietBuddy "Partner" ICP |
| D10 | Text-evaluation feature (`mistral-evaluate`) | Check whether the client still calls it. If yes, rewrite it on Qwen. If not, drop it |
| D11 | Pricing | Copy VietBuddy ($69.99/yr, $7.99/wk, "Fallback" offering) as the starting point |

---

## 2. What we keep, adapt, rewrite, drop

### 2.1 Drop (do not port)
- **Android:** all of `mobile-app/android/`, the `android` platform in analytics checks, and the Android secrets.
- **Dialogue / Listening Quest:**
  - App code: `ConversationPracticeView.swift`, `ConversationRepository.swift`, `Resources/Audio/Conversations/`, the second card of `PracticeSessionChooser`.
  - Backend: `vietbuddy_conversation_*` tables, the `conversation-audio` bucket, the conversation badges and their triggers, the `conversation_completed` XP rule.
  - Analytics: the `conversation_*` events.
  - Scripts: `generate-conversation-audio.ts`, `conversation-audio-mastering.ts`, `publish-conversation-audio.ts`, `build-conversation-seed.ts`, `verify-conversation-catalog.ts`; the `content/conversations-v1*.json` files; `CONVERSATION_PRACTICE_RUNBOOK.md`.
  - Check whether the `vietbuddy_conversation_attempts` branch in `award-xp` has anything else depending on it before removing it.
- **Legacy live paths:**
  - `vietbuddy-live` (the ElevenLabs Agent path, the OpenAI `gpt-live-1` relay, OpenAI moderation).
  - `LivePracticeSession.swift` (the `VIETBUDDY_LIVE_AGENT` flag).
  - The `elevenlabs-swift-sdk` and LiveKit dependencies, once the audio meter no longer needs LiveKit.
  - `vietbuddy_live_reserve` and the 5-minute allowance RPCs, if the pipeline's own session logic replaces them (§10).
- **Mistral:** `vietbuddy-mistral-lessons` becomes `kumusta-lessons` (Qwen only), along with `vietbuddy-qwen-lessons` (the preview shim), the dead `alignment.ts` / `glosses.ts`, and `MISTRAL_*` env.
- **Dead client code:**
  - `ColdListenDemoScreen`, `OnboardingPhraseDecode/Build/FirstWin` screens, the custom `PaywallView`, `ReviewSessionView`.
  - `WordDetailView`, `ContextPracticeView`, `WordsViewModel`, `QuickRepViews`, `DailyGoalRing`, the legacy `curriculum-v1.json` / `SampleContent` fallback, the legacy `PracticeScheduler`.
- **Stale data:**
  - Old voice IDs in `.env.example` and DB checks.
  - Quarantine migrations, backfill migrations, dropped tables.
  - The hardcoded project ref `hjfuruunhhwkszdysyuo`.
- **Secrets — never copy:** `*.p8` keys, `VB/.env`, `Config/Secrets.xcconfig`, `.opencode/supabase-auth.json`, `android/secrets.properties`.

### 2.2 Keep almost as is (rename only)
- App architecture: `DependencyContainer`, protocols and actors, local-first stores, the `CloudUserState` sync blob, the launch state machine.
- RevenueCat flow: the hosted paywall → `Fallback` offering → exit screen, plus the purchase attribution plumbing.
- Anonymous Supabase auth → email/password upgrade. Optionally also wire up the existing Sign in with Apple code, which is implemented but not used.
- Analytics outbox, PostHog, AppsFlyer, TikTok, Meta, and the `check_analytics_catalog.py` parity check.
- Notifications (daily reminder, streak-at-risk, achievements) and `RatingPromptManager`.
- XP system, achievements (10), streaks, realtime leaderboard, DiceBear avatars, celebrations, sound effects.
- FSRS-5 `MemoryScheduler` / `MemoryStore` and daily review session logic (the exercise *content* is adapted, see §6).
- Lesson queue, job, lease and quota machinery; deterministic adaptation RPCs; durable adaptive outbox; TTS cache (bucket + lease RPCs).
- RevenueCat webhook + admin, entitlement mirror, email worker (Resend) + pg_cron, account export/delete, cancellation-feedback flow.
- `_shared/http.ts`, `_shared/auth.ts`, quota RPCs, the dev entitlement bypass.
- Live pipeline session/streaming skeleton: NDJSON, PCM streaming, the half-duplex mic, VAD turn commit, 10 s silence end, captions, mute, continuation window, echo ignore.
- Mascot lip-sync engine (audio-feature based, so it works for any language) and the rig renderer.
- Design-system mechanics: motion rules, type floors, hit targets, audio-reactive border.
- Website stack, legal pages, App Store redirect worker, screenshot renderers.

### 2.3 Adapt or rewrite (language-specific)
Covered in §4–§10. Summary:
- Domain types for accent / tones / numbers.
- Tokenization and glosses.
- Lesson contract and validators.
- Prompts (lessons, editorial review, live coaching, personalities).
- Pronunciation matcher and coaching.
- Listen tile-bank distractors.
- First lessons and the First Steps course.
- Roadmap and goal curricula.
- Flashcard seed.
- Onboarding copy and options.
- Fixed TTS lines.
- Profanity filter.
- STT / TTS provider adapters.
- Fonts / CJK rendering.
- Mascot artwork.
- Website content.

---

## 3. Phase 0 — Provider bake-off and accounts (do first; blocks content and live)

### 3.1 Test set
- About 60 Cantonese clips:
  - 20 beginner phrases spoken by a learner (non-native accent);
  - 20 native conversational lines with HK code-mixing ("OK 啦", "check 下", "book 咗枱");
  - 10 numbers, prices and times;
  - 10 noisy or phone-quality clips.
- Ground truth in Traditional characters plus Jyutping.

### 3.2 STT candidates
Each candidate needs both **realtime streaming** (live practice) and **batch** (speak checks):
- **Soniox** `stt-rt` (already wired in `vietbuddy-live-pipeline`; set `language_hints:["yue","en"]` and verify the code name).
- ElevenLabs Scribe v2 / v2 realtime (verify that `yue` is supported and outputs Traditional characters).
- Azure Speech `zh-HK`.
- Google Chirp (`yue-Hant-HK`).
- Alibaba DashScope Paraformer / Qwen-ASR (the `DASHSCOPE_API_KEY` is already in place).
- Deepgram (Cantonese).

**Metrics:**
- Character error rate (CER) on Traditional output, after OpenCC s→t normalization;
- whether it outputs **Cantonese colloquial characters** rather than "Mandarin-izing" them (e.g. 佢 not 他);
- code-mixed English handling;
- first-partial latency and endpointing quality;
- price per minute;
- a single-use / temporary token flow, so the client never holds the key.

### 3.3 TTS candidates
Each candidate needs **low-latency streaming PCM** for live, plus high-quality MP3 for lessons:
- ElevenLabs (`eleven_v4` / `eleven_v4_turbo` with `language_code:"yue"` if available).
- Azure Neural `zh-HK` (HiuGaai / HiuMaan / WanLung).
- MiniMax Speech (Cantonese).
- Qwen-TTS (Cantonese dialect voices).
- Google Chirp 3 HD `yue-HK`.

**Criteria:**
- Native-speaker MOS on tones and naturalness. This is the most important criterion: tone errors make the voice unusable for teaching.
- Correct reading of colloquial characters and polyphones (e.g. 行 hang4 / hong4, 樂 lok6 / ngok6).
- Speed control.
- Determinism / seed.
- Streaming PCM 24 kHz.
- Price.

**Rules:**
- One approved female voice is the default teacher. An optional male voice can be used for live personalities.
- Voice IDs stay in a server-side allowlist, exactly as now.
- The client never sends a voice ID (or any accent); the server always uses the one approved teacher voice.

### 3.4 Output of Phase 0
- `docs/PROVIDERS.md` with the scores, the decision, and pinned model / voice IDs.
- If TTS and STT come from different vendors, the server-side `SpeechProvider` interfaces described in §5.3 become mandatory, not optional.

### 3.5 Accounts and infra to create
- New Supabase project for dev, and a separate one for prod.
- RevenueCat project (entitlement `kumusta_pro`, default + `Fallback` offerings, weekly / annual products).
- App Store Connect app and IAPs.
- AppsFlyer, TikTok, Meta and PostHog apps.
- Resend domain.
- Anthropic key / workspace and DashScope key.
- Keys for the chosen STT and TTS providers.
- Domain, website hosting, support inbox.
- Apple team: reuse the existing one.

---

## 4. Phase 1 — Repo bootstrap

1. Copy into `kumusta/`:
   - `VB/` → `ios/` (app, tests, `project.yml`, Podfile, Config examples, scripts, docs).
   - `S/` → `supabase/`.
   - `website/` → `website/`.
   - `mobile-app/app-store-screenshots/` → `marketing/screenshots/`.
   - `content/prompts` → `marketing/prompts`.
   - Copy only source files: no `build/`, `Pods/`, `.next/`, `dist/` or `.wrangler/`.
2. Apply every drop in §2.1 **before** renaming, so the diff stays reviewable.
3. Rename everywhere:
   - Prefixes: `vietbuddy_`, `vietbuddy-`, `VIETBUDDY_`, `VietBuddy` → `kumusta_`, `kumusta-`, `KUMUSTA_`, `Kumusta`.
   - Headers: `x-vietbuddy-*` → `x-kumusta-*`.
   - Bucket names, JSON-schema names, the `Symbol.for(...)` key, the cron job, the Vault secret, AppStorage / UserDefaults keys, the bundle ID, test target IDs, `Info.plist` keys, the entitlement ID.
   - Email sender, support email, legal URLs.
4. Neutralize language-bound field names in contracts and models:
   - `vietnamese` → `text` (or `target`); `prompt_vietnamese` → `prompt_text`; `vietnamese_text` → `text`.
   - Add a `jyutping` field next to every target-language string.
   - This is a one-time cost that makes the next language trivial.
5. Squash migrations into a single `0001_baseline.sql` that reproduces the **final** VietBuddy schema minus the dropped objects (the accent columns are removed in Phase 2, §5.2). Then add seed migrations separately.
6. Tooling:
   - `.mcp.json` with the Supabase MCP for the new project.
   - Serena configured for swift + typescript.
   - `deno.json`.
   - Rename `scripts/check-app-strings.py`, `build-app-strings.py`, `check_analytics_catalog.py`.
   - CI: `xcodegen` drift check, `xcodebuild test`, `deno fmt/lint/check/test`, secret scan.
7. `CLAUDE.md` / `README.md` for the new repo:
   - Language rules: Traditional HK, colloquial, Jyutping.
   - The no-secrets rule.
   - Build and run commands.

**Exit criteria:** the app builds and runs against the new dev Supabase project with Vietnamese content still inside it. That proves the rename and the strip before the language swap.

---

## 5. Phase 2 — Cantonese language core (client and server)

The single most important phase. Build a shared, well-tested language layer and route every former Vietnamese special case through it.

### 5.1 Data assets
- **Jyutping lexicon:** a word → Jyutping map with frequencies, built from **rime-cantonese** (CC BY 4.0; check the licence). Optionally cross-check against CC-Canto / CC-CEDICT (CC BY-SA).
  - Ship it as a compact JSON/SQLite in the app and as a JSON module in Edge Functions.
  - Avoid words.hk data unless its licence allows it.
- **Simplified-only character set:** from OpenCC `STCharacters`, used to reject Simplified output.
- **Standard Written Chinese marker list:** 他 / 她 / 不 / 的 (as a particle) / 了 / 在 / 沒有 / 這 / 那 / 什麼 / 是不是, mapped to their colloquial equivalents (佢 / 唔 / 嘅 / 咗 / 喺 / 冇 / 呢 / 嗰 / 乜嘢 / 係唔係).
  - Use it as a validator **warning / score**, not a hard ban, because some SWC forms are legitimate.
- **Number reader:** Arabic digits ↔ 一二三 / 兩 / 十 / 百 / 千 / 萬, plus money (蚊 / 毫 / 個半) and times (點 / 個字 / 半).
  - This replaces `VietnameseNumber` and is needed for STT normalization.

### 5.2 Domain model changes (`Domain/UserProfile.swift`, the TS contracts, DB checks)
- **Accent:** `VietnameseAccent {southern, northern}` is **deleted**. There is no replacement enum, column, request field or UI. One Cantonese, one voice allowlist entry, one bundled-audio folder.
  - Remove the accent onboarding step, or replace it with the Jyutping display question (§7.1).
  - DB `accent` columns and their checks are dropped.
  - The location-consistency validator is dropped.
  - Per-accent bundled audio folders collapse to one.
- **Goals:** `lifeInVietnam` → `lifeInHongKong`. Keep family, travel, partner, work and culture/roots. Consider adding "Understand Cantopop / TVB / films" as a culture variant.
- **Levels:** `beginner / intermediate / advanced` (owner decision, 2026-10-24). Heritage speakers who understand but can't speak start at intermediate.
- **Tones:** `CantoneseTone 1…6` (map 7/8/9 entering tones onto 1/3/6 in Jyutping, as standard), each with contour metadata (55/53, 25, 33, 21/11, 23, 22) for the teaching visuals.

### 5.3 Tokenization and segmentation (replaces every `split(/\s+/)`)
- `CantoneseText.segment(text) -> [Token]`.
  - Longest-match over the lexicon.
  - Latin runs (English code-mixing) count as one token; digits as one token; punctuation (。，！？、「」…) as separate tokens.
  - Implement it in **both** Swift and TS from the same lexicon file, with shared golden tests (one JSON fixture both test suites read).
- `jyutping(for: token)`: lexicon lookup with polyphone resolution.
  - Prefer the LLM-provided reading when it is a valid reading of that character or word; otherwise use the most frequent reading and flag it.
- **Gloss rules**, which replace "≤ 2 syllables per gloss":
  - A gloss unit is a lexicon word (1–4 characters), and must be a valid segmentation.
  - The concatenation of all gloss tokens must equal the utterance exactly, punctuation included.
  - Each gloss carries `{token, jyutping, english}`.
- **Answer-leakage check:** compare UI copy against the utterance's Han characters **and** its toneless Jyutping. The current de-accent normalization returns an empty string for Han text, so the check would silently pass.

### 5.4 Validators (server `contract.ts`; mirrored client-side where the app re-validates)
These replace `boundedVietnamese`, `containsVietnameseOrthography`, diacritic checks, speaker-label regex, location checks and quarantine regexes.

- **Utterance:**
  - must contain Han characters;
  - zero Simplified-only characters;
  - Latin tokens allowed only up to a share (e.g. ≤ 30%);
  - no speaker labels (the regex must also catch `店員：`, using a full-width colon).
- **Jyutping:**
  - every syllable matches `^(b|p|m|f|d|t|n|l|g|k|ng|h|gw|kw|w|z|c|s|j)?(aa|a|e|i|o|u|oe|eo|yu|m|ng)(i|u|p|t|k|m|n|ng)?[1-6]$` (refine with the valid-final table);
  - the syllable count equals the Han character count per token;
  - every reading is in the lexicon's reading set for that character (polyphones allowed).
- **Colloquial score:** count SWC markers against Cantonese markers. Reject at beginner levels if the utterance is clearly 書面語; otherwise warn and pass it to the editorial review.
- **Chunks:** must be ordered substrings of the utterance. This already works for Han text; just remove whitespace normalization.
- **UI copy:** title / scenario / translation / options must be English, i.e. contain no Han characters. This replaces the "no Vietnamese orthography in UI copy" check.
- **Content safety:** a prohibited-subject list in English and Cantonese.
- **Profanity:** extend `ProfanityFilter` with Cantonese 粗口 (the 5 classic characters and their variants, e.g. 屌 / 閪 / 撚 / 柒 / 鳩, and their homophone substitutions) for the onboarding name and topic inputs.

### 5.5 Pronunciation matching and coaching (replaces `PronunciationFeedback.swift` and `isToleratedSpokenDifference`)
**Pipeline:**
1. STT transcript → OpenCC s→t → number normalization → segmentation.
2. Map both target and transcript to Jyutping.
3. Align by syllable (reuse the existing DP aligner).

**Per-syllable verdicts:**
- `correct`: same character, or a homophone with identical Jyutping;
- `tone`: same segmental, different tone, e.g. STT heard 買 maai5 instead of 賣 maai6;
- `sound`: a different initial or final;
- `missing` / `extra`.

**Tolerated variants (懶音).** These count as correct, with an optional gentle tip:
- n- ↔ l- (你 nei5 → lei5);
- ng- dropped / added (我 ngo5 ↔ o5);
- gw- / kw- → g- / k- before o (廣 gwong2 → gong2);
- final -ng ↔ -n, final -k ↔ -t;
- a dropped final particle (啦 / 呀 / 喎 / 囉) is ignored.

**Coaching tips:** at most 2, and Cantonese-specific: 3 vs 6 level tones, 2 vs 5 rising tones, 4 low-falling, entering-tone stops.
- Never claim an acoustic tone assessment. STT only shows which character it *heard*. Keep VietBuddy's honesty rule.

**Onboarding:** `OnboardingSpeechMatcher` still ignores the learner's name (an English name inside Cantonese speech).

### 5.6 Listen tile bank (`ListenTileBank.swift`)
- Tiles are characters or words (from segmentation), with Jyutping shown according to the display setting.
- Distractors:
  - **tone look-alikes** (same segmental Jyutping, different tone, e.g. 詩 si1 / 史 si2 / 試 si3 / 時 si4 / 市 si5 / 事 si6);
  - **sound look-alikes** (n/l, ng-, -n/-ng);
  - visually similar characters.
- All come from the lexicon and are deterministic per seed.

### 5.7 Rendering (DesignSystem)
- A `RubyText` / `CantoneseLineView` component: characters with Jyutping above, per token, wrapping correctly, honoring Dynamic Type.
  - Each token stays tappable to open the gloss sheet.
- Force the `zh-Hant-HK` locale on CJK text so PingFang HK glyph variants are used, not TC or SC.
- Check type floors: the 22–34 pt focus phrase should probably grow for characters, and clipping tests must pass at accessibility sizes.
- Brand font: Patriot is Latin-only, so pair it with a CJK font. System PingFang HK is the default; a licensed display font is optional.

### 5.8 Apple fallbacks
- Debug-only: `AVSpeechSynthesizer` with `zh-HK` (Sin-ji) and `SFSpeechRecognizer` with `zh-HK`.

**Exit criteria:**
- Golden tests pass in both Swift and Deno: segmentation, Jyutping, number reader, validator, matcher, variants.
- About 200 fixture sentences have been reviewed by a native speaker.

---

## 6. Phase 3 — Backend port (Supabase)

### 6.1 Baseline schema (`0001_baseline.sql`)
All tables are renamed `kumusta_*`. The RLS init-plan pattern, `security definer` RPCs granted to `service_role`, and `touch_updated_at` triggers are preserved.

| Area | Tables / objects |
|---|---|
| Core | profiles (+avatar_seed), onboarding_responses, learning_preferences (goal, level, daily_minutes {5,7,10,15}, target_level, challenge_preference, **`jyutping_display`**), lessons (roadmap), vocabulary, user_vocabulary, learning_sessions, review_events, daily_progress, entitlements, revenuecat_events, analytics_events, api_rate_limits, project_api_rate_limits |
| Adaptive | learner_states, lesson_generation_jobs, generated_lessons, user_lesson_queue (+priority), difficulty_feedback, generated_vocabulary_progress / _review_events, lesson_generation_quota_overrides; all composite owner FKs |
| State | user_state (2 MB jsonb blob), subscription_cancellation_feedback |
| Audio | tts_cache plus the bucket `kumusta-tts` (lease RPCs). Make `voice_id` / `model_id` checks follow the Phase 0 allowlist |
| First Steps | foundation_courses / _units / _items / _item_variants / _course_progress / _item_progress (content rewritten, §7.4) |
| XP | xp_rules, xp_events, user_xp_totals, xp_period_totals, xp_leaderboard_signal (+realtime publication), view `xp_leaderboard` |
| Telemetry | app_sessions, flashcard_sessions, analytics columns, views customer_learning_activity / customer_lesson_usage |
| Live | live_sessions, live_rounds, live_transcripts, live_account_overrides (simplified to the pipeline model, §10) |
| Curriculum | goal_lessons, goal_lesson_translations (keep the table for future UI languages) |
| Email | email_jobs + `claim_email_jobs` + pg_cron job + Vault secret |

**Rules for the baseline:**
- Remove every `southern|northern|both` check and every Vietnamese voice-ID check.
- The analytics validator enum lists must match the new events (§11).
- **Fix while porting:** `account-data` export/delete is missing the XP, live and foundation tables. Add every user-owned table, plus a test that fails when a new `user_id` table is not listed.
- **Add:** a retention / cleanup cron for expired generated lessons. VietBuddy has a TODO for this.

### 6.2 Edge Functions

| Function | Action |
|---|---|
| `_shared/http.ts`, `_shared/auth.ts`, `_shared/speech_gate.ts` | Rename; keep the logic. Update the quota scope enums (`tts`, `stt`, `lessons`, …), made provider-neutral |
| `kumusta-lessons` (from `mistral-lessons`) | Qwen only. New Cantonese prompt (§7.1), new contract v1 with `jyutping` fields, the validators from §5.4, segmentation-based gloss repair, server-side Jyutping verification against the lexicon. Queue, lease, quota and topic-preference logic unchanged |
| `kumusta-curriculum-admin` | Same operations flow. Cantonese syllabus `plan.ts`; the editorial review prompt becomes a Cantonese spoken-language editor that checks colloquial vs 書面語, Jyutping, register, naturalness, level and translations. Beginner length rule becomes ≤ N characters (≈ 10–12) instead of ≤ 9 whitespace tokens |
| `kumusta-tts` (from `elevenlabs-tts`) | Provider adapter from Phase 0. `language_code` → `yue` (or the provider's equivalent). A single server-side teacher-voice constant (no accent input). Cache key covers provider, model, voice, settings version, text and speed. The lowercase / punctuation normalization for vocabulary text becomes NFC + strip CJK punctuation. Rewrite the fixed onboarding lines (`greeting`, `ask_name`, `reply_name`, …) in Cantonese (e.g. 你好！ / 你叫咩名呀？ / 我叫{name}。) |
| `kumusta-stt` (batch) + `kumusta-stt-token` (realtime) | Provider adapter. Language `yue`; drop the `languageCode == "vie"` assertions. Sanitize to Traditional (s→t). Keep the byte limits, the onboarding 3-take allowance and the quotas |
| `kumusta-live-pipeline` | See §10 |
| `kumusta-evaluate` | Only if D10 says keep. Rewrite on Qwen with the Cantonese matcher short-circuit |
| `kumusta-award-xp` | Remove the `conversation_completed` branch |
| `kumusta-account-data` | Full table list (see §6.1) |
| `kumusta-revenuecat-webhook` (+admin) | Rename; parameterize the project ref / webhook URL by env |
| `kumusta-email-worker` | New copy and sender; Resend domain |

**Config and env:**
- `config.toml`: same `verify_jwt` pattern. Give `curriculum-admin` an explicit entry.
- `.env.example`: `DASHSCOPE_API_KEY`, `QWEN_LESSON_MODEL`, `ANTHROPIC_API_KEY` (+`ANTHROPIC_WORKSPACE_ID`), `KUMUSTA_LIVE_LLM_MODEL=claude-opus-5-5`, the STT / TTS provider keys and `KUMUSTA_*_PROVIDER` switches, the RevenueCat secrets, `RESEND_API_KEY`, `EMAIL_*`, `KUMUSTA_ENTITLEMENT_ID`, quota limits, `KUMUSTA_ENVIRONMENT`, `KUMUSTA_DEVELOPMENT_BYPASS_ENTITLEMENT`.

**Tests:**
- Port every `*_test.ts`.
- Add Cantonese fixtures.
- Port `tests/live_practice.sql` and update it for the simplified live model.
- RLS tests: two users plus an anonymous user.

---

## 7. Phase 4 — Content pipeline (Qwen + TTS)

### 7.1 Lesson generation prompt (`kumusta-lessons/prompt.ts`)
Rewrite `systemPrompt` / `userPrompt` and keep the structure (role, level ceiling, connected mini-story, rounds, chunks, hear-and-respond, vocabulary grounding, topic preference as untrusted data, safety, JSON only). Cantonese-specific rules:

**Script and register:**
- Colloquial Hong Kong Cantonese in **Traditional characters**, with the standard colloquial characters (佢 / 唔 / 嘅 / 咗 / 喺 / 冇 / 嚟 / 啲 / 嘢 / 咩 / 乜 / 點 / 邊).
- Never Standard Written Chinese, never Simplified.
- Natural code-mixing where locals would use it (OK, Wi-Fi, book, check, 搭 MTR), but no English for words learners should learn.
- Jyutping for every utterance, chunk, gloss and vocabulary item: lowercase, tone numbers, syllables separated by spaces.
- Sentence-final particles (啦 / 呀 / 喎 / 囉 / 㗎 / 嘛 / 啩 / 咩 / 吖) are explained by their social function, never translated one-to-one. This is the analogue of VietBuddy's ạ / nhé rule.

**Address and politeness** (replaces the tôi / bạn rule):
- Kinship terms (媽咪 / 爹哋 / 阿媽, 婆婆 / 公公 / 嫲嫲 / 爺爺, 姨媽 / 姑媽 / 舅父 / 叔叔 / 阿姨).
- 先生 / 小姐 / 師傅 / 靚仔 / 靚女 in service contexts.
- 唔該 vs 多謝, 早晨, 食咗飯未.
- Location-consistent HK settings: 茶餐廳, MTR, 街市, 八達通, 小巴, 酒樓 / 飲茶.

**Glosses:** `word_glosses` follow the segmentation rule from §5.3.

**Level adaptation:**
- Character-count tiers replace syllable tiers. Total beginner: 2–8 characters, at most about 10; exactly 8 vocabulary items.
- Recent scenarios to avoid, and topic success test: unchanged.

**Hear-and-respond:** 3 English options, exactly one equal to the translation. The deterministic repair is kept.

**Shape:** `schema_version` 1, `prompt_version` 1 for the new product. Same JSON shape plus the `jyutping` fields, with snake_case on the wire and camelCase in storage.

### 7.2 Roadmap catalogs (bundled + `kumusta_lessons`)
- Rebuild `supabase/catalog/<level>-cantonese-v1/` for beginner, intermediate and advanced, 10 lessons each to start (v1 authored in `content/roadmap/`). No accent duplication.
  - Example unit arc for "beginner": Greet and introduce yourself (你好 / 我叫 / 早晨) → Order at a 茶餐廳 → Get around (MTR, 小巴, 的士) → Shop and pay (幾多錢, 八達通) → Talk about family and life → Stay in control (唔該講慢啲, 聽唔明).
- Authoring:
  - Port `catalog.ts`, `build.ts`, `round()` / `segment()` helpers. `segment()` now takes `(text, jyutping, english, note?)`.
  - Swap `word-gloss-lexicon.ts` for the shared segmenter plus the lexicon.
  - Keep the deterministic UUID families, contract validation, SHA-256 hashing, the seed migration and `review_status='native_speaker_review_required'`.
- Who writes it: Qwen draft → Claude cross-review → **native HK speaker review** (a hard gate before publishing).

### 7.3 Goal curriculum
- `plan.ts`: goals lifeInHongKong / family / partner / travel (add work / culture later) × 4 stages × 10 lessons = 160 lessons (no accent duplication).
- Run `generate-goal-curriculum.ts`, then `verify-goal-curriculum.ts`, then export `goal-cantonese-v1.json` + report, then publish in one transaction.
- Budget: track the `usage` tokens. Spot-check 10% with a native speaker before publishing.

### 7.4 First lessons and First Steps
- **Onboarding first lessons** (`FirstLessons/onboarding-{beginner,intermediate,advanced}.json`), rewritten. Step kinds stay the same:
  - `teach`: tone samples use Cantonese contours, e.g. the classic 詩 / 史 / 試 / 時 / 市 / 事 si1–si6 set.
  - Also `listenPick`, `meaningPick`, `naturalPick`, `newPhrase`, `speak`, `build`, `conversation` (with the `{name}` line 我叫{name}。).
  - Hook example: 唔該，一杯凍奶茶。 ("One iced milk tea, please"), the HK analogue of the cà phê sữa đá moment.
- **`first-lesson-new.json` (First Steps course)** plus a **basics cheat sheet**, rewritten as a Cantonese foundations course:
  - the 6 tones;
  - how to read Jyutping (initials and finals that trip English speakers: z / c / j / eo / oe / yu / aa vs a);
  - entering tones (-p / -t / -k);
  - n/l and ng- (and why locals merge them);
  - common particles;
  - people words (kinship terms);
  - numbers and money (兩 vs 二, 蚊 / 毫);
  - the 唔該 / 多謝 distinction;
  - "characters vs what people say" (colloquial vs written).
  - Unit seed: `foundation_*` tables.
- **Accent samples** step in onboarding: replace it with a "How do you want to see Cantonese?" step that previews characters + Jyutping and sets D8.
- Bundled audio: `generate-first-lesson-audio.ts`, using the new TTS provider and settings; hash keys stay the same.

### 7.5 Flashcard seed and offline bank
- Replace the 100 Vietnamese / English candidate pairs with 100–150 high-frequency Cantonese items with Jyutping.
- Rebuild `OfflineVocabularyCandidateBank` the same way.

### 7.6 Audio prewarm
- Port `prewarm-all-audio.ts`, `prewarm-roadmap-audio.ts` and `prewarm-onboarding-conversation-audio.ts`, so every bundled and published line is in the TTS cache before launch.

### 7.7 Translations
- None. The app is English only (D7); the French translation workflow was removed.

**Exit criteria:**
- Every catalog passes the contract.
- Native-speaker sign-off is logged (reviewer, date, content version) for first lessons, First Steps and roadmap "beginner".
- Audio has been QA'd at natural and slow speed.

---

## 8. Phase 5 — iOS app port, feature by feature

Every item below exists in VietBuddy today. "Adapt" means rename plus the language-layer changes from §5.

### 8.1 Launch and shell
- `LaunchPhase` state machine (loading → onboarding → paywall → paywallFallback → paywallExit → accountCreation → firstStepsOffer → firstSteps → main | failed): keep it as is.
- Bootstrap: keep the order anonymous Supabase session → PostHog identify → RevenueCat configure (Supabase UUID) → local profile → streak reconcile → routing.
  - Access check order stays RevenueCat → restore → Supabase entitlement mirror.
- On foreground, re-validate the session.
- Debug launch arguments: `debugUnlock`, `paywall`, `mainApp`, `firstLesson`, `badgeDemo`, `mascotAnimationReview`, `-SeedDueReviews`, `-UITestScenario …`.
- Cloud sync of `CloudUserState` (250 ms debounce), app sessions, daily progress, achievement XP replay.
- `RootView` overlays: badge celebration, audio-reactive border, a StoreKit review request that waits for a calm screen.
- 4 tabs: **Today / Practice / Words / Profile**, with the same SF Symbols and the native tab bar.

### 8.2 Onboarding
- **Welcome:** "Hi! I'm <mascot>. I'll be your Cantonese buddy."
- **Name:** profanity filter extended to Cantonese; live reply becomes "哈囉 %@!" or "Hello %@!".
- **Accent step:** replaced by the **script display preference** step (characters + Jyutping preview, with audio).
- **Goal:** Talk with family / Live in Hong Kong / Travel / Connect with my partner / Use Cantonese at work / Reconnect with my roots.
- **Level:** Starting fresh / I know the basics / I can hold a conversation.
- **Daily plan:** 5 / 7 / 10 / 15 min.
- **Building screen:**
  - Keep the plan components and the progress bar.
  - **Do not port the hardcoded fake App Store reviews or the "1,000+ students" claim** until real numbers exist. Replace them with honest copy.
  - Prefetch the personalized name clip.
- **Pre-paywall first lesson** (§7.4): 3 graded speech takes (`FirstLessonSpeechBudget`), the exit sheet, combo flame, completion stats, the skip path.
- **Comparison screen:** "YOUR NEXT 30 DAYS" chart, a level-specific headline ("You just ordered a milk tea in Cantonese."), goal benefits, the "SEE MY PLAN" CTA.
- `completeOnboarding` → profile save, analytics plus TikTok / AppsFlyer / Meta tutorial-complete, Supabase sync → paywall.

### 8.3 Paywall, account, First Steps
- RevenueCatUI hosted paywall → `Fallback` offering → `PaywallExitView` (sign in / see plans again / sign out / delete account).
  - Keep the `HostedPaywallRoutingGate` and purchase attribution.
- `AccountCreationView`: email + password; upgrades the anonymous user; email confirmation screen.
  - Wiring up Sign in with Apple is an optional, low-cost improvement.
- `FirstStepsOfferView` → `FirstStepsCourseView` + cheat sheet (Cantonese foundations, §7.4).

### 8.4 Today
- Top bar (streak) → roadmap title → `DailyReviewCard` → zig-zag roadmap (units, nodes, START bubble, mascot companion, finish flag, sequential unlock, replay, auto-scroll).
- Level promotion beginner → intermediate → advanced with a "New roadmap unlocked" alert; advanced is terminal.
- Goal curriculum appended after the level roadmap (`SupabaseGoalCurriculum`, disk cache, stage entry by level).
- **Lesson flow** (`LessonFlowView`). Every round: **coldListen → decode | hearRespond → speak**.
  - coldListen: listen, build what you heard from the tile bank (§5.6), reveal with `RubyText`.
  - decode: tap chunks and word glosses (characters + Jyutping + English) → gloss sheet with "Add to Vocabulary".
  - hearRespond: 1–2 rounds per lesson.
  - speak: record → STT → `PronunciationReview` (§5.5). The UI states that this is a repeat-after-me task.
  - Round count = clamp(dailyMinutes, 5, 12). Slow / Natural / Fast controls; resume from step; first-time `LessonFormatExplainer`.
- `LessonCompleteView`: confetti, server XP, stats, "Tune your next lesson" (level and pace feedback), reminder invitation (9:00 / 12:00 / 19:00).
- Next-lesson topic: `SessionFeedbackSheet`, `NextLessonPreparationCard`, `LearningJourneyStore` polling.
  - In VietBuddy the sheet is wired only through `PracticeHomeView`. Keep that behaviour, or decide to surface it in Today.
- Adaptive delivery is stale-while-revalidate: bundled content first, queued generated lesson swapped in, 5-minute cache, coalesced fetches, durable outbox.

### 8.5 Practice
- **Real-time chat card** → `LivePracticeView` (§10). This is now the only "session" card, since the dialogue card is removed.
- `PracticeHomeView` "next lesson" cold-listen guess ("What's happening?", 3 choices), driving adaptive preparation, plus `StreakCelebrationView`.
- **Daily review** (`DailyReviewView` / `DailyReviewSession`):
  - 12 cards.
  - Exercise kinds: `listenMeaning`, `pickVietnamese` → **`pickCantonese`** (tone and sound look-alikes), `build` (character tiles), `speak`.
  - FSRS stability gates kind selection; missed cards return at the end; combo; first-attempt and time-based grading.

### 8.6 Words (vocabulary tab)
- Saved-phrase bank fed by "Add to Vocabulary". Sort by Recent or **by Jyutping** (A–Z on Jyutping instead of Latin letters). Swipe to add or remove from flashcards; animated speaker icon.
- `SavedWordDetailView`: characters + Jyutping + meaning, "In real life" example, audio, remove.
- **Phrase Quest** flashcards: listen → 4 choices, +10 XP per correct card, correct cards retired, `vocabulary_flashcard_session_completed`.
- FSRS-5 deck (0.9 retention, 365-day cap, fuzz, 3,000 cards, 600 logs). Enrolled from completed lessons and saved words; merged on cloud restore.
- Optional, since VietBuddy has none: a search field matching characters, Jyutping with or without tones, and English. Cheap with the lexicon, and useful for a character-based language.

### 8.7 Profile
- Header: DiceBear avatar, name, share streak, edit.
- First Steps quest card.
- Leaderboard preview + full view (realtime channel, medals, "YOU", "x XP to reach #n").
- Badges (x of 10).
- Last 7 days chart.
- Lesson history: replay any line and read the chunks.
- Learning plan: goal, daily pace, starting level, desired level, challenge, **Jyutping display**.
  - The VietBuddy accent editor (which drops the queue and audio cache) is removed. Changing the Jyutping display does not invalidate anything.
- Appearance (System / Light / Dark).
- Notifications (reminder time, streak at risk at 20:00).
- Listening: default speed, autoplay, sound-effects volume.
- Membership: sign out, restore, cancel flow with a required reason → App Store settings.
- Data & help: privacy, support email, delete account, erase local data. Optionally expose the existing `exportAccountData`.

### 8.8 Gamification
- XP is server-awarded and idempotent. Reasons: `lesson_completed`, `vocabulary_flashcard_session_completed`, `achievement_<id>`.
- Streaks.
  - Streak freezes are implemented but never called in VietBuddy. Decide whether to wire them in (recommended: yes, it matches the "no guilt" promise).
- 10 achievements with the same XP values.
- Badge and streak celebrations (7 / 14 / 30 / 60 / 100 / 365), confetti, mascot correct / mistake states.

### 8.9 Audio services
- TTS gateway:
  - edge function only;
  - memory LRU of 32 + disk cache of 160;
  - in-flight de-duplication;
  - 1 retry;
  - prewarm with 3 concurrent requests;
  - slow and fast speeds applied locally via playback rate (verify that this sounds acceptable for tonal Cantonese; otherwise generate slow audio server-side);
  - 50 ms metering → audio-reactive border.
- Sound effects: valid, wrong, pop, pop_word_select (pitched tiles), finished_lesson, badge.
- Speaking recorder: 20 s maximum, 0.45 s minimum, metering, streaming to realtime STT, scrubbing of abandoned takes.
- STT: batch provider → Apple `zh-HK` fallback.
- Text normalization: `SpokenUtterance`, ported to Cantonese punctuation and width (full-width / half-width) normalization.

### 8.10 Other services
- `NotificationService`: rewrite the copy.
- `RatingPromptManager`: unchanged.
- `AppLanguage`: unchanged.
- `ProfanityFilter`: extended (§5.4).
- Privacy manifest: **update it to declare PostHog / AppsFlyer / TikTok / Meta collection**. VietBuddy's says "no collected data", which is out of date.

**Tests to port:**
- All 23 unit test files, adapted (WordsSearch, ListenTileBank, SpokenUtterance, PronunciationFeedback, FirstLessonContent, MascotPerformance, etc.).
- UI journeys for `firstLaunch | returningFreeUser | subscribedUser | offlineWithPendingSync | purchasePending`.
- The accessibility matrix.

---

## 9. Phase 6 — Mascot

The rendering engine and lip-sync are kept, because they depend on the language only through the audio. The artwork is new.

1. **Concept (D3).** Write an anchor prompt and record it in `ASSET_PROVENANCE.md`.
   - Constraints: hand-drawn, warm ink and watercolor, big expressive eyes, one signature accessory (the role Bé Trâu's red scarf plays). Must read well as the app icon.
2. **Sprite sheets.** Poses: reference, launch-greeting, welcome-wave, listening, curious, speaking, correct, mistake, streak.
   - `build_mascot_assets.py` → 8-frame atlases (724 px cells), statics, roadmap mascots, icon.
   - Used by `BuddyMark` (happy / listening / proud) and `BuddyMotionView` (launch, welcomeWave, listening, curious, reviewing, correct, mistake, streak).
3. **Layered puppet rig** for live practice:
   - One approved master painting plus face and body underpaintings → `build_master_mascot_rig.swift` cuts the `RigV2*` parts.
   - Parts: head, body, ears or equivalents, arms, legs, tail or equivalents, accessory, eyes, brows, smile, and **12 mouth shapes** (`RigMouth0–11`).
   - Update the `ConversationRigV2.json` bounds and the pivot points in `ConversationMascot.swift` / `MascotPerformance.swift`.
   - Non-buffalo anatomy: if the character has no ears or tail (e.g. a milk-tea cup), remap those 24 pose parameters to equivalent parts (lid, straw, steam) or zero them. Budget time for this.
4. **Behaviour:**
   - activities: greeting, idle, speaking, listening, thinking, reassuring, celebrating, farewell;
   - about 70 procedural gestures;
   - `MascotListeningResponse` driven by mic level;
   - `MascotSpeechTimeline` lip-sync (RMS, brightness, voicing → openness and roundness → cross-faded mouth sprites).
   - Retune the thresholds for the new TTS voice.
5. **Checks:** the `mascotAnimationReview` debug screen; `MascotPerformanceTests` (60 fps budget).
6. **Brand assets:** app icon, website hero, social / marketing poses. If possible, an animated mascot export for TikTok; VietBuddy lacked one.

---

## 10. Phase 7 — Real-time conversation pipeline (STT → Opus 5.5 → TTS)

Port `vietbuddy-live-pipeline` and `LivePracticePipelineSession.swift`, then make these changes.

### 10.1 Sessions and allowance (`sessions.ts`)
- Keep: `allowance`, `start`, `transcriber`, `reply`, `finish`; settlement of abandoned sessions; transcripts table; 20 s grace.
- Product decision: VietBuddy currently allows 1 h per session and 200 starts per day, while the client shows a 5:00 timer derived from `daily_limit_seconds`. Pick one model:
  - Recommended: **a daily allowance (e.g. 10 min/day), enforced server-side**, plus `live_account_overrides` / bonus seconds. Opus 5.5 costs more per turn than Haiku 5.5.
- Drop the legacy `live_reserve` RPC if the pipeline owns sessions directly. Remove the dead `gpt-live-1` default in the `model` column.

### 10.2 STT (realtime)
- The `transcriber` action returns a provider grant: Phase 0 winner, single-use token, wss URL, config.
- Soniox config: `language_hints: ["yue","en"]`, endpoint detection on, `max_endpoint_delay_ms` tuned (~800–1000).
- ElevenLabs config if chosen: `language_code=yue`, `commit_strategy=vad`, `vad_silence_threshold_secs=0.8`, secondary `eng`.
- Client: AVAudioEngine 16 kHz PCM16 mono over WebSocket; partial and committed transcripts; s→t normalization on captions.

### 10.3 LLM — Claude Opus 5.5
- `@anthropic-ai/sdk` `messages.stream`, model `claude-opus-5-5` (env-overridable).
- Thinking disabled, low effort, `max_tokens` about 300–400.
- System prompt as one cached block (`cache_control: ephemeral`).
- History: last 24 turns, 1,000 characters each, consecutive same-role turns merged, the "(The learner opened the call.)" prefix kept.
- `greeting:true` skips the LLM; refusals → `llm_refusal`.
- **Latency budget:** measure `llm_first_token_ms` and `first_audio_ms` (the logs already exist). Target first audio under about 1.5 s after the turn commits.
  - If Opus misses it, options are a shorter prompt, lower effort, or a Haiku 5.5 opener with Opus for corrections. Decide from data.

### 10.4 Coaching prompt
Rewritten for Cantonese (`coachingPrompt` / `PIPELINE_VOICE_PROMPT`):
- Persona: the mascot, a warm HK Cantonese conversation coach.
- Short colloquial sentences; corrects word choice, register and particles, then asks for a retry.
- It receives an **STT transcript**, not audio, so it must never claim to judge tones. Homophone characters from STT should be read charitably.
- Output in Traditional colloquial characters. **Optional:** a parallel caption with Jyutping (the text event can carry `jyutping` computed server-side with the lexicon, not by the LLM).
- Family-friendly safety and prompt-injection refusal; roleplay games (ordering at a 茶餐廳, haggling at 女人街, chatting with 婆婆 on a call).

### 10.5 Personalities
Keep the 4 slots, recast for HK:

| Slot | Recast | Notes |
|---|---|---|
| friendly | 好朋友 | casual peer |
| familiar | 老友記 | slang, code-mixing |
| grumpy | the **茶餐廳 waiter / 阿叔** | brusque, fast; an iconic HK trope. The Vietnamese profanity list becomes a **mild** Cantonese rough-talk list. Keep it out of 粗口 by default and gate anything stronger behind an 18+ setting, or drop it. App Store review risk |
| strict | 老師 | tone drills, mimicking the "repeat after me" style |

Each personality keeps its own address terms, particles and TTS style tags, if the chosen TTS supports tags.

### 10.6 Sentence splitting (`takeSentences`) — Cantonese-critical
- Split on `。！？…` **without** requiring whitespace after.
- Also on `，、；：` for the eager first chunk (after about 8–10 characters instead of 24 Latin characters).
- Handle mixed Latin punctuation as before; merge bare audio tags.

### 10.7 TTS (streaming)
- Phase 0 provider, streaming PCM 24 kHz; `previous_text` context if supported.
- `speechLanguage()` heuristic → Han means `yue`, otherwise `en`. The learner may speak English and the coach may explain in English, so both must be voiced correctly.
- One sentence buffered ahead (pipelined) as today.

### 10.8 Client
Keep:
- half-duplex mic (sends silence while the buddy talks);
- the 3 s continuation window;
- echo ignore (comparison on normalized Han text);
- 10 s silence end;
- captions toggle, Mute, End, timer;
- status strings;
- mascot lip-sync from the PCM stream;
- mic level → listening response and border;
- interruption, background and headset-loss handling;
- context: chosen topic and latest completed lesson.

### 10.9 Analytics and logging
- `live_practice_*` events.
- Engine label `pipeline:<stt>:<llm>:<tts>`.
- Per-turn timing and token usage, including cache tokens.

### 10.10 Verification (on device)
- Greeting and two-way audio; lip-sync; captions; mute; End; timer zero.
- Backgrounding; network loss; killing the app mid-call then reopening (settlement); daily exhaustion.
- Code-mixed speech; a native-speaker evaluation of the coach's Cantonese for each personality.

---

## 11. Phase 8 — Analytics and attribution

- Port the `AnalyticsEvent` enum, the property allowlist and the SQL validator together. Run `check_analytics_catalog.py` in CI.
- Remove the `conversation_*` events and the `android` platform.
- Rename `onboarding_completed` enum checks: drop `accent`, add `jyutping_display`, rename goal values.
- Funnel positions: re-number after the accent step is replaced. Flow version `first_lesson_v1`.
- PostHog project; AppsFlyer as the SKAN owner; TikTok and Meta in hybrid mode with SKAN and auto-purchase off.
  - Purchase / trial events only from `RevenueCatPurchaseService`.
- RevenueCat integrations: AppsFlyer (renewals; keep initial purchase and trial off), Meta (`$fbAnonId`), Apple AdServices.
- AppsFlyer → TikTok postback mapping as in `INTEGRATIONS.md`.
- Reporting views for customer learning activity and lesson usage.
- Website `?from=<campaign>` App Store redirect click logging. **Create the missing `app_store_redirect_clicks` table migration**; VietBuddy's repo doesn't include it.

---

## 12. Phase 9 — Website and marketing

- **Website:** fork `website/` (Next.js 16 + vinext → Cloudflare Workers, Tailwind 4).
  - Rebrand: fonts, colors, mascot.
  - Pages: landing, privacy, terms, support, delete-account.
  - Delete the unused Drizzle / D1 scaffolding unless needed.
- **SEO blog**, replacing the Vietnamese articles:
  - best app to learn Cantonese 2026;
  - Cantonese tones explained;
  - Jyutping guide;
  - Cantonese vs Mandarin;
  - learning Cantonese for your partner's family;
  - HK slang / particles.
  - Podcasts page: curate Cantonese-learning YouTube content, or drop it.
- **App Store:**
  - Port `render_store_screenshots.py` / editorial renderers with new captures, fonts, mascot.
  - Write the ASO keyword set (Cantonese, learn Cantonese, Hong Kong, Jyutping, Cantonese tones).
- **Content playbook:**
  - Adapt `content/app-brief.md` (verified-claims table, "never claim" list), `partner-icp-content-prompt.md` and `tiktok-slideshow-generator-prompt.md` for Cantonese. Situations: yum cha with the in-laws, Chinese New Year 利是, the video call with 婆婆, the HK trip, the wedding tea ceremony (斟茶).
  - Run the Apify research pipeline (`research/build_videos.py`) with Cantonese search terms and hashtags.
- **Native review:** every Cantonese phrase used in marketing is reviewed by a native speaker.

---

## 13. Phase 10 — QA and release gates

Ported from `RELEASE_READINESS.md`, plus the Cantonese-specific gates:

**Build and tests**
- [ ] Swift 6 build with no warnings in app code; unit and UI tests pass; Deno fmt / lint / check / test pass; analytics and strings parity scripts pass.

**Language**
- [ ] Shared segmentation / Jyutping / matcher golden tests pass in Swift and Deno.
- [ ] Native HK speaker sign-off recorded for first lessons, First Steps, the "beginner" roadmap, 10% of the goal curriculum, the TTS voice (tones, polyphones, numbers), and each live personality.
- [ ] No Simplified characters anywhere in bundled or published content (automated scan).
- [ ] Colloquial-vs-SWC scan run on all content; flagged items resolved.

**Accessibility**
- [ ] Dynamic Type at the largest sizes with CJK + Jyutping ruby: no clipping.
- [ ] VoiceOver reads Cantonese with the `zh-HK` language attribute.
- [ ] Reduce Motion.

**Offline and purchases**
- [ ] Offline first lesson works (bundled audio); cached entitlement path works.
- [ ] Sandbox purchase / cancel / pending / restore on device; `Fallback` offering flow; exit screen.

**Backend**
- [ ] RLS security and performance advisors clean.
- [ ] Export / delete cover every user table (with a test).
- [ ] Queue / lease / outbox / fallback / quota paths verified.
- [ ] Generated-row cleanup cron live.
- [ ] Live pipeline device checklist (§10.10); latency targets met with Opus 5.5.

**Secrets and environment**
- [ ] No secrets in git or the bundle.
- [ ] `KUMUSTA_ENVIRONMENT=production`; bypass off; separate dev and prod projects.

**Store**
- [ ] Privacy manifest and App Store privacy answers match the SDKs.
- [ ] Legal pages live; support inbox monitored.
- [ ] No unverifiable marketing claims (fake reviews, user counts, "native-speaker certified" for generated content).

---

## 14. Suggested order and parallelism

```text
Phase 0 (bake-off, accounts, mascot concept) ─┬─> Phase 2 (language core) ─┬─> Phase 4 (content) ──┐
Phase 1 (fork / strip / rename / baseline) ───┘                            ├─> Phase 5 (app port) ─┼─> Phase 10 (QA / release)
                                                Phase 3 (backend port) ────┤                       │
                                                Phase 6 (mascot art/rig) ──┴─> Phase 7 (live) ─────┤
                                                Phase 8 (analytics) / Phase 9 (website) ───────────┘
```

**Milestones:**
1. **M1, foundation:** the renamed app runs against new Supabase; the bake-off is decided; the mascot concept is approved.
2. **M2, language core:** segmentation, Jyutping, validators and matcher, with golden tests and native-reviewed fixtures.
3. **M3, learn loop:** onboarding → first lesson → paywall → Today roadmap lesson → review → words, all in Cantonese with real audio.
4. **M4, adaptive and live:** Qwen generation queue live; Opus 5.5 live practice on device; new mascot rig lip-synced.
5. **M5, launch:** content sign-off, website, store assets, TestFlight, release gates.

**Biggest risks:**
1. Cantonese TTS tone quality.
2. STT turning colloquial Cantonese into Mandarin-style characters.
3. LLMs drifting into Standard Written Chinese or Simplified characters. Mitigated by the validators plus the editorial pass plus native review.
4. Opus 5.5 latency and cost in live practice.
5. Polyphone Jyutping errors.
6. Mascot rig remapping if the character isn't a quadruped.
