"""Builds the Devilbane display font from geometric strokes.

The letterforms extrapolate the "d" and "b" of the Devilbane logo: heavy, even strokes, bowls
that are pointed-top hexagons with vertical sides, ascenders cut diagonally into a flag, and
stems that end in a forked thorn below the baseline.

Usage: python3 tools/font/build_devilbane_font.py <out.ttf>
Needs fonttools and shapely (pip install fonttools shapely).
"""
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from shapely import affinity
from shapely.geometry import LineString, MultiPolygon, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

S = 118          # stroke width (verticals end up wider, see XSCALE)
XSCALE = 1.1     # glyphs are widened after drawing: heavier verticals, as in the logo
H = S / 2
XH = 500         # x-height
CH = 700         # cap height
ASC = 770        # ascender
DSC = -220       # descender
SB = 45          # side bearing
BAR = 100        # horizontal bars are a little lighter


# ---------------------------------------------------------------- primitives

def st(*pts, w=S):
    """A stroke along a centreline, square ends, mitred joins."""
    return LineString(pts).buffer(w / 2, cap_style=2, join_style=2, mitre_limit=4)


def poly(*pts):
    return Polygon(pts)


def rect(x0, y0, x1, y1):
    return box(x0, y0, x1, y1)


def hexagon(x0, x1, y0, y1, p=0.3):
    """Pointed-top hexagon with vertical sides, the logo's bowl shape."""
    xm = (x0 + x1) / 2
    d = (y1 - y0) * p
    return poly((x0, y0 + d), (xm, y0), (x1, y0 + d), (x1, y1 - d), (xm, y1), (x0, y1 - d))


def ring(x0, x1, y0, y1, p=0.3, w=S):
    outer = hexagon(x0, x1, y0, y1, p)
    return outer.difference(outer.buffer(-w, join_style=2, mitre_limit=4))


def bowl(x0, x1):
    return ring(x0, x1, -10, XH + 10)


def flip(xs, cx, side):
    return [(cx + side * dx, y) for dx, y in xs]


def flag(cx, top, side=-1):
    """Ascender top: a diagonal cut rising to the far edge, with a flag jutting out."""
    return poly(*flip([(-H, top), (H + 88, top - 118), (H + 4, top - 152), (H, top - 280),
                       (-H, top - 280)], cx, -side))


def wedge(cx, top, side=-1):
    """The smaller flag for x-height and cap stems."""
    return poly(*flip([(-H, top + 18), (H + 52, top - 60), (H, top - 92), (H, top - 200),
                       (-H, top - 200)], cx, -side))


def foot(cx, base=0, side=1):
    """The logo's forked thorn: a long tip below the baseline and a short spur."""
    return poly(*flip([(-H, base + 120), (H, base + 120), (H + 16, base - 55), (0, base + 30),
                       (-H - 48, base - 4)], cx, side))


def spike(cx, base=0, side=1):
    """A plain slanted stem end, its point towards side."""
    return poly(*flip([(-H, base + 130), (H, base + 130), (H, base - 22), (-H, base + 22)],
                      cx, side))


def stem(cx, y0, y1):
    return rect(cx - H, y0, cx + H, y1)


def diamond(cx, cy, r=70):
    return poly((cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy))


def clip(g, y0=-1000, y1=2000, x0=-1000, x1=3000):
    return g.intersection(box(x0, y0, x1, y1))


def mirror(g):
    return affinity.scale(g, -1, 1, origin=(0, 0))


def U(*gs):
    return unary_union(list(gs))


# shared parts
def arch(xl, xr, low=XH - 210):
    """The n shoulder: a pointed half hexagon from the left stem to the right leg."""
    return st((xl, low), ((xl + xr) / 2, XH - H + 8), (xr, low), (xr, 110))


def tail(cx, to_x):
    """A descender hooking left, as in g, j, y."""
    return st((cx, XH - 190), (cx, -90), (cx - 95, DSC + H), (to_x, DSC + H))


def xstem(cx, foot_side=1):
    return U(stem(cx, 100, XH - 190), wedge(cx, XH), foot(cx, 0, foot_side))


def capstem(cx, foot_side=1, top=True):
    parts = [stem(cx, 0 if foot_side is None else 100, CH - (190 if top else 0))]
    if foot_side is not None:
        parts.append(foot(cx, 0, foot_side))
    if top:
        parts.append(wedge(cx, CH))
    return U(*parts)


def dots(cx, y, gap=115):
    return U(diamond(cx - gap, y, 64), diamond(cx + gap, y, 64))


def quote(cx, y, low=False):
    # a slanted wedge, heavy end up for openers drawn at the baseline
    return poly((cx - 34, y), (cx + 46, y), (cx + 6, y - 210), (cx - 40, y - 210))


# ---------------------------------------------------------------- glyphs

G = {}


def glyph(ch):
    def deco(fn):
        G[ch] = fn
        return fn
    return deco


# lowercase -----------------------------------------------------------------
d_shape = lambda: U(bowl(0, 420), stem(370, 100, ASC - 270), flag(370, ASC, -1), foot(370, 0, 1))

G['a'] = lambda: U(bowl(0, 420), xstem(370))
G['b'] = lambda: affinity.translate(mirror(d_shape()), 420, 0)
G['c'] = lambda: bowl(0, 390).difference(rect(250, 165, 500, XH - 165))
G['d'] = d_shape
G['e'] = lambda: U(bowl(0, 410).difference(rect(250, 100, 500, 210)), rect(40, 215, 380, 215 + BAR))
G['f'] = lambda: U(stem(110, 100, ASC - 150), st((110, ASC - 200), (110, ASC - 140), (200, ASC - H), (330, ASC - H)),
                   rect(0, XH - BAR, 290, XH), foot(110, 0, 1))
G['g'] = lambda: U(bowl(0, 420), tail(370, 40), wedge(370, XH))
G['h'] = lambda: U(stem(50, 100, ASC - 270), flag(50, ASC), foot(50, 0, 1), arch(50, 370), spike(370))
G['i'] = lambda: U(xstem(50), diamond(50, XH + 150))
G['j'] = lambda: U(tail(220, -10), wedge(220, XH), diamond(220, XH + 150))
G['k'] = lambda: U(stem(50, 100, ASC - 270), flag(50, ASC), foot(50, 0, 1),
                   clip(st((420, XH + 40), (100, 220)), 0, XH), clip(st((190, 290), (440, -40)), 0, XH))
G['l'] = lambda: U(stem(50, 100, ASC - 270), flag(50, ASC), foot(50, 0, 1))
G['m'] = lambda: U(xstem(50), arch(50, 330), spike(330), arch(330, 610), spike(610))
G['n'] = lambda: U(xstem(50), arch(50, 370), spike(370))
G['o'] = lambda: bowl(0, 420)
G['p'] = lambda: U(bowl(0, 420), stem(50, DSC + 120, XH - 190), wedge(50, XH), spike(50, DSC, -1))
G['q'] = lambda: U(bowl(0, 420), stem(370, DSC + 120, XH - 190), wedge(370, XH), spike(370, DSC, 1))
G['r'] = lambda: U(xstem(50), st((50, XH - 190), (150, XH - H), (310, XH - H)), spike(310, XH - 140, 1).difference(rect(0, -999, 999, XH - 150)))
G['s'] = lambda: st((370, XH - H), (120, XH - H), (H, XH - 120), (H, XH - 175), (360, 175), (360, 120), (290, H), (30, H))
G['t'] = lambda: U(st((110, XH + 140), (110, 130), (190, H), (300, H)), rect(0, XH - BAR, 280, XH),
                   poly((60, XH + 140), (160, XH + 190), (160, XH + 100), (60, XH + 100)))
G['u'] = lambda: U(st((50, XH - 190), (50, 200), (210, H - 8), (370, 200)), wedge(50, XH), xstem(370))
G['v'] = lambda: U(st((50, XH - 190), (50, 240), (210, H - 8), (370, 240), (370, XH - 190)), wedge(50, XH), wedge(370, XH))
G['w'] = lambda: U(st((50, XH - 190), (50, 220), (185, H - 8), (320, 220), (320, XH - 190)),
                   st((320, 220), (455, H - 8), (590, 220), (590, XH - 190)),
                   wedge(50, XH), wedge(320, XH), wedge(590, XH))
G['x'] = lambda: clip(U(st((30, XH + 30), (390, -30)), st((390, XH + 30), (30, -30))), 0, XH)
G['y'] = lambda: U(st((50, XH - 190), (50, 240), (210, H - 8), (370, 240)), tail(370, 40), wedge(50, XH), wedge(370, XH))
G['z'] = lambda: st((30, XH - H), (370, XH - H), (40, H), (390, H))
G['ß'] = lambda: U(stem(50, 100, ASC - 150), foot(50, 0, 1),
                   st((50, ASC - 200), (50, ASC - 140), (140, ASC - H), (270, ASC - H), (360, ASC - 140),
                      (360, ASC - 210), (210, XH - 40)),
                   st((210, XH - 40), (400, XH - 150), (400, 150), (310, H), (170, H)))

# uppercase -----------------------------------------------------------------
G['A'] = lambda: U(st((50, 0), (50, 430), (250, CH - H + 10), (450, 430), (450, 0)), rect(50, 250, 450, 250 + BAR))
G['B'] = lambda: U(capstem(50, None, False), st((50, CH - H), (320, CH - H), (410, CH - 140), (410, CH - 220), (320, 380), (50, 380)),
                   st((50, 380), (340, 380), (450, 285), (450, 140), (350, H), (50, H)))
G['C'] = lambda: ring(0, 480, -10, CH + 10, 0.27).difference(rect(330, 230, 600, CH - 230))
G['D'] = lambda: U(capstem(50, None, False), st((50, CH - H), (300, CH - H), (450, CH - 210), (450, 210), (300, H), (50, H)))
G['E'] = lambda: U(stem(50, 0, CH), rect(50, CH - S, 420, CH), rect(50, 310, 360, 310 + BAR), rect(50, 0, 440, S),
                   poly((420, CH), (440, CH + 20), (440, CH - S - 20), (420, CH - S)))
G['F'] = lambda: U(capstem(50, 1, False), rect(50, CH - S, 420, CH), rect(50, 300, 360, 300 + BAR))
G['G'] = lambda: U(ring(0, 480, -10, CH + 10, 0.27).difference(rect(330, 300, 600, CH - 230)),
                   rect(250, 260, 480, 260 + BAR), rect(380, 100, 480, 300))
G['H'] = lambda: U(capstem(50), capstem(450, 1), rect(50, 300, 450, 300 + BAR))
G['I'] = lambda: capstem(50)
G['J'] = lambda: U(st((320, CH - 190), (320, 190), (210, H), (110, H), (H, 130)), wedge(320, CH))
G['K'] = lambda: U(capstem(50), clip(st((470, CH + 40), (100, 300)), 0, CH), clip(st((210, 390), (480, -40)), 0, CH))
G['L'] = lambda: U(stem(50, 0, CH - 190), wedge(50, CH), rect(50, 0, 420, S))
G['M'] = lambda: U(st((50, 0), (50, 480), (175, CH - H + 10), (300, 480), (425, CH - H + 10), (550, 480), (550, 0)),
                   st((300, 480), (300, 260)))
G['N'] = lambda: clip(U(st((50, 0), (50, CH - 80)), st((50, CH), (450, 0)), st((450, 80), (450, CH)),
                        stem(50, 0, CH), stem(450, 0, CH)), 0, CH)
G['O'] = lambda: ring(0, 500, -10, CH + 10, 0.25)
G['P'] = lambda: U(capstem(50, 1, False), st((50, CH - H), (320, CH - H), (450, CH - 170), (450, CH - 250), (320, 310), (50, 310)))
G['Q'] = lambda: U(ring(0, 500, -10, CH + 10, 0.25), poly((270, 150), (350, 210), (500, -90), (410, -70)))
G['R'] = lambda: U(G['P'](), clip(st((260, 320), (470, -60)), 0, CH))
G['S'] = lambda: st((440, CH - H), (150, CH - H), (H, CH - 140), (H, CH - 250), (450, 250), (450, 140), (350, H), (30, H))
G['T'] = lambda: U(rect(0, CH - S, 500, CH), capstem(250, 1, False))
G['U'] = lambda: U(st((50, CH - 190), (50, 210), (250, H - 8), (450, 210), (450, CH - 190)), wedge(50, CH), wedge(450, CH))
G['V'] = lambda: U(st((50, CH - 190), (50, 470), (250, H - 8), (450, 470), (450, CH - 190)), wedge(50, CH), wedge(450, CH))
G['W'] = lambda: U(st((50, CH - 190), (50, 240), (175, H - 8), (300, 240), (300, 520)),
                   st((300, 240), (425, H - 8), (550, 240), (550, CH - 190)), wedge(50, CH), wedge(550, CH))
G['X'] = lambda: clip(U(st((30, CH + 40), (470, -40)), st((470, CH + 40), (30, -40))), 0, CH)
G['Y'] = lambda: U(st((50, CH - 190), (50, 500), (250, 340), (450, 500), (450, CH - 190)), wedge(50, CH), wedge(450, CH),
                   stem(250, 100, 360), foot(250, 0, 1))
G['Z'] = lambda: st((30, CH - H), (450, CH - H), (40, H), (460, H))
for low, up in (('ä', 'a'), ('ö', 'o'), ('ü', 'u')):
    G[low] = (lambda b: lambda: U(G[b](), dots(210, XH + 150)))(up)
G['Ä'] = lambda: U(G['A'](), dots(250, CH + 140))
G['Ö'] = lambda: U(G['O'](), dots(250, CH + 140))
G['Ü'] = lambda: U(G['U'](), dots(250, CH + 140))
G['ẞ'] = lambda: U(stem(50, 100, CH - 150), foot(50, 0, 1),
                   st((50, CH - 200), (50, CH - 140), (140, CH - H), (450, CH - H), (230, 420)),
                   st((230, 420), (450, 300), (450, 150), (350, H), (170, H)))

# digits --------------------------------------------------------------------
G['0'] = lambda: ring(0, 440, -10, CH + 10, 0.22)
G['1'] = lambda: U(stem(250, 100, CH - 270), flag(250, CH, -1), foot(250, 0, 1))
G['2'] = lambda: st((H, CH - 150), (140, CH - H), (300, CH - H), (400, CH - 150), (400, CH - 270), (H, 140), (H, H), (440, H))
G['3'] = lambda: U(st((30, CH - H), (310, CH - H), (400, CH - 150), (400, CH - 250), (300, 380), (150, 380)),
                   st((300, 380), (410, 280), (410, 150), (310, H), (30, H)))
G['4'] = lambda: U(st((350, CH - 40), (H, 280), (H, 230), (470, 230)), stem(350, 100, CH - 120), foot(350, 0, 1))
G['5'] = lambda: st((420, CH - H), (H, CH - H), (H, 400), (300, 400), (420, 300), (420, 150), (310, H), (30, H))
G['6'] = lambda: U(ring(0, 440, -10, 440, 0.3), st((H, 300), (H, CH - 150), (150, CH - H), (400, CH - H)))
G['7'] = lambda: clip(st((30, CH - H), (440, CH - H), (440, CH - 140), (160, -60)), 0, CH)
G['8'] = lambda: U(ring(30, 410, 330, CH + 10, 0.32), ring(0, 440, -10, 410, 0.3))
G['9'] = lambda: affinity.rotate(G['6'](), 180, origin=(220, CH / 2))

# punctuation ---------------------------------------------------------------
G[' '] = None
G['.'] = lambda: diamond(72, 72)
G[','] = lambda: U(diamond(72, 72), poly((65, 3), (127, 65), (60, -170), (10, -150)))
G[':'] = lambda: U(diamond(72, 72), diamond(72, XH - 72))
G[';'] = lambda: U(G[','](), diamond(72, XH - 72))
G['!'] = lambda: U(poly((15, CH), (115, CH), (88, 210), (42, 210)), diamond(72, 72))
G['?'] = lambda: U(st((H, CH - 150), (140, CH - H), (300, CH - H), (400, CH - 150), (400, CH - 260), (220, 360), (220, 210)),
                   diamond(220, 72))
G["'"] = lambda: poly((0, CH), (100, CH), (72, CH - 230), (28, CH - 230))
G['"'] = lambda: U(G["'"](), affinity.translate(G["'"](), 150, 0))
G['‚'] = lambda: quote(40, 90)
G['„'] = lambda: U(quote(40, 90), quote(170, 90))
G['‘'] = lambda: affinity.rotate(quote(40, CH), 180, origin=(40, CH - 105))
G['’'] = lambda: quote(40, CH)
G['“'] = lambda: U(G['‘'](), affinity.translate(G['‘'](), 130, 0))
G['”'] = lambda: U(quote(40, CH), quote(170, CH))
G['-'] = lambda: poly((0, 250), (240, 250), (260, 290), (240, 330), (0, 330), (-20, 290))
G['–'] = lambda: poly((0, 250), (440, 250), (460, 290), (440, 330), (0, 330), (-20, 290))
G['—'] = lambda: poly((0, 250), (840, 250), (860, 290), (840, 330), (0, 330), (-20, 290))
G['−'] = lambda: rect(0, 250, 400, 250 + BAR)
G['_'] = lambda: rect(0, -140, 480, -140 + BAR)
G['('] = lambda: st((220, CH + 60), (H + 20, CH - 140), (H + 20, -20), (220, -200))
G[')'] = lambda: affinity.translate(mirror(G['(']()), 240, 0)
G['['] = lambda: st((230, CH + 60 - H), (H, CH + 60 - H), (H, -200 + H), (230, -200 + H))
G[']'] = lambda: affinity.translate(mirror(G['[']()), 230, 0)
G['{'] = lambda: U(st((240, CH + 60 - H), (130, CH + 10), (130, 390), (40, 290), (130, 190), (130, -150), (240, -200 + H)))
G['}'] = lambda: affinity.translate(mirror(G['{']()), 260, 0)
G['/'] = lambda: st((40, -150), (340, CH + 60))
G['\\'] = lambda: st((340, -150), (40, CH + 60))
G['|'] = lambda: stem(H, -200, CH + 60)
G['+'] = lambda: U(rect(0, 250, 420, 250 + BAR), rect(210 - BAR / 2, 80, 210 + BAR / 2, 500))
G['='] = lambda: U(rect(0, 170, 420, 170 + BAR), rect(0, 330, 420, 330 + BAR))
G['×'] = lambda: clip(U(st((0, 80), (360, 440), w=BAR), st((0, 440), (360, 80), w=BAR)), 80, 440, 0, 360)
G['<'] = lambda: st((400, 520), (H, 290), (400, 60))
G['>'] = lambda: st((H, 520), (400, 290), (H, 60))
G['«'] = lambda: U(st((220, 440), (H, 260), (220, 80), w=80), st((420, 440), (250, 260), (420, 80), w=80))
G['»'] = lambda: affinity.translate(mirror(G['«']()), 460, 0)
G['*'] = lambda: affinity.translate(U(*[affinity.rotate(poly((-34, 0), (34, 0), (0, 190)), a, origin=(0, 0))
                                             for a in (0, 72, 144, 216, 288)]), 200, CH - 200)
G['#'] = lambda: U(st((150, -20), (210, CH - 60), w=80), st((330, -20), (390, CH - 60), w=80),
                   rect(0, 180, 520, 180 + 80), rect(30, 420, 550, 420 + 80))
G['$'] = lambda: U(G['S'](), stem(250, -110, CH + 110).intersection(U(rect(0, -200, 999, 0), rect(0, CH, 999, 999))))
G['%'] = lambda: U(ring(0, 230, 380, CH + 10, 0.3, w=70), ring(330, 560, -10, 320, 0.3, w=70), st((40, -40), (520, CH + 40), w=80))
G['&'] = lambda: U(st((460, 0), (130, CH - 330), (130, CH - 130), (220, CH - H), (310, CH - 130), (310, CH - 230), (H, 300),
                      (H, 140), (150, H), (310, H), (460, 260)))
G['@'] = lambda: U(ring(0, 640, -40, CH, 0.25, w=70), ring(160, 420, 150, 520, 0.3, w=80), st((420, 520), (420, 210), (520, 210), w=80))
G['^'] = lambda: st((40, 400), (210, CH - 60), (380, 400), w=80)
G['~'] = lambda: st((0, 260), (110, 340), (300, 240), (410, 320), w=BAR)
G['`'] = lambda: st((40, CH + 20), (180, CH - 120), w=80)
G['©'] = lambda: U(ring(0, 640, -10, CH + 10, 0.25, w=60), ring(160, 480, 170, 530, 0.3, w=80).difference(rect(380, 300, 600, 400)))
G['·'] = lambda: diamond(65, 290)
G['•'] = lambda: diamond(90, 290, 90)
G['…'] = lambda: U(diamond(72, 72), diamond(272, 72), diamond(472, 72))
G['°'] = lambda: ring(0, 240, CH - 250, CH + 10, 0.3, w=64)
G['€'] = lambda: U(G['C'](), rect(-40, 410, 340, 410 + 70), rect(-40, 250, 320, 250 + 70))


# ---------------------------------------------------------------- font output

def name_of(ch):
    from fontTools.agl import UV2AGL
    cp = ord(ch)
    return UV2AGL.get(cp, 'uni%04X' % cp)


def to_glyph(geom):
    pen = TTGlyphPen(None)
    if geom is None or geom.is_empty:
        return pen.glyph(), 0, 0
    geom = affinity.scale(geom.buffer(0), XSCALE, 1, origin=(0, 0))
    minx, _, maxx, _ = geom.bounds
    geom = affinity.translate(geom, SB - minx, 0).simplify(0.4)
    polys = geom.geoms if isinstance(geom, MultiPolygon) else [geom]
    for p in polys:
        if p.is_empty or p.area < 1:
            continue
        p = orient(p, sign=-1.0)   # TrueType: outer contours clockwise
        for ringcoords in [p.exterior.coords] + [i.coords for i in p.interiors]:
            pts = [(round(x), round(y)) for x, y in list(ringcoords)[:-1]]
            pts = [pt for i, pt in enumerate(pts) if pt != pts[i - 1]]
            if len(pts) < 3:
                continue
            pen.moveTo(pts[0])
            for pt in pts[1:]:
                pen.lineTo(pt)
            pen.closePath()
    return pen.glyph(), round(maxx - minx + 2 * SB), SB


def build(out):
    order = ['.notdef']
    glyphs = {}
    metrics = {}
    cmap = {}
    nd = TTGlyphPen(None)
    for c in [[(50, 0), (50, CH), (450, CH), (450, 0)], [(110, 60), (390, 60), (390, CH - 60), (110, CH - 60)]]:
        nd.moveTo(c[0]); [nd.lineTo(p) for p in c[1:]]; nd.closePath()
    glyphs['.notdef'] = nd.glyph()
    metrics['.notdef'] = (500, 50)
    for ch, fn in G.items():
        n = name_of(ch)
        if ch == ' ':
            glyphs[n] = TTGlyphPen(None).glyph()
            metrics[n] = (260, 0)
        else:
            g, adv, lsb = to_glyph(fn())
            glyphs[n] = g
            metrics[n] = (adv, lsb)
        order.append(n)
        cmap[ord(ch)] = n
    cmap[0xA0] = 'space'

    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=900, descent=-260)
    fb.setupNameTable({'familyName': 'Devilbane', 'styleName': 'Regular',
                       'uniqueFontIdentifier': 'Devilbane-Regular', 'fullName': 'Devilbane Regular',
                       'psName': 'Devilbane-Regular', 'version': 'Version 1.000'})
    fb.setupOS2(sTypoAscender=900, sTypoDescender=-260, sTypoLineGap=0, usWinAscent=920,
                usWinDescent=280, sxHeight=XH, sCapHeight=CH, achVendID='DVLB')
    fb.setupPost()
    fb.font['head'].fontRevision = 1.0
    fb.save(out)
    print('wrote', out, len(order), 'glyphs')


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else 'Devilbane-Regular.ttf')
