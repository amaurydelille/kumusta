# Tuko — image-generation prompt pack

Every prompt below is self-contained: copy one code block, paste it, attach the
listed reference images, generate. One image per generation.

## Before you start

- **Always attach `art/tuko-source.png`** (use the model's image-reference /
  edit / "character reference" mode). From Step 2 on, also attach the approved
  `reference.png` from Step 1.
- **Canvas:** 2048 × 2048, square.
- **Background:** solid magenta `#FF00FF`. Never green (Tuko is green), never white
  (the eye whites and cream belly would be cut out).
- **Reject and regenerate** any image where the green, spot pattern, toe count,
  bandana color, eye color or proportions changed, or where black outlines appeared.
- **Negative prompt** (paste it wherever your model has a negative-prompt field):

```
black outlines, lineart, ink lines, cel shading, 3D render, plastic, photorealistic,
texture noise, grain, cast shadow, ground shadow, drop shadow, gradient background,
vignette, white background, green background, scenery, props, text, letters, logo,
watermark, signature, extra limbs, extra toes, missing toes, extra fingers, teeth, fangs,
ears, hair, horns, clothing other than the bandana, cropped, cut off, blurry, deformed
```

---

## Step 1 — Rig master (`reference.png`)

Attach: `tuko-source.png`. Generate several, pick the best, it defines everything after.

```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference image exactly: same character, proportions, colors and painting style.

Character details: oversized rounded head about 45% of total height, small pear-shaped body,
short soft limbs. Bright lime / yellow-green skin with soft lighter highlights, scattered round
darker olive-green spots on the head, back, limbs and tail with the same density as the
reference. Cream / butter-yellow belly, throat, lower jaw and underside of the tail. Large
glossy dark-brown eyes with white sclera, one big and one small white catchlight. Thin
dark-green arched eyebrows floating above each eye. Round soft orange-coral cheek blush. Two
tiny dark nostril dots. Red-orange bandana neckerchief tied in a bow with a round knot on the
chest. Toes end in round yellow-orange toe pads, same toe count as the reference. Long tail
curling into a spiral. Soft digital painting, smooth gradients, gentle soft shading, no black
outlines, no lineart.

Pose: neutral rig pose for animation. Same three-quarter camera as the reference: body turned
slightly to the viewer's right, head facing the viewer, tail curling out on the right side.
Standing upright, weight centered, both feet flat and slightly apart with no overlap. Both arms
relaxed and hanging down at the sides, held slightly away from the torso so there is a clear
gap of background between each arm and the body. Hands open and relaxed, toe pads visible.
Tail clearly separated from the legs. Mouth closed in a gentle smile. Eyes fully open, looking
at the viewer. Nothing overlaps the face.

Composition: full body, centered, about 10% empty margin on every side. Flat even lighting,
no cast shadow. Perfectly flat solid magenta #FF00FF background. No text, no logo.
```

---

## Step 2 — Rig parts (`rig/*.png`)

Attach: `tuko-source.png` **and** `reference.png`. One part per generation.
"Underpainting" = paint the hidden area as if it were visible, so nothing shows a hole when
the part moves.

### rig/Head.png
```
Using the attached Tuko master image, paint ONLY Tuko's head as an isolated cut-out body part,
at exactly the same size, angle, colors and soft painted style as in the master.

The face is BLANK: no eyes, no eyebrows, no mouth. Where the eyes and the mouth were, paint
smooth continuous skin as if they had never been drawn: lime-green skin around the eye areas,
cream skin on the muzzle and lower jaw. Keep the two tiny nostril dots, the round orange-coral
cheek blush and the darker olive-green spots on the top and back of the head.

Cut the head off just below the jaw, and include a short rounded stub of neck at the bottom
(it will be hidden under the bandana). Clean smooth silhouette edge.

Isolated single body part only, nothing else in the image, no body, no bandana, no arms.
Soft digital painting, smooth gradients, no black outlines. Flat even lighting, no shadow.
Perfectly flat solid magenta #FF00FF background. No text.
```

### rig/Body.png
```
Using the attached Tuko master image, paint ONLY Tuko's torso as an isolated cut-out body part,
at exactly the same size, angle, colors and soft painted style as in the master.

Include: the lime-green back and sides with darker olive-green spots, the cream / butter-yellow
belly, the neck top and both shoulders painted completely, the hips where the legs attach, and
the area where the tail attaches. Paint the neck, shoulders, hips and tail base fully, as
smooth skin, because head, arms, legs and tail will be layered over them.

Do NOT include: head, arms, legs, tail, bandana. No bandana anywhere: paint plain skin where it
was.

Isolated single body part only, nothing else in the image. Soft digital painting, smooth
gradients, no black outlines. Flat even lighting, no shadow. Perfectly flat solid magenta
#FF00FF background. No text.
```

### rig/ArmLeft.png (the arm on the viewer's left)
```
Using the attached Tuko master image, paint ONLY the arm on the VIEWER'S LEFT side as an
isolated cut-out body part, at exactly the same size, colors and soft painted style as in the
master.

The whole arm hangs straight down: from a rounded shoulder end at the top (a smooth ball shape,
fully painted, so the arm can rotate around it) down to an open relaxed hand at the bottom.
Palm turned slightly toward the viewer, toes spread a little, round yellow-orange toe pads
visible, same toe count as the reference. Lime-green skin with a few darker olive-green spots,
slightly lighter on the inside of the arm.

Isolated single body part only, nothing else in the image, no body attached. Soft digital
painting, smooth gradients, no black outlines. Flat even lighting, no shadow. Perfectly flat
solid magenta #FF00FF background. No text.
```

### rig/ArmRight.png (the arm on the viewer's right)
```
Using the attached Tuko master image, paint ONLY the arm on the VIEWER'S RIGHT side as an
isolated cut-out body part, at exactly the same size, colors, perspective and soft painted
style as in the master.

The whole arm hangs straight down: from a rounded shoulder end at the top (a smooth ball shape,
fully painted, so the arm can rotate around it) down to an open relaxed hand at the bottom.
Palm turned slightly toward the viewer, toes spread a little, round yellow-orange toe pads
visible, same toe count as the reference. Lime-green skin with a few darker olive-green spots,
slightly lighter on the inside of the arm.

Isolated single body part only, nothing else in the image, no body attached. Soft digital
painting, smooth gradients, no black outlines. Flat even lighting, no shadow. Perfectly flat
solid magenta #FF00FF background. No text.
```

### rig/LegLeft.png (the leg on the viewer's left)
```
Using the attached Tuko master image, paint ONLY the leg on the VIEWER'S LEFT side as an
isolated cut-out body part, at exactly the same size, colors, perspective and soft painted
style as in the master.

From a rounded, fully painted hip end at the top down to the foot standing flat at the bottom.
Toes spread, round yellow-orange toe pads, same toe count as the reference. Lime-green skin
with darker olive-green spots.

Isolated single body part only, nothing else in the image. Soft digital painting, smooth
gradients, no black outlines. Flat even lighting, no ground shadow. Perfectly flat solid
magenta #FF00FF background. No text.
```

### rig/LegRight.png (the leg on the viewer's right)
```
Using the attached Tuko master image, paint ONLY the leg on the VIEWER'S RIGHT side as an
isolated cut-out body part, at exactly the same size, colors, perspective and soft painted
style as in the master.

From a rounded, fully painted hip end at the top down to the foot standing flat at the bottom.
Toes spread, round yellow-orange toe pads, same toe count as the reference. Lime-green skin
with darker olive-green spots.

Isolated single body part only, nothing else in the image. Soft digital painting, smooth
gradients, no black outlines. Flat even lighting, no ground shadow. Perfectly flat solid
magenta #FF00FF background. No text.
```

### rig/Tail.png
```
Using the attached Tuko master image, paint ONLY Tuko's tail as an isolated cut-out body part,
at exactly the same size, curl, colors and soft painted style as in the master.

From a thick rounded base (fully painted, it will tuck behind the body) out to the tip curled
into a spiral. Lime-green top with darker olive-green spots, cream / butter-yellow underside
following the curl, exactly like the reference.

Isolated single body part only, nothing else in the image, no body, no legs. Soft digital
painting, smooth gradients, no black outlines. Flat even lighting, no shadow. Perfectly flat
solid magenta #FF00FF background. No text.
```

### rig/Scarf.png
```
Using the attached Tuko master image, paint ONLY Tuko's red-orange bandana neckerchief as an
isolated cut-out item, at exactly the same size, angle, colors and soft painted style as worn
in the master.

Include the triangular front panel, the band that wraps around the neck (with the part that
goes around the back of the neck visible as a thin band behind), the bow with its two loops
and two tails, and the round knot in the middle. Soft folds, gentle shading, slightly darker
red in the folds.

No gecko, no skin, nothing else in the image. Soft digital painting, smooth gradients, no
black outlines. Flat even lighting, no shadow. Perfectly flat solid magenta #FF00FF
background. No text.
```

### rig/EyeLeft.png (the eye on the viewer's left)
```
Using the attached Tuko master image, paint ONLY the eye on the VIEWER'S LEFT side as an
isolated cut-out part, at exactly the same size, shape and painted style as in the master.

The eyeball only: white sclera, large glossy dark-brown iris and pupil looking at the viewer,
one big round white catchlight upper right and one small catchlight lower left. Fully open,
complete oval. No eyelid, no eyelashes, no eyebrow, no surrounding skin.

Isolated single part only, nothing else in the image. Soft digital painting, no black
outlines. Perfectly flat solid magenta #FF00FF background. No text.
```

### rig/EyeRight.png (the eye on the viewer's right)
```
Using the attached Tuko master image, paint ONLY the eye on the VIEWER'S RIGHT side as an
isolated cut-out part, at exactly the same size, shape and painted style as in the master.

The eyeball only: white sclera, large glossy dark-brown iris and pupil looking at the viewer,
one big round white catchlight upper right and one small catchlight lower left. Fully open,
complete oval. No eyelid, no eyelashes, no eyebrow, no surrounding skin.

Isolated single part only, nothing else in the image. Soft digital painting, no black
outlines. Perfectly flat solid magenta #FF00FF background. No text.
```

### rig/BrowLeft.png (the eyebrow on the viewer's left)
```
Using the attached Tuko master image, paint ONLY the eyebrow above the eye on the VIEWER'S
LEFT side, at exactly the same size, curve, angle and color as in the master: a single thin
dark-green arched stroke with soft tapered ends.

Nothing else in the image, no eye, no skin. No black outlines. Perfectly flat solid magenta
#FF00FF background. No text.
```

### rig/BrowRight.png (the eyebrow on the viewer's right)
```
Using the attached Tuko master image, paint ONLY the eyebrow above the eye on the VIEWER'S
RIGHT side, at exactly the same size, curve, angle and color as in the master: a single thin
dark-green arched stroke with soft tapered ends.

Nothing else in the image, no eye, no skin. No black outlines. Perfectly flat solid magenta
#FF00FF background. No text.
```

### rig/Smile.png
```
Using the attached Tuko master image, paint ONLY Tuko's closed resting smile as an isolated
mark, at exactly the same size, position angle and painted style as on the master's face:
a soft curved dark-red-brown mouth line with gently upturned corners and a faint soft crease
at each corner.

Only the mouth marking, no skin patch, no face, nothing else in the image. No black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

---

## Step 3 — Mouth shapes (`mouths/mouth-00.png` … `mouth-11.png`)

Attach: `tuko-source.png`, `reference.png` and `rig/Smile.png`. Do all 12 in **the same
session**, in order, so the size and style stay consistent. Each mouth must be the same width
as `Smile.png` and drawn at the same angle.

### mouths/mouth-00.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: closed resting smile,
a soft curved line with gently upturned corners (same as the Smile image).
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-01.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: barely parted, a thin
dark-red slit along the smile line, corners still upturned.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-02.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: slightly open and
relaxed, a narrow dark-red opening, a hint of pink tongue at the bottom.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-03.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: medium open, rounded
dark-red inside, pink tongue clearly visible at the bottom.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-04.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: wide open happy mouth,
like in the original reference image: big dark-red inside, large pink tongue, upturned corners.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-05.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same angle and soft painted style as
the attached Smile image and the master's face, centered where the smile is. Mouth shape:
rounded "oh", a medium open circle, dark-red inside with a little pink tongue at the bottom.
Narrower than the smile.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-06.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same angle and soft painted style as
the attached Smile image and the master's face, centered where the smile is. Mouth shape:
small tight rounded "oo", pursed into a small dark-red circle, much narrower than the smile.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-07.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same angle and soft painted style as
the attached Smile image and the master's face. Mouth shape: wide flat "ee", corners
stretched sideways a little wider than the smile, a thin wide dark-red opening.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-08.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: "f / v", mostly closed,
the upper edge resting on the lower edge, a tiny dark-red gap at the sides.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-09.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: "m / b / p", lips
pressed firmly closed, a straight line slightly puffed at the middle, no opening.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-10.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same width, angle and soft painted
style as the attached Smile image and the master's face. Mouth shape: "l / th", medium open
with the pink tongue tip raised to touch the top of the mouth, dark-red inside.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

### mouths/mouth-11.png
```
Paint ONLY Tuko the gecko's mouth as an isolated mark, same angle and soft painted style as
the attached Smile image and the master's face. Mouth shape: closed big happy grin, a wide
deeply curved line with strongly upturned corners, slightly wider than the smile.
Only the mouth, no face, no skin patch, no teeth, no lips outline, no black outlines.
Perfectly flat solid magenta #FF00FF background. No text.
```

---

## Step 4 — State keyframes (full body)

Attach: `tuko-source.png` and `reference.png`. Every state must keep the same camera, scale
and on-canvas size as `reference.png`.

### launch-greeting.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: cheerful hello. The arm on the viewer's left raised high with the hand
open, palm toward the viewer; the other arm relaxed at the side. Big open happy smile with pink
tongue, eyes bright and looking at the viewer, eyebrows lifted. Standing upright, feet flat.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### launch-loading.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: calm and content. Standing upright, both hands loosely together in front
of the belly, closed gentle smile, eyes open and warm, looking at the viewer. Relaxed, still,
symmetrical-feeling pose.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### welcome-wave.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: friendly wave, as in the original reference. The arm on the viewer's left
raised beside the head, hand open and waving, toes spread; the other hand resting on the belly.
Big open happy smile with pink tongue, head tilted slightly, eyes looking at the viewer.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### listening.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: attentively listening. Head tilted gently to one side, eyes wide and
focused on the viewer, eyebrows slightly raised, closed soft smile. One hand raised near the
side of the head as if cupping to listen, the other relaxed at the side. Leaning a tiny bit
forward.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### curious.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: curious and thinking. Head tilted to the side, eyes glancing up and to
one side, eyebrows raised, small rounded "oh" mouth. One toe-tip touching the chin, the other
arm folded under it across the belly. Tail curled up a little more.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### speaking.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: talking and explaining, friendly teacher energy. Mouth medium open
mid-word with a little pink tongue visible. One arm extended outward at chest height, hand
open palm up, as if presenting an idea; the other arm relaxed. Eyebrows lifted, eyes engaged
with the viewer.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### correct.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: delighted "you got it!" cheer. Both hands raised in small happy fists
at shoulder height, eyes closed happily into upward curved arcs, big open grin with pink
tongue, cheeks extra rosy, tail flicked up, standing on tiptoe.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### mistake.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: gentle and encouraging after a small mistake, NOT sad, NOT disappointed.
Soft sympathetic closed smile, eyebrows tilted kindly upward in the middle, warm eyes on the
viewer, head tilted slightly. One hand extended open toward the viewer as if saying
"no worries, try again", the other hand resting on the belly.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### streak.png
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, proportions, colors and soft painted style.
Bright lime / yellow-green skin, darker olive-green round spots, cream belly, throat and tail
underside, large glossy dark-brown eyes with white catchlights, thin dark-green floating
eyebrows, orange-coral cheek blush, red-orange bandana with a bow on the chest, round
yellow-orange toe pads (same toe count), spiral tail. Soft digital painting, smooth gradients,
no black outlines.

Pose and expression: big celebration jump. Both feet off the ground, both arms thrown up high,
toes spread, tail swishing out in a wide curve, bandana tails fluttering, eyes sparkling with
extra catchlights, huge open grin with pink tongue. No floor, no sparkle effects, no confetti.

Same three-quarter camera as the master. Full body, centered, about 10% margin on every side,
same scale as the master. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text, no logo.
```

### icon.png (app icon)
```
Tuko, a chibi baby gecko mascot for a children's language-learning app. Match the attached
reference images exactly: same character, colors and soft painted style. Bright lime /
yellow-green skin, darker olive-green round spots, cream throat, large glossy dark-brown eyes
with white catchlights, thin dark-green floating eyebrows, orange-coral cheek blush, red-orange
bandana with a bow. Soft digital painting, smooth gradients, no black outlines.

App icon portrait: head and shoulders only, facing the viewer straight on, head filling about
80% of the frame width, big open happy smile with pink tongue, eyes looking at the viewer,
bandana bow visible at the bottom. Bold simple shapes that read well at very small sizes.
Centered, nothing cropped on the head. Flat even lighting, no shadow. Perfectly flat solid
magenta #FF00FF background. No text, no logo, no border, no rounded corners.
```

---

## Step 5 (optional) — 8-frame loops (`Frames/<state>/frame-01.png` … `frame-08.png`)

Only for `welcome-wave`, `speaking`, `correct`, `mistake`, `streak`. Skip a state if the
model can't keep Tuko identical between frames; the app has a fallback.

Attach for each frame: `reference.png`, that state's keyframe, and **the previous frame**.
Paste this template and replace `<STATE>`, `<N>` and `<CHANGE>` with a row from the tables
below.

```
Frame <N> of an 8-frame looping animation of Tuko the chibi baby gecko, state: <STATE>.
Redraw the attached previous frame with exactly ONE small change: <CHANGE>.
Everything else stays pixel-identical: same character, colors, spots, proportions, scale,
position on the canvas, camera, and both feet in exactly the same place (unless the change
says otherwise). Soft digital painting, smooth gradients, no black outlines. Full body,
centered, same margin. Flat even lighting, no cast shadow. Perfectly flat solid magenta
#FF00FF background. No text.
```

### welcome-wave
| N | CHANGE |
|---|---|
| 1 | the keyframe itself: waving hand raised beside the head, palm toward the viewer |
| 2 | waving hand tilted 10° outward, away from the head |
| 3 | waving hand tilted 20° outward, toes fanned wide, smile widens slightly |
| 4 | waving hand tilted 10° outward, head tilts 3° toward the waving hand |
| 5 | waving hand back upright, as in frame 1 |
| 6 | waving hand tilted 10° inward, toward the head |
| 7 | waving hand tilted 20° inward, eyes squint happily a little |
| 8 | waving hand tilted 10° inward, returning to the frame 1 position |

### speaking
| N | CHANGE |
|---|---|
| 1 | the keyframe itself: presenting hand open palm up, mouth medium open |
| 2 | mouth slightly more open, eyebrows lift a little |
| 3 | mouth nearly closed, presenting hand moves 5% higher |
| 4 | mouth wide open "ah", head tilts 3° toward the presenting hand |
| 5 | mouth small rounded "oh", presenting hand back to the frame 1 height |
| 6 | mouth closed in a soft smile, a small nod: head 2% lower |
| 7 | mouth medium open, head back up, eyebrows relaxed |
| 8 | mouth slightly open, returning to the frame 1 pose |

### correct
| N | CHANGE |
|---|---|
| 1 | the keyframe itself: both fists up at shoulder height, eyes happy arcs, big grin |
| 2 | whole body squashes down 4% in anticipation, fists slightly lower |
| 3 | body stretches up 4%, on tiptoe, fists 8% higher |
| 4 | both feet just off the ground, fists at their highest, tail flicked up |
| 5 | starting to land: feet almost on the ground, fists coming down slightly |
| 6 | landed, small squash 3%, grin still wide |
| 7 | body back to normal height, fists give a small shake |
| 8 | settling back into the frame 1 pose |

### mistake
| N | CHANGE |
|---|---|
| 1 | the keyframe itself: open hand extended toward the viewer, kind smile |
| 2 | head tilts 2° more, eyes blink half closed softly |
| 3 | eyes open again, small encouraging nod: head 2% lower |
| 4 | head back up, extended hand moves 4% closer toward the viewer |
| 5 | smile widens slightly, eyebrows lift a little |
| 6 | extended hand back to the frame 1 position |
| 7 | head tilts back 2°, gentle slow blink |
| 8 | returning to the frame 1 pose |

### streak
| N | CHANGE |
|---|---|
| 1 | crouched with knees bent, arms down and back, ready to jump, big grin |
| 2 | pushing off: legs straightening, arms swinging forward and up |
| 3 | just off the ground, arms halfway up |
| 4 | the keyframe: top of the jump, both arms high, tail swishing wide |
| 5 | still in the air, starting to come down, arms still high |
| 6 | toes touching the ground, arms coming down |
| 7 | landed with a small squash, arms out to the sides |
| 8 | straightening up, moving back into the crouch of frame 1 |

---

## Delivery checklist

```
tuko-art/
  reference.png
  launch-greeting.png  launch-loading.png  welcome-wave.png  listening.png
  curious.png  speaking.png  correct.png  mistake.png  streak.png  icon.png
  rig/     Head.png Body.png ArmLeft.png ArmRight.png LegLeft.png LegRight.png Tail.png
           Scarf.png EyeLeft.png EyeRight.png BrowLeft.png BrowRight.png Smile.png
  mouths/  mouth-00.png … mouth-11.png
  Frames/  welcome-wave/ speaking/ correct/ mistake/ streak/   (optional, 8 each)
```

Before sending, check each image:

- [ ] solid magenta background, nothing else on it
- [ ] same green, spots, cream areas, eye color and bandana as the source
- [ ] same toe count everywhere
- [ ] no black outlines, no shadows, no text
- [ ] rig parts: hidden areas painted in (neck, shoulders, hips, tail base, blank face)
- [ ] full-body states: same scale and canvas position as `reference.png`
