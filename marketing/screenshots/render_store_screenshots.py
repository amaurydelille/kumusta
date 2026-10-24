"""Render VietBuddy App Store screenshots in a bright, mascot-led style.

Run from anywhere:
    python3 mobile-app/app-store-screenshots/render_store_screenshots.py

Inputs:  source-assets/1-7.png (real app captures + background art) and the
         Bé Trâu poses in vietbuddy/Artwork/Mascot.
Outputs: store-{english,french}-1320x2868 (6.9") and -1242x2688 (6.5").
         With iPad captures in source-assets/ipad/<n>.png (same numbering),
         also store-{english,french}-ipad-2064x2752 and -ipad-2048x2732 (13").
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "source-assets"
MASCOTS = HERE.parent / "vietbuddy" / "Artwork" / "Mascot"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"

W, H = 1320, 2868
WHITE = (255, 255, 255)
INK = (43, 29, 26)
CORAL = (229, 83, 61)
SUN = (255, 208, 50)

# Each panel: background, source screen, mascot pose/side.
PANELS = [
    dict(bg="art", screen="1.png", mascot="welcome-wave", side="left",
         text=INK, accent=CORAL, buddy_width=640, buddy_lift=330),
    dict(bg=(218, 37, 29), screen="4.png", mascot="conversation-female", side="left",
         text=WHITE, accent=SUN),
    dict(bg=(184, 28, 36), screen="3.png", mascot="correct", side="right",
         text=WHITE, accent=SUN),
    dict(bg=(232, 76, 52), screen="2.png", mascot="curious", side="left",
         text=WHITE, accent=SUN),
    dict(bg=(150, 24, 30), screen="6.png", mascot="listening", side="right",
         text=WHITE, accent=SUN),
    dict(bg=(240, 90, 60), screen="7.png", mascot="streak", side="left",
         text=WHITE, accent=SUN),
]

# (file name, line 1, line 2, highlighted phrase)
COPY = {
    "english": [
        ("01-learn-the-fun-way", "Learn Vietnamese", "the fun way", "fun way"),
        ("02-real-conversations", "Have real", "conversations", "conversations"),
        ("03-speak-with-confidence", "Speak with", "confidence", "confidence"),
        ("04-understand-every-word", "Understand", "every word", "every word"),
        ("05-words-that-stick", "Words that", "actually stick", "stick"),
        ("06-learn-with-friends", "Learn with", "your friends", "friends"),
    ],
    "french": [
        ("01-en-s-amusant", "Le vietnamien", "en s'amusant", "en s'amusant"),
        ("02-vraies-conversations", "De vraies", "conversations", "conversations"),
        ("03-parlez-avec-assurance", "Parlez avec", "assurance", "assurance"),
        ("04-comprenez-chaque-mot", "Comprenez", "chaque mot", "chaque mot"),
        ("05-des-mots-qui-restent", "Des mots qui", "restent", "restent"),
        ("06-entre-amis", "Apprenez", "entre amis", "entre amis"),
    ],
}


def font(size, weight="Heavy"):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def paste_with_shadow(canvas, layer, pos, blur=40, offset=(0, 24), opacity=110):
    alpha = layer.split()[-1]
    shadow = Image.new("RGBA", layer.size, (20, 12, 10, 0))
    shadow.putalpha(alpha.point(lambda a: a * opacity // 255))
    pad = blur * 3
    padded = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    padded.paste(shadow, (pad, pad))
    padded = padded.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(padded, (pos[0] - pad + offset[0], pos[1] - pad + offset[1]))
    canvas.alpha_composite(layer, pos)


def tablet(screen, width):
    """Screenshot inside a dark iPad body: thin even bezel, soft corners, no notch."""
    bezel = int(width * 0.034)
    inner_w = width - bezel * 2
    inner_h = round(screen.height * inner_w / screen.width)
    body = Image.new("RGBA", (width, inner_h + bezel * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, body.height - 1), int(width * 0.062),
                                           fill=(18, 20, 24, 255), outline=(70, 74, 82, 255), width=5)
    shot = screen.convert("RGBA").resize((inner_w, inner_h), Image.LANCZOS)
    shot.putalpha(rounded_mask(shot.size, int(inner_w * 0.034)))
    body.alpha_composite(shot, (bezel, bezel))
    return body, inner_w / screen.width, bezel


def phone(screen, width):
    """Screenshot inside a dark rounded device body."""
    bezel = int(width * 0.028)
    inner_w = width - bezel * 2
    inner_h = round(screen.height * inner_w / screen.width)
    body = Image.new("RGBA", (width, inner_h + bezel * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, body.height - 1), int(width * 0.15),
                                           fill=(18, 20, 24, 255), outline=(70, 74, 82, 255), width=4)
    shot = screen.convert("RGBA").resize((inner_w, inner_h), Image.LANCZOS)
    shot.putalpha(rounded_mask(shot.size, int(inner_w * 0.125)))
    body.alpha_composite(shot, (bezel, bezel))
    return body, inner_w / screen.width, bezel


def sparkle(draw, cx, cy, r, color):
    k = r * 0.22
    draw.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k),
                  (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)], fill=color)


def decorate(canvas, bg):
    """Soft blobs, confetti and sparkles in tints of the background."""
    layer = Image.new("RGBA", (1320, 2868), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    light = tuple(min(255, c + 45) for c in bg) + (255,)
    dark = tuple(max(0, c - 28) for c in bg) + (255,)
    d.ellipse((-260, 1050, 420, 1730), fill=dark)
    d.ellipse((980, 640, 1560, 1220), fill=light)
    d.ellipse((900, 2250, 1600, 2950), fill=dark)
    for cx, cy, r in [(120, 560, 34), (1210, 470, 24), (90, 2020, 22), (1235, 1600, 40)]:
        sparkle(d, cx, cy, r, (255, 255, 255, 210))
    for cx, cy, r, c in [(215, 700, 14, SUN), (1150, 1420, 12, WHITE), (60, 1330, 11, SUN), (1270, 2080, 15, SUN)]:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c + (230,))
    # Laid out on the 6.9" canvas, then stretched onto any other size.
    canvas.alpha_composite(layer.resize(canvas.size, Image.LANCZOS))


def headline(canvas, line1, line2, highlight, color, accent, size=138, y=190, margin=150):
    d = ImageDraw.Draw(canvas)
    W = canvas.width
    while size > 80:
        f = font(size)
        if max(d.textlength(line1, font=f), d.textlength(line2, font=f)) <= W - margin:
            break
        size -= 4
    f = font(size)
    for line in (line1, line2):
        start = line.find(highlight) if highlight in line else -1
        x = (W - d.textlength(line, font=f)) / 2
        if start < 0:
            d.text((x, y), line, font=f, fill=color)
        else:
            before, hl, after = line[:start], highlight, line[start + len(highlight):]
            d.text((x, y), before, font=f, fill=color)
            x += d.textlength(before, font=f)
            d.text((x, y), hl, font=f, fill=accent)
            x += d.textlength(hl, font=f)
            d.text((x, y), after, font=f, fill=color)
        y += int(size * 1.12)


def trim(img):
    box = img.split()[-1].getbbox()
    return img.crop(box) if box else img


# Canvas layouts. The phone values are the original 6.9" design; the tablet
# keeps the same composition on Apple's wider 13" iPad canvas.
PHONE = dict(size=(1320, 2868), source=SOURCE, frame=phone, device_width=1010, device_top=640,
             headline=dict(size=138, y=190, margin=150), buddy_scale=1.0, buddy_x=-70, lift=1.0)
TABLET = dict(size=(2064, 2752), source=SOURCE / "ipad", frame=tablet, device_width=1420,
              device_top=690, headline=dict(size=196, y=150, margin=320), buddy_scale=1.5, buddy_x=-60, lift=0.55)


def render(panel, copy, layout=PHONE, size=None):
    name, line1, line2, highlight = copy
    W, H = size or layout["size"]
    k = W / layout["size"][0]
    if panel["bg"] == "art":
        art = Image.open(SOURCE / "5.png").convert("RGBA")
        ratio = max(W / art.width, H / art.height)
        art = art.resize((round(art.width * ratio), round(art.height * ratio)), Image.LANCZOS)
        canvas = art.crop(((art.width - W) // 2, 0, (art.width - W) // 2 + W, H))
    else:
        canvas = Image.new("RGBA", (W, H), panel["bg"] + (255,))
        decorate(canvas, panel["bg"])

    hl = layout["headline"]
    headline(canvas, line1, line2, highlight, panel["text"], panel["accent"],
             size=round(hl["size"] * k), y=round(hl["y"] * k), margin=round(hl["margin"] * k))

    screen = Image.open(layout["source"] / panel["screen"])
    device, s, bezel = layout["frame"](screen, round(layout["device_width"] * k))
    px, py = (W - device.width) // 2, round(layout["device_top"] * k)
    paste_with_shadow(canvas, device, (px, py), blur=46, offset=(0, 30), opacity=120)


    buddy = trim(Image.open(MASCOTS / f"{panel['mascot']}.png").convert("RGBA"))
    # Panel 1's screen already shows Bé Trâu bottom-left, so a bigger buddy covers it.
    scale = layout["buddy_scale"] * k
    bw = round(panel.get("buddy_width", 560) * scale)
    buddy = buddy.resize((bw, round(buddy.height * bw / buddy.width)), Image.LANCZOS)
    bx = round(layout["buddy_x"] * k)
    if panel["side"] == "right":
        buddy = buddy.transpose(Image.FLIP_LEFT_RIGHT)
        bx = W - bw - bx
    lift = round(panel.get("buddy_lift", 110) * scale * layout["lift"])
    paste_with_shadow(canvas, buddy, (bx, H - buddy.height - lift), blur=26, offset=(0, 18), opacity=90)
    return name, canvas.convert("RGB")


def main():
    for lang, copies in COPY.items():
        big = HERE / f"store-{lang}-1320x2868"
        small = HERE / f"store-{lang}-1242x2688"
        big.mkdir(exist_ok=True)
        small.mkdir(exist_ok=True)
        for panel, copy in zip(PANELS, copies):
            name, image = render(panel, copy)
            image.save(big / f"{name}.png", optimize=True)
            # 6.5" slot: same art scaled to width, trimmed at the bottom where the phone bleeds off.
            scaled = image.resize((1242, round(H * 1242 / W)), Image.LANCZOS)
            scaled.crop((0, 0, 1242, 2688)).save(small / f"{name}.png", optimize=True)
        print(f"{lang}: {len(copies)} screenshots")

        # iPad panels render only for the screens captured on iPad so far.
        tablet = [(p, c) for p, c in zip(PANELS, copies) if (TABLET["source"] / p["screen"]).exists()]
        for size in [(2064, 2752), (2048, 2732)]:
            folder = HERE / f"store-{lang}-ipad-{size[0]}x{size[1]}"
            folder.mkdir(exist_ok=True)
            for panel, copy in tablet:
                name, image = render(panel, copy, TABLET, size)
                image.save(folder / f"{name}.png", optimize=True)
        print(f"{lang}: {len(tablet)} iPad screenshots")


if __name__ == "__main__":
    main()
