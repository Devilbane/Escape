"""Paints stained glass into the temple's windows.

The Modular Cathedral Kit's window atlas (assets/chapel/window_diffuse.png)
has the stone tracery of each window drawn twice: the lower row seen from
inside (light, clear glass) and the upper row seen from outside (dark glass),
128 px apart. This keeps the stone and fills every opening with coloured
panes held in lead, like the windows of a real church:

- the tall lancets: a border of red and gold beads, a medallion in each
  panel (quartered in ruby and green round a golden boss) on a blue ground
  of diamond quarries, with an iron saddle bar between the panels;
- the rose: rings of colour round a golden heart, ruby and blue petals
  turn about, the small openings round the rim in green, purple and amber;
- the small foils in the tracery: petals round a golden middle.

The openings are found in the lower row (the bright, checkered glass) and
the same shapes are filled in the upper row. The outside panes come out a
little darker, as glass looks from the street by day.

Writes two pictures next to the kit's:
- stained_glass.png: the atlas with the coloured glass (albedo);
- stained_glass_glow.png: only the glass, black elsewhere, so that at night
  the panes light up and the stone round them stays dark.

Needs numpy and Pillow. Run: python3 tools/make_stained_glass.py"""
import os
import numpy as np
from PIL import Image, ImageFilter

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "chapel")
SCALE = 2  # 256 px kit atlas -> 512 px, so the lead lines stay crisp
ROW = 128  # the upper (outside) row sits this far above the lower one
rng = np.random.default_rng(7)

GLASS = {
	"ruby": (0.72, 0.07, 0.10),
	"cobalt": (0.10, 0.20, 0.66),
	"sky": (0.30, 0.55, 0.86),
	"gold": (0.95, 0.72, 0.16),
	"emerald": (0.08, 0.52, 0.26),
	"purple": (0.46, 0.14, 0.56),
	"amber": (0.88, 0.46, 0.10),
	"pale": (0.92, 0.88, 0.72),
}
LEAD = np.array((0.10, 0.09, 0.09))
OUTSIDE = 0.8  # how bright the outside panes are against the inside ones


def glass_mask(src: Image.Image) -> np.ndarray:
	"""The openings of the lower row, at the output size (0..1, soft edge)."""
	grey = src.convert("L").filter(ImageFilter.BoxBlur(1))
	a = np.asarray(grey).astype(float)
	m = np.zeros_like(a)
	m[ROW:] = (a[ROW:] > 170).astype(float)
	big = Image.fromarray((m * 255).astype(np.uint8)).resize(
		(src.width * SCALE, src.height * SCALE), Image.BILINEAR
	).filter(ImageFilter.GaussianBlur(0.8))
	return np.clip((np.asarray(big).astype(float) / 255.0 - 0.35) * 3.0, 0.0, 1.0)


def components(mask: np.ndarray) -> np.ndarray:
	"""Labels every opening (4-connected flood fill)."""
	h, w = mask.shape
	solid = mask > 0.5
	labels = np.zeros((h, w), int)
	n = 0
	for y in range(h):
		for x in range(w):
			if solid[y, x] and labels[y, x] == 0:
				n += 1
				stack = [(y, x)]
				labels[y, x] = n
				while stack:
					cy, cx = stack.pop()
					for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
						if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and labels[ny, nx] == 0:
							labels[ny, nx] = n
							stack.append((ny, nx))
	return labels


def near(value: np.ndarray, step: float, width: float) -> np.ndarray:
	"""True close to every multiple of step: a lead line."""
	d = np.abs((value + step / 2) % step - step / 2)
	return d < width


def paint_lancet(ys, xs, top, x0, x1):
	"""Bead border, a medallion per panel on a ground of blue quarries."""
	w = x1 - x0 + 1
	u = (xs - x0) / w
	v = ys - top
	colour = np.zeros((len(ys), 3))
	lead = np.zeros(len(ys), bool)
	border = (u < 0.17) | (u > 0.83)
	bead = (v // 6).astype(int) % 2
	colour[border] = np.where(bead[border, None] == 0, GLASS["ruby"], GLASS["gold"])
	lead |= border & near(v, 6.0, 0.6)
	lead |= np.abs(u - 0.17) < 0.6 / w
	lead |= np.abs(u - 0.83) < 0.6 / w
	panel = 2.4 * w
	pv = v % panel
	inner = ~border
	# The ground: blue diamond quarries, a few of them sky blue.
	qa = (xs + v) / 7.0
	qb = (xs - v) / 7.0
	cell = (np.floor(qa).astype(int) * 7 + np.floor(qb).astype(int) * 13) % 5
	colour[inner] = np.where(cell[inner, None] == 0, GLASS["sky"], GLASS["cobalt"])
	lead |= inner & (near(qa * 7.0, 7.0, 0.55) | near(qb * 7.0, 7.0, 0.55))
	# The medallion, quartered round a golden boss.
	cx = x0 + w / 2.0
	dx = xs - cx
	dy = pv - panel / 2.0
	r = np.hypot(dx, dy)
	rad = 0.36 * w
	med = inner & (r < rad)
	quarter = ((dx > 0).astype(int) + (dy > 0).astype(int)) % 2
	colour[med] = np.where(quarter[med, None] == 0, GLASS["ruby"], GLASS["emerald"])
	boss = inner & (r < rad * 0.38)
	colour[boss] = GLASS["gold"]
	lead[med] = False
	lead |= inner & (np.abs(r - rad) < 0.7)
	lead |= inner & (np.abs(r - rad * 0.38) < 0.6)
	lead |= med & ~boss & ((np.abs(dx) < 0.55) | (np.abs(dy) < 0.55))
	# The saddle bar between the panels.
	lead |= near(v - panel, panel, 1.0) & (v > 4)
	return colour, lead


def paint_foil(ys, xs, cy, cx, size, petals, ring):
	"""Petals turning about a golden middle."""
	dx = xs - cx
	dy = ys - cy
	r = np.hypot(dx, dy)
	ang = np.arctan2(dy, dx)
	sector = np.floor((ang + np.pi) / (2 * np.pi) * petals).astype(int) % petals
	colour = np.where((sector % 2 == 0)[:, None], GLASS[ring[0]], GLASS[ring[1]])
	middle = r < size * 0.32
	colour[middle] = GLASS["gold"]
	lead = np.abs(r - size * 0.32) < 0.6
	edge = (ang + np.pi) / (2 * np.pi) * petals
	lead |= ~middle & (np.abs(edge - np.round(edge)) * r * 2 * np.pi / petals < 0.6)
	return colour, lead


def paint_rose_piece(ys, xs, rcy, rcx, rr, index):
	"""A piece of the rose: rings of colour, out from the golden heart."""
	dx = xs - rcx
	dy = ys - rcy
	r = np.hypot(dx, dy) / rr
	ang = np.arctan2(dy, dx)
	mid = np.arctan2(ys.mean() - rcy, xs.mean() - rcx)
	reach = np.hypot(ys.mean() - rcy, xs.mean() - rcx) / rr
	colour = np.zeros((len(ys), 3))
	if reach < 0.12:
		colour[:] = GLASS["gold"]
		inner = r < 0.06
		colour[inner] = GLASS["ruby"]
		return colour, np.abs(r - 0.06) * rr < 0.6
	if reach > 0.72:
		pick = ["emerald", "purple", "amber"][index % 3]
		colour[:] = GLASS[pick]
		ring = r > 0.86
		colour[ring] = GLASS["gold"] if pick != "amber" else GLASS["ruby"]
		return colour, np.abs(r - 0.86) * rr < 0.6
	# A petal: blue and ruby turn about, a golden tip, a lead down its middle.
	first, second = ("cobalt", "ruby") if index % 2 == 0 else ("ruby", "cobalt")
	colour[:] = GLASS[first]
	colour[r > 0.42] = GLASS[second]
	colour[r > 0.74] = GLASS["gold"]
	lead = (np.abs(r - 0.42) * rr < 0.6) | (np.abs(r - 0.74) * rr < 0.6)
	off = np.angle(np.exp(1j * (ang - mid)))
	lead |= np.abs(off) * r * rr < 0.55
	return colour, lead


def main():
	src = Image.open(os.path.join(DIR, "window_diffuse.png")).convert("RGB")
	size = (src.width * SCALE, src.height * SCALE)
	base = np.asarray(src.resize(size, Image.BICUBIC)).astype(float) / 255.0
	mask = glass_mask(src)
	labels = components(mask)
	h, w = mask.shape
	paint = np.zeros((h, w, 3))
	# The rose is the big round group of openings on the right.
	ry, rx = np.nonzero((labels > 0) & (np.arange(w)[None, :] > w * 0.53))
	rcy, rcx = (ry.min() + ry.max()) / 2.0, (rx.min() + rx.max()) / 2.0
	rr = max(ry.max() - ry.min(), rx.max() - rx.min()) / 2.0
	rose_pieces = []
	for n in range(1, labels.max() + 1):
		ys, xs = np.nonzero(labels == n)
		if len(ys) < 6:
			continue
		top, bottom, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
		hh, ww = bottom - top + 1, x1 - x0 + 1
		if x0 > w * 0.53:
			rose_pieces.append((np.arctan2(ys.mean() - rcy, xs.mean() - rcx), n, ys, xs))
			continue
		if hh > 2.2 * ww and hh > 30:
			colour, lead = paint_lancet(ys, xs, top, x0, x1)
		else:
			cy, cx = ys.mean(), xs.mean()
			big = max(hh, ww) / 2.0
			petals = 4 if big > 12 else 3
			ring = ("ruby", "cobalt") if big > 12 else (("emerald", "amber") if n % 2 else ("purple", "gold"))
			colour, lead = paint_foil(ys, xs, cy, cx, big, petals, ring)
		colour = colour.copy()
		colour[lead] = LEAD
		paint[ys, xs] = colour
	# Number the rose's pieces round the wheel so the colours turn about.
	petal_i = rim_i = 0
	for _, n, ys, xs in sorted(rose_pieces):
		reach = np.hypot(ys.mean() - rcy, xs.mean() - rcx) / rr
		index = rim_i if reach > 0.72 else petal_i
		colour, lead = paint_rose_piece(ys, xs, rcy, rcx, rr, index)
		if reach > 0.72:
			rim_i += 1
		else:
			petal_i += 1
		colour[lead] = LEAD
		paint[ys, xs] = colour
	# The glass is never quite even: each piece a little lighter or darker,
	# with faint streaks running down it.
	grain = np.asarray(Image.fromarray((rng.random((h // 4, w // 4)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(float) / 255.0
	streak = np.asarray(Image.fromarray((rng.random((h // 16, w)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(float) / 255.0
	paint *= (0.86 + 0.14 * grain + 0.08 * (streak - 0.5))[..., None]
	# Lead lines darken a hair into the glass round them.
	is_lead = np.all(np.abs(paint - LEAD) < 0.02, axis=2) & (mask > 0.5)
	soft = np.asarray(Image.fromarray((is_lead * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))).astype(float) / 255.0
	paint *= (1.0 - 0.45 * soft)[..., None]
	paint = np.clip(paint, 0.0, 1.0)
	# Spread the colours a few pixels past the openings, under the soft edge
	# where glass meets stone.
	for _ in range(3):
		empty = paint.sum(axis=2) == 0
		grown = np.stack([np.asarray(Image.fromarray((paint[..., c] * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))).astype(float) / 255.0 for c in range(3)], axis=2)
		paint[empty] = grown[empty]
	# The same panes in the upper row, seen from outside.
	up = ROW * SCALE
	inside_mask = mask.copy()
	outside_mask = np.zeros_like(mask)
	outside_mask[:-up] = mask[up:]
	outside = np.zeros_like(paint)
	outside[:-up] = paint[up:] * OUTSIDE
	glass = paint + outside
	m = np.maximum(inside_mask, outside_mask)[..., None]
	albedo = base * (1.0 - m) + glass * m
	glow = glass * m
	Image.fromarray((albedo * 255).round().astype(np.uint8)).save(os.path.join(DIR, "stained_glass.png"))
	Image.fromarray((glow * 255).round().astype(np.uint8)).save(os.path.join(DIR, "stained_glass_glow.png"))
	print("wrote stained_glass.png and stained_glass_glow.png", size)


if __name__ == "__main__":
	main()
