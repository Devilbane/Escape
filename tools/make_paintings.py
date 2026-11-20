"""Paints the pictures that Ilse the furnisher sells for the walls of a built house.

Three oil paintings, each 1040 x 800 px (the canvas of the frame is 1.3 m by
1.0 m, see HouseFurnisher.PAINTING):

- painting_mountains.jpg: snowy peaks at dusk, the sun going down between
  them, a fir wood and a meadow with a stream in front;
- painting_lake.jpg: a still lake under the full moon, the moon's path on
  the water, dark woods on the shore and a hut with a lit window;
- painting_dragon.jpg: a red dragon over the village, the houses and the
  chapel tower on a green hill, smoke rising where it has breathed fire.

Each scene is drawn sharp first (shapes on a canvas twice the size, shrunk),
then painted over with brush strokes that follow the shapes, so it reads as
a painting from close up and as a clear picture from across the room. A
faint canvas weave and a darker, warmer varnish at the rim finish it.

Needs numpy and Pillow. Run: python3 tools/make_paintings.py"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "house")
W, H = 1040, 800
S = 2  # the sharp drawing is made this many times larger, then shrunk
SW, SH = W * S, H * S


# ---------------------------------------------------------------- helpers

def rgb(*c):
    return np.array(c, dtype=np.float32) / 255.0


def vgrad(stops, h=SH, w=SW):
    """A sky: colours from top (0) to bottom (1), given as [(t, colour), ...]."""
    t = np.linspace(0.0, 1.0, h, dtype=np.float32)
    out = np.zeros((h, 3), np.float32)
    for c in range(3):
        out[:, c] = np.interp(t, [s[0] for s in stops], [s[1][c] for s in stops])
    return np.repeat(out[:, None, :], w, axis=1)


def noise1(n, rng, octaves=6, base=6, persistence=0.55):
    """1-D fractal value noise in about [-1, 1], n samples long."""
    x = np.linspace(0.0, 1.0, n)
    out = np.zeros(n)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        k = base * 2 ** o
        pts = rng.uniform(-1, 1, k + 2)
        xs = np.linspace(0, 1, k + 2)
        out += amp * np.interp(x, xs, pts)
        total += amp
        amp *= persistence
    return out / total


def noise2(h, w, rng, scale=64, octaves=4):
    """2-D fractal value noise in about [-1, 1]."""
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cell = max(2, int(scale / 2 ** o))
        small = rng.uniform(-1, 1, (h // cell + 2, w // cell + 2)).astype(np.float32)
        img = Image.fromarray(small).resize((small.shape[1] * cell, small.shape[0] * cell), Image.BICUBIC)
        out += amp * np.asarray(img)[:h, :w]
        total += amp
        amp *= 0.5
    return out / total


def blend(dst, mask, colour):
    """Lays colour (an rgb or an image) over dst where mask (0..1) says."""
    m = mask[..., None]
    dst[:] = dst * (1 - m) + colour * m


def poly_mask(points, blur=1.5):
    img = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in points], fill=255)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, np.float32) / 255.0


def ellipse_mask(boxes, blur=0.0):
    img = Image.new("L", (SW, SH), 0)
    d = ImageDraw.Draw(img)
    for b in boxes:
        d.ellipse(b, fill=255)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, np.float32) / 255.0


def soft_disc(cx, cy, r, falloff):
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return np.clip((r + falloff - d) / falloff, 0, 1)


def glow(cx, cy, r):
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return np.exp(-(d / r) ** 2)


def ridge_mask(ridge):
    """Everything below a skyline (one y per column)."""
    yy = np.arange(SH, dtype=np.float32)[:, None]
    return np.clip(yy - ridge[None, :] + 1.0, 0, 1)


def mountains(img, rng, base, amp, rock, shade, light, haze, haze_amt, snow_y=None, peaks=None, light_from=1):
    """A range: a jagged skyline, rock faces lit on one side, snow above snow_y, hazy with distance."""
    x = np.arange(SW, dtype=np.float32)
    ridge = base - amp * (0.55 + 0.45 * noise1(SW, rng, octaves=7, base=3))
    if peaks:
        for px, ph, pw in peaks:
            d = np.abs(x - px) / pw
            jag = 70 * noise1(SW, rng, 7, 10) * np.clip(d * 2, 0.2, 1) + 30 * np.abs(noise1(SW, rng, 5, 30))
            # Shoulders: the flanks step down in ledges rather than running straight.
            ledges = 40 * np.sin(d * 9.0 + rng.uniform(0, 6)) * np.clip(d, 0, 1)
            ridge = np.minimum(ridge, base - ph + ph * d ** 0.85 + jag + ledges)
    mask = ridge_mask(ridge)
    slope = np.gradient(ridge)
    yy = np.arange(SH, dtype=np.float32)[:, None]
    depth = np.clip(yy - ridge[None, :], 0, None)
    # Rock faces run down from the skyline: the slope there, wandering a little with depth.
    wob = noise2(SH, SW, rng, scale=90) * 60.0
    col = np.clip((x[None, :] + wob * np.clip(depth / 200.0, 0, 1)).astype(np.int32), 0, SW - 1)
    facing = np.tanh(-light_from * slope[col] * 1.6)
    streak = noise2(SH, SW, rng, scale=18, octaves=3)
    lit = np.clip(0.5 + 0.5 * facing + 0.18 * streak, 0, 1)
    colour = shade[None, None, :] * (1 - lit[..., None]) + light[None, None, :] * lit[..., None]
    colour = colour * 0.75 + rock[None, None, :] * 0.25
    if snow_y is not None:
        # Snow lies above the snowline, reaching down the gullies and thin on steep rock.
        line = snow_y + 70 * noise1(SW, rng, 6, 14)[None, :] + 90 * noise2(SH, SW, rng, scale=30, octaves=3)
        snowy = np.clip((line - yy) / 14.0, 0, 1) * np.clip(0.75 + 0.5 * streak, 0, 1)
        snow_col = rgb(205, 205, 228)[None, None, :] * (1 - lit[..., None]) + rgb(255, 236, 222)[None, None, :] * lit[..., None]
        colour = colour * (1 - snowy[..., None]) + snow_col * snowy[..., None]
    # Distance: fade towards the haze, more at the foot.
    fog = np.clip(haze_amt + 0.25 * np.clip(depth / 400.0, 0, 1), 0, 1)
    colour = colour * (1 - fog[..., None]) + haze[None, None, :] * fog[..., None]
    blend(img, mask, colour)
    return ridge


def firs(img, rng, xs, ground, heights, dark, light, lean_light=1):
    """A wood of firs: layered triangles, a lighter edge on the lit side."""
    lay = Image.new("L", (SW, SH), 0)
    rim = Image.new("L", (SW, SH), 0)
    d, dr = ImageDraw.Draw(lay), ImageDraw.Draw(rim)
    for x, h in zip(xs, heights):
        gy = ground(x)
        w = h * rng.uniform(0.22, 0.3)
        tiers = 6
        for t in range(tiers):
            top = gy - h + h * t / tiers * 0.85
            bot = top + h * 0.35
            hw = w * (0.3 + 0.7 * (t + 1) / tiers)
            pts = [(x, top), (x + hw, bot), (x + hw * 0.4, bot - h * 0.03), (x, bot), (x - hw * 0.4, bot - h * 0.03), (x - hw, bot)]
            d.polygon(pts, fill=255)
            side = 1 if lean_light > 0 else -1
            dr.polygon([(x, top), (x + side * hw, bot), (x + side * hw * 0.55, bot)], fill=255)
        d.rectangle([x - w * 0.06, gy - h * 0.1, x + w * 0.06, gy], fill=255)
    m = np.asarray(lay.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    r = np.asarray(rim.filter(ImageFilter.GaussianBlur(2.0)), np.float32) / 255.0 * m
    blend(img, m, dark)
    blend(img, r * 0.55, light)


def clouds(img, rng, n, area, size, lit, dark, alpha=0.9, light_dir=(0, 1), flat=(0.35, 0.6)):
    """Heaped clouds: many soft ovals, lit along one edge."""
    x0, y0, x1, y1 = area
    body = np.zeros((SH, SW), np.float32)
    edge = np.zeros((SH, SW), np.float32)
    for _ in range(n):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        count = rng.integers(5, 10)
        boxes, lit_boxes = [], []
        for _ in range(count):
            rx = size * rng.uniform(0.5, 1.3)
            ry = rx * rng.uniform(*flat)
            ox, oy = rng.normal(0, size * 0.9), rng.normal(0, size * 0.18)
            boxes.append((cx + ox - rx, cy + oy - ry, cx + ox + rx, cy + oy + ry))
            sx, sy = light_dir[0] * ry * 0.35, light_dir[1] * ry * 0.35
            lit_boxes.append((cx + ox - rx * 0.9 + sx, cy + oy - ry * 0.8 + sy, cx + ox + rx * 0.9 + sx, cy + oy + ry * 0.8 + sy))
        b = ellipse_mask(boxes, blur=size * 0.12)
        inner = ellipse_mask([(bx0 - light_dir[0] * size * 0.12, by0 - light_dir[1] * size * 0.12,
                               bx1 - light_dir[0] * size * 0.12, by1 - light_dir[1] * size * 0.12) for bx0, by0, bx1, by1 in boxes], blur=size * 0.2)
        body = np.maximum(body, b)
        edge = np.maximum(edge, np.clip(b - inner, 0, 1))
    grain = 0.85 + 0.15 * noise2(SH, SW, rng, scale=40)
    blend(img, body * alpha * grain, dark * 0.55 + lit * 0.45)
    shadow = np.clip(body - edge * 3, 0, 1) * np.clip(noise2(SH, SW, rng, scale=size * 0.5, octaves=2) + 0.3, 0, 1)
    blend(img, shadow * alpha * 0.7, dark)
    blend(img, np.clip(edge * 2.2, 0, 1) * alpha, lit)


def reflect(img, top, bottom, darken, tint, rng, ripple=4.0, blur=3):
    """Mirrors the picture above the waterline into the water, broken by ripples."""
    h = bottom - top
    src = img[max(0, top - h):top][::-1].copy()
    if src.shape[0] < h:
        src = np.concatenate([src, np.repeat(src[-1:], h - src.shape[0], 0)], 0)
    out = np.empty_like(src)
    for y in range(h):
        shift = int(ripple * (1 + y / 60.0) * math.sin(y * 0.9 + rng.uniform(0, 0.4)) + rng.normal(0, 0.6 + y / 300.0))
        out[y] = np.roll(src[y], shift, axis=0)
    pil = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    out = np.asarray(pil, np.float32) / 255.0
    out = out * (1 - darken) + tint * darken
    img[top:bottom] = out


def house(d, md, x, ground, w, h, roof_h, wall, roof, window, door=True, chimney=False, flip=False):
    """A cottage seen from the front-side: whitewashed wall, steep red roof, a lit window."""
    gy = ground
    d.append(("rect", [x, gy - h, x + w, gy], wall))
    d.append(("rect", [x + w, gy - h * 0.92, x + w * 1.45, gy], tuple(int(c * 0.72) for c in wall)))
    d.append(("poly", [(x - w * 0.08, gy - h), (x + w * 0.5, gy - h - roof_h), (x + w * 1.08, gy - h)], tuple(int(c * 1.08) for c in roof)))
    d.append(("poly", [(x + w * 0.5, gy - h - roof_h), (x + w * 1.5, gy - h - roof_h * 0.9), (x + w * 1.5, gy - h * 0.92), (x + w * 1.08, gy - h)], roof))
    if chimney:
        d.append(("rect", [x + w * 1.1, gy - h - roof_h * 1.15, x + w * 1.22, gy - h - roof_h * 0.6], (120, 92, 80)))
    if door:
        d.append(("rect", [x + w * 0.38, gy - h * 0.5, x + w * 0.62, gy], (92, 58, 36)))
    for wx in ([x + w * 0.1] if door else [x + w * 0.2, x + w * 0.62]):
        d.append(("rect", [wx, gy - h * 0.78, wx + w * 0.2, gy - h * 0.5], window))


def draw_ops(img, ops, blur=0.8):
    layer = Image.new("RGB", (SW, SH))
    alpha = Image.new("L", (SW, SH), 0)
    dl, da = ImageDraw.Draw(layer), ImageDraw.Draw(alpha)
    for kind, geo, col in ops:
        if kind == "rect":
            dl.rectangle(geo, fill=col)
            da.rectangle(geo, fill=255)
        elif kind == "poly":
            dl.polygon(geo, fill=col)
            da.polygon(geo, fill=255)
        elif kind == "ellipse":
            dl.ellipse(geo, fill=col)
            da.ellipse(geo, fill=255)
        elif kind == "line":
            dl.line(geo[0], fill=col, width=geo[1])
            da.line(geo[0], fill=255, width=geo[1])
    a = np.asarray(alpha.filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255.0
    c = np.asarray(layer.filter(ImageFilter.GaussianBlur(blur * 0.5)), np.float32) / 255.0
    blend(img, a, c)


# ------------------------------------------------------------ the brushwork

def brushwork(sharp, seed):
    """Paints the sharp picture over with strokes that follow its shapes: broad ones first, then
    finer ones where there is detail, and lets a little of the sharp drawing show through."""
    rng = np.random.default_rng(seed)
    src = sharp
    lum = src @ np.array([0.3, 0.59, 0.11], np.float32)
    gy, gx = np.gradient(np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), np.float32))
    mag = np.sqrt(gx ** 2 + gy ** 2)
    canvas = Image.fromarray((src * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
    d = ImageDraw.Draw(canvas, "RGBA")
    passes = [(16, 5, 14000, 0.0), (9, 3, 26000, 1.5), (5, 2, 30000, 4.0)]
    for length, width, count, need in passes:
        xs = rng.integers(0, W, count)
        ys = rng.integers(0, H, count)
        keep = mag[ys, xs] >= need
        if need:
            keep |= rng.random(count) < 0.25
        for x, y in zip(xs[keep], ys[keep]):
            c = src[y, x] * 255 + rng.normal(0, 6, 3)
            # Along the edge (across the gradient); flat areas take a gentle sideways sweep.
            if mag[y, x] > 0.8:
                ang = math.atan2(gy[y, x], gx[y, x]) + math.pi / 2
            else:
                ang = rng.normal(0, 0.35)
            L = length * rng.uniform(0.7, 1.3)
            ca, sa = math.cos(ang), math.sin(ang)
            pts = []
            for k in range(10):
                t = k / 10 * 2 * math.pi
                px, py = math.cos(t) * L * 0.5, math.sin(t) * width * 0.5
                pts.append((x + px * ca - py * sa, y + px * sa + py * ca))
            d.polygon(pts, fill=(int(np.clip(c[0], 0, 255)), int(np.clip(c[1], 0, 255)), int(np.clip(c[2], 0, 255)), 200))
    painted = np.asarray(canvas, np.float32) / 255.0
    # Keep the drawing readable: the strokes on flat ground, the sharp picture at its edges.
    edge = np.clip(mag / 18.0, 0, 1)[..., None] * 0.55
    return painted * (1 - edge) + src * edge


def finish(img, seed):
    """Canvas weave, a warm varnish and a darker rim."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    weave = 0.03 * np.sin(xx * 2.1) * np.sin(yy * 2.1) + 0.02 * rng.normal(0, 1, (H, W))
    img = img * (1 + weave[..., None])
    cx, cy = (W - 1) / 2, (H - 1) / 2
    r = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
    vig = 1 - 0.28 * np.clip(r - 0.55, 0, 1) ** 1.5
    img = img * vig[..., None]
    varnish = np.array([1.03, 1.0, 0.92], np.float32)
    return np.clip(img * varnish, 0, 1)


def save(sharp_big, name, seed, keep=None):
    """Shrinks, paints over and finishes the picture. keep (0..1, full size) marks small details,
    such as stars, that the brush would smear: they stay as drawn."""
    small = Image.fromarray((np.clip(sharp_big, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    sharp = np.asarray(small, np.float32) / 255.0
    painted = brushwork(sharp, seed)
    if keep is not None:
        k = np.asarray(Image.fromarray((np.clip(keep, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), np.float32)[..., None] / 255.0
        painted = painted * (1 - k) + sharp * k
    out = finish(painted, seed + 1)
    Image.fromarray((out * 255).astype(np.uint8)).save(os.path.join(DIR, name), quality=90, optimize=True)
    print("wrote", name)


# --------------------------------------------------------------- the scenes

def mountains_at_dusk():
    rng = np.random.default_rng(11)
    img = vgrad([(0.0, rgb(58, 46, 98)), (0.25, rgb(142, 78, 120)), (0.45, rgb(236, 128, 86)), (0.58, rgb(255, 196, 120)), (1.0, rgb(255, 214, 150))])
    sun = (SW * 0.58, SH * 0.5)
    blend(img, glow(*sun, 420) * 0.6, rgb(255, 222, 150))
    blend(img, soft_disc(*sun, 62, 6), rgb(255, 244, 210))
    clouds(img, rng, 9, (0, SH * 0.06, SW, SH * 0.3), 170, rgb(255, 180, 120), rgb(150, 82, 118), alpha=0.85, flat=(0.12, 0.2))
    clouds(img, rng, 6, (0, SH * 0.32, SW, SH * 0.42), 120, rgb(255, 210, 150), rgb(214, 112, 104), alpha=0.7, flat=(0.1, 0.16))
    # Far range, then the great peaks, lit from the sun at the left of them.
    mountains(img, rng, SH * 0.6, 140, rgb(150, 110, 150), rgb(160, 110, 150), rgb(230, 160, 160), rgb(236, 160, 140), 0.55, snow_y=SH * 0.53)
    mountains(img, rng, SH * 0.66, 120, rgb(70, 52, 84), rgb(66, 50, 88), rgb(206, 132, 120), rgb(214, 130, 120), 0.2, snow_y=SH * 0.36,
              peaks=[(SW * 0.22, 760, 620), (SW * 0.44, 560, 470), (SW * 0.82, 820, 640)], light_from=-1)
    # Foothills in shadow, the meadow and the wood.
    hill = SH * 0.76 - 110 * (0.5 + 0.5 * noise1(SW, rng, 5, 2))
    blend(img, ridge_mask(hill), vgrad([(0, rgb(52, 64, 52)), (0.8, rgb(40, 50, 40)), (1, rgb(40, 50, 40))]))
    meadow_y = lambda x: SH * 0.84 - 30 * math.sin(x / SW * 3.0)
    mx = np.array([meadow_y(x) for x in range(SW)])
    yy = np.arange(SH, dtype=np.float32)[:, None]
    grass = vgrad([(0, rgb(120, 128, 60)), (0.86, rgb(150, 140, 62)), (1.0, rgb(70, 82, 38))])
    grass = grass * (1 + 0.12 * noise2(SH, SW, rng, scale=12, octaves=2)[..., None])
    blend(img, ridge_mask(mx), grass)
    # Low sun on the meadow's crest.
    blend(img, np.clip(1 - (yy - mx[None, :]) / 40.0, 0, 1) * ridge_mask(mx) * 0.6, rgb(240, 196, 110))
    # The wood's far edge along the foothills, small with distance.
    edge_xs = list(np.linspace(0, SW, 70) + rng.normal(0, 12, 70))
    firs(img, rng, edge_xs, lambda x: hill[int(min(SW - 1, max(0, x)))] + 40, [rng.uniform(60, 120) for _ in edge_xs],
         rgb(36, 50, 40), rgb(140, 104, 72), lean_light=1)
    xs = list(rng.uniform(0, SW * 0.36, 26)) + list(rng.uniform(SW * 0.7, SW, 22))
    xs.sort(key=lambda v: -abs(v - SW * 0.5))
    firs(img, rng, xs, lambda x: hill[int(min(SW - 1, max(0, x)))] + rng.uniform(40, 160), [rng.uniform(140, 260) for _ in xs],
         rgb(28, 40, 32), rgb(150, 110, 70), lean_light=1)
    big = [SW * 0.05, SW * 0.13, SW * 0.9, SW * 0.97]
    firs(img, rng, big, lambda x: SH * 0.97, [520, 430, 470, 560], rgb(20, 28, 24), rgb(170, 110, 60), lean_light=1)
    # A stream winding down the meadow, holding the sky.
    pts_l, pts_r = [], []
    for i in range(41):
        t = i / 40
        y = SH * 0.8 + t * SH * 0.2
        cx = SW * 0.56 + math.sin(t * 4.0) * SW * 0.08 - t * SW * 0.06
        hw = 8 + t * 90
        pts_l.append((cx - hw, y))
        pts_r.append((cx + hw, y))
    m = poly_mask(pts_l + pts_r[::-1], blur=2)
    water = vgrad([(0, rgb(255, 214, 150)), (0.85, rgb(250, 190, 130)), (1, rgb(200, 130, 120))])
    blend(img, m, water * (1 + 0.1 * noise2(SH, SW, rng, scale=8, octaves=2)[..., None]))
    banks = np.clip(poly_mask([(x - 14, y) for x, y in pts_l] + [(x + 14, y) for x, y in pts_r[::-1]], blur=4) - m, 0, 1)
    blend(img, banks * 0.7, rgb(70, 78, 40))
    glints = (noise2(SH, SW, rng, scale=6, octaves=1) > 0.55).astype(np.float32) * m
    blend(img, glints * 0.8, rgb(255, 246, 220))
    save(img, "painting_mountains.jpg", 101)


def lake_by_moonlight():
    rng = np.random.default_rng(23)
    img = vgrad([(0.0, rgb(8, 12, 34)), (0.5, rgb(26, 40, 82)), (0.62, rgb(54, 72, 118)), (1.0, rgb(54, 72, 118))])
    # Stars, fewer near the moon.
    moon = (SW * 0.3, SH * 0.2)
    stars = np.zeros((SH, SW), np.float32)
    for _ in range(420):
        x, y = rng.integers(0, SW), rng.integers(0, int(SH * 0.55))
        if math.hypot(x - moon[0], y - moon[1]) < 260:
            continue
        r = rng.choice([1, 1, 1, 2, 3])
        stars[max(0, y - r):y + r, max(0, x - r):x + r] = rng.uniform(0.5, 1)
    stars = np.asarray(Image.fromarray((stars * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    blend(img, np.clip(stars * 2.2, 0, 1), rgb(240, 240, 255))
    keep = np.clip(stars * 3, 0, 1)
    blend(img, glow(*moon, 360) * 0.55, rgb(120, 140, 190))
    blend(img, soft_disc(*moon, 84, 5), rgb(246, 244, 226))
    # The moon's seas, faintly.
    seas = ellipse_mask([(moon[0] - 40, moon[1] - 30, moon[0] + 10, moon[1] + 10), (moon[0] + 10, moon[1] + 15, moon[0] + 50, moon[1] + 50),
                         (moon[0] - 25, moon[1] + 25, moon[0] + 5, moon[1] + 55)], blur=10) * soft_disc(*moon, 80, 4)
    blend(img, seas * 0.22, rgb(170, 170, 160))
    clouds(img, rng, 4, (SW * 0.4, SH * 0.1, SW, SH * 0.32), 130, rgb(150, 164, 200), rgb(36, 48, 84), alpha=0.55, light_dir=(-1, -0.4), flat=(0.15, 0.25))
    water_y = int(SH * 0.6)
    # Far mountains, blue with night, then the near shore wooded black.
    mountains(img, rng, water_y, 260, rgb(40, 52, 88), rgb(30, 40, 72), rgb(110, 124, 170), rgb(54, 70, 112), 0.35, snow_y=SH * 0.36,
              peaks=[(SW * 0.12, 300, 380), (SW * 0.4, 360, 420), (SW * 0.72, 560, 600)], light_from=1)
    mountains(img, rng, water_y, 110, rgb(22, 30, 50), rgb(20, 26, 46), rgb(46, 60, 90), rgb(40, 54, 92), 0.15)
    shore = lambda x: water_y + 4
    xs = sorted(list(rng.uniform(0, SW * 0.25, 30)) + list(rng.uniform(SW * 0.55, SW, 40)))
    firs(img, rng, xs, shore, [rng.uniform(90, 210) for _ in xs], rgb(12, 18, 30), rgb(70, 90, 130), lean_light=-1)
    # A hut on the right shore with a warm window.
    ops = []
    hx = SW * 0.66
    ops.append(("rect", [hx, water_y - 110, hx + 170, water_y], (40, 36, 44)))
    ops.append(("poly", [(hx - 20, water_y - 108), (hx + 85, water_y - 200), (hx + 190, water_y - 108)], (30, 30, 44)))
    ops.append(("rect", [hx + 120, water_y - 220, hx + 145, water_y - 150], (34, 30, 40)))
    ops.append(("rect", [hx + 30, water_y - 80, hx + 70, water_y - 40], (255, 196, 110)))
    ops.append(("rect", [hx + 100, water_y - 90, hx + 138, water_y], (30, 24, 26)))
    draw_ops(img, ops)
    blend(img, glow(hx + 50, water_y - 60, 70) * 0.35, rgb(255, 180, 90))
    reflect(img, water_y, SH, 0.38, rgb(10, 18, 40), rng, ripple=2.5, blur=2)
    # The moon's path on the water: broken bright strokes widening towards us.
    path = np.zeros((SH, SW), np.float32)
    for y in range(water_y + 6, SH, 3):
        t = (y - water_y) / (SH - water_y)
        half = 20 + t * 220
        for _ in range(int(2 + t * 6)):
            x = moon[0] + rng.normal(0, half * 0.5)
            ln = rng.uniform(20, 60 + t * 140)
            path[y:y + 2, int(max(0, x - ln / 2)):int(min(SW, x + ln / 2))] = rng.uniform(0.5, 1.0) * (1 - 0.5 * t)
    path = np.asarray(Image.fromarray((path * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255.0
    blend(img, np.clip(path * 1.4, 0, 1), rgb(236, 236, 214))
    # A rowing boat drawn up at the near shore, and reeds.
    ops = [("poly", [(SW * 0.12, SH * 0.9), (SW * 0.3, SH * 0.9), (SW * 0.27, SH * 0.94), (SW * 0.15, SH * 0.94)], (24, 20, 26)),
           ("line", ([(SW * 0.16, SH * 0.88), (SW * 0.26, SH * 0.92)], 6), (60, 50, 50))]
    for _ in range(60):
        x = rng.uniform(0, SW * 0.12) if rng.random() < 0.5 else rng.uniform(SW * 0.86, SW)
        top = SH * rng.uniform(0.78, 0.9)
        ops.append(("line", ([(x, SH), (x + rng.normal(0, 14), top)], 4), (14, 20, 22)))
    draw_ops(img, ops, blur=0.6)
    save(img, "painting_lake.jpg", 202, keep=keep)


def dragon_over_village():
    rng = np.random.default_rng(37)
    img = vgrad([(0.0, rgb(70, 112, 182)), (0.45, rgb(140, 182, 222)), (0.7, rgb(214, 224, 228)), (1.0, rgb(214, 224, 228))])
    clouds(img, rng, 7, (0, SH * 0.05, SW, SH * 0.42), 130, rgb(255, 255, 250), rgb(150, 168, 198), alpha=0.92, light_dir=(0.3, -1))
    mountains(img, rng, SH * 0.6, 300, rgb(110, 130, 160), rgb(120, 140, 170), rgb(206, 216, 230), rgb(190, 206, 222), 0.4, snow_y=SH * 0.46,
              peaks=[(SW * 0.08, 380, 420), (SW * 0.33, 300, 380), (SW * 0.6, 440, 460), (SW * 0.9, 340, 400)])
    # Rolling hills: a far bluish one, then the village's hill rising to the right.
    far = SH * 0.62 - 50 * (0.5 + 0.5 * noise1(SW, rng, 4, 2))
    blend(img, ridge_mask(far), vgrad([(0, rgb(120, 156, 110)), (1, rgb(96, 136, 90))]))
    xx = np.arange(SW, dtype=np.float32)
    hill = SH * 0.68 - 240 * np.sin(np.pi * (xx / SW) ** 0.8) + 20 * noise1(SW, rng, 4, 4)
    grass = vgrad([(0, rgb(128, 176, 80)), (0.75, rgb(96, 146, 60)), (1, rgb(70, 112, 46))]) * (1 + 0.1 * noise2(SH, SW, rng, scale=14, octaves=2)[..., None])
    blend(img, ridge_mask(hill), grass)
    # Fields in strips running down to us, gold and green, with hedges between.
    vx, vy = SW * 0.5, SH * 0.66
    edges = np.linspace(-SW * 0.6, SW * 1.6, 12)
    for i, (a, b) in enumerate(zip(edges, edges[1:])):
        col = [(206, 182, 92), (118, 160, 70), (184, 170, 84), (140, 176, 80)][i % 4]
        m = poly_mask([(vx + (a - vx) * 0.3, SH * 0.78), (vx + (b - vx) * 0.3, SH * 0.78), (b, SH), (a, SH)], blur=2)
        blend(img, m * 0.85, rgb(*col) * (1 + 0.08 * noise2(SH, SW, rng, scale=5, octaves=2)[..., None]))
        hedge = [(vx + (a - vx) * 0.3, SH * 0.78), (a, SH)]
        draw_ops(img, [("line", (hedge, 10), (60, 92, 44))], blur=1.5)
    draw_ops(img, [("line", ([(0, SH * 0.78), (SW, SH * 0.78)], 14), (60, 92, 44))], blur=2)
    # A road climbing from the fields to the village.
    road = [(SW * 0.4 + math.sin(t * 2.2) * 80 - t * 40, SH * 1.0 - t * (SH * 1.0 - float(hill[int(SW * 0.38)]) - 120)) for t in np.linspace(0, 1, 24)]
    widths = np.linspace(80, 14, len(road))
    road_poly = [(x - w, y) for (x, y), w in zip(road, widths)] + [(x + w, y) for (x, y), w in list(zip(road, widths))[::-1]]
    draw_ops(img, [("poly", road_poly, (196, 172, 130))], blur=2)
    # The village: rows of cottages up the slope, smaller further off, the chapel among them.
    ground = lambda x: float(hill[int(np.clip(x, 0, SW - 1))])
    rows = []
    for depth, n, scale in [(0.0, 7, 0.62), (60.0, 6, 0.8), (150.0, 5, 1.0)]:
        xs = np.linspace(SW * 0.04, SW * 0.92, n) + rng.normal(0, 40, n)
        for x in xs:
            rows.append((depth, x, scale))
    chapel_x = SW * 0.36
    ops = []
    burning = None
    for depth, x, sc in rows:
        if abs(x - chapel_x) < 210 and depth < 100:
            continue
        w, h = 120 * sc * rng.uniform(0.9, 1.15), 95 * sc * rng.uniform(0.9, 1.1)
        g = ground(x + w * 0.7) + 30 + depth
        roof = [(168, 64, 44), (150, 56, 40), (120, 84, 60), (176, 92, 54)][int(rng.integers(0, 4))]
        house(ops, None, x, g, w, h, h * 0.85, (236, 226, 204), roof, (250, 210, 120), chimney=rng.random() < 0.4)
        if depth == 60.0 and burning is None and x < SW * 0.4 and x > SW * 0.15:
            burning = (x + w * 0.7, g - h - h * 0.6)
        if depth == 0.0:
            # The chapel stands on the back row so its tower shows over the roofs.
            pass
    # The chapel, drawn with the far row.
    g = ground(chapel_x + 100) + 30
    chapel = [("rect", [chapel_x, g - 150, chapel_x + 240, g], (220, 210, 190)),
              ("poly", [(chapel_x - 10, g - 150), (chapel_x + 120, g - 240), (chapel_x + 250, g - 150)], (110, 70, 60)),
              ("rect", [chapel_x + 180, g - 350, chapel_x + 254, g], (204, 194, 176)),
              ("poly", [(chapel_x + 170, g - 350), (chapel_x + 217, g - 520), (chapel_x + 264, g - 350)], (96, 64, 58)),
              ("ellipse", [chapel_x + 200, g - 316, chapel_x + 234, g - 282], (64, 54, 54))]
    for k in range(3):
        wx = chapel_x + 24 + k * 50
        chapel.append(("poly", [(wx, g - 40), (wx, g - 100), (wx + 14, g - 116), (wx + 28, g - 100), (wx + 28, g - 40)], (80, 92, 128)))
    draw_ops(img, chapel + ops)
    # One cottage has caught fire: flames on its roof and smoke leaning away with the wind.
    fx, fy = burning if burning else (SW * 0.25, SH * 0.5)
    smoke = np.zeros((SH, SW), np.float32)
    for i in range(46):
        t = i / 45
        r = 24 + t * 150
        smoke = np.maximum(smoke, soft_disc(fx + t * 600 + rng.normal(0, 18), fy - t * 760, r * 0.7, r * 0.6) * (1 - t * 0.55))
    blend(img, smoke * 0.82, rgb(92, 86, 90) * (1 + 0.25 * noise2(SH, SW, rng, scale=40)[..., None]))
    flames = []
    for i in range(16):
        bx = fx - 70 + i * 9 + rng.normal(0, 4)
        hgt = rng.uniform(40, 130)
        flames.append(("poly", [(bx - 14, fy + 50), (bx + rng.normal(0, 10), fy + 50 - hgt), (bx + 14, fy + 50)], (255, int(rng.uniform(110, 210)), 40)))
    draw_ops(img, flames, blur=2.5)
    blend(img, glow(fx, fy + 30, 130) * 0.55, rgb(255, 170, 80))
    dragon(img, SW * 0.66, SH * 0.25, 1.1)
    save(img, "painting_dragon.jpg", 303)


def dragon(img, ox, oy, s):
    """A red dragon flying left: wings raised, neck stretched, tail curling behind."""
    def P(pts):
        return [(ox + x * s, oy + y * s) for x, y in pts]
    red, dark, belly, wing = (150, 30, 24), (96, 18, 16), (214, 140, 70), (120, 36, 30)
    ops = []
    # The far wing, darker, behind the body.
    ops.append(("poly", P([(40, -10), (160, -230), (330, -330), (300, -250), (360, -200), (290, -160), (330, -100), (230, -70), (180, -10)]), dark))
    # Tail: a long curve ending in a spade.
    tail = []
    for i in range(30):
        t = i / 29
        tail.append((180 + t * 360, 20 + math.sin(t * 3.4) * 70 - t * 30))
    top = [(x, y - 26 * (1 - i / 30) - 4) for i, (x, y) in enumerate(tail)]
    bot = [(x, y + 26 * (1 - i / 30) + 4) for i, (x, y) in enumerate(tail)]
    ops.append(("poly", P(top + bot[::-1]), red))
    ex, ey = tail[-1]
    ops.append(("poly", P([(ex - 10, ey), (ex + 30, ey - 40), (ex + 70, ey + 4), (ex + 30, ey + 40)]), dark))
    # Body: a long oval with a pale belly.
    ops.append(("ellipse", P([(-80, -40), (220, 60)]), red))
    ops.append(("poly", P([(-60, 30), (40, 58), (180, 52), (210, 30), (100, 46), (0, 40)]), belly))
    # Neck and head reaching forward and a little down.
    neck = []
    for i in range(20):
        t = i / 19
        neck.append((-60 - t * 190, -10 - math.sin(t * 2.6) * 70))
    ntop = [(x, y - 30 * (1 - 0.5 * i / 20)) for i, (x, y) in enumerate(neck)]
    nbot = [(x, y + 30 * (1 - 0.5 * i / 20)) for i, (x, y) in enumerate(neck)]
    ops.append(("poly", P(ntop + nbot[::-1]), red))
    hx, hy = neck[-1]
    ops.append(("poly", P([(hx + 20, hy - 26), (hx - 40, hy - 30), (hx - 110, hy - 8), (hx - 112, hy + 6), (hx - 50, hy + 12), (hx - 70, hy + 26), (hx + 10, hy + 26)]), red))
    ops.append(("poly", P([(hx - 10, hy - 24), (hx + 40, hy - 70), (hx + 20, hy - 20)]), (230, 210, 180)))
    ops.append(("poly", P([(hx - 30, hy - 26), (hx + 4, hy - 64), (hx - 6, hy - 22)]), (230, 210, 180)))
    ops.append(("ellipse", P([(hx - 52, hy - 18), (hx - 38, hy - 6)]), (255, 220, 80)))
    # Spines along the back.
    for i in range(9):
        x = -40 + i * 30
        ops.append(("poly", P([(x, -36 + abs(i - 3) * 2), (x + 10, -62 + abs(i - 3) * 3), (x + 20, -36 + abs(i - 3) * 2)]), dark))
    # Legs tucked under.
    ops.append(("poly", P([(0, 40), (-20, 90), (-50, 100), (-10, 108), (20, 60)]), dark))
    ops.append(("poly", P([(150, 40), (140, 96), (110, 106), (150, 112), (180, 56)]), dark))
    # The near wing: arm bones and a scalloped membrane, lit underneath.
    arm = [(60, -20), (-30, -200), (-120, -330)]
    tips = [(-120, -330), (-220, -260), (-150, -180), (-200, -110), (-100, -90), (-90, -20), (10, 0)]
    membrane = [arm[0], arm[1], arm[2]]
    for a, b in zip(tips, tips[1:]):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        membrane += [a, (mx + (arm[1][0] - mx) * 0.18, my + (arm[1][1] - my) * 0.18)]
    membrane += [tips[-1]]
    ops.append(("poly", P(membrane), wing))
    for t in tips[1:-1]:
        ops.append(("line", (P([arm[1], t]), max(3, int(6 * s))), dark))
    ops.append(("line", (P(arm), max(5, int(12 * s))), dark))
    draw_ops(img, ops, blur=1.0)


if __name__ == "__main__":
    mountains_at_dusk()
    lake_by_moonlight()
    dragon_over_village()
