"""Paints the faces of the village's hanging shop shields (see scripts/hanging_shield.gd).

For every mark a shield can carry, two pictures in assets/signs/:

- shield_<mark>.jpg: the colour. Old boards of wood with their grain and knots, painted over
  in the field's colour, the paint worn through to the wood at the edges and in chips; a painted
  trim band inside the rim; and the mark itself painted with care: each part shaded from a light
  above-left, a dark outline, a highlight on its upper edges and a soft shadow on the field;
- shield_<mark>_n.png: the normal map, at half the size. The mark is carved up out of the board, the trim band a
  little raised, the planks' joints and grain cut in, so light runs over it in the game.

The picture covers the shield's outline exactly as HangingShield.outline() draws it (its top
middle at the top middle of the picture, WIDE across, TALL down to the point), so the mesh can map
it straight on.

Each picture is drawn twice the size and shrunk, for clean edges. Needs numpy and Pillow.
Run: python3 tools/make_shield_paintings.py [mark ...]"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "signs")
# The shield in metres (HangingShield.WIDE, TALL) and the picture's size in pixels.
WIDE, TALL = 1.1, 1.32
W = 448
H = int(round(W * TALL / WIDE))
S = 2
SW, SH = W * S, H * S

# field colour, trim colour for every mark (the fields match HangingShield.LOOKS).
FIELDS = {
    "mug": ((0.2, 0.42, 0.24), (0.92, 0.8, 0.45)),
    "scale": ((0.18, 0.32, 0.6), (0.93, 0.82, 0.5)),
    "horn": ((0.85, 0.66, 0.16), (0.16, 0.12, 0.1)),
    "crown": ((0.15, 0.22, 0.52), (0.93, 0.8, 0.42)),
    "swords": ((0.62, 0.14, 0.12), (0.93, 0.85, 0.6)),
    "coins": ((0.12, 0.36, 0.3), (0.93, 0.8, 0.42)),
    "anvil": ((0.72, 0.32, 0.12), (0.2, 0.16, 0.13)),
    "scissors": ((0.75, 0.18, 0.18), (0.95, 0.92, 0.85)),
    "stone": ((0.36, 0.42, 0.5), (0.9, 0.86, 0.75)),
    "axe": ((0.3, 0.45, 0.2), (0.9, 0.8, 0.5)),
    "ring": ((0.38, 0.18, 0.45), (0.93, 0.8, 0.45)),
    "gem": ((0.2, 0.2, 0.32), (0.85, 0.85, 0.9)),
    "flask": ((0.15, 0.38, 0.42), (0.92, 0.85, 0.6)),
    "chest": ((0.5, 0.32, 0.18), (0.93, 0.8, 0.45)),
    "coin": ((0.12, 0.36, 0.3), (0.93, 0.8, 0.42)),
}

LIGHT = np.array([-0.55, -0.7], np.float32)  # from the upper left (x right, y down)
LIGHT /= np.linalg.norm(LIGHT)


# ---------------------------------------------------------------- the outline

def outline_px(grow=0.0):
    """HangingShield.outline(grow) in big-picture pixels."""
    pts = []
    w = WIDE * 0.5 + grow
    top = grow
    shoulder = -TALL * 0.4
    pts += [(-w, top), (w, top), (w, shoulder)]
    steps = 10
    for i in range(1, steps):
        t = i / steps
        x = w * (1.0 - t * t)
        y = shoulder + (-TALL - grow - shoulder) * t
        pts.append((x * math.cos(t * 0.3), y))
    pts.append((0.0, -TALL - grow * 1.4))
    for i in range(steps - 1, 0, -1):
        t = i / steps
        x = w * (1.0 - t * t)
        y = shoulder + (-TALL - grow - shoulder) * t
        pts.append((-x * math.cos(t * 0.3), y))
    pts.append((-w, shoulder))
    return [((x + WIDE * 0.5) / WIDE * SW, -y / TALL * SH) for x, y in pts]


def mask_of(draw_fn):
    img = Image.new("L", (SW, SH), 0)
    draw_fn(ImageDraw.Draw(img))
    return np.asarray(img, np.float32) / 255.0


def blur(a, r):
    if r <= 0:
        return a
    img = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def grow_mask(a, px):
    img = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8))
    size = px * 2 + 1
    return np.asarray(img.filter(ImageFilter.MaxFilter(size)), np.float32) / 255.0


def shrink_mask(a, px):
    img = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8))
    size = px * 2 + 1
    return np.asarray(img.filter(ImageFilter.MinFilter(size)), np.float32) / 255.0


def noise2(h, w, rng, scale, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, int(h / scale * 2 ** o) + 2), max(2, int(w / scale * 2 ** o) + 2)
        g = rng.random((gh, gw)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, np.float32) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


# ---------------------------------------------------------------- the board

def board(rng):
    """Old planks running down the shield: colour (h, w, 3) and height (h, w)."""
    planks = 4
    x = np.arange(SW, dtype=np.float32)[None, :]
    y = np.arange(SH, dtype=np.float32)[:, None]
    pw = SW / planks
    idx = np.clip((x // pw).astype(int), 0, planks - 1)
    tone = rng.uniform(0.85, 1.1, planks).astype(np.float32)[idx]
    warp = noise2(SH, SW, rng, 220, 3) * 40.0
    grain = np.sin((x + warp) * 0.11 + np.sin(y * 0.004 + x * 0.01) * 3.0) * 0.5 + 0.5
    fine = noise2(SH, SW, rng, 6, 2)
    streak = grain * 0.6 + fine * 0.4
    base = np.array([0.5, 0.34, 0.2], np.float32)
    col = base[None, None, :] * (0.78 + streak[..., None] * 0.32) * tone[..., None]
    # Knots: dark rings with the grain bent round them.
    height = streak * 0.15
    for _ in range(3):
        kx, ky = rng.uniform(0.15, 0.85) * SW, rng.uniform(0.15, 0.8) * SH
        r = np.sqrt((x - kx) ** 2 + ((y - ky) * 0.6) ** 2)
        k = np.clip(1.0 - r / rng.uniform(14, 24), 0, 1)
        ring = (np.sin(r * 0.6) * 0.5 + 0.5) * np.clip(1.0 - r / 60.0, 0, 1)
        col *= (1.0 - k[..., None] * 0.55 - ring[..., None] * 0.12)
    # The joints between the planks.
    joint = np.abs(((x + pw * 0.5) % pw) - pw * 0.5)
    seam = np.clip(1.0 - (pw * 0.5 - joint) / 3.0, 0, 1) * np.ones_like(y)
    col *= (1.0 - seam[..., None] * 0.6)
    height = height - seam * 0.8
    return col, height, streak, seam


def paint_layer(field, trim, inside, rng):
    """The paint on the board: field colour with brush marks, a trim band, worn at the edges."""
    brush = noise2(SH, SW, rng, 12, 3)
    streaks = noise2(SH, SW // 8, rng, 3, 2)
    streaks = np.asarray(Image.fromarray((streaks * 255).astype(np.uint8)).resize((SW, SH), Image.BILINEAR), np.float32) / 255.0
    col = np.array(field, np.float32)[None, None, :] * (0.88 + brush[..., None] * 0.16 + streaks[..., None] * 0.08)
    # Trim band: a painted line inside the rim.
    band_out = shrink_mask(inside, 26)
    band_in = shrink_mask(inside, 44)
    band = np.clip(band_out - band_in, 0, 1)
    band = blur(band, 1.2)
    tcol = np.array(trim, np.float32)[None, None, :] * (0.92 + brush[..., None] * 0.12)
    col = col * (1 - band[..., None]) + tcol * band[..., None]
    # Wear: where the paint has gone, near the edges and in chips.
    edge = 1.0 - blur(shrink_mask(inside, 10), 22)
    chips = noise2(SH, SW, rng, 40, 4)
    worn = np.clip((chips * 0.9 + edge * 0.85 - 0.72) * 5.0, 0, 1)
    flecks = np.clip((noise2(SH, SW, rng, 5, 2) - 0.74) * 8.0, 0, 1) * 0.7
    worn = np.clip(np.maximum(worn, flecks), 0, 1)
    return col, band, worn


# ---------------------------------------------------------------- painting parts

class Painter:
    """Paints the parts of a mark one over the other: each a mask and a colour, shaded."""

    def __init__(self, col, height, rng):
        self.col = col
        self.height = height
        self.rng = rng
        self.shadow = np.zeros((SH, SW), np.float32)
        self.cover = np.zeros((SH, SW), np.float32)

    def part(self, m, colour, relief=1.0, outline=(0.08, 0.06, 0.05), shine=0.35, rim=3, gloss=0.0, depth=None):
        colour = np.array(colour, np.float32)
        h = blur(m, 7 * S) if depth is None else depth
        gy, gx = np.gradient(h)
        lit = -(gx * LIGHT[0] + gy * LIGHT[1]) * 26.0
        top = np.linspace(1.08, 0.86, SH, dtype=np.float32)[:, None]
        tex = 0.94 + noise2(SH, SW, self.rng, 4, 2) * 0.1
        c = colour[None, None, :] * (top * tex)[..., None] * (1.0 + np.clip(lit, -0.45, 0.6)[..., None])
        if gloss > 0:
            spot = np.clip(lit - 0.25, 0, 1) * gloss
            c = c + spot[..., None]
        # A highlight along the upper-left edges, inside the part.
        inner = np.clip(m - np.roll(np.roll(m, 3 * S, 0), 3 * S, 1), 0, 1)
        c = c + inner[..., None] * shine * 0.6
        # The shadow it casts on what lies under it.
        self.shadow = np.maximum(self.shadow, np.roll(np.roll(blur(m, 5 * S), 7 * S, 0), 5 * S, 1) * 0.55)
        line = np.clip(grow_mask(m, rim * S) - m, 0, 1) if rim > 0 else np.zeros_like(m)
        out = np.array(outline, np.float32)
        self.col = self.col * (1 - line[..., None]) + out[None, None, :] * line[..., None]
        self.col = self.col * (1 - m[..., None]) + np.clip(c, 0, 1) * m[..., None]
        self.height = np.maximum(self.height, self.height * (1 - m) + (h * relief * 3.0 + 1.2) * m)
        self.cover = np.maximum(self.cover, np.maximum(m, line))


def P(x, y):
    """Mark space to big pixels: x 0..1 across the picture, y 0..1 down the top 0.9 of the shield."""
    return (x * SW, y * SH * 0.88)


def poly(points):
    return mask_of(lambda d: d.polygon([P(*p) for p in points], fill=255))


def ellipse(cx, cy, rx, ry):
    ax, ay = P(cx - rx, cy - ry)
    bx, by = P(cx + rx, cy + ry)
    return mask_of(lambda d: d.ellipse([ax, ay, bx, by], fill=255))


def ring(cx, cy, rx, ry, thick):
    return np.clip(ellipse(cx, cy, rx, ry) - ellipse(cx, cy, rx - thick, ry - thick * ry / rx), 0, 1)


def rect(x0, y0, x1, y1, r=0.0):
    ax, ay = P(x0, y0)
    bx, by = P(x1, y1)
    return mask_of(lambda d: d.rounded_rectangle([ax, ay, bx, by], radius=r * SW, fill=255))


def line(points, width):
    return mask_of(lambda d: d.line([P(*p) for p in points], fill=255, width=int(width * SW), joint="curve"))


def turned(points, cx, cy, angle):
    c, s = math.cos(angle), math.sin(angle)
    k = SH * 0.88 / SW
    out = []
    for x, y in points:
        dx, dy = x - cx, (y - cy) * k
        out.append((cx + dx * c - dy * s, cy + (dx * s + dy * c) / k))
    return out


def cut(a, b):
    return np.clip(a - b, 0, 1)


GOLD = (0.95, 0.74, 0.28)
GOLD_DARK = (0.7, 0.48, 0.16)
STEEL = (0.78, 0.8, 0.84)
IRON = (0.26, 0.26, 0.29)
WOOD = (0.52, 0.32, 0.17)
CREAM = (0.97, 0.94, 0.85)
RED = (0.78, 0.12, 0.1)
BLUE = (0.25, 0.45, 0.92)


# ---------------------------------------------------------------- the marks

def mark_mug(p):
    body = rect(0.3, 0.36, 0.62, 0.8, 0.03)
    p.part(ring(0.67, 0.57, 0.12, 0.13, 0.045), (0.6, 0.4, 0.22), shine=0.25)
    p.part(body, (0.62, 0.42, 0.22), shine=0.3)
    for y in (0.42, 0.6, 0.74):
        p.part(rect(0.29, y, 0.63, y + 0.035), IRON, relief=0.6, gloss=0.3)
    for i in range(4):
        p.part(rect(0.34 + i * 0.075, 0.46, 0.355 + i * 0.075, 0.71), (0.5, 0.32, 0.16), relief=0.3, rim=0, shine=0.1)
    foam = np.zeros((SH, SW), np.float32)
    for cx, cy, r in ((0.33, 0.33, 0.07), (0.42, 0.3, 0.085), (0.52, 0.31, 0.08), (0.6, 0.34, 0.065), (0.38, 0.38, 0.06), (0.56, 0.38, 0.06)):
        foam = np.maximum(foam, ellipse(cx, cy, r, r * 0.9))
    foam = np.maximum(foam, ellipse(0.64, 0.42, 0.035, 0.07))
    p.part(foam, CREAM, shine=0.4)


def mark_scale(p):
    p.part(rect(0.33, 0.84, 0.67, 0.9, 0.02), GOLD_DARK)
    p.part(poly([(0.44, 0.84), (0.56, 0.84), (0.52, 0.76), (0.48, 0.76)]), GOLD)
    p.part(rect(0.48, 0.22, 0.52, 0.8, 0.01), GOLD, gloss=0.3)
    p.part(rect(0.18, 0.26, 0.82, 0.3, 0.01), GOLD, gloss=0.3)
    p.part(ellipse(0.5, 0.2, 0.04, 0.04), GOLD, gloss=0.4)
    for cx in (0.24, 0.76):
        p.part(line([(cx, 0.29), (cx - 0.1, 0.6)], 0.008), GOLD_DARK, relief=0.3, rim=1)
        p.part(line([(cx, 0.29), (cx + 0.1, 0.6)], 0.008), GOLD_DARK, relief=0.3, rim=1)
        pan = cut(ellipse(cx, 0.6, 0.14, 0.1), rect(0, 0, 1, 0.6))
        p.part(pan, GOLD, gloss=0.4)
        p.part(ellipse(cx, 0.6, 0.14, 0.022), GOLD_DARK, relief=0.5)
    for cx, cy in ((0.21, 0.575), (0.26, 0.58), (0.235, 0.56)):
        p.part(ellipse(cx, cy, 0.03, 0.022), GOLD, relief=0.5, gloss=0.4)


def mark_horn(p):
    black = (0.14, 0.11, 0.1)
    p.part(line([(0.5, 0.6), (0.47, 0.75)], 0.018), RED, relief=0.4)
    p.part(line([(0.5, 0.6), (0.55, 0.77)], 0.018), RED, relief=0.4)
    for cx in (0.47, 0.55):
        p.part(poly([(cx - 0.035, 0.84), (cx + 0.035, 0.84), (cx + 0.015, 0.75), (cx - 0.015, 0.75)]), RED, relief=0.6)
    p.part(ring(0.44, 0.43, 0.2, 0.17, 0.06), black, gloss=0.35, shine=0.5)
    p.part(rect(0.24, 0.53, 0.72, 0.58, 0.02), black, gloss=0.35, shine=0.5)
    p.part(poly([(0.7, 0.55), (0.86, 0.43), (0.88, 0.7), (0.7, 0.58)]), black, gloss=0.35, shine=0.5)
    p.part(ellipse(0.87, 0.565, 0.025, 0.14), (0.3, 0.26, 0.22), relief=0.5)
    p.part(rect(0.17, 0.535, 0.25, 0.575, 0.01), GOLD, gloss=0.4)
    p.part(rect(0.44, 0.27, 0.48, 0.32), GOLD, relief=0.5, gloss=0.4)


def mark_crown(p):
    p.part(cut(ellipse(0.5, 0.48, 0.24, 0.2), rect(0, 0.48, 1, 1)), (0.62, 0.1, 0.12))
    points = [(0.2, 0.62), (0.2, 0.36), (0.3, 0.5), (0.38, 0.28), (0.45, 0.48), (0.5, 0.18), (0.55, 0.48), (0.62, 0.28), (0.7, 0.5), (0.8, 0.36), (0.8, 0.62)]
    p.part(poly(points), GOLD, gloss=0.4)
    p.part(rect(0.18, 0.6, 0.82, 0.74, 0.02), GOLD_DARK, gloss=0.4)
    for x, y in ((0.2, 0.34), (0.38, 0.26), (0.5, 0.16), (0.62, 0.26), (0.8, 0.34)):
        p.part(ellipse(x, y, 0.03, 0.03), CREAM, gloss=0.5)
    for i, x in enumerate((0.28, 0.4, 0.5, 0.6, 0.72)):
        colour = RED if i % 2 == 0 else BLUE
        p.part(poly(turned([(x - 0.03, 0.67), (x, 0.635), (x + 0.03, 0.67), (x, 0.705)], x, 0.67, 0.0)), colour, gloss=0.6)
    p.part(ellipse(0.5, 0.11, 0.025, 0.025), GOLD, gloss=0.4)
    p.part(rect(0.493, 0.06, 0.507, 0.16), GOLD, relief=0.5)
    p.part(rect(0.47, 0.095, 0.53, 0.11), GOLD, relief=0.5)


def sword(p, angle):
    cx, cy = 0.5, 0.5
    blade = turned([(0.485, 0.12), (0.5, 0.06), (0.515, 0.12), (0.515, 0.68), (0.485, 0.68)], cx, cy, angle)
    p.part(poly(blade), STEEL, gloss=0.6, shine=0.5)
    p.part(poly(turned([(0.497, 0.12), (0.503, 0.12), (0.503, 0.66), (0.497, 0.66)], cx, cy, angle)), (0.6, 0.62, 0.66), relief=0.2, rim=0)
    p.part(poly(turned([(0.42, 0.68), (0.58, 0.68), (0.58, 0.71), (0.42, 0.71)], cx, cy, angle)), GOLD, gloss=0.4)
    p.part(poly(turned([(0.49, 0.71), (0.51, 0.71), (0.51, 0.82), (0.49, 0.82)], cx, cy, angle)), (0.4, 0.22, 0.12))
    pommel = turned([(0.5, 0.84)], cx, cy, angle)[0]
    p.part(ellipse(pommel[0], pommel[1], 0.028, 0.028), GOLD, gloss=0.4)


def mark_swords(p):
    p.part(ellipse(0.5, 0.47, 0.2, 0.18), (0.55, 0.36, 0.2))
    p.part(ring(0.5, 0.47, 0.2, 0.18, 0.025), IRON, gloss=0.3)
    p.part(ellipse(0.5, 0.47, 0.05, 0.045), STEEL, gloss=0.5)
    sword(p, 0.72)
    sword(p, -0.72)


def mark_coins(p):
    bag = poly([(0.3, 0.86), (0.25, 0.72), (0.28, 0.56), (0.4, 0.44), (0.46, 0.38), (0.58, 0.38), (0.62, 0.44), (0.72, 0.56), (0.75, 0.72), (0.7, 0.86)])
    p.part(bag, (0.62, 0.44, 0.26))
    p.part(poly([(0.42, 0.38), (0.4, 0.26), (0.47, 0.32), (0.5, 0.24), (0.54, 0.32), (0.61, 0.26), (0.59, 0.38)]), (0.62, 0.44, 0.26))
    p.part(rect(0.42, 0.36, 0.6, 0.41, 0.02), RED, relief=0.6)
    p.part(ellipse(0.5, 0.66, 0.11, 0.11), GOLD, gloss=0.5)
    p.part(ring(0.5, 0.66, 0.085, 0.085, 0.015), GOLD_DARK, relief=0.4, rim=1)
    p.part(rect(0.485, 0.6, 0.515, 0.72), GOLD_DARK, relief=0.5, rim=1)
    for i, (x, y) in enumerate(((0.18, 0.86), (0.82, 0.86), (0.82, 0.81), (0.18, 0.81), (0.82, 0.76))):
        p.part(ellipse(x, y, 0.07, 0.025), GOLD if i % 2 == 0 else GOLD_DARK, gloss=0.5)


def mark_anvil(p):
    p.part(poly([(0.28, 0.86), (0.72, 0.86), (0.64, 0.78), (0.36, 0.78)]), IRON)
    p.part(rect(0.4, 0.62, 0.6, 0.8), IRON)
    p.part(poly([(0.12, 0.48), (0.3, 0.46), (0.3, 0.6), (0.24, 0.56)]), IRON, gloss=0.3)
    p.part(rect(0.3, 0.46, 0.86, 0.6, 0.015), IRON, gloss=0.35)
    p.part(rect(0.3, 0.46, 0.86, 0.485), (0.55, 0.56, 0.6), relief=0.3, rim=0, gloss=0.4)
    # The hammer swung over it, and sparks.
    p.part(poly(turned([(0.58, 0.12), (0.62, 0.12), (0.62, 0.42), (0.58, 0.42)], 0.6, 0.27, 0.6)), WOOD)
    p.part(poly(turned([(0.5, 0.08), (0.7, 0.08), (0.7, 0.16), (0.5, 0.16)], 0.6, 0.27, 0.6)), IRON, gloss=0.4)
    for x, y, r in ((0.42, 0.36, 0.018), (0.36, 0.3, 0.012), (0.48, 0.3, 0.014), (0.3, 0.38, 0.01), (0.54, 0.38, 0.01)):
        p.part(ellipse(x, y, r, r), (1.0, 0.85, 0.35), relief=0.3, rim=1, outline=(0.6, 0.25, 0.05))


def mark_scissors(p):
    for a in (0.42, -0.42):
        p.part(poly(turned([(0.49, 0.1), (0.5, 0.08), (0.53, 0.14), (0.52, 0.56), (0.51, 0.69), (0.49, 0.69), (0.48, 0.56)], 0.5, 0.5, a)), STEEL, gloss=0.6)
    for a in (0.42, -0.42):
        cx, cy = turned([(0.5, 0.76)], 0.5, 0.5, a)[0]
        p.part(ring(cx, cy, 0.09, 0.09, 0.03), (0.2, 0.2, 0.22), gloss=0.4)
    p.part(ellipse(0.5, 0.5, 0.025, 0.025), GOLD, gloss=0.5)


def mark_stone(p):
    p.part(poly([(0.2, 0.86), (0.8, 0.86), (0.84, 0.62), (0.7, 0.56), (0.26, 0.58), (0.16, 0.66)]), (0.75, 0.72, 0.66))
    for pts in ([(0.3, 0.7), (0.5, 0.72)], [(0.55, 0.64), (0.72, 0.68)], [(0.36, 0.8), (0.62, 0.78)]):
        p.part(line(pts, 0.006), (0.5, 0.48, 0.45), relief=-0.3, rim=0)
    p.part(poly(turned([(0.47, 0.12), (0.53, 0.12), (0.53, 0.5), (0.47, 0.5)], 0.5, 0.31, -0.5)), WOOD)
    p.part(poly(turned([(0.36, 0.06), (0.64, 0.06), (0.64, 0.16), (0.36, 0.16)], 0.5, 0.31, -0.5)), IRON, gloss=0.4)
    p.part(poly(turned([(0.49, 0.18), (0.51, 0.18), (0.52, 0.5), (0.5, 0.54), (0.48, 0.5)], 0.5, 0.36, 0.55)), STEEL, gloss=0.5)


def mark_axe(p):
    p.part(ellipse(0.5, 0.78, 0.26, 0.08), (0.78, 0.62, 0.4))
    p.part(ring(0.5, 0.78, 0.2, 0.06, 0.02), (0.62, 0.45, 0.25), relief=0.3, rim=0)
    p.part(rect(0.24, 0.78, 0.76, 0.88), (0.45, 0.28, 0.14))
    p.part(poly(turned([(0.48, 0.18), (0.52, 0.18), (0.52, 0.76), (0.48, 0.76)], 0.5, 0.47, 0.35)), WOOD)
    p.part(poly(turned([(0.53, 0.2), (0.68, 0.14), (0.7, 0.36), (0.53, 0.32)], 0.5, 0.47, 0.35)), STEEL, gloss=0.6)


def mark_ring(p):
    p.part(ring(0.5, 0.56, 0.22, 0.22, 0.06), GOLD, gloss=0.5)
    p.part(poly([(0.4, 0.34), (0.5, 0.22), (0.6, 0.34), (0.5, 0.44)]), RED, gloss=0.8, shine=0.6)
    p.part(rect(0.42, 0.33, 0.58, 0.36), GOLD_DARK, relief=0.5)


def mark_gem(p):
    p.part(poly([(0.24, 0.38), (0.36, 0.22), (0.64, 0.22), (0.76, 0.38), (0.5, 0.82)]), BLUE, gloss=0.8)
    p.part(poly([(0.36, 0.22), (0.5, 0.38), (0.64, 0.22)]), (0.6, 0.8, 1.0), relief=0.4, rim=1, gloss=0.6)
    p.part(poly([(0.24, 0.38), (0.5, 0.38), (0.5, 0.82)]), (0.18, 0.32, 0.75), relief=0.4, rim=1)


def mark_flask(p):
    p.part(ellipse(0.5, 0.64, 0.22, 0.2), (0.8, 0.9, 0.85), gloss=0.5)
    p.part(cut(ellipse(0.5, 0.64, 0.2, 0.18), rect(0, 0, 1, 0.58)), (0.3, 0.8, 0.35), gloss=0.5)
    p.part(rect(0.45, 0.22, 0.55, 0.48), (0.8, 0.9, 0.85), gloss=0.4)
    p.part(rect(0.44, 0.14, 0.56, 0.24, 0.02), WOOD)
    for x, y, r in ((0.45, 0.7, 0.02), (0.55, 0.66, 0.015), (0.5, 0.75, 0.012)):
        p.part(ellipse(x, y, r, r), (0.75, 1.0, 0.75), relief=0.3, rim=0)


def mark_chest(p):
    p.part(rect(0.22, 0.52, 0.78, 0.84, 0.02), (0.55, 0.33, 0.16))
    p.part(cut(ellipse(0.5, 0.52, 0.28, 0.16), rect(0, 0.52, 1, 1)), (0.6, 0.37, 0.18))
    for x in (0.3, 0.7):
        p.part(rect(x - 0.03, 0.38, x + 0.03, 0.84), IRON, relief=0.6, gloss=0.3)
    p.part(rect(0.22, 0.5, 0.78, 0.54), IRON, relief=0.6)
    p.part(rect(0.45, 0.54, 0.55, 0.66, 0.01), GOLD, gloss=0.5)


def mark_coin(p):
    p.part(ellipse(0.5, 0.52, 0.24, 0.24), GOLD, gloss=0.5)
    p.part(ring(0.5, 0.52, 0.19, 0.19, 0.02), GOLD_DARK, relief=0.4, rim=1)


MARKS = {
    "mug": mark_mug, "scale": mark_scale, "horn": mark_horn, "crown": mark_crown, "swords": mark_swords,
    "coins": mark_coins, "anvil": mark_anvil, "scissors": mark_scissors, "stone": mark_stone, "axe": mark_axe,
    "ring": mark_ring, "gem": mark_gem, "flask": mark_flask, "chest": mark_chest, "coin": mark_coin,
}


# ---------------------------------------------------------------- one shield

def paint(name, seed):
    rng = np.random.default_rng(seed)
    field, trim = FIELDS[name]
    inside = mask_of(lambda d: d.polygon(outline_px(), fill=255))
    # The shield's edge, kept off the picture's border so the trim band runs all round.
    inside[:3, :] = 0
    inside[:, :3] = 0
    inside[:, -3:] = 0
    wood, height, grain, seam = board(rng)
    paint_col, band, worn = paint_layer(field, trim, inside, rng)
    # Thin paint: the grain and the planks' joints show through it.
    paint_col = paint_col * (0.82 + grain[..., None] * 0.26) * (1 - seam[..., None] * 0.5)
    col = paint_col * (1 - worn[..., None]) + wood * worn[..., None]
    height = height + (1 - worn) * 0.25 + band * 0.4
    p = Painter(col, height, rng)
    MARKS[name](p)
    # The marks' shadow on the field, then wear over the marks too (lighter).
    shade = p.shadow * (1 - p.cover)
    p.col = p.col * (1 - shade[..., None] * 0.6)
    mark_worn = np.clip(worn * 0.6 - 0.1, 0, 1) * p.cover
    p.col = p.col * (1 - mark_worn[..., None]) + wood * mark_worn[..., None]
    # Dirt in the corners and along the rim, and a warm varnish.
    edge = 1.0 - blur(shrink_mask(inside, 6), 30)
    grime = noise2(SH, SW, rng, 30, 3)
    p.col = p.col * (1 - (edge * 0.35 + grime * 0.08)[..., None])
    p.col = p.col * np.array([1.0, 0.97, 0.9], np.float32)
    # Outside the shield: the rim's iron (never seen, the mesh stops at the outline).
    p.col = p.col * inside[..., None] + np.array([0.2, 0.2, 0.22], np.float32) * (1 - inside[..., None])
    colour = Image.fromarray((np.clip(p.col, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    colour.save(os.path.join(DIR, "shield_%s.jpg" % name), quality=90)
    # The normal map from the heights (OpenGL: green up).
    # Half the colour's size is enough for the relief.
    hgt = np.asarray(Image.fromarray(np.clip(p.height * 40 + 60, 0, 255).astype(np.uint8)).resize((W // 2, H // 2), Image.LANCZOS), np.float32) / 255.0
    gy, gx = np.gradient(hgt)
    strength = 3.5
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(hgt)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / n, ny / n, nz / n], -1) * 0.5 + 0.5
    Image.fromarray((nrm * 255).astype(np.uint8)).save(os.path.join(DIR, "shield_%s_n.png" % name), optimize=True)


def main():
    os.makedirs(DIR, exist_ok=True)
    names = sys.argv[1:] or list(MARKS)
    for i, name in enumerate(MARKS):
        if name in names:
            paint(name, 1000 + i)
            print("painted", name)


if __name__ == "__main__":
    main()
