"""Draws the game's mouse cursors, themed on the devilbane logo: a faceted crystal
arrow (blue like the "db" letters) and a fiery gold one (like the "HARDCORE" lettering)
for things the player can press. Run: python3 tools/make_cursors.py
Writes assets/ui/cursor_arrow.png and cursor_hand.png (64x64, the tip is the hotspot)."""
from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 64
SS = 4  # draw four times larger, then shrink for smooth edges
S = SIZE * SS

# The arrow, in 64-px units. Index 0 is the tip, which is the hotspot.
TIP = (4.0, 3.0)
OUTLINE = [TIP, (4.0, 46.0), (14.5, 36.5), (22.5, 55.0), (31.0, 51.5), (23.0, 33.5), (37.0, 33.5)]
# The facet line runs from the tip down the middle of the arrow.
MID = [TIP, (23.0, 33.5)]


def px(points):
    return [(x * SS, y * SS) for x, y in points]


def inset(points, amount):
    """Shrinks a convex-ish polygon towards its centre of mass (good enough for an arrow)."""
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    out = []
    for x, y in points:
        d = math.hypot(x - cx, y - cy)
        k = max(0.0, (d - amount) / d)
        out.append((cx + (x - cx) * k, cy + (y - cy) * k))
    return out


def star(d, cx, cy, r, colour):
    colour = colour
    """The logo's four-pointed star of light."""
    pts = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * 0.22
        pts.append((cx + math.cos(a) * rad * SS, cy + math.sin(a) * rad * SS))
    d.polygon(pts, fill=colour)


def draw(dark, mid, light, rim, glow, name):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # soft glow so it reads on dark ground, a dark rim so it reads on snow
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.polygon(px(OUTLINE), fill=glow + (200,))
    g = g.filter(ImageFilter.GaussianBlur(3.2 * SS))
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    # the dark rim: the arrow's mask grown by a few pixels
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(px(OUTLINE), fill=255)
    m = m.filter(ImageFilter.MaxFilter(2 * int(1.6 * SS) + 1))
    img.paste((10, 14, 30, 255), (0, 0), m)
    d = ImageDraw.Draw(img)
    d.polygon(px(OUTLINE), fill=rim)
    body = inset(OUTLINE, 2.3)
    d.polygon(px(body), fill=mid)
    # two facets: lit on the left, shaded on the right, like the cut crystal letters
    left = [body[0], body[1], body[2], (23.0, 33.5)]
    right = [body[0], (23.0, 33.5), body[6], body[0]]
    d.polygon(px(inset(left, 0.3)), fill=light)
    d.polygon(px(inset([body[0], body[2], body[3], body[4], body[5], body[6]], 0.0)), fill=mid)
    d.polygon(px(inset(left, 0.3)), fill=light)
    d.polygon(px([body[0], (22.5, 32.0), body[6]]), fill=dark)
    d.polygon(px([body[5], (23.0, 33.5), body[4]]), fill=dark)
    d.line(px([body[0], (23.0, 33.5)]), fill=rim, width=int(1.2 * SS))
    # the star of the logo, up and to the right of the tip so the tip stays clean
    sm = Image.new("L", (S, S), 0)
    star(ImageDraw.Draw(sm), 41 * SS, 12 * SS, 10, 255)
    sm2 = sm.filter(ImageFilter.MaxFilter(2 * int(1.2 * SS) + 1))
    img.paste((10, 14, 30, 255), (0, 0), sm2)
    img.paste(light, (0, 0), sm)
    st = Image.new("L", (S, S), 0)
    star(ImageDraw.Draw(st), 41 * SS, 12 * SS, 6, 255)
    img.paste((255, 255, 255, 255), (0, 0), st)
    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    out.save(name)


BLUE = dict(dark=(20, 70, 200, 255), mid=(40, 130, 245, 255), light=(130, 215, 255, 255),
            rim=(205, 240, 255, 255), glow=(60, 160, 255))
GOLD = dict(dark=(200, 70, 10, 255), mid=(255, 150, 20, 255), light=(255, 220, 90, 255),
            rim=(255, 245, 200, 255), glow=(255, 140, 30))

if __name__ == "__main__":
    draw(name="assets/ui/cursor_arrow.png", **BLUE)
    draw(name="assets/ui/cursor_hand.png", **GOLD)
