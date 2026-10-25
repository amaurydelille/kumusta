# Tuko — master-cut rig

Open **[rig-preview.html](rig-preview.html)** to inspect the assembled character, overlay the original master, move individual joints, hide the facial features or arms, and switch between all twelve registered mouths. Browser execution was not available in the agent session; the rendered PNG assemblies were inspected directly.

The previous independently generated rig parts have been replaced. The master itself, `reference.png`, is unchanged.

## Artwork and registration

- `face-underpainting.png`: full-master image edit removing eyes, brows and smile.
- `body-underpainting.png`: full-master image edit removing arms and bandana.
- `rig/*.png`: thirteen parts on exact solid #FF00FF, at their original positions on the master's native 1254 × 1254 canvas.
- `rig-alpha/*.png`: the same parts as transparent full-canvas layers. Stack them at (0, 0), without rescaling, in the manifest draw order.
- `rig-cropped/*.png`: transparent crops. Use the top-left offsets and local pivots in `rig-manifest.json`; no manual alignment is required.
- `mouths/*.png` and `mouths-alpha/*.png`: twelve registered speech shapes, on magenta and transparency respectively. `mouth-00` is the exact extracted master smile. Other mouths share its articulation angle and position; OH/OO and the wider EE/grin retain their intended width differences.
- `mouths-cropped/*.png` and `mouth-manifest.json`: matching crop offsets and measured opening depths.
- `mouth-sources/`: preserved generation inputs for repeatable mouth registration. Mouths 01, 07 and 10 were regenerated with visible separation, an open EE cavity, and a tongue touching the upper edge respectively. Mouth 01 received a further edit to make its dark slit visible.
- `review/`: the assembled rest pose and all twelve mouths rendered on the character, plus keyed master comparisons.

Visible limb, eye, brow, scarf and smile artwork comes directly from the master. The head retains its master silhouette, three-quarter angle, snout, blush and spots. Underpaintings replace removed facial marks and supply the torso skin revealed by removing arms/scarf; the original central belly is retained. Shoulder and hip masks have rounded overlaps. The hidden tail-root overlap extends sampled tail material beneath the thigh; exposed tail artwork is retained.

The output deliberately stays at the native master size rather than independently scaling parts to 2048. All offsets and pivots use top-left pixel coordinates. Scale the entire assembled rig uniformly if a 2048 export is needed.

## Rebuild

From the repository root:

```sh
rtk proxy swiftc -O -module-cache-path /tmp/tuko-swift-cache scripts/build_tuko_master_rig.swift -o /tmp/build-tuko-master-rig
rtk proxy /tmp/build-tuko-master-rig art/tuko
```

`scripts/build_tuko_master_rig.swift` adapts the same master/underpainting extraction approach as `scripts/build_master_mascot_rig.swift`. No application assets or application rendering code are changed.

`rig-validation.json` records the source-pixel comparison and head-contour check. `validation.json` records file completeness and dimensions. Mask antialiasing and the deliberately repainted hidden areas are distinct from the unchanged exposed source pixels.

The ten original state/icon generations remain in the folder and have not been repaired in this revision; their previously noted generation drift remains. Optional animation loops were not generated.
