# Asset provenance

## Tuko mascot

Source artwork supplied by the owner on 2026-10-25: `art/tuko-source.png`
(1254 px square, white background). Every mascot asset is derived from it:

- The static buddy image was cut out with an edge flood-fill matte and resized:
  `Kumusta/Resources/Assets.xcassets/TukoBuddy.imageset/tuko-buddy@1x.png`
  (and `@2x`, `@3x`).
- The state poses, launch art and app icon were generated with the source as
  a character reference, using the prompt pack in `art/tuko-prompts.md`
  (prompts recorded in `art/tuko/prompts.json`). The state sprites
  (`Mascot*Sprite`) are assembled from those poses by
  `scripts/build_mascot_assets.py`.
- The puppet rig is cut from the master by `scripts/build_tuko_master_rig.swift`
  into `art/tuko/` and installed by `scripts/import_tuko_rig.py` as
  the `RigV2*` and `RigMouth*` image sets plus the `ConversationRigV2` manifest.
  `art/tuko/README.md` documents the registration and validation.

## Correct-answer feedback

Integrated file:

- `Kumusta/Resources/Audio/Feedback/mixkit-correct-answer-tone-2870.wav`

Source: Mixkit, “Correct answer tone,” supplied as a local WAV by the product
owner. The asset is used as a short success cue after correct choices, exact
speech matches, and “Got it” review ratings. Its use follows the Mixkit Free
Sound Effects License; the source and license should be retained with the
release archive.

Before commercial release, product counsel should confirm the applicable
generated-content policy and asset records should be retained with the release
archive.
