# VietBuddy — App Brief

_Last updated 2026-10-07. Sources: `mobile-app/vietbuddy/docs/*`, `content/prompts/partner-icp-content-prompt.md`, app code, and the screenshots in the repo. Anything marked **[MISSING]** has to be filled in or checked before it is used in content._

---

## 1. The app

**Name:** VietBuddy (mascot: Bé Trâu, a baby water buffalo)
**Platform:** iOS only (no Android or web app)
**Description:** An iOS app for learning spoken Vietnamese, starting with listening. Learners hear natural Vietnamese audio before they see a transcript, work out what is happening, reveal useful phrase chunks, and then say them out loud. They choose a Southern (Saigon) or Northern (Hanoi) accent, and that choice changes the audio and the lessons.

## 2. Audience

**Primary: "The Partner"** (converts at about 2× any other group, per the ICP prompt)
- A non-Vietnamese speaker, or a Việt Kiều who never learned, who is dating, engaged to, or married to a Vietnamese person.
- Lives in the diaspora: mainly the US, also Canada and Australia.
- A complete beginner, or knows a few words their partner taught them. Their partner's family speaks **Southern** Vietnamese.
- **The situation:** family dinners switch to Vietnamese and they get left out. The in-laws or grandparents speak little English. The partner is tired of translating.
- **What they fear:** sounding rude to elders, using the wrong pronouns, the tones, embarrassing themselves.

**Secondary** (onboarding goals in the app: family, life in Vietnam, travel, partner, work, cultural roots)
1. Diaspora / heritage learners reconnecting with family and roots
2. People moving to, living in, or often visiting Vietnam
3. Learners frustrated by text-first courses and unnatural speech

## 3. Core outcome

The learner **understands what is being said around them and can answer with a few phrases that fit the moment** (in the right accent, with the right pronouns), so they stop being "the guest who smiles and nods."
Emotional promise: **be part of the family, not the guest who smiles and nods.**

## 4. Magic moment

**The cold listen.** The learner hears a real Vietnamese exchange **without subtitles**, picks what situation it is from three large choices, and gets it right. Then the transcript and phrase chunks are revealed, and they say the phrase back.
- It happens during onboarding (a coffee-order demo, before the paywall) and at the start of every Practice round ("Tune in. What's the story?" with the Mai & Duy audio player).
- **On camera:** phone shows the listening screen → creator looks confused → taps the right answer → reveal → creator says the phrase. Then cut to the real-life payoff (the in-law smiles).
- **Second moment:** a live spoken conversation with the AI coach, which corrects the learner and asks them to try again.

## 5. Verified features and claims

Checked against the code and docs. Only these may be used as product claims.

| Feature / claim | Evidence | Safe wording |
|---|---|---|
| Choice of Southern or Northern accent; it changes audio and lessons | PRODUCT_REQUIREMENTS, GOAL_CURRICULUM (320 accent versions) | "Pick Southern or Northern Vietnamese" |
| Listening first: hear it, work out the meaning, then speak | PRODUCT_REQUIREMENTS (cold listen → decode → speak) | "You hear real Vietnamese first, then you say it" |
| Daily lesson sized to your time (5 / 7 / 10 / 15 min) | PRODUCT_REQUIREMENTS | "A short daily lesson that fits your day" |
| Lessons follow your goal (family, partner, travel, life in VN, work, roots) and level | GOAL_CURRICULUM, onboarding | "Lessons built around why you're learning" |
| Spaced review of words and phrases (Again / Almost / Got it) | Practice, Words / Word Gym | "Flashcards that bring back what you're unsure of" |
| Word Gym: Hear it and Say it modes | PRODUCT_REQUIREMENTS | "Practice hearing and saying each phrase" |
| Live AI voice conversation (shipped), about 5 min/day, with corrections and a retry | LIVE_PRACTICE.md; confirmed shipped by owner 2026-10-07 | "Practice real conversations out loud" |
| Female voice that matches your chosen accent | ROADMAP, PRODUCT_REQUIREMENTS | — |
| Streaks with freezes; no punishment for missed days | LocalLearningActivityStore, PRODUCT_VISION | "Miss a day? No guilt." |
| Lesson history with audio you can replay | ADAPTIVE_LEARNING | — |
| Subscription with a hard paywall (RevenueCat): **$69.99/year or $7.99/week** (US) | Confirmed by owner 2026-10-07 | "$69.99/year" — confirm any trial in the live offering before claiming one |
| On the App Store (US) | https://apps.apple.com/us/app/vietbuddy-learn-vietnamese/id6796837982 | Link in bio / CTA |

**Never claim:**
- Fluency in X days, "master Vietnamese," or fluency scores
- That content was certified or approved by teachers or native speakers. Generated lessons have only had automated review (ADAPTIVE_LEARNING, GOAL_CURRICULUM).
- That the AI conversation is unlimited. The base allowance is 5 minutes per day.
- Android or web availability
- Grammar jargon (classifiers, particles, tonal phonology)

## 6. Real product screenshots and recordings

| Asset | Path | Shows |
|---|---|---|
| App Store screenshots (1242×2688, framed) | `app-store-screenshots/1242x2688/{first,second,third,fourth}.png` | "Learn Real Vietnamese": Today path, units, Bé Trâu |
| App Store screenshots (other size) | `app-store-screenshots/{first..fourth}.png` | Same set |
| Raw app screens | `website/public/screenshots/{home,conv,vocab,profile}.PNG` | Today, Listening ("Tune in. What's the story?"), Vocabulary, Profile |
| Simulator captures | `website/public/screenshots/Simulator Screenshot - iPhone 17 Pro Max - 2026-08-27 *.png` (4) | **[MISSING]** Contents not reviewed |
| Device screenshots | `content/references-slideshows/IMG_04{02,06,10,19,26,27}.*` | **[MISSING]** Check whether these are VietBuddy screens or references |
| UGC videos | `ugc-videos/1/{1,2,3}.mp4`, `video2/`, `video3/shocked.mp4`, `ugc-videos/grok.mp4` | **[MISSING]** Check which are real app footage and which are AI-generated (grok.mp4 is likely generated) |
| Mascot and icon | `website/public/be-trau-buddy.png`, `website/public/app-icon.png` | Brand assets |
| Reference slideshows | `content/references-slideshows/1–10/` | Competitor or inspiration carousels (not our product) |

No screen recordings exist yet of the cold listen, the onboarding demo, or a live AI conversation. → see §12.

## 7. Markets and language

- **Markets:** US first, then Canada and Australia. The diaspora, not people living in Vietnam.
- **UI and copy language:** English only. French is a later expansion.
- **Vietnamese in content:** Southern by default (ba/má, dạ, nha, vậy). Never mix accents in one post. Always use full diacritics. Follow the pronoun table in `content/prompts/partner-icp-content-prompt.md`.
- **Platforms:** TikTok, Instagram Reels and carousels, YouTube Shorts.

## 8. Budgets

- **Research budget:** Up to $8 of Apify usage per research pass (owner is on the $19 Apify plan, 2026-10-07). Each run carries its own `maxTotalChargeUsd` cap. No transcripts or video downloads unless a shortlist justifies them.
- **Generation budget:** **[MISSING]** For example: number of AI video/image generations per week, $ cap, UGC creator spend.

---

## 9. Five situations where the Partner naturally needs the app

| # | Situation | Tension | What they need |
|---|---|---|---|
| 1 | **Family dinner switches to Vietnamese** | Everyone laughs, they nod along and understand nothing. | Understand the gist (listening) and join in with "Má nấu ngon quá!" or "Mời ba má ăn cơm." |
| 2 | **Meeting the parents for the first time** | Fear of being rude to elders, of using the wrong pronoun (con / cô chú), of a cold reception. | Greet properly ("Dạ, con chào cô chú"), say a few polite phrases, show respect. |
| 3 | **Tết with the in-laws** | Lì xì, New Year wishes, a house full of relatives, karaoke and "Một, hai, ba, dô!" | Seasonal wishes ("Chúc mừng năm mới", "An khang thịnh vượng") and understanding the chaos. |
| 4 | **Video calls with her mom / his grandma** | The partner translates every sentence and the call feels awkward. | Small talk with no translator: "Bà khỏe không?", "Con ăn cơm rồi." |
| 5 | **First trip to Vietnam together / the wedding** | Ordering, relatives at the đám cưới, being the only one who can't talk. | Practical chunks for ordering and greetings, plus confidence before the trip. |

Backup situations: the partner's speech at the wedding, raising bilingual kids, the partner's family group chat, the partner speaking Vietnamese "when she's mad."

## 10. Search terms for content about these situations

**TikTok / Reels / Shorts** (for scraping with Apify):
- Dinner: `vietnamese family dinner`, `when your vietnamese family switches to vietnamese`, `white boyfriend vietnamese family`, `vietnamese in laws dinner`, `my vietnamese mother in law`
- Parents: `meeting my vietnamese girlfriends parents`, `meeting vietnamese parents first time`, `vietnamese boyfriend meets my parents`, `what to say to vietnamese parents`
- Tết: `tet with vietnamese in laws`, `first tet with vietnamese family`, `lunar new year vietnamese wife`, `lì xì husband`, `chúc mừng năm mới husband`
- Calls: `facetime vietnamese grandma`, `talking to my vietnamese mother in law`, `my husband speaks vietnamese to my mom`, `surprising vietnamese in laws speaking vietnamese`
- Trip / wedding: `vietnamese wedding foreign groom`, `first time in vietnam with wife's family`, `đám cưới chú rể nước ngoài`, `interracial couple vietnam trip`
- Category: `learn vietnamese`, `southern vietnamese phrases`, `saigon accent vs hanoi accent`, `vietnamese tones funny`, `ba má vs bố mẹ`

**Hashtags:** #vietnamesewife #vietnamesehusband #vietnamesegirlfriend #vietnameseboyfriend #vietnamesefamily #inlaws #amwf #wmaf #interracialcouple #vietkieu #learnvietnamese #tet

**Reddit / YouTube (long form for insight):** r/Vietnamese, r/AsianParentStories, r/interracialdating. Queries like "learning vietnamese for girlfriend's family" and "vietnamese in-laws don't speak english."

## 11. Video formats worth investigating

| Format | Why it fits | Where the product enters |
|---|---|---|
| **"Family switched to Vietnamese and I understood" POV** | Payoff after a familiar pain | Flashback to a cold listen on the phone, or a CTA screenshot at the end |
| **Surprise-the-in-laws reaction** (partner speaks Vietnamese to mom on FaceTime) | Very shareable; real emotion | Before: practicing in the app. After: mom's reaction. |
| **Phrase carousel** (hook photo → 3–5 black phrase slides → CTA) | Our best-performing format (ICP prompt §4) | Last slide: screenshots plus a recommendation in the creator's voice |
| **Couple skit: "what she says vs what she means"** | Humor about the learner's own struggle | Partner tests them; they pass thanks to the app |
| **Southern vs Northern comparison** ("her family says ba má, my textbook says bố mẹ") | Hook about the accent; makes the accent choice the product's edge | The accent picker in onboarding |
| **Listening challenge / quiz** ("Can you tell what's happening? 🇻🇳") | Interactive and gets comments; mirrors the cold listen | The real cold-listen screen recording |
| **Day-X learning diary** before Tết or the wedding | Builds a story over a series | The daily lesson and streak screen |
| **Talking to the AI coach in the app** | Shows the speaking feature live | Screen recording of the live conversation with a correction |

## 12. Where the product enters each story

| Situation | Entry point | App surface to show |
|---|---|---|
| 1. Family dinner | After the "lost at the table" beat: "So I started training my ears." | Practice cold listen ("Tune in. What's the story?") |
| 2. Meeting the parents | The night before: rehearsing greetings out loud | Word Gym "Say it" / a Today lesson with the partner goal |
| 3. Tết | Prep montage: learning wishes in the Southern accent | Accent picker + phrase chunks + review cards |
| 4. Video calls | Pre-call practice with the AI coach, then the real call | Live conversation screen |
| 5. Trip / wedding | Countdown diary: "14 days until we fly to Saigon" | Today path and streak, daily-minutes picker |

Rule: the app is the **training montage, never the hero**. The partner and the family are the payoff. The app appears in the middle or at the CTA, not in the hook.

## 13. Still missing

**Claims and facts**
- [x] Pricing: $69.99/year, $7.99/week (owner, 2026-10-07). [ ] Whether a free trial is attached to either plan.
- [x] App Store URL: https://apps.apple.com/us/app/vietbuddy-learn-vietnamese/id6796837982. [ ] Rating, number of reviews, download or user numbers (no social-proof claims until confirmed).
- [ ] Number of lessons to quote publicly (goal curriculum: 10 lessons × 4 levels per goal × 2 accents; the partner goal's coverage needs confirming. The curriculum has 4 goals but onboarding lists 6.)
- [x] Live AI conversation is shipped (owner, 2026-10-07). [ ] Exact daily minutes to state publicly (docs: 5 base minutes/day).
- [ ] Whether speech feedback / pronunciation scoring can be claimed (the roadmap lists "better speech feedback" as post-MVP).
- [ ] A native-speaker check of every Vietnamese phrase used in content.

**Assets**
- [ ] Screen recordings (portrait, 1080×1920, no notifications) of: the onboarding coffee-order demo, the cold listen → reveal → speak loop, the Word Gym, the accent picker, and a live AI conversation with a correction.
- [ ] A review of `ugc-videos/*` and `content/references-slideshows/IMG_*` to separate real product footage from AI-generated or reference material.
- [ ] Hook photos: couples and family settings (diverse pairings; not only men with Vietnamese women).
- [ ] Creators: real partners (ideally with willing in-laws) for reaction formats, plus consent and release forms.
- [ ] Brand kit for video: fonts, colors, an animated Bé Trâu (only static PNGs exist).
- [ ] Usage rights for any sound or music.

**Inputs**
- [x] Research budget (§8). [ ] Generation budget (§8)
- [ ] Posting accounts and platforms to prioritize, and how attribution is tracked (TikTok and Meta events exist in the app; campaign redirect links exist on the website).
