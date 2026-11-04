"""Builds the coin sounds from scratch: a single coin (coin), a few coins
(coins_small_*) and a handful of gold (coins_big_*).
Every sound is many small coins jingling against each other, light and
metallic: each clink is a thin metal disc struck, a tiny click and a few high,
inharmonic partials (the modes of a thin plate). Every partial rings as a
close pair, a few hertz apart, so it shimmers like real metal instead of
beeping. The lowest partials sit high (3.6-6 kHz), and nothing below about
2 kHz is kept, so the coins sound small and light, not like bells.
Written at 44.1 kHz, so the shine above 11 kHz survives. No recordings, so
there are no licences to worry about. Needs numpy.
Run: python3 tools/make_coin_sounds.py"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(31)

# The ringing modes of a thin metal disc, as multiples of the lowest one.
MODES = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.50]


def highpass(x, cutoff):
    # One-pole high-pass, run twice: takes away any body below the coins.
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(2):
        y = np.zeros_like(x)
        prev_x = 0.0
        prev_y = 0.0
        for i, v in enumerate(x):
            prev_y = a * (prev_y + v - prev_x)
            prev_x = v
            y[i] = prev_y
        x = y
    return x


def clink(base, ring, gain=1.0):
    """One small coin struck: `base` the lowest partial (Hz), `ring` how long
    the partials ring (s)."""
    n = int(SR * (ring * 5 + 0.01))
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for i, m in enumerate(MODES):
        f = base * m * rng.uniform(0.99, 1.01)
        if f > SR * 0.46:
            break
        # The upper partials carry the sound; they ring nearly as long as
        # the lowest, which is what makes it metallic.
        amp = rng.uniform(0.5, 1.0) / (1 + i * 0.15)
        decay = ring / (1 + i * 0.18)
        beat = rng.uniform(2.0, 9.0)
        phase = rng.uniform(0, np.pi)
        pair = np.sin(2 * np.pi * f * tt + phase) + 0.7 * np.sin(2 * np.pi * (f + beat) * tt + phase * 1.7)
        out += amp * pair * np.exp(-tt / decay)
    # The tick of coin on coin: a 1 ms burst of very bright noise.
    k = int(SR * 0.001)
    out[:k] += rng.uniform(-1, 1, k) * np.linspace(1, 0, k) * 1.2
    a = int(SR * 0.0003)
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
    x = highpass(x, 1800)
    x = np.concatenate([x, np.zeros(int(SR * 0.03))])
    # Cut the tail where it has gone quiet.
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 0.004)[0]
    x = x[: loud[-1] + int(SR * 0.02)]
    f = min(len(x), int(SR * 0.04))
    x[-f:] *= np.linspace(1, 0, f)
    x = x / max(1e-6, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def jingle(count, spread, length, ringing=0.3):
    """`count` coins jingling over `spread` seconds: thickest at the start,
    thinning out as they settle. Most are short ticks of coin on coin; some
    (`ringing`) ring out over them."""
    parts = []
    for _ in range(count):
        at = spread * rng.uniform(0, 1) ** 1.6
        base = rng.uniform(3600, 6200)
        if rng.uniform() < ringing:
            ring = rng.uniform(0.07, 0.14)
            gain = rng.uniform(0.5, 0.9)
        else:
            ring = rng.uniform(0.015, 0.04)
            gain = rng.uniform(0.35, 1.0)
        parts.append((clink(base, ring, gain), at))
    # The first coin lands clearly.
    parts.append((clink(rng.uniform(4200, 5000), 0.12, 1.0), 0.0))
    return lay(parts, length)


def build():
    # One coin (shops, the bank): a bright ting with a couple of clinks.
    save("coin", jingle(4, 0.12, 0.5, 0.5), 0.55)
    # A coin or a few: a short jingle.
    save("coins_small_0", jingle(7, 0.18, 0.55), 0.6)
    save("coins_small_1", jingle(9, 0.22, 0.6), 0.6)
    save("coins_small_2", jingle(6, 0.16, 0.5), 0.6)
    # A handful of gold: a long, dense jingle.
    save("coins_big_0", jingle(45, 0.7, 1.1), 0.7)
    save("coins_big_1", jingle(60, 0.85, 1.25), 0.7)
    save("coins_big_2", jingle(38, 0.6, 1.0), 0.7)


if __name__ == "__main__":
    build()
