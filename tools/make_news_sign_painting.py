"""Paints the face of the town crier's NEWS! sign (see scripts/news_sign.gd), in the manner of the
Apples & Ivy! pub sign (tools/make_pub_sign_painting.py, whose helpers it uses).

Two pictures in assets/signs/:

- news_sign.jpg: old planks painted deep blue, the paint worn through to the grain at the edges and in
  chips; a cream and gilt double border; the crown's crown in a gilt ring on the left; NEWS! gilded in
  Cinzel Bold with the times of the news, 10 . 16, under it. The gilding is worn and brushed like the paint,
  so the lettering shows the grain through it and sits in the board and not on it;
- news_sign_n.png: the normal map (half size): the letters, the crown and the border stand up a little out
  of the board, the planks' joints and the grain are cut in.

The picture covers the board exactly (NewsSign.WIDE across, NewsSign.TALL down). The text is part of the
picture; the explanation of the sign is in its mouse-over, in the player's language.
Needs numpy, Pillow and fontTools with brotli. Run: python3 tools/make_news_sign_painting.py"""
import os
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import make_pub_sign_painting as pub

WIDE, TALL = 1.7, 0.9
pub.WIDE, pub.TALL = WIDE, TALL
pub.W = 1088
pub.H = int(round(pub.W * TALL / WIDE))
pub.SW, pub.SH = pub.W * pub.S, pub.H * pub.S
pub.UNIT = pub.SW
SW, SH, UNIT, S = pub.SW, pub.SH, pub.UNIT, pub.S
HT = TALL / WIDE

BLUE = (0.1, 0.2, 0.48)
CREAM, GOLD, GOLD_DARK = pub.CREAM, pub.GOLD, pub.GOLD_DARK
DIR = pub.DIR


def text_mask(text, centre, width_frac, max_h_frac=None):
    with tempfile.TemporaryDirectory() as tmp:
        from fontTools.ttLib import TTFont
        f = TTFont(pub.FONT)
        f.flavor = None
        ttf = os.path.join(tmp, "font.ttf")
        f.save(ttf)
        size = 100
        font = ImageFont.truetype(ttf, size)
        font = ImageFont.truetype(ttf, int(size * width_frac * UNIT / font.getlength(text)))
        img = Image.new("L", (SW, SH), 0)
        ImageDraw.Draw(img).text((centre[0] * UNIT, centre[1] * UNIT), text, font=font, fill=255, anchor="mm")
    return np.asarray(img, np.float32) / 255.0


def gilt_letters(p, m, top, bottom):
    yy = np.linspace(0, 1, SH, dtype=np.float32)[:, None]
    t = np.clip((yy - top) / max(bottom - top, 0.01), 0, 1)
    gilt = np.array(CREAM, np.float32)[None, None, :] * (1 - t[..., None]) + np.array(GOLD, np.float32)[None, None, :] * t[..., None]
    gilt = gilt * np.ones((1, SW, 1), np.float32)
    back = pub.blur(pub.grow_mask(m, 7 * S), 8 * S)
    p.col = p.col * (1 - back[..., None] * 0.4)
    p.part(m, gilt, relief=1.0, rim=4, outline=(0.05, 0.08, 0.2), shine=0.3, gloss=0.3, soft=5, shade=0.8)


def crown(p, cx, cy, r):
    """The crown of the crown's insignia: a band with five points, each with a pearl, and a cap."""
    pts = [(-1.0, 0.55), (-1.0, -0.25), (-0.62, 0.15), (-0.5, -0.7), (-0.2, 0.05), (0.0, -0.95), (0.2, 0.05),
           (0.5, -0.7), (0.62, 0.15), (1.0, -0.25), (1.0, 0.55)]
    m = pub.poly([(cx + x * r, cy + y * r) for x, y in pts])
    p.part(m, GOLD, relief=1.0, rim=3, gloss=0.4, soft=4, shade=0.6)
    band = pub.rrect(cx - r, cy + r * 0.32, cx + r, cy + r * 0.62, 0.004)
    p.part(band, GOLD_DARK, relief=0.6, rim=2, gloss=0.3, soft=3, drop=False)
    for x, y in [(-0.5, -0.7), (0.0, -0.95), (0.5, -0.7), (-1.0, -0.25), (1.0, -0.25)]:
        p.part(pub.ellipse(cx + x * r, cy + y * r - r * 0.12, r * 0.12, r * 0.12), (0.97, 0.94, 0.85), relief=1.2, rim=2, gloss=0.6, soft=2, shade=0.4)
    for x in (-0.55, 0.0, 0.55):
        p.part(pub.ellipse(cx + x * r, cy + r * 0.47, r * 0.09, r * 0.09), (0.75, 0.12, 0.14), relief=0.8, rim=2, gloss=0.5, soft=2, drop=False)


def paint(seed=1337):
    rng = np.random.default_rng(seed)
    wood, height, grain, seam = pub.board(rng)
    noise2, blur = pub.noise2, pub.blur
    inside = pub.rrect(0.0, 0.0, 1.0, HT, 0.03)
    brush = noise2(SH, SW, rng, 14, 3)
    streaks = np.asarray(Image.fromarray((noise2(SH // 8, SW, rng, 3, 2) * 255).astype(np.uint8)).resize((SW, SH), Image.BILINEAR), np.float32) / 255.0
    paint_col = np.array(BLUE, np.float32)[None, None, :] * (0.84 + brush[..., None] * 0.22 + streaks[..., None] * 0.12)
    inner_px = np.asarray(Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(21)), np.float32) / 255.0
    edge = 1.0 - blur(inner_px, 24)
    chips = noise2(SH, SW, rng, 44, 4)
    worn = np.clip((chips * 0.9 + edge * 0.9 - 0.68) * 5.0, 0, 1)
    flecks = np.clip((noise2(SH, SW, rng, 5, 2) - 0.76) * 8.0, 0, 1) * 0.7
    worn = np.clip(np.maximum(worn, flecks), 0, 1)
    paint_col = paint_col * (0.78 + grain[..., None] * 0.3) * (1 - seam[..., None] * 0.5)
    col = paint_col * (1 - worn[..., None]) + wood * worn[..., None]
    height = height + (1 - worn) * 0.25
    p = pub.Painter(col, height, rng)

    p.part(pub.rframe(0.022, 0.03, 0.978, HT - 0.03, 0.02, 0.012), CREAM, relief=0.5, rim=2, soft=2, shade=0.3, shine=0.2)
    p.part(pub.rframe(0.042, 0.05, 0.958, HT - 0.05, 0.014, 0.005), GOLD, relief=0.4, rim=1, soft=2, shade=0.2, shine=0.2, gloss=0.3)
    for x in (0.022, 0.978):
        for y in (0.03, HT - 0.03):
            pub.ornament(p, x, y, 0.014)
    p.flatten_shadow()

    mx, my, mr = 0.17, HT * 0.5, 0.125
    p.part(pub.ellipse(mx, my, mr, mr), (0.04, 0.09, 0.26), relief=-0.5, rim=3, outline=(0.03, 0.03, 0.06), soft=6, shade=0.5, shine=0.0)
    p.part(pub.ring(mx, my, mr, 0.012), GOLD, relief=0.8, rim=3, gloss=0.4, soft=3, shade=0.5)
    p.part(pub.ring(mx, my, mr - 0.018, 0.005), CREAM, relief=0.4, rim=1, soft=2, shade=0.1, drop=False)
    p.flatten_shadow()
    crown(p, mx, my - 0.005, 0.07)
    p.flatten_shadow()

    news = text_mask("NEWS!", (0.6, HT * 0.38), 0.58)
    gilt_letters(p, news, HT * 0.38 - 0.1, HT * 0.38 + 0.1)
    p.flatten_shadow()
    for x0, x1 in ((0.36, 0.45), (0.75, 0.84)):
        p.part(pub.rframe(x0, HT * 0.78 - 0.004, x1, HT * 0.78 + 0.004, 0.002, 0.002), GOLD, relief=0.4, rim=1, soft=2, drop=False, gloss=0.3)
    times = text_mask("10 · 16", (0.6, HT * 0.78), 0.2)
    gilt_letters(p, times, HT * 0.7, HT * 0.86)
    p.flatten_shadow()

    # Everything is paint: the grain shows through it, it wears and is dirty like the rest.
    covered = p.cover
    p.col = p.col * (1 - covered[..., None] * 0.3 * (1 - grain[..., None]))
    letters = np.maximum(news, times)
    scuff = np.clip((noise2(SH, SW, rng, 16, 4) - 0.52) * 3.0, 0, 1) * 0.7 * letters
    mark_worn = np.clip(np.clip(worn * 0.6 - 0.08, 0, 1) + scuff, 0, 1) * covered
    p.col = p.col * (1 - mark_worn[..., None]) + wood * mark_worn[..., None]
    edge = 1.0 - blur(inner_px, 30)
    grime = noise2(SH, SW, rng, 30, 3)
    p.col = p.col * (1 - (edge * 0.4 + grime * 0.1)[..., None])
    p.col = p.col * np.array([1.0, 0.97, 0.92], np.float32)
    p.col = p.col * inside[..., None] + np.array([0.2, 0.15, 0.1], np.float32) * (1 - inside[..., None])
    colour = Image.fromarray((np.clip(p.col, 0, 1) * 255).astype(np.uint8)).resize((pub.W, pub.H), Image.LANCZOS)
    colour.save(os.path.join(DIR, "news_sign.jpg"), quality=90)
    hgt = np.asarray(Image.fromarray(np.clip(p.height * 40 + 60, 0, 255).astype(np.uint8)).resize((pub.W // 2, pub.H // 2), Image.LANCZOS), np.float32) / 255.0
    gy, gx = np.gradient(hgt)
    nx, ny, nz = -gx * 3.5, gy * 3.5, np.ones_like(hgt)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / n, ny / n, nz / n], -1) * 0.5 + 0.5
    Image.fromarray((nrm * 255).astype(np.uint8)).save(os.path.join(DIR, "news_sign_n.png"), optimize=True)
    print("painted news sign", pub.W, pub.H)


if __name__ == "__main__":
    paint()
