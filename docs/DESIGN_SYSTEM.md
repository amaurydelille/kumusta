# Design system

## Visual character

Kumusta uses a warm paper-and-café palette instead of white screens. Dark warm
ink carries content, coral is the single primary action color, and muted
surfaces make hierarchy without card overload.

Core colors:

| Token | Hex | Purpose |
|---|---:|---|
| Canvas | `#F8E8CF` | Screen background |
| Surface | `#FFF3DF` | Interactive and reading surfaces |
| Ink | `#24221E` | Primary text |
| Muted | `#6E6255` | Supporting text |
| Coral | `#DE5640` | Primary actions |
| Deep coral | `#A83A2D` | Contrast and pressed depth |
| Line | `#D9BFA0` | Borders and separators |

The main learning surfaces follow the approved editorial reference: a compact
brand/mode/streak header, oversized two-line headlines, deliberately offset
card shadows, sparse outlined shapes, and a persistent cream tab bar. The
active tab uses a soft coral capsule behind its icon. This visual grammar is
shared by Today, Practice, Words, and Profile. Navigation uses the native iOS
tab bar so supported OS versions receive Apple’s translucent glass material,
selection animation, and accessibility behavior automatically.

## Type floor

- Vietnamese focus phrase: 22–34 points
- Screen title: 28 points
- Body and instructions: 17 points
- Supporting text: 16 points in learning interactions
- Non-essential metadata: 15 points minimum

All layouts must survive large accessibility sizes. Vietnamese diacritics must
never be clipped by fixed line heights.

## Motion

Motion communicates state:

- Press: 97–98% scale and a 2-point downward response.
- Screen change: short spring plus fade.
- Listening: waveform motion and a small mascot lean.
- Success: one sub-second hop or small shape burst.

Reduce Motion replaces travel, rotation, and celebration with opacity changes.
Continuous animation stops when the relevant screen disappears.

## Mascot

The primary buddy is Bé Trâu, a hand-drawn baby water buffalo with warm ink,
watercolor texture, oversized expressive eyes, and a red scarf. Bé Trâu is a
teaching companion, not a decorative sticker. Its pose or motion responds to
idle, listening, and success states. The generated source prompt and integration
details are tracked in `ASSET_PROVENANCE.md`.

## Interaction rules

- Minimum hit target: 44 by 44 points.
- Primary control height: 56 points.
- One obvious primary action per step.
- Feedback never relies on color alone.
- No emoji substitute for product icons.
- No pure white screen, fake glass, excessive pills, or nested card grids.
