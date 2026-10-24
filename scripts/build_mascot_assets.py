#!/usr/bin/env python3
"""Build the Kumusta mascot asset family from reference-locked poses.

The runtime expects one square cell per sprite frame. Keeping the composition
here deterministic makes the SwiftUI atlas cropper predictable and gives each
motion a consistent silhouette even when the source poses have different
amounts of transparent padding. Every source pose is anthropomorphic: two arms,
two legs, and an upright human-like stance. Generated motion families use eight
individual frames when available; missing families fall back to deterministic
micro-motion variants so the atlas never repeats a single abrupt pose.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


CELL = 724
FRAME_COUNT = 8
SHEET = CELL * FRAME_COUNT


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def fit_pose(source: Image.Image, scale: float = 1.0, rotation: float = 0.0, y: int = 0) -> Image.Image:
    """Fit a transparent pose into one square sprite cell."""
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        source = source.crop(bbox)

    available = int(CELL * 0.90)
    ratio = min(available / source.width, available / source.height) * scale
    size = (
        max(1, int(source.width * ratio)),
        max(1, int(source.height * ratio)),
    )
    pose = source.resize(size, Image.Resampling.LANCZOS)
    if rotation:
        pose = pose.rotate(rotation, Image.Resampling.BICUBIC, expand=True)

    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x = (CELL - pose.width) // 2
    y_position = (CELL - pose.height) // 2 + y
    frame.alpha_composite(pose, (x, y_position))
    return frame


def write_sheet(
    destination: Path,
    frames: list[tuple[Image.Image, float, float, int]],
) -> None:
    sheet = Image.new("RGBA", (SHEET, CELL), (0, 0, 0, 0))
    for index, (source, scale, rotation, y) in enumerate(frames):
        sheet.alpha_composite(fit_pose(source, scale, rotation, y), (index * CELL, 0))
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, "PNG", optimize=True)


def load_motion_frames(
    source_dir: Path,
    name: str,
    fallback: Image.Image,
    fallback_motion: list[tuple[float, float, int]],
) -> list[tuple[Image.Image, float, float, int]]:
    frame_dir = source_dir / "Frames" / name
    paths = sorted(frame_dir.glob("frame-*.png"))
    if len(paths) == FRAME_COUNT:
        return [(load(path), 1.0, 0.0, 0) for path in paths]
    return [(fallback, scale, rotation, y) for scale, rotation, y in fallback_motion]


def write_static(destination: Path, source: Image.Image, size: tuple[int, int]) -> None:
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        source = source.crop(bbox)
    ratio = min((size[0] * 0.90) / source.width, (size[1] * 0.90) / source.height)
    frame = source.resize(
        (max(1, int(source.width * ratio)), max(1, int(source.height * ratio))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(frame, ((size[0] - frame.width) // 2, (size[1] - frame.height) // 2))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", optimize=True)


def write_icon(destination: Path, source: Image.Image) -> None:
    canvas = Image.new("RGBA", (1024, 1024), (255, 107, 95, 255))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((92, 92, 932, 932), fill=(255, 240, 199, 255))
    pose = fit_pose(source, 1.05)
    pose.thumbnail((840, 840), Image.Resampling.LANCZOS)
    canvas.alpha_composite(pose, ((1024 - pose.width) // 2, (1024 - pose.height) // 2 + 20))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    output = args.output
    project_root = output.resolve().parents[1]
    source_dir = args.source_dir
    master = load(source_dir / "reference.png")
    launch = load(source_dir / "launch-greeting.png")
    launch_loading = load(source_dir / "launch-loading.png")
    wave = load(source_dir / "welcome-wave.png")
    listening = load(source_dir / "listening.png")
    curious = load(source_dir / "curious.png")
    speaking = load(source_dir / "speaking.png")
    correct = load(source_dir / "correct.png")
    mistake = load(source_dir / "mistake.png")
    streak = load(source_dir / "streak.png")

    assets = output / "Kumusta/Resources/Assets.xcassets"
    static_dir = assets / "TukoBuddy.imageset"
    write_static(static_dir / "be-trau-buddy@3x.png", master, (1024, 1150))
    write_static(static_dir / "be-trau-buddy@2x.png", master, (342, 384))
    write_static(static_dir / "be-trau-buddy@1x.png", master, (171, 192))

    write_static(assets / "BuddyRoadmapCafe.imageset/buddy-roadmap-cafe@3x.png", speaking, (374, 420))
    write_static(assets / "BuddyRoadmapCafe.imageset/buddy-roadmap-cafe@2x.png", speaking, (249, 280))
    write_static(assets / "BuddyRoadmapCafe.imageset/buddy-roadmap-cafe.png", speaking, (124, 140))
    write_static(assets / "BuddyRoadmapTraveler.imageset/buddy-roadmap-traveler@3x.png", launch, (374, 420))
    write_static(assets / "BuddyRoadmapTraveler.imageset/buddy-roadmap-traveler@2x.png", launch, (249, 280))
    write_static(assets / "BuddyRoadmapTraveler.imageset/buddy-roadmap-traveler.png", launch, (124, 140))

    fallback_motion = [
        (0.96, -1.0, 8),
        (0.98, -0.5, 4),
        (1.0, 0.0, 0),
        (1.02, 0.5, -4),
        (1.0, 1.0, -6),
        (0.98, 0.5, -2),
        (0.97, 0.0, 3),
        (0.96, -0.5, 7),
    ]
    # The loading screen renders the mascot large enough that even small
    # redraw differences are visible. Repeat one canonical pose in every cell;
    # BuddyMotionView supplies the smooth movement without changing its scale.
    launch_frames = [(launch_loading, 1.0, 0.0, 0) for _ in range(FRAME_COUNT)]
    wave_frames = load_motion_frames(source_dir, "welcome-wave", wave, fallback_motion)
    # Listening and curious are shown at compact sizes beside instructional
    # copy. Keep one canonical drawing in every cell so body bounds, scale, and
    # scarf layering cannot jump between independently generated poses. Their
    # breathing movement is applied continuously by BuddyMotionView.
    listening_frames = [(listening, 1.0, 0.0, 0) for _ in range(FRAME_COUNT)]
    curious_frames = [(curious, 1.0, 0.0, 0) for _ in range(FRAME_COUNT)]
    generation_frames = load_motion_frames(source_dir, "speaking", speaking, fallback_motion)
    correct_frames = load_motion_frames(source_dir, "correct", correct, fallback_motion)
    mistake_frames = load_motion_frames(source_dir, "mistake", mistake, fallback_motion)
    streak_frames = load_motion_frames(source_dir, "streak", streak, fallback_motion)

    write_sheet(assets / "MascotLaunchSprite.imageset/mascot-launch-sprite@3x.png", launch_frames)
    write_sheet(assets / "MascotWelcomeWaveSprite.imageset/mascot-welcome-wave-sprite@3x.png", wave_frames)
    write_sheet(assets / "MascotListeningSprite.imageset/mascot-listening-sprite@3x.png", listening_frames)
    write_sheet(assets / "MascotCuriousSprite.imageset/mascot-curious-sprite@3x.png", curious_frames)
    write_sheet(assets / "MascotGenerationSprite.imageset/mascot-generation-sprite@3x.png", generation_frames)
    write_sheet(assets / "MascotCorrectSprite.imageset/mascot-correct-sprite@3x.png", correct_frames)
    write_sheet(assets / "MascotMistakeSprite.imageset/mascot-mistake-sprite@3x.png", mistake_frames)
    write_sheet(assets / "MascotStreakSprite.imageset/mascot-streak-sprite@3x.png", streak_frames)

    write_icon(assets / "AppIcon.appiconset/AppIcon.png", master)
    write_static(project_root / "website/public/be-trau-buddy.png", master, (1024, 1150))


if __name__ == "__main__":
    main()
