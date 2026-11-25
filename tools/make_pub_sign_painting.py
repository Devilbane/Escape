"""Paints the face of the Apples & Ivy! pub sign (see scripts/pub_sign.gd).

Two pictures in assets/signs/:

- pub_sign.jpg: the colour. An old board of horizontal planks with grain and knots, painted dark
  green, the paint worn through to the wood at the edges and in chips; a cream double border with
  corner flourishes; a round medallion with two red apples and a green one on their leafy twig,
  ivy trailing round them and along the border; and the name in classic pub lettering (the repo's
  Cinzel Bold), gilded and cream, with a dark outline and a drop shadow;
- pub_sign_n.png: the normal map, at half the size: the letters, the apples, the leaves and the
  border stand up out of the board, the planks' joints and the grain are cut in.

The picture covers the board exactly (PubSign.WIDE across, PubSign.TALL down). It is drawn twice the
size and shrunk, for clean edges. The name is part of the picture and the same in every language.
Needs numpy, Pillow and fontTools with brotli (to read the woff2 font). Run: python3 tools/make_pub_sign_painting.py"""
import math
import os
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
DIR = os.path.join(HERE, "..", "assets", "signs")
FONT = os.path.join(HERE, "..", "assets", "fonts", "Cinzel-Bold.woff2")
NAME = "Apples & Ivy!"

# The board in metres (PubSign.WIDE, TALL) and the picture's size in pixels.
WIDE, TALL = 1.3, 0.95
W = 1040
H = int(round(W * TALL / WIDE))
S = 2
SW, SH = W * S, H * S
# Lengths below are in "board units": fractions of the board's width.
UNIT = SW

GREEN = (0.09, 0.27, 0.16)
CREAM = (0.93, 0.87, 0.68)
GOLD = (0.95, 0.74, 0.28)
GOLD_DARK = (0.62, 0.42, 0.12)
LIGHT = np.array([-0.55, -0.7], np.float32)
LIGHT /= np.linalg.norm(LIGHT)


# ---------------------------------------------------------------- helpers

def P(x, y):
    return (x * UNIT, y * UNIT)


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
    return np.asarray(img.filter(ImageFilter.MaxFilter(int(px) * 2 + 1)), np.float32) / 255.0


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


def poly(points):
    pts = [P(*p) for p in points]
    return mask_of(lambda d: d.polygon(pts, fill=255))


def ellipse(cx, cy, rx, ry):
    return mask_of(lambda d: d.ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=255))


def ring(cx, cy, r, thick):
    def draw(d):
        d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=255)
        d.ellipse([P(cx - r + thick, cy - r + thick), P(cx + r - thick, cy + r - thick)], fill=0)
    return mask_of(draw)


def rrect(x0, y0, x1, y1, r):
    return mask_of(lambda d: d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * UNIT, fill=255))


def rframe(x0, y0, x1, y1, r, thick):
    def draw(d):
        d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * UNIT, fill=255)
        d.rounded_rectangle([P(x0 + thick, y0 + thick), P(x1 - thick, y1 - thick)], radius=max(r - thick, 0) * UNIT, fill=0)
    return mask_of(draw)


def stroke(points, width):
    pts = [P(*p) for p in points]

    def draw(d):
        d.line(pts, fill=255, width=max(1, int(width * UNIT)), joint="curve")
        for p in (pts[0], pts[-1]):
            r = width * UNIT * 0.5
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    return mask_of(draw)


def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


# ---------------------------------------------------------------- the board

def board(rng):
    """Old planks running across the sign: colour (h, w, 3), height, the grain and the seams."""
    planks = 5
    x = np.arange(SW, dtype=np.float32)[None, :]
    y = np.arange(SH, dtype=np.float32)[:, None]
    ph = SH / planks
    idx = np.clip((y // ph).astype(int), 0, planks - 1)
    tone = rng.uniform(0.85, 1.1, planks).astype(np.float32)[idx] * np.ones_like(x)
    warp = noise2(SH, SW, rng, 260, 3) * 50.0
    grain = np.sin((y + warp) * 0.12 + np.sin(x * 0.004 + y * 0.01) * 3.0) * 0.5 + 0.5
    fine = noise2(SH, SW, rng, 6, 2)
    streak = grain * 0.6 + fine * 0.4
    base = np.array([0.5, 0.34, 0.2], np.float32)
    col = base[None, None, :] * (0.78 + streak[..., None] * 0.32) * tone[..., None]
    height = streak * 0.15
    for _ in range(4):
        kx, ky = rng.uniform(0.1, 0.9) * SW, rng.uniform(0.15, 0.85) * SH
        r = np.sqrt(((x - kx) * 0.6) ** 2 + (y - ky) ** 2)
        k = np.clip(1.0 - r / rng.uniform(16, 26), 0, 1)
        rings = (np.sin(r * 0.6) * 0.5 + 0.5) * np.clip(1.0 - r / 70.0, 0, 1)
        col *= (1.0 - k[..., None] * 0.55 - rings[..., None] * 0.12)
    joint = np.abs(((y + ph * 0.5) % ph) - ph * 0.5)
    seam = np.clip(1.0 - (ph * 0.5 - joint) / 3.5, 0, 1) * np.ones_like(x)
    col *= (1.0 - seam[..., None] * 0.6)
    height = height - seam * 0.8
    return col, height, streak, seam


class Painter:
    """Paints parts one over the other: each a mask and a colour (or a colour picture), shaded."""

    def __init__(self, col, height, rng):
        self.col = col
        self.height = height
        self.rng = rng
        self.shadow = np.zeros((SH, SW), np.float32)
        self.cover = np.zeros((SH, SW), np.float32)

    def part(self, m, colour, relief=1.0, outline=(0.06, 0.05, 0.04), shine=0.35, rim=3, gloss=0.0, soft=7, shade=0.55, drop=True):
        colour = np.array(colour, np.float32)
        h = blur(m, soft * S)
        gy, gx = np.gradient(h)
        lit = -(gx * LIGHT[0] + gy * LIGHT[1]) * 26.0
        top = np.linspace(1.06, 0.9, SH, dtype=np.float32)[:, None]
        tex = 0.95 + noise2(SH, SW, self.rng, 4, 2) * 0.1
        base = colour[None, None, :] if colour.ndim == 1 else colour
        c = base * (top * tex)[..., None] * (1.0 + np.clip(lit, -0.45, 0.6)[..., None])
        if gloss > 0:
            c = c + (np.clip(lit - 0.25, 0, 1) * gloss)[..., None]
        inner = np.clip(m - np.roll(np.roll(m, 3 * S, 0), 3 * S, 1), 0, 1)
        c = c + inner[..., None] * shine * 0.6
        if drop:
            self.shadow = np.maximum(self.shadow, np.roll(np.roll(blur(m, 5 * S), 7 * S, 0), 5 * S, 1) * shade)
        line = np.clip(grow_mask(m, rim * S) - m, 0, 1) if rim > 0 else np.zeros_like(m)
        out = np.array(outline, np.float32)
        self.col = self.col * (1 - line[..., None]) + out[None, None, :] * line[..., None]
        self.col = self.col * (1 - m[..., None]) + np.clip(c, 0, 1) * m[..., None]
        self.height = np.maximum(self.height, self.height * (1 - m) + (h * relief * 3.0 + 1.2) * m)
        self.cover = np.maximum(self.cover, m)

    def flatten_shadow(self):
        """Lays the cast shadows onto the colour as they stand (called between layers)."""
        shade = self.shadow * (1 - self.cover)
        self.col = self.col * (1 - shade[..., None] * 0.6)
        self.shadow = np.zeros_like(self.shadow)


# ---------------------------------------------------------------- the pictures

def ivy_leaf(cx, cy, size, angle):
    """An ivy leaf's outline: five lobes, a heart-shaped base. The tip points along `angle`
    (0 = up), the stalk end sits at (cx, cy). Also the lobes' tips for the veins."""
    # Unit leaf, y up, base at the origin, tip at (0, 1): (x, y)
    shape = [(0.0, 0.04), (-0.1, -0.06), (-0.26, -0.08), (-0.4, 0.0), (-0.36, 0.12), (-0.5, 0.26),
             (-0.4, 0.36), (-0.3, 0.34), (-0.34, 0.5), (-0.2, 0.62), (-0.1, 0.62), (0.0, 1.0),
             (0.1, 0.62), (0.2, 0.62), (0.34, 0.5), (0.3, 0.34), (0.4, 0.36), (0.5, 0.26), (0.36, 0.12),
             (0.4, 0.0), (0.26, -0.08), (0.1, -0.06)]
    tips = [(0.0, 1.0), (-0.5, 0.26), (0.5, 0.26), (-0.36, 0.0), (0.36, 0.0)]
    ca, sa = math.cos(angle), math.sin(angle)

    def put(p):
        x, y = p[0] * size, p[1] * size
        return (cx + x * ca + y * sa, cy + x * sa - y * ca)
    return [put(p) for p in shape], [put(p) for p in tips], put((0.0, 0.0))


def leaf(p, cx, cy, size, angle, tone=0.0, flip=1.0):
    outline, tips, base = ivy_leaf(cx, cy, size, angle)
    m = poly(outline)
    # Dome shading: lighter towards the middle vein's left side, so each leaf looks curved.
    shift = 0.18 + tone * 0.3
    colour = np.array((0.34 + shift * 0.5, 0.62 + shift * 0.4, 0.2 + shift * 0.15), np.float32)
    p.part(m, colour, relief=0.6, rim=2, outline=(0.04, 0.12, 0.06), gloss=0.12, soft=4)
    veins = np.zeros_like(m)
    for t in tips:
        veins = np.maximum(veins, stroke([base, ((base[0] + t[0]) * 0.5, (base[1] + t[1]) * 0.5), t], size * 0.014))
    veins = veins * m
    p.part(veins, (0.82, 0.88, 0.55), relief=0.4, rim=0, shine=0.0, drop=False, soft=2)
    return outline


def sprig(p, path, size, gap, flip=1.0, seed=0):
    """An ivy twig along `path` (points): a stalk with leaves on alternating sides, big at the
    start, small at the end."""
    stalk = stroke(path, size * 0.05)
    p.part(stalk, (0.28, 0.2, 0.1), relief=0.5, rim=2, soft=3, shade=0.35)
    rng = np.random.default_rng(seed)
    n = len(path)
    side = flip
    placed = 0
    walk = 0.0
    for i in range(1, n):
        a, b = path[i - 1], path[i]
        walk += math.dist(a, b)
        if walk < gap:
            continue
        walk = 0.0
        along = math.atan2(b[0] - a[0], -(b[1] - a[1]))
        t = i / n
        sz = size * (1.0 - 0.45 * t) * rng.uniform(0.9, 1.1)
        leaf(p, b[0], b[1], sz, along + side * rng.uniform(0.7, 1.1), tone=rng.uniform(-0.3, 0.5))
        side = -side
        placed += 1
    # A leaf at the twig's end, pointing on.
    a, b = path[-2], path[-1]
    leaf(p, b[0], b[1], size * 0.55, math.atan2(b[0] - a[0], -(b[1] - a[1])), tone=0.3)


def apple(p, cx, cy, r, base, deep, spec=0.7, turn=0.0, speckle=True):
    """A round apple with a dimple on top, shaded as a ball lit from the upper left."""
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    # The silhouette: a ball a little wider than tall, with a dent on top and a blunt base.
    ang = np.arctan2((yy - cy * UNIT), (xx - cx * UNIT) * 1.0)
    rad = np.hypot(xx - cx * UNIT, (yy - cy * UNIT) * 1.04)
    dent = 1.0 - 0.1 * np.exp(-((ang + math.pi / 2) / 0.32) ** 2)
    foot = 1.0 - 0.05 * np.exp(-((ang - math.pi / 2) / 0.35) ** 2)
    lobes = 1.0 + 0.018 * np.sin(ang * 5 + turn)
    edge = r * UNIT * dent * foot * lobes
    m = np.clip((edge - rad) / 1.6 + 0.5, 0, 1).astype(np.float32)
    # Ball normals for the shading.
    nx = np.clip((xx - cx * UNIT) / edge, -1, 1)
    ny = np.clip((yy - cy * UNIT) / edge, -1, 1)
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    l = np.array([-0.5, -0.6, 0.62], np.float32)
    l /= np.linalg.norm(l)
    diff = np.clip(nx * l[0] + ny * l[1] + nz * l[2], 0, 1)
    base = np.array(base, np.float32)
    deep = np.array(deep, np.float32)
    # Streaks of the deeper colour running from the stalk down, and a shaded underside.
    streak = noise2(SH, SW, np.random.default_rng(int(cx * 1000)), 140, 3)
    streak = np.clip((streak - 0.35) * 2.0, 0, 1)
    mix = np.clip(streak * 0.45 + (1 - nz) * 0.45, 0, 1)[..., None]
    c = (base * (1 - mix) + deep * mix) * (0.38 + 0.85 * diff)[..., None]
    spot = np.clip((diff - 0.82) / 0.18, 0, 1) ** 2 * spec
    c = c + spot[..., None] * np.array([1.0, 0.95, 0.85], np.float32) * 0.55
    # A soft shine patch on the upper left.
    patch = np.exp(-(((xx - (cx - r * 0.38) * UNIT) / (r * UNIT * 0.2)) ** 2 + ((yy - (cy - r * 0.4) * UNIT) / (r * UNIT * 0.13)) ** 2))
    c = c + patch[..., None] * 0.35
    if speckle:
        dots = np.clip((noise2(SH, SW, np.random.default_rng(7 + int(cy * 1000)), 5, 1) - 0.8) * 9, 0, 1) * (nz > 0.3)
        c = c + dots[..., None] * np.array([0.9, 0.8, 0.45], np.float32) * 0.22
    p.part(m, np.clip(c, 0, 1), relief=0.0, rim=3, shine=0.0, outline=(0.12, 0.03, 0.03), shade=0.6, soft=2)
    # The apple stands up out of the board like a ball: its normal map height is a dome.
    p.height = np.maximum(p.height, p.height * (1 - m) + (nz * 6.0 + 1.5) * m)
    # The dimple with the stalk, and the calyx dot at the base.
    dimple = ellipse(cx, cy - r * 0.9, r * 0.2, r * 0.08)
    p.part(dimple, deep * 0.35, relief=0.0, rim=0, shine=0.0, drop=False, soft=3)
    p.part(stroke([(cx, cy - r * 0.86), (cx + r * 0.05, cy - r * 1.16), (cx + r * 0.14, cy - r * 1.3)], r * 0.07), (0.3, 0.2, 0.1), relief=0.5, rim=2, soft=2, shade=0.3)
    p.part(ellipse(cx + r * 0.02, cy + r * 0.88, r * 0.07, r * 0.035), (0.2, 0.12, 0.06), relief=0.0, rim=0, shine=0.0, drop=False, soft=2)


def ornament(p, cx, cy, r):
    """A small gilded rosette for a border corner."""
    p.part(ellipse(cx, cy, r, r), GOLD_DARK, rim=2, soft=3, shade=0.4)
    p.part(ellipse(cx, cy, r * 0.62, r * 0.62), GOLD, rim=1, gloss=0.4, soft=3, drop=False)
    p.part(ellipse(cx - r * 0.12, cy - r * 0.12, r * 0.22, r * 0.22), (1.0, 0.92, 0.6), rim=0, soft=2, drop=False, shine=0.0)


def lettering(p, rng):
    with tempfile.TemporaryDirectory() as tmp:
        from fontTools.ttLib import TTFont
        f = TTFont(FONT)
        f.flavor = None
        ttf = os.path.join(tmp, "font.ttf")
        f.save(ttf)
        size = 100
        want = 0.8 * UNIT
        font = ImageFont.truetype(ttf, size)
        width = font.getlength(NAME)
        font = ImageFont.truetype(ttf, int(size * want / width))
        img = Image.new("L", (SW, SH), 0)
        ImageDraw.Draw(img).text((SW * 0.5, 0.615 * UNIT), NAME, font=font, fill=255, anchor="mm")
    m = np.asarray(img, np.float32) / 255.0
    yy = np.linspace(0, 1, SH, dtype=np.float32)[:, None]
    # Gilded letters: gold at the foot, cream on the head, with a band of shine between.
    t = np.clip((yy - 0.55) / 0.2, 0, 1)
    gilt = np.array(CREAM, np.float32)[None, None, :] * (1 - t[..., None]) + np.array(GOLD, np.float32)[None, None, :] * t[..., None]
    gilt = gilt * np.ones((1, SW, 1), np.float32)
    # A dark band behind the name, so the letters read from far away.
    back = blur(grow_mask(m, 9 * S), 9 * S)
    p.col = p.col * (1 - back[..., None] * 0.45)
    p.part(m, gilt, relief=1.1, rim=5, outline=(0.07, 0.05, 0.02), shine=0.5, gloss=0.35, soft=5, shade=0.8)


def paint(seed=4711):
    rng = np.random.default_rng(seed)
    wood, height, grain, seam = board(rng)
    inside = rrect(0.0, 0.0, 1.0, TALL / WIDE, 0.035)
    # The green paint: brush marks along the grain, worn at the edges and in chips.
    brush = noise2(SH, SW, rng, 14, 3)
    streaks = np.asarray(Image.fromarray((noise2(SH // 8, SW, rng, 3, 2) * 255).astype(np.uint8)).resize((SW, SH), Image.BILINEAR), np.float32) / 255.0
    paint_col = np.array(GREEN, np.float32)[None, None, :] * (0.86 + brush[..., None] * 0.2 + streaks[..., None] * 0.1)
    inner_px = np.asarray(Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(21)), np.float32) / 255.0
    edge = 1.0 - blur(inner_px, 24)
    chips = noise2(SH, SW, rng, 44, 4)
    worn = np.clip((chips * 0.9 + edge * 0.9 - 0.68) * 5.0, 0, 1)
    flecks = np.clip((noise2(SH, SW, rng, 5, 2) - 0.76) * 8.0, 0, 1) * 0.7
    worn = np.clip(np.maximum(worn, flecks), 0, 1)
    paint_col = paint_col * (0.8 + grain[..., None] * 0.28) * (1 - seam[..., None] * 0.5)
    col = paint_col * (1 - worn[..., None]) + wood * worn[..., None]
    height = height + (1 - worn) * 0.25
    p = Painter(col, height, rng)

    # The double border in cream: a wide band and a fine line inside it, corners rounded.
    p.part(rframe(0.03, 0.03, 0.97, TALL / WIDE - 0.03, 0.025, 0.014), CREAM, relief=0.5, rim=2, soft=2, shade=0.3, shine=0.2)
    p.part(rframe(0.052, 0.052, 0.948, TALL / WIDE - 0.052, 0.018, 0.006), GOLD, relief=0.4, rim=1, soft=2, shade=0.2, shine=0.2, gloss=0.3)
    for x in (0.03, 0.97):
        for y in (0.03, TALL / WIDE - 0.03):
            ornament(p, x, y, 0.017)
    p.flatten_shadow()

    # The medallion: a ring of gilt round a darker field, the apples and the ivy in it.
    mx, my, mr = 0.5, 0.275, 0.205
    p.part(ellipse(mx, my, mr, mr), (0.05, 0.17, 0.1), relief=-0.5, rim=3, outline=(0.04, 0.03, 0.02), soft=6, shade=0.5, shine=0.0)
    p.part(ring(mx, my, mr, 0.014), GOLD, relief=0.8, rim=3, gloss=0.4, soft=3, shade=0.5)
    p.part(ring(mx, my, mr - 0.02, 0.006), CREAM, relief=0.4, rim=1, soft=2, shade=0.1, drop=False)
    p.flatten_shadow()

    # Ivy first: long twigs from the medallion's foot out to both sides, and tendrils up the corners.
    sprig(p, bezier((0.5, 0.455), (0.38, 0.5), (0.22, 0.46), (0.11, 0.37), 60), 0.095, 0.075, flip=1.0, seed=1)
    sprig(p, bezier((0.5, 0.455), (0.62, 0.5), (0.78, 0.46), (0.89, 0.37), 60), 0.095, 0.075, flip=-1.0, seed=2)
    sprig(p, bezier((0.12, 0.2), (0.18, 0.1), (0.26, 0.09), (0.3, 0.13), 40), 0.07, 0.07, flip=1.0, seed=3)
    sprig(p, bezier((0.88, 0.2), (0.82, 0.1), (0.74, 0.09), (0.7, 0.13), 40), 0.07, 0.07, flip=-1.0, seed=4)
    p.flatten_shadow()

    # Apples: two red ones side by side, a green one in front, leaves from their twig.
    leaf(p, 0.5, 0.2, 0.1, -0.5, tone=0.2)
    leaf(p, 0.5, 0.2, 0.1, 0.5, tone=0.5)
    apple(p, 0.425, 0.285, 0.088, (0.8, 0.12, 0.1), (0.5, 0.04, 0.06), turn=0.4)
    apple(p, 0.585, 0.275, 0.082, (0.9, 0.3, 0.12), (0.62, 0.08, 0.07), turn=1.7)
    apple(p, 0.505, 0.345, 0.079, (0.72, 0.8, 0.22), (0.35, 0.55, 0.12), turn=2.6)
    p.flatten_shadow()
    leaf(p, 0.5, 0.215, 0.115, 0.0, tone=0.1)
    leaf(p, 0.39, 0.4, 0.075, -1.9, tone=0.4)
    leaf(p, 0.62, 0.4, 0.075, 1.9, tone=0.0)
    p.flatten_shadow()

    lettering(p, rng)
    p.flatten_shadow()

    # Wear over the marks too (lighter), dirt in the corners and along the border, a warm varnish.
    mark_worn = np.clip(worn * 0.55 - 0.1, 0, 1) * p.cover
    p.col = p.col * (1 - mark_worn[..., None]) + wood * mark_worn[..., None]
    edge = 1.0 - blur(inner_px, 30)
    grime = noise2(SH, SW, rng, 30, 3)
    p.col = p.col * (1 - (edge * 0.4 + grime * 0.1)[..., None])
    p.col = p.col * np.array([1.0, 0.97, 0.9], np.float32)
    p.col = p.col * inside[..., None] + np.array([0.2, 0.15, 0.1], np.float32) * (1 - inside[..., None])
    colour = Image.fromarray((np.clip(p.col, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    colour.save(os.path.join(DIR, "pub_sign.jpg"), quality=90)
    hgt = np.asarray(Image.fromarray(np.clip(p.height * 40 + 60, 0, 255).astype(np.uint8)).resize((W // 2, H // 2), Image.LANCZOS), np.float32) / 255.0
    gy, gx = np.gradient(hgt)
    strength = 3.5
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(hgt)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / n, ny / n, nz / n], -1) * 0.5 + 0.5
    Image.fromarray((nrm * 255).astype(np.uint8)).save(os.path.join(DIR, "pub_sign_n.png"), optimize=True)
    print("painted pub sign", W, H)


if __name__ == "__main__":
    os.makedirs(DIR, exist_ok=True)
    paint()
