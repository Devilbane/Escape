"""Paints the cape back "Sbinortz" for the cape wardrobe (scripts/cape_designs.gd):
the name in golden letters with a bejewelled golden crown below it.

Run:  python3 tools/make_cape_designs.py /path/to/CinzelDecorative-Black.ttf
(PIL needs a .ttf; convert the game's woff2 with fontTools first.)
Writes assets/logo/cape_sbinortz.png and cape_brikan.png (the BRIKAN crest: a navy shield with a
gold border, a compass, a saw and an open book), 480 x 512 like the devilbane logo.
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


def smooth(pts, rounds=4):
    """Chaikin corner cutting: a closed polygon with its corners rounded off."""
    for _ in range(rounds):
        out = []
        for i, (x0, y0) in enumerate(pts):
            x1, y1 = pts[(i + 1) % len(pts)]
            out += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        pts = out
    return pts


NAVY, NAVY_LIGHT = (20, 30, 74), (34, 48, 106)
SILVER_TOP, SILVER_LOW = (236, 238, 242), (140, 146, 158)
WOOD, WOOD_LIGHT = (140, 70, 30), (196, 112, 52)
COPPER = (196, 104, 56)
PAPER, PAPER_SHADE = (248, 236, 200), (206, 188, 140)


def grad(size, top, low):
    """A vertical gradient from `top` to `low`."""
    w, h = size
    strip = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        strip.putpixel((0, y), tuple(int(top[i] + (low[i] - top[i]) * t) for i in range(3)) + (255,))
    return strip.resize(size)


def paint(canvas, poly, fill, outline=DARK, rim=3):
    """Draws a polygon (in 480 x 512 coordinates) on `canvas` with a dark rim round it."""
    m = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in poly], fill=255)
    paint_mask(canvas, m, fill, outline, rim)


def paint_mask(canvas, m, fill, outline=DARK, rim=3):
    if rim:
        canvas.paste(Image.new("RGBA", canvas.size, outline + (255,)), (0, 0), m.filter(ImageFilter.MaxFilter(2 * rim * S + 1)))
    if isinstance(fill, tuple):
        fill = Image.new("RGBA", canvas.size, fill + (255,))
    canvas.paste(fill, (0, 0), m)


def thick(p, q, w):
    """The corners of a straight bar of width w from p to q."""
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = (dx * dx + dy * dy) ** 0.5
    ox, oy = -dy / n * w / 2, dx / n * w / 2
    return [(p[0] + ox, p[1] + oy), (q[0] + ox, q[1] + oy), (q[0] - ox, q[1] - oy), (p[0] - ox, p[1] - oy)]


def shield_points():
    pts = [(14, 70), (240, 16), (466, 70), (466, 330)]
    n = 24
    for i in range(1, n + 1):  # the lower half curves in to the point
        t = i / n
        pts.append((466 - 226 * t ** 1.8, 330 + 172 * t))
    for i in range(n - 1, 0, -1):
        t = i / n
        pts.append((14 + 226 * t ** 1.8, 330 + 172 * t))
    pts.append((14, 330))
    return pts


def shield(canvas, border=(GOLD_TOP, GOLD_LOW), cloth=(NAVY_LIGHT, NAVY)):
    """The dark navy shield with its gold border: nearly the whole picture, so the emblem is as large as it can be."""
    outer = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(outer).polygon([(x * S, y * S) for x, y in shield_points()], fill=255)
    paint_mask(canvas, outer, grad(canvas.size, *border), rim=3)
    inner = outer.filter(ImageFilter.GaussianBlur(24 * S)).point(lambda v: 255 if v > 200 else 0)
    inner = inner.filter(ImageFilter.GaussianBlur(S)).point(lambda v: 255 if v > 128 else 0)
    paint_mask(canvas, inner, grad(canvas.size, *cloth), rim=2)


def book(canvas):
    """An open book seen from the front: two cream pages with lines, on a gold cover."""
    paint(canvas, [(122, 394), (358, 394), (340, 420), (140, 420)], grad(canvas.size, GOLD_MID, GOLD_LOW))
    left = [(118, 350), (238, 366), (238, 404), (126, 390)]
    right = [(362, 350), (242, 366), (242, 404), (354, 390)]
    for page in (left, right):
        paint(canvas, page, grad(canvas.size, PAPER, PAPER_SHADE))
    d = ImageDraw.Draw(canvas)
    for k in range(3):  # the lines of text
        y = 363 + k * 9
        d.line((138 * S, (y + 1) * S, 224 * S, (y + 8) * S), fill=(120, 96, 60, 255), width=2 * S)
        d.line((342 * S, (y + 1) * S, 256 * S, (y + 8) * S), fill=(120, 96, 60, 255), width=2 * S)
    d.line((240 * S, 366 * S, 240 * S, 404 * S), fill=DARK + (255,), width=3 * S)


def saw(canvas, n=16):
    """A hand saw rising to the right behind the emblem's centre: toothed steel blade, wooden handle."""
    L = Image.new("RGBA", (360 * S, 150 * S), (0, 0, 0, 0))  # drawn flat, then tilted
    # Blade: a long strip with a row of teeth along its lower edge.
    blade = [(0, 40), (250, 22), (250, 100)]
    blade = [(0, 36), (250, 20), (250, 78), (0, 96)]
    teeth = []
    for i in range(n):
        x0 = i * 250 / n
        y0 = 96 - (96 - 78) * i / n
        x1 = (i + 1) * 250 / n
        y1 = 96 - (96 - 78) * (i + 1) / n
        teeth += [(x0, y0), ((x0 + x1) / 2 + 3, (y0 + y1) / 2 + 22)]
    teeth += [(250, 78)]
    blade_poly = [(0, 36), (250, 20), (250, 78)] + list(reversed(teeth))
    paint(L, blade_poly, grad(L.size, SILVER_TOP, SILVER_LOW), rim=3)
    # Handle: a wooden grip with an opening and three rivets.
    handle = [(236, 8), (300, 0), (352, 14), (356, 118), (312, 138), (262, 118), (242, 84)]
    paint(L, handle, grad(L.size, WOOD_LIGHT, WOOD), rim=3)
    hole = [(284, 28), (326, 26), (332, 84), (300, 96), (286, 72)]
    m = Image.new("L", L.size, 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in hole], fill=255)
    L.paste(Image.new("RGBA", L.size, (0, 0, 0, 0)), (0, 0), m)
    d = ImageDraw.Draw(L)
    d.line([(x * S, y * S) for x, y in hole + [hole[0]]], fill=DARK + (255,), width=3 * S)
    for rx, ry in [(262, 22), (344, 100), (270, 100)]:
        d.ellipse(((rx - 6) * S, (ry - 6) * S, (rx + 6) * S, (ry + 6) * S), fill=(236, 190, 120, 255), outline=DARK + (255,), width=2 * S)
    px, py = 50, 262  # the blade's left end stays here; the saw rises to the right
    full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full.alpha_composite(L, (px * S, (py - 60) * S))
    canvas.alpha_composite(full.rotate(18, resample=Image.BICUBIC, center=(px * S, py * S)))


def compass(canvas):
    """A golden drawing compass: ring and hinge on top, two legs spread over the book, a copper arc between them."""
    gold = grad(canvas.size, GOLD_TOP, GOLD_LOW)
    apex = (240, 128)
    left_foot, right_foot = (150, 392), (330, 392)
    for foot in (left_foot, right_foot):
        paint(canvas, thick(apex, foot, 24), gold, rim=3)
    # Steel needle tips.
    for foot, tip in ((left_foot, (138, 424)), (right_foot, (342, 424))):
        dx, dy = foot[0] - apex[0], foot[1] - apex[1]
        n = (dx * dx + dy * dy) ** 0.5
        t = (foot[0] + dx / n * 26, foot[1] + dy / n * 26)
        paint(canvas, [(foot[0] - dy / n * 8, foot[1] + dx / n * 8), t, (foot[0] + dy / n * 8, foot[1] - dx / n * 8)], SILVER_LOW, rim=2)
    # The copper arc between the legs.
    pts = []
    for i in range(21):
        t = i / 20
        x = 188 + 104 * t
        pts.append((x, 296 + 34 * (1 - (2 * t - 1) ** 2) * -1 + 34))
    arc = pts + [(x, y + 22) for x, y in reversed(pts)]
    paint(canvas, arc, COPPER, rim=3)
    # The top ring and the hinge.
    d = ImageDraw.Draw(canvas)
    ring = Image.new("L", canvas.size, 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse((218 * S, 52 * S, 262 * S, 96 * S), fill=255)
    rd.ellipse((229 * S, 63 * S, 251 * S, 85 * S), fill=0)
    paint_mask(canvas, ring, gold, rim=3)
    hub = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(hub).ellipse((206 * S, 94 * S, 274 * S, 162 * S), fill=255)
    paint_mask(canvas, hub, gold, rim=3)
    d = ImageDraw.Draw(canvas)
    d.ellipse((222 * S, 110 * S, 258 * S, 146 * S), fill=COPPER + (255,), outline=DARK + (255,), width=3 * S)
    d.ellipse((232 * S, 120 * S, 248 * S, 136 * S), fill=GOLD_TOP + (255,), outline=DARK + (255,), width=2 * S)


def square(canvas, w=30):
    """A try square (Winkelmass): two golden arms meeting at a right angle, corner up, with marks along the arms."""
    gold = grad(canvas.size, GOLD_TOP, GOLD_LOW)
    apex, a, b = (240, 104), (76, 268), (404, 268)
    paint(canvas, thick((apex[0], apex[1] - w * 0.2), a, w), gold, rim=3)
    paint(canvas, thick((apex[0], apex[1] - w * 0.2), b, w), gold, rim=3)
    paint(canvas, [(240, apex[1] - w * 0.85), (240 + w * 0.8, apex[1] - w * 0.05), (240, apex[1] + w * 0.75), (240 - w * 0.8, apex[1] - w * 0.05)], gold, rim=3)
    d = ImageDraw.Draw(canvas)
    for k in range(1, 6):  # the scale marks, across each arm
        t = k / 6.4
        for end, sign in ((a, -1), (b, 1)):
            x, y = apex[0] + (end[0] - apex[0]) * t, apex[1] + (end[1] - apex[1]) * t
            ux, uy = sign * 0.7071, 0.7071
            d.line(((x + uy * w * 0.5 * -sign) * S, (y + ux * w * 0.5 * sign) * S, (x - uy * w * 0.5 * -sign * (0.2 if k % 2 else -0.2)) * S, (y - ux * w * 0.5 * sign * (0.2 if k % 2 else -0.2)) * S), fill=DARK + (255,), width=2 * S)


def pi_sign(canvas):
    """The Greek letter pi in gold, as tall as the compass was: a bar across the top with a straight and a curved leg."""
    gold = grad(canvas.size, GOLD_TOP, GOLD_LOW)
    bar = [(120, 118), (200, 96), (360, 96), (372, 150), (352, 156), (340, 134), (140, 144), (124, 166)]
    paint(canvas, [(112, 104), (368, 84), (376, 140), (112, 150)], gold, rim=3)
    paint(canvas, [(112, 150), (176, 150), (170, 168), (118, 170)], gold, rim=3)
    paint(canvas, [(176, 130), (222, 130), (210, 390), (170, 394), (148, 396), (146, 376), (176, 366)], gold, rim=3)
    # The right leg curves out to the right at its foot.
    leg = [(262, 130), (306, 130), (300, 330)]
    for i in range(1, 13):
        t = i / 12
        leg.append((300 + 52 * t ** 1.6, 330 + 60 * (t ** 0.8) * (1 if t < 1 else 1)))
    leg += [(352, 394), (326, 414), (298, 418), (278, 394)]
    for i in range(12, 0, -1):
        t = i / 12
        leg.append((254 + 18 * t ** 1.2, 330 + 50 * t))
    paint(canvas, leg, gold, rim=3)
    ImageDraw.Draw(canvas)


def brikan(variant="square", path="assets/logo/cape_brikan.png"):
    """The BRIKAN emblem: a shield with a gold border, a try square (or compass) with a hand saw crossing
    behind it and an open book below. The shield fills the whole picture so the emblem is as big as it can be.
    Variants: "square" (the chosen look), "compass", "bold" (thicker, fewer details), "crimson" (red shield, silver rim)."""
    big = (W * S, H * S)
    out = Image.new("RGBA", big, (0, 0, 0, 0))
    if variant == "crimson":
        shield(out, (SILVER_TOP, SILVER_LOW), ((120, 24, 36), (66, 10, 20)))
    else:
        shield(out)
    book(out)
    saw(out, 8 if variant == "bold" else 16)
    if variant == "compass":
        compass(out)
    else:
        square(out, 44 if variant == "bold" else 30)
    out.resize((W, H), Image.LANCZOS).save(path)


if __name__ == "__main__":
    main(sys.argv[1])
    brikan("compass")
