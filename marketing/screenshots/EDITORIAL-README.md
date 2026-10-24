# VietBuddy App Store story screenshots

This five-panel set is drawn with AppKit in `render_editorial_screenshots.swift`. It uses the existing Bé Trâu mascot and unmodified simulator captures from `real-simulator-1242x2688`. The campaign colors are drawn from `VietBuddyColors.swift`.

The first panel introduces the app with the mascot, its seven-minute lesson format, and its two accent options. The next four use numbered arrows, highlighted headlines, pastel brand colors, and one large real app screen per panel.

## Render

Run from the repository root:

```sh
rtk env CLANG_MODULE_CACHE_PATH=/tmp/vietbuddy-clang-cache SWIFT_MODULECACHE_PATH=/tmp/vietbuddy-swift-cache swift mobile-app/app-store-screenshots/render_editorial_screenshots.swift
```

The source creates five ordered PNGs per language in each of these folders:

- `story-english-1320x2868` and `story-french-1320x2868` for Apple's 6.9-inch iPhone slot.
- `story-english-1242x2688` and `story-french-1242x2688` for the 6.5-inch slot.

The PNGs are opaque RGB. To refresh their in-app content, replace the corresponding captures in `real-simulator-1242x2688` and rerun the renderer. The French campaign copy surrounds English-language app captures because those are the simulator captures currently in the repository.

The layout takes inspiration from the supplied Falou reference's storytelling structure. All copy, app imagery, mascot, and colors are specific to VietBuddy.
