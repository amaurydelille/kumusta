"""Render Kumusta's App Store screenshots (1320 x 2868, iPhone 6.9").

Run from the repo root:  python3 art/app-store/render_screenshots.py
Inputs: real simulator captures in art/app-store/captures/ and Tuko poses
in art/app-store/mascot/ (frames of the app's sprite sheets).
Output: art/app-store/screenshots-1320x2868/*.png (opaque RGB).
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
OUT = ROOT / "screenshots-1320x2868"
FONT = REPO / "Kumusta/Resources/Fonts/Fredoka-Bold.ttf"

W, H = 1320, 2868

# KumustaColors: island teal, deep teal, mango.
TEAL_TOP = (20, 146, 146)
TEAL_BOTTOM = (8, 86, 89)
DEEP = (4, 52, 56)
MANGO = (255, 184, 48)
WHITE = (255, 255, 255)

SLIDES = [
    ("1-home.png", "Learn Tagalog", "the fun way", "WelcomeWave-3.png", "right", "01-learn-the-fun-way.png"),
    ("2-conversation.png", "Have real", "conversations", "Listening-3.png", "right", "02-real-conversations.png"),
    ("3-lesson.png", "Understand", "every word", "Curious-0.png", "left", "03-understand-every-word.png"),
    ("4-flashcard.png", "Words that", "actually stick", "Correct-3.png", "right", "04-words-that-stick.png"),
    ("5-moods.png", "Talk like", "a local", "Generation-3.png", "left", "05-talk-like-a-local.png"),
]


def gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize((w, h))


def soft_layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def sparkle(draw, cx, cy, r, color):
    # Four-point star with concave sides.
    points = []
    for i in range(16):
        angle = i * math.pi / 8 - math.pi / 2
        radius = r if i % 4 == 0 else (r * 0.22 if i % 2 == 1 else r * 0.38)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    draw.polygon(points, fill=color)


def background(seed, mirror):
    canvas = gradient((W, H), TEAL_TOP, TEAL_BOTTOM).convert("RGBA")
    shapes = soft_layer()
    d = ImageDraw.Draw(shapes)
    # Large soft discs give depth without competing with the phone.
    d.ellipse((W - 520, -380, W + 520, 660), fill=(255, 255, 255, 22))
    d.ellipse((-560, 1500, 520, 2580), fill=(255, 255, 255, 16))
    d.ellipse((W - 300, 1900, W + 420, 2620), fill=(0, 30, 34, 40))
    # A tilted light band, like a sunbeam across the island.
    band = soft_layer()
    ImageDraw.Draw(band).rectangle((-400, 1180, W + 400, 1440), fill=(255, 255, 255, 16))
    band = band.rotate(-14, resample=Image.BICUBIC, center=(W / 2, 1310))
    shapes = Image.alpha_composite(shapes, band)
    if mirror:
        shapes = shapes.transpose(Image.FLIP_LEFT_RIGHT)
    canvas = Image.alpha_composite(canvas, shapes.filter(ImageFilter.GaussianBlur(2)))

    rng = random.Random(seed)
    stars = soft_layer()
    sd = ImageDraw.Draw(stars)
    spots = [(110, 560), (1210, 600), (70, 1250), (1250, 1320), (1240, 2050), (90, 2150)]
    for i, (x, y) in enumerate(spots):
        x = W - x if mirror else x
        r = rng.choice([22, 28, 34])
        color = (*MANGO, 235) if i % 3 == 0 else (255, 255, 255, 215)
        sparkle(sd, x + rng.randint(-20, 20), y + rng.randint(-30, 30), r, color)
    for x, y in [(1180, 470), (160, 1660), (1150, 1640)]:
        x = W - x if mirror else x
        sd.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(*MANGO, 220))
    return Image.alpha_composite(canvas, stars)


def fitted_font(lines, max_width, size):
    while size > 60:
        font = ImageFont.truetype(str(FONT), size)
        widths = [font.getbbox(line)[2] - font.getbbox(line)[0] for line in lines]
        if max(widths) <= max_width:
            return font
        size -= 4
    return ImageFont.truetype(str(FONT), size)


def headline(canvas, first, second):
    font = fitted_font([first, second], W - 150, 138)
    line_height = round(font.size * 1.06)
    top = 150
    shadow = soft_layer()
    text = soft_layer()
    sd, td = ImageDraw.Draw(shadow), ImageDraw.Draw(text)
    for i, (line, color) in enumerate([(first, WHITE), (second, MANGO)]):
        y = top + i * line_height
        sd.text((W / 2, y + 10), line, font=font, fill=(*DEEP, 120), anchor="ma")
        td.text((W / 2, y), line, font=font, fill=color, anchor="ma")
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(10)))
    return Image.alpha_composite(canvas, text)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def phone(canvas, capture_path):
    shot = Image.open(capture_path).convert("RGB")
    screen_w = 1000
    screen_h = round(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 24
    rim = 5
    device_w, device_h = screen_w + 2 * (bezel + rim), screen_h + 2 * (bezel + rim)
    x = (W - device_w) // 2
    y = 556

    shadow = soft_layer()
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 10, y + 46, x + device_w - 10, y + device_h + 40), radius=190, fill=(0, 24, 28, 150)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(46)))

    device = soft_layer()
    dd = ImageDraw.Draw(device)
    # Titanium rim, then the black bezel, then the screen.
    dd.rounded_rectangle((x, y, x + device_w, y + device_h), radius=176, fill=(58, 74, 80, 255))
    dd.rounded_rectangle((x + 2, y + 2, x + device_w - 2, y + device_h - 2), radius=174, outline=(120, 140, 146, 255), width=2)
    dd.rounded_rectangle((x + rim, y + rim, x + device_w - rim, y + device_h - rim), radius=170, fill=(8, 12, 14, 255))
    canvas = Image.alpha_composite(canvas, device)

    screen = Image.new("RGBA", (screen_w, screen_h))
    screen.paste(shot, (0, 0))
    canvas.paste(screen, (x + rim + bezel, y + rim + bezel), rounded_mask((screen_w, screen_h), 146))
    return canvas, (x, y, x + device_w, y + device_h)


def mascot(canvas, pose_path, side, device_box):
    pose = Image.open(pose_path).convert("RGBA")
    bbox = pose.getchannel("A").getbbox()
    pose = pose.crop(bbox)
    height = 500
    pose = pose.resize((round(pose.width * height / pose.height), height), Image.LANCZOS)
    if side == "right":
        pose = pose.transpose(Image.FLIP_LEFT_RIGHT)
    left, top, right, bottom = device_box
    px = left - 205 if side == "left" else right - pose.width + 205
    px = max(24, min(W - pose.width - 24, px))
    py = H - pose.height - 26

    ground = soft_layer()
    gx = px + pose.width / 2
    ImageDraw.Draw(ground).ellipse((gx - 190, H - 78, gx + 190, H - 4), fill=(0, 24, 28, 120))
    canvas = Image.alpha_composite(canvas, ground.filter(ImageFilter.GaussianBlur(22)))

    alpha = pose.getchannel("A")
    halo = Image.new("RGBA", pose.size, (0, 24, 28, 0))
    halo.putalpha(ImageChops.multiply(alpha, Image.new("L", pose.size, 110)))
    layer = soft_layer()
    layer.alpha_composite(halo.filter(ImageFilter.GaussianBlur(18)), (px + 8, py + 20))
    layer.alpha_composite(pose, (px, py))
    return Image.alpha_composite(canvas, layer)


def render(index, capture, first, second, pose, side, out_name):
    canvas = background(seed=index, mirror=side == "right")
    canvas = headline(canvas, first, second)
    canvas, device_box = phone(canvas, ROOT / "captures" / capture)
    canvas = mascot(canvas, ROOT / "mascot" / pose, side, device_box)
    OUT.mkdir(exist_ok=True)
    canvas.convert("RGB").save(OUT / out_name, optimize=True)
    return OUT / out_name


if __name__ == "__main__":
    for i, slide in enumerate(SLIDES):
        print(render(i, *slide))
