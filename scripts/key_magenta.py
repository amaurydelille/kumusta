#!/usr/bin/env python3
"""Remove the flat magenta background from generated Tuko artwork.

The generator's magenta is not exact and varies across the canvas, so the
background colour is sampled from the image border. Alpha comes from how
magenta a pixel is (min(R, B) - G), and edge colour is unmixed from the
background so no pink fringe remains. Tuko has no magenta of his own; the
pinkest painted colour, his tongue, scores far below the background.

Usage: key_magenta.py SOURCE_DIR OUTPUT_DIR
Keys every PNG directly in SOURCE_DIR (not subfolders) into OUTPUT_DIR.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Magenta score bounds: at or above OPAQUE_BELOW is fully transparent.
OPAQUE_BELOW = 70.0
CLEAR_ABOVE = 170.0


def key(path: Path) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3),
                             rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
    background = np.median(border, axis=0)

    score = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    alpha = 1 - np.clip((score - OPAQUE_BELOW) / (CLEAR_ABOVE - OPAQUE_BELOW), 0, 1)

    # Undo the blend with the background on partially transparent edges.
    safe = np.maximum(alpha, 1e-3)[..., None]
    colour = np.clip((rgb - (1 - safe) * background) / safe, 0, 255)
    colour = np.where(alpha[..., None] > 0.999, rgb, colour)

    out = np.dstack([colour, alpha * 255]).round().astype(np.uint8)
    out[alpha < 0.02] = 0
    return Image.fromarray(out)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source, output = Path(sys.argv[1]), Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    for path in sorted(source.glob("*.png")):
        key(path).save(output / path.name, "PNG", optimize=True)
        print(path.name)


if __name__ == "__main__":
    main()
