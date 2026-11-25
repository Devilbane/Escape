"""Builds the sounds of the water's small life from noise and tones, like tools/make_sounds.py (whose
helpers it uses): the plop of a fish breaking the surface, the splash of its dive, and the faint blip of a
ring of ripples. Played by IceFish (scripts/ice_fish.gd).
Run: python3 tools/make_water_sounds.py"""
import numpy as np
from make_sounds import SR, OUT, t, lowpass, highpass, env, save

rng = np.random.default_rng(91)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def plop(pitch, sec=0.35):
    # A little air bubble closing over a fin: a soft "bloop" whose pitch rises, a breath of splash.
    tt = t(sec)
    f = pitch * (1 + np.minimum(tt, 0.06) * 9)
    bloop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.004, 0.07)
    wash = highpass(noise(sec), 1800) * env(len(tt), 0.002, 0.03) * 0.18
    return lowpass(bloop + wash, 3500)


def dive(sec=0.5):
    # A quick, soft flick of water: noise through a falling band, with a small bloop at the end.
    tt = t(sec)
    x = noise(sec)
    x = lowpass(highpass(x, 700), 2600) * env(len(tt), 0.01, 0.09)
    tail = plop(330, sec) * 0.5
    out = np.zeros(len(tt))
    out += x * 0.8
    start = int(SR * 0.08)
    out[start:] += tail[: len(tt) - start]
    return out


def blip(sec=0.25):
    # The faintest sound of a ring starting: one tiny, high drop.
    tt = t(sec)
    f = 1500 * (1 + np.minimum(tt, 0.03) * 12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.002, 0.03) * 0.6


if __name__ == "__main__":
    for i, p in enumerate((520, 600, 690)):
        save("water_plop_%d" % i, plop(p), 0.5)
    for i in range(2):
        save("water_dive_%d" % i, dive(), 0.5)
    save("water_ring", blip(), 0.3)
