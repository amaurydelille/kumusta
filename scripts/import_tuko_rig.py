#!/usr/bin/env python3
"""Install the master-cut Tuko rig into the asset catalog.

Reads the registered parts and mouths produced by build_tuko_master_rig.swift
(`art/tuko/rig-cropped`, `mouths-cropped` and their manifests) and
writes the `RigV2*` and `RigMouth*` image sets plus the `ConversationRigV2`
manifest that ConversationMascotRenderer reads. Coordinates stay in the
master's 1,254 px canvas; `stage` is the region the renderer fits to its view,
with headroom for raised arms and the celebration jump.

Usage: import_tuko_rig.py ART_DIR ASSET_CATALOG
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

STAGE = {"x": 170, "y": 40, "width": 1030, "height": 1150}


def image_set(catalog: Path, name: str, source: Path) -> None:
    folder = catalog / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, folder / f"{name}.png")
    if (folder / "Contents.json").exists():
        return
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2, sort_keys=True) + "\n")


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    art, catalog = Path(sys.argv[1]), Path(sys.argv[2])
    rig = json.loads((art / "rig-manifest.json").read_text())
    mouths = json.loads((art / "mouth-manifest.json").read_text())

    manifest: dict[str, dict] = {"stage": STAGE}
    for name, part in rig["parts"].items():
        image_set(catalog, f"RigV2{name}", art / "rig-cropped" / f"{name}.png")
        manifest[name] = {key: part[key] for key in ("x", "y", "width", "height", "pivotX", "pivotY")}
    for index, mouth in enumerate(mouths):
        image_set(catalog, f"RigMouth{index}", art / "mouths-cropped" / mouth["file"])
        manifest[f"Mouth{index}"] = {key: mouth[key] for key in ("x", "y", "width", "height")}

    data = catalog / "ConversationRigV2.dataset" / "ConversationRigV2.json"
    data.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"{len(rig['parts'])} parts, {len(mouths)} mouths")


if __name__ == "__main__":
    main()
