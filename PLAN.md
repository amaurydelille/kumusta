# Kumusta — Tagalog app plan

Kumusta teaches spoken, everyday Metro Manila Tagalog to English speakers
(heritage learners, partners of Filipinos, travellers, people living in the
Philippines). iOS only, English UI only. It is a fork of VietBuddy; VietBuddy
itself is a separate production app and is never touched.

The earlier Cantonese plan (NeiHou) is in git history. The owner renamed the
app to Kumusta and switched it to Tagalog on 2026-10-24.

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Name, bundle, domain: Kumusta, `com.kumusta.app`, `kumusta_pro`, `kumusta.app` | Decided; App Store Connect, RevenueCat and the domain still need registering |
| D2 | Language: everyday Metro Manila Tagalog, standard spelling, no stress marks, po/opo, natural Taglish only | Decided (CLAUDE.md) |
| D3 | No accent, dialect or other Philippine language anywhere | Decided; the accent axis is removed from the data model |
| D4 | Levels: beginner / intermediate / advanced | Decided |
| D5 | Mascot: Tuko, a gecko (*tuko* in Tagalog); the static buddy image is done | Animated rig, sprites, conversation mascots and app icon still show the buffalo and need gecko art |
| D6 | TTS voice: ElevenLabs `qZLi51uuzx5jdu6q0ayz` for lessons and live conversation (`KUMUSTA_TTS_VOICE_ID` overrides) | Decided |
| D7 | Spelling house style: standard forms (puwede, huwag, saka) vs common Manila forms (pwede, wag, tsaka) | Open; lessons use standard, grading accepts both |

## Done

- **Language core.** `vietnamese` fields became `tagalog`, the Southern/Northern accent and
  tone logic is gone. Pronunciation grading works word by word with Tagalog spelling variants
  (pwede/puwede, rin/din, ho/po) and native plus Spanish-derived numbers. Review exercises use
  Tagalog look-alikes (ang/ng/sa, ka/kayo, mag-/nag-) instead of tone traps.
- **Backend.** Migration `20261025000000_tagalog_language_core.sql`: accent columns dropped,
  levels and goals switched (`lifeInThePhilippines`), vocabulary columns renamed, `goal_tags`
  added. Edge Functions speak Filipino (`fil`) for STT and TTS. The lesson generator, the live
  coaching prompt and the four tutor personalities are written for Tagalog.
- **Content.** 30 authored roadmap lessons (`supabase/catalog/tagalog-v1/`), bundled as app
  seeds and seeded unpublished in `kumusta_lessons`. Four welcome lessons in
  `Kumusta/Resources/FirstLessons/`. The First Steps cheat sheet and the offline word bank are
  Tagalog.

## Next

1. **Native-speaker review** of the roadmap (`supabase/catalog/tagalog-v1/REVIEW-*.md`) and the
   welcome lessons (`Kumusta/Resources/FirstLessons/REVIEW-first-lessons.md`). Approved rows can
   then be published (`review_status = 'approved'`, `is_published = true`).
2. **Audio.** Generate the welcome-lesson clips with `scripts/generate-first-lesson-audio.ts`.
   Then enable the skipped `fixedLinesAreBundled` test. The roadmap and prewarm scripts
   (`scripts/prewarm-*.ts`) still assume accents and need porting.
3. **Remove the Vietnamese leftovers** (old seeds, catalogs, first lessons, audio, accent images).
4. **Goal curriculum.** Regenerate `kumusta_goal_lessons` in Tagalog with
   `kumusta-curriculum-admin` (40 lessons per goal).
5. **Provider secrets.** Set `ANTHROPIC_API_KEY`, `DASHSCOPE_API_KEY`, `SONIOX_API_KEY` and the
   RevenueCat and email secrets, then test generation and live practice on device.
6. **Website and marketing.** Both are still VietBuddy copies.
7. **Docs.** Most of `docs/` is still VietBuddy text.
