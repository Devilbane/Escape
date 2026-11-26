"""Builds the sounds of the water's small life from noise and tones, like tools/make_sounds.py (whose
helpers it uses): the soft splash of a fish breaking the surface or diving (water_splash_*) and the
smaller, quieter splash of a ring of ripples spreading (water_ripple_*). Several of each, all a little
different. Played by IceFish (scripts/ice_fish.gd). Made from scratch, no recordings.
Run: python3 tools/make_water_sounds.py"""
import numpy as np
from make_sounds import SR, OUT, t, lowpass, highpass, env, save

rng = np.random.default_rng(91)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def add(out, x, at):
    i = int(SR * at)
    if i < len(out):
        out[i:i + len(x)] += x[:len(out) - i]


def splash(sec, low, high, body, droplets, bright):
    # Water thrown up and falling back: a soft wash of noise (rises fast, dies away), a low "whump" of the
    # water closing, and a few small droplets pattering down after it, each a tiny falling-pitch plink.
    n = int(SR * sec)
    tt = t(sec)
    wash = lowpass(highpass(noise(sec), low), high) * env(n, 0.006, 0.07 * bright)
    # A second, softer splatter a moment later, as the water falls back.
    splatter = lowpass(highpass(noise(sec), low * 1.4), high * 0.8) * env(n, 0.03, 0.09) * 0.45
    out = wash + np.concatenate([np.zeros(int(SR * 0.05)), splatter])[:n]
    whump = lowpass(noise(sec), 420) * env(n, 0.012, 0.09) * body
    out += whump
    for _ in range(droplets):
        at = rng.uniform(0.04, sec * 0.7)
        pitch = rng.uniform(1700, 3600)
        d = t(0.05)
        f = pitch * (1 - 0.4 * d / 0.05)
        ping = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(d), 0.001, 0.012) * rng.uniform(0.05, 0.14)
        add(out, ping, at)
    return out


if __name__ == "__main__":
    # A fish breaking the surface or diving: a soft splash, 0.35 to 0.5 s.
    for i in range(4):
        save("water_splash_%d" % i,
             splash(rng.uniform(0.38, 0.52), rng.uniform(500, 800), rng.uniform(2800, 3800),
                    rng.uniform(0.5, 0.9), int(rng.integers(3, 7)), rng.uniform(0.8, 1.2)), 0.5)
    # The ring spreading where a fish stirred: a smaller, shorter splash, softer and without the heavy whump.
    for i in range(4):
        save("water_ripple_%d" % i,
             splash(rng.uniform(0.22, 0.32), rng.uniform(900, 1300), rng.uniform(2400, 3200),
                    rng.uniform(0.1, 0.3), int(rng.integers(1, 4)), rng.uniform(0.5, 0.8)), 0.3)
