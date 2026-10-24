# Product requirements

## Required launch flow

The deterministic launch state machine is:

```text
loading -> onboarding -> value demo -> paywall -> main tabs
```

A stored active entitlement may enter the main tabs. Failure to reach
RevenueCat must not be interpreted as a confirmed inactive entitlement.

## Onboarding inputs

- Preferred accent: Southern or Northern
- Goal: family, life in Vietnam, travel, partner, work, or cultural roots
- Listening/speaking level
- Optional preferred first name
- Daily commitment: 3, 5, 7, or 10 minutes

Every answer must visibly affect copy, lesson ordering, or lesson behavior.
The name is optional and is never sent in analytics.

## Value demonstration

The user hears a natural coffee-order phrase without subtitles, identifies the
situation, then reveals practical phrase chunks. A wrong answer is recoverable
and never produces a hostile red failure screen. The demo must remain usable
offline using bundled or pre-cached audio.

## Main tabs

### Today

One primary time-budgeted lesson contains multiple distinct oral rounds. Every
round follows cold listen → decode → speak; the session completes only after all
rounds. Current plans map 5, 7, 10, and 15 selected minutes to 5, 7, 10, and 12
substantial rounds respectively. At most two quick reps and one listening tip
appear below it.

### Practice

The primary surface is a cold-listen situation check: transcript hidden,
female accent-matched audio, three large situation choices, then progression
into authored phrase chunks. Review sessions use audio-first recall followed by
reveal and one of three ratings:

- Again — scheduler-derived short interval
- Almost got it — scheduler-derived medium interval
- Got it — scheduler-derived longer interval

Rating names are at least 17 points and scheduling labels at least 16 points.

### Words

The primary surface is a two-minute Word Gym with Hear it and Say it modes,
one Vietnamese chunk at a time, natural audio, tap-to-reveal meaning, and three
large scheduling choices. Review timing and mastery remain repository-backed.
The phrase-bank model and detail screens remain available for future library
navigation rather than being discarded.

### Profile

Profile exposes the choices that change learning, weekly factual progress,
audio/download preferences, subscription management, privacy, export, account
deletion, legal links, and support.

## Future compatibility

A later bounded-conversation activity must have a hard 120-second cap, visible
time remaining, an always-available exit, and a structured recap. Vocabulary
from it must enter the same review pipeline.
