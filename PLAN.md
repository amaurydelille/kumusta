# Kumusta — Tagalog app plan

Kumusta teaches spoken, everyday Metro Manila Tagalog to English speakers
(heritage learners, partners of Filipinos, travellers, people living in the
Philippines). iOS only, English UI only.

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Name, bundle, domain: Kumusta, `com.kumusta.app`, `kumusta_pro`, `kumusta.app` | Decided; App Store Connect, RevenueCat and the domain still need registering |
| D2 | Language: everyday Metro Manila Tagalog, standard spelling, no stress marks, po/opo, natural Taglish only | Decided (CLAUDE.md) |
| D3 | No accent, dialect or other Philippine language anywhere | Decided; the accent axis is removed from the data model |
| D4 | Levels: beginner / intermediate / advanced | Decided |
| D5 | Mascot: Tuko, a gecko (*tuko* in Tagalog) | Done: buddy image, sprites, rig and app icon are gecko art |
| D6 | TTS voice: ElevenLabs `qZLi51uuzx5jdu6q0ayz` for lessons and live conversation (`KUMUSTA_TTS_VOICE_ID` overrides) | Decided |
| D7 | Spelling house style: standard forms (puwede, huwag, saka) vs common Manila forms (pwede, wag, tsaka) | Open; lessons use standard, grading accepts both |

## Done

- **Language core.** Content fields are `tagalog` and there is no accent or tone logic.
  Pronunciation grading works word by word with Tagalog spelling variants
  (pwede/puwede, rin/din, ho/po) and native plus Spanish-derived numbers. Review exercises use
  Tagalog look-alikes (ang/ng/sa, ka/kayo, mag-/nag-).
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
   welcome lessons (`Kumusta/Resources/FirstLessons/REVIEW-first-lessons.md`). The app reads the
   roadmap from the bundled `Kumusta/Resources/Seed/*-tagalog-v1.json`, so approved fixes go
   there; nothing reads `kumusta_lessons`.
2. **Audio.** The welcome-lesson clips are bundled. After the review, prewarm the server cache
   with `scripts/prewarm-all-audio.ts plan`, then `generate` and `audit` (one Tagalog voice).
3. **Goal curriculum (postponed).** Needs `DASHSCOPE_API_KEY`. Then run `scripts/generate-goal-curriculum.ts`
   and `scripts/verify-goal-curriculum.ts` (160 lessons: 4 goals × 4 levels × 10), have a native
   speaker review them, and publish. Work and culture have no goal curriculum yet.
4. **Provider secrets.** RevenueCat production key and webhook. DashScope (lesson generation)
   and the email worker are postponed.
5. **Website.** `site/` (home, privacy, terms, support) is ready to deploy on Vercel.
6. **Docs.** Rewritten for Kumusta on 2026-10-25.
