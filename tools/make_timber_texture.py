#!/usr/bin/env python3
"""Builds the oak of the houses' half-timber beams: assets/house/timber_oak.png (colour) and
timber_oak_n.png (normal map).

Tileable. The grain runs along x; one copy covers TIMBER_LENGTH metres along a beam and TIMBER_WIDTH
across it (see VillageHouse). Long fibres, cathedral rings, a few knots, dry cracks along the grain,
weathered silver-grey patches and dark damp streaks, so a beam is never one flat brown.

Usage: python3 tools/make_timber_texture.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "house")
W, H = 1024, 256
rng = np.random.default_rng(7)


def field(sx, sy):
    """Tileable noise with features `sx` pixels long along x and `sy` along y, 0 mean, 1 deviation."""
    white = rng.standard_normal((H, W))
    fy = np.fft.fftfreq(H)[:, None]
    fx = np.fft.fftfreq(W)[None, :]
    filt = np.exp(-((fx * sx) ** 2 + (fy * sy) ** 2) * 6.0)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    return (out - out.mean()) / out.std()


def norm(a):
    return (a - a.min()) / (a.max() - a.min())


yy, xx = np.mgrid[0:H, 0:W]
# Cathedral rings: stripes across the beam, bent by slow noise so they wander along it.
warp = field(260, 40) * 0.55 + field(90, 14) * 0.12
rings = 0.5 + 0.5 * np.sin(2 * np.pi * (yy / H * 5.0 + warp))
rings = rings ** 1.6
# Long fibres and fine pores.
fibres = norm(field(240, 1.6))
pores = norm(field(60, 1.2))
height = 0.45 * rings + 0.35 * fibres + 0.2 * pores

# Knots: dark whorls the rings bend round.
for kx, ky, kr in [(180, 70, 20), (590, 190, 26), (860, 40, 16)]:
    dx = (xx - kx + W / 2) % W - W / 2
    dy = (yy - ky + H / 2) % H - H / 2
    d = np.sqrt((dx / 1.7) ** 2 + dy ** 2) / kr
    whorl = np.exp(-d ** 2) * (0.5 + 0.5 * np.sin(d * 14))
    height = np.where(d < 1.4, height * (1 - 0.5 * np.exp(-d ** 2)) + 0.25 * whorl, height)
    height -= 0.35 * np.exp(-(d * 2.2) ** 2)

# Dry cracks along the grain: thin dark slits where a stretched ridge noise crosses zero.
crack_n = field(120, 2.5)
cracks = np.clip(1 - np.abs(crack_n) * 9.0, 0, 1) * (norm(field(300, 30)) > 0.62)
height -= 0.5 * cracks

h = norm(height)
# Colour: dark oak between a warm brown and a near-black grain line.
dark = np.array([0.16, 0.10, 0.065])
mid = np.array([0.37, 0.25, 0.16])
light = np.array([0.52, 0.37, 0.24])
t = h[..., None]
col = np.where(t < 0.5, dark + (mid - dark) * (t / 0.5), mid + (light - mid) * ((t - 0.5) / 0.5))
# Weathering: patches that have gone silver-grey and dry, and damp, darker streaks.
silver = norm(field(200, 60))[..., None]
grey = np.array([0.46, 0.43, 0.39])
col = col + (grey * (0.8 + 0.4 * h[..., None]) - col) * np.clip((silver - 0.58) * 3.0, 0, 0.7)
damp = norm(field(500, 8))[..., None]
col *= 1 - 0.28 * np.clip((damp - 0.6) * 3.0, 0, 1)
col *= 1 - 0.7 * cracks[..., None]
col *= 0.93 + 0.14 * norm(field(30, 30))[..., None]

Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "timber_oak.png"))

# Normal map from the height, wrapped so it tiles.
gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.0
gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 7.0
nz = np.ones_like(h)
ln = np.sqrt(gx ** 2 + gy ** 2 + nz ** 2)
nrm = np.stack([-gx / ln, gy / ln, nz / ln], -1)  # green up = OpenGL convention
Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, "timber_oak_n.png"))
print("done")
