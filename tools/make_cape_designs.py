"""Paints the cape back "Sbinortz" for the cape wardrobe (scripts/cape_designs.gd):
the name in golden letters with a bejewelled golden crown below it.

Run:  python3 tools/make_cape_designs.py /path/to/CinzelDecorative-Black.ttf
(PIL needs a .ttf; convert the game's woff2 with fontTools first.)
Writes assets/logo/cape_sbinortz.png, 480 x 512 like the devilbane logo.
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H, S = 480, 512, 3  # drawn S times larger, then shrunk for smooth edges
GOLD_TOP, GOLD_MID, GOLD_LOW = (255, 236, 150), (236, 180, 52), (150, 96, 20)
DARK = (50, 28, 6)


def gold_fill(size, top=0, bottom=None):
    """A vertical gold gradient with a bright band at the top third."""
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        if t < 0.4:
            k = t / 0.4
            c = tuple(int(GOLD_TOP[i] + (GOLD_MID[i] - GOLD_TOP[i]) * k) for i in range(3))
        else:
            k = (t - 0.4) / 0.6
            c = tuple(int(GOLD_MID[i] + (GOLD_LOW[i] - GOLD_MID[i]) * k) for i in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    return img


def main(font_path):
    big = (W * S, H * S)
    mask = Image.new("L", big, 0)  # where gold goes
    d = ImageDraw.Draw(mask)
    font = ImageFont.truetype(font_path, 92 * S)
    text = "Sbinortz"
    # Shrink the font until the name fits the cape with a margin.
    size = 92
    while d.textlength(text, font=font) > (W - 40) * S:
        size -= 2
        font = ImageFont.truetype(font_path, size * S)
    tw = d.textlength(text, font=font)
    d.text(((W * S - tw) / 2, 70 * S), text, font=font, fill=255)

    # The crown: a band, five points with balls on their tips.
    cx, base, top = W * S // 2, 440 * S, 250 * S
    half = 150 * S
    band_h = 46 * S
    pts = [(cx - half, base), (cx - half, top + 70 * S), (cx - half * 0.55, top + 120 * S),
           (cx - half * 0.5, top + 30 * S), (cx - half * 0.2, top + 100 * S), (cx, top),
           (cx + half * 0.2, top + 100 * S), (cx + half * 0.5, top + 30 * S),
           (cx + half * 0.55, top + 120 * S), (cx + half, top + 70 * S), (cx + half, base)]
    d.polygon(pts, fill=255)
    for px, py in [pts[1], pts[3], pts[5], pts[7], pts[9]]:
        r = 15 * S
        d.ellipse((px - r, py - r - 4 * S, px + r, py + r - 4 * S), fill=255)
    gold = gold_fill(big)
    out = Image.new("RGBA", big, (0, 0, 0, 0))
    # Dark outline round everything, so it reads on any cape colour.
    edge = mask.filter(ImageFilter.MaxFilter(9 * 2 + 1))
    dark = Image.new("RGBA", big, DARK + (255,))
    out.paste(dark, (0, 0), edge)
    out.paste(gold, (0, 0), mask)
    d = ImageDraw.Draw(out)
    # The crown's band: a darker gold strip, rim lines and the jewels.
    d.rectangle((cx - half, base - band_h, cx + half, base), fill=GOLD_MID + (255,))
    d.rectangle((cx - half, base - band_h, cx + half, base - band_h + 6 * S), fill=GOLD_TOP + (255,))
    d.rectangle((cx - half, base - 6 * S, cx + half, base), fill=GOLD_LOW + (255,))
    d.line((cx - half, base - band_h, cx + half, base - band_h), fill=DARK + (255,), width=3 * S)
    d.line((cx - half, base, cx + half, base), fill=DARK + (255,), width=3 * S)
    jewels = [((cx - half * 0.66, base - band_h / 2), (214, 32, 52)), ((cx - half * 0.33, base - band_h / 2), (40, 190, 90)),
              ((cx, base - band_h / 2), (60, 120, 240)), ((cx + half * 0.33, base - band_h / 2), (40, 190, 90)),
              ((cx + half * 0.66, base - band_h / 2), (214, 32, 52))]
    for (jx, jy), col in jewels:
        r = 13 * S
        d.ellipse((jx - r - 3 * S, jy - r - 3 * S, jx + r + 3 * S, jy + r + 3 * S), fill=DARK + (255,))
        d.ellipse((jx - r, jy - r, jx + r, jy + r), fill=col + (255,))
        d.ellipse((jx - r * 0.55, jy - r * 0.6, jx - r * 0.05, jy - r * 0.1), fill=(255, 255, 255, 190))
    # Gems on the tips and a big one in the middle point.
    tips = [(pts[1], (214, 32, 52)), (pts[3], (60, 120, 240)), (pts[5], (40, 190, 90)), (pts[7], (60, 120, 240)), (pts[9], (214, 32, 52))]
    for (tx, ty), col in tips:
        r = 9 * S
        ty = ty - 4 * S
        d.ellipse((tx - r, ty - r, tx + r, ty + r), fill=col + (255,))
        d.ellipse((tx - r * 0.5, ty - r * 0.6, tx, ty - r * 0.1), fill=(255, 255, 255, 200))
    # A big diamond on the crown's front.
    gx, gy, gr = cx, top + 105 * S, 24 * S
    d.polygon([(gx, gy - gr), (gx + gr, gy), (gx, gy + gr * 1.2), (gx - gr, gy)], fill=DARK + (255,))
    k = 0.78
    d.polygon([(gx, gy - gr * k), (gx + gr * k, gy), (gx, gy + gr * 1.2 * k), (gx - gr * k, gy)], fill=(235, 70, 80, 255))
    d.polygon([(gx, gy - gr * k), (gx - gr * k, gy), (gx, gy)], fill=(255, 150, 150, 255))
    img = out.resize((W, H), Image.LANCZOS)
    img.save("assets/logo/cape_sbinortz.png")


if __name__ == "__main__":
    main(sys.argv[1])
