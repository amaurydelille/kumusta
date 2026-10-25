# Master rig repair — image edit prompts

Built-in ImageGen was used for these edits. Mechanical extraction, masking, background keying and registration are implemented in [build_tuko_master_rig.swift](../../scripts/build_tuko_master_rig.swift). Use the README commands from the repository root.

## Face underpainting

Input: `reference.png`.

> Edit the attached image, DO NOT redraw or recompose it. Remove ONLY both eyes including sclera, irises, pupils and dark eyelid rims, both floating eyebrows and the entire closed smile mouth marking. Paint smooth continuous skin where they were: lime-green around eye areas, cream skin on the muzzle where smile was. Keep everything else exactly identical, pixel for pixel: head shape and three-quarter angle, snout lower left, nostrils, cheek blush, spots, body, bandana, arms, legs, tail, scale, position and magenta background. No blank eye holes. Same original 1254x1254 canvas. This is a full-body UNDERPAINTING edit, not an isolated head. Do not change any silhouette.

## Body underpainting

Input: `reference.png`.

> Edit the attached image, DO NOT redraw or recompose it. Remove ONLY the two entire arms and hands, and the entire red-orange bandana including neck band, triangle, knot and bow. Reveal and paint the body underneath: smooth lime-green shoulders and torso sides with olive spots, cream throat and belly. Remove hands and arms outside torso leaving the original magenta background there. Keep everything else exactly identical pixel for pixel: head, face, head silhouette and angle, legs, tail, body position, scale, camera and background. Preserve both legs and tail exactly. Same original 1254x1254 canvas. Full-body UNDERPAINTING edit, not isolated torso.

## Mouth repairs

Base prompts: `../tuko-prompts.md`, mouths 01, 07 and 10. References: original `../tuko-source.png`, `reference.png`, and the newly extracted `rig/Smile.png`.

- 01: “A visible thin dark-red gap between the upper and lower edge, clearly OPEN, not a line. Keep a slim sliver of dark-red cavity visible across the entire width.”
- 07: “Clearly OPEN, a wide flat dark-red opening about ONE FIFTH as tall as it is wide. A visible interior cavity, not a closed line. No teeth.”
- 10: “The pink tongue tip curls UP to TOUCH the TOP EDGE of the opening. A slender upright tongue reaches all the way to the roof of the mouth; dark-red cavity visible to both sides.”

Common registration instruction: preserve the extracted smile's width and downward-right three-quarter angle. Center at the master mouth position. Canvas 1254 × 1254, flat solid #FF00FF. Only mouth mark/interior; no cream skin or peach corner patches.

The first 01 still looked closed. A final edit used the open 07 as its edit target:

> Edit this isolated OPEN mouth asset into a BARELY PARTED speech mouth, keeping the same color palette and angle. Reduce only its opening height to roughly ONE THIRD of its current height. It must remain an actual visibly OPEN dark burgundy cavity with an upper edge and lower edge distinctly separated by a thin area of dark interior, about 8 percent of its width. The interior is DARKER than the red-brown edges. Keep width unchanged, same slight smile, no tongue, no teeth, no skin, no face. Flat pure #FF00FF background. One mouth only. Do not collapse it into a single closed smile line.

The extraction script then registers and sizes the generated mouth marks mechanically. All twelve original generation inputs are preserved in `mouth-sources/`.
