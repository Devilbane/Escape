"""Builds the coin sounds from scratch: a single coin (coin), a coin or two
(coins_small_*) and a handful of gold (coins_big_*).
Each clink is a struck metal disc: a hard click and a few bright, inharmonic
ringing partials (the modes of a thin plate) that die away fast, the higher
ones first. Written at 44.1 kHz, so the shine above 11 kHz survives, which is
what makes them sound crisp. No recordings, so there are no licences to worry
about. Needs numpy. Run: python3 tools/make_coin_sounds.py"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(23)

# The ringing modes of a thin metal disc, as multiples of the lowest one.
MODES = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.50, 4.06]


def highpass(x, cutoff):
    # One-pole high-pass: keeps the click sharp, takes the thump out.
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev_x = 0.0
    prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = a * (prev_y + v - prev_x)
        prev_x = v
        y[i] = prev_y
    return y


def clink(base, ring, gain=1.0):
    """One coin struck: `base` the lowest partial (Hz), `ring` how long the
    lowest one rings (s)."""
    n = int(SR * (ring * 5 + 0.01))
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for i, m in enumerate(MODES):
        f = base * m * rng.uniform(0.985, 1.015)
        if f > SR * 0.45:
            break
        # Higher partials are quieter and die sooner.
        amp = rng.uniform(0.5, 1.0) / (1 + i * 0.35)
        decay = ring / (1 + i * 0.6)
        out += amp * np.sin(2 * np.pi * f * tt + rng.uniform(0, np.pi)) * np.exp(-tt / decay)
    # The strike itself: a 2 ms burst of bright noise.
    k = int(SR * 0.002)
    click = highpass(rng.uniform(-1, 1, k), 5000) * np.linspace(1, 0, k) ** 2
    out[:k] += click * 1.6
    # A hair of attack, so it does not pop.
    a = int(SR * 0.0004)
    out[:a] *= np.linspace(0, 1, a)
    return out * gain


def lay(parts, length):
    """parts: (sound, at seconds). Lays them over each other."""
    out = np.zeros(int(SR * length))
    for x, at in parts:
        s = int(SR * at)
        e = min(len(out), s + len(x))
        out[s:e] += x[: e - s]
    return out


def save(name, x, peak=0.8):
    x = np.concatenate([x, np.zeros(int(SR * 0.03))])
    # Cut the tail where it has gone quiet.
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 0.004)[0]
    x = x[: loud[-1] + int(SR * 0.02)]
    f = min(len(x), int(SR * 0.03))
    x[-f:] *= np.linspace(1, 0, f)
    x = x / max(1e-6, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def small(seed_hits):
    """A coin or two: a clear ting, maybe a smaller one bouncing after it."""
    parts = []
    at = 0.0
    for i, (base, ring) in enumerate(seed_hits):
        parts.append((clink(base, ring, 1.0 if i == 0 else 0.55), at))
        at += rng.uniform(0.06, 0.11)
    return lay(parts, 0.6)


def handful(count, length):
    """A handful of gold poured out: many short coin-on-coin clicks, thickest
    at the start, with a few coins ringing out over them."""
    parts = []
    for i in range(count):
        at = length * 0.75 * (rng.uniform(0, 1) ** 1.8)
        ringing = rng.uniform() < 0.25
        base = rng.uniform(2600, 4200)
        ring = rng.uniform(0.12, 0.22) if ringing else rng.uniform(0.02, 0.05)
        parts.append((clink(base, ring, rng.uniform(0.4, 1.0)), at))
    # One clear coin on top, right away.
    parts.append((clink(rng.uniform(2900, 3300), 0.25, 1.0), 0.0))
    return lay(parts, length)


def build():
    save("coin", small([(3150, 0.24), (3900, 0.12)]), 0.55)
    save("coins_small_0", small([(2950, 0.2)]), 0.6)
    save("coins_small_1", small([(3300, 0.18), (3700, 0.1)]), 0.6)
    save("coins_small_2", small([(2750, 0.22), (3450, 0.09), (4000, 0.06)]), 0.6)
    save("coins_big_0", handful(16, 0.75), 0.7)
    save("coins_big_1", handful(22, 0.9), 0.7)
    save("coins_big_2", handful(12, 0.6), 0.7)


if __name__ == "__main__":
    build()
