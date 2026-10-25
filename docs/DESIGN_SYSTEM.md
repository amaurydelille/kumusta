# Design system

## Visual character

Kumusta uses a warm paper palette instead of white screens. Dark warm ink
carries content, island teal is the single primary action color, and muted
surfaces make hierarchy without card overload. Every token has a light and a
dark value in `KumustaColors.swift`; the light values are:

| Token | Hex | Purpose |
|---|---:|---|
| Canvas | `#FBF4E6` | Screen background |
| Surface | `#FFFBF2` | Interactive and reading surfaces |
| Ink | `#24221E` | Primary text |
| Muted | `#6B6052` | Supporting text |
| Accent (island teal) | `#0E7F81` | Primary actions |
| Accent deep | `#0A6466` | Text accents, selected tab, contrast |
| Error (coral) | `#DE5640` | Wrong answers and failures only, never brand |
| Caution (mango) | `#F5A623` | Highlights and "almost right" marks |
| Line | `#E0CFB1` | Borders and separators |

The main learning surfaces follow the approved editorial reference: a compact
brand/mode/streak header, oversized two-line headlines, deliberately offset
card shadows, sparse outlined shapes, and a persistent canvas-colored tab bar.
The selected tab is tinted with accent deep. This visual grammar is
shared by Today, Practice, Words, and Profile. Navigation uses the native iOS
tab bar so supported OS versions receive Apple’s translucent glass material,
selection animation, and accessibility behavior automatically.

## Type floor

- Tagalog focus phrase: 22–34 points
- Screen title: 28 points
- Body and instructions: 17 points
- Supporting text: 16 points in learning interactions
- Non-essential metadata: 15 points minimum

All layouts must survive large accessibility sizes. Long Tagalog words and
affixed verbs must wrap or scale, never truncate or clip.

## Motion

Motion communicates state:

- Press: 97–98% scale and a 2-point downward response.
- Screen change: short spring plus fade.
- Listening: waveform motion and a small mascot lean.
- Success: one sub-second hop or small shape burst.

Reduce Motion replaces travel, rotation, and celebration with opacity changes.
Continuous animation stops when the relevant screen disappears.

## Mascot

The primary buddy is Tuko, a friendly green gecko (*tuko* in Tagalog) with big
brown eyes, rosy cheeks and a red neckerchief. Tuko is a teaching companion,
not a decorative sticker. Its pose or motion responds to idle, listening, and
success states. The static buddy, animated rig, state sprites and app icon are
all derived from the owner's Tuko master artwork; integration details are
tracked in `ASSET_PROVENANCE.md`.

## Interaction rules

- Minimum hit target: 44 by 44 points.
- Primary control height: 56 points.
- One obvious primary action per step.
- Feedback never relies on color alone.
- No emoji substitute for product icons.
- No pure white screen, fake glass, excessive pills, or nested card grids.
