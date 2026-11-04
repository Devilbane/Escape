"""Builds the coin sounds from scratch: a single coin (coin), a few coins
(coins_small_*) and a handful of gold (coins_big_*).
Every sound is many coins jingling against each other. Each clink has two
parts:
- the impact: a short burst of bright noise with some body in it (coin
  knocking on coin, a few milliseconds of "chk"), plus a faint dull knock
  of weight;
- the ring: a few inharmonic partials of a thin metal disc, each as a close
  pair a few hertz apart so it shimmers like metal. Coins lying in a heap
  touch each other, so the ring is damped fast, the high partials fastest.
  That keeps them from ringing on like wind chimes.
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


def one_pole(x, cutoff, high):
    # One-pole low-pass, or the high-pass that is what it leaves out.
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return x - y if high else y


def band(x, low, high):
    return one_pole(one_pole(x, low, True), high, False)


def clink(base, ring, gain=1.0, weight=0.5):
    """One coin knocking on another: `base` the lowest partial (Hz), `ring`
    how long the lowest one rings (s), `weight` how much of the dull knock."""
    n = int(SR * (ring * 6 + 0.03))
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for i, m in enumerate(MODES):
        f = base * m * rng.uniform(0.99, 1.01)
        if f > SR * 0.46:
            break
        amp = rng.uniform(0.5, 1.0) / (1 + i * 0.3)
        # Touching coins damp the high partials hardest.
        decay = ring / (1 + i * 0.5)
        beat = rng.uniform(3.0, 10.0)
        phase = rng.uniform(0, np.pi)
        pair = np.sin(2 * np.pi * f * tt + phase) + 0.6 * np.sin(2 * np.pi * (f + beat) * tt + phase * 1.7)
        out += amp * pair * np.exp(-tt / decay)
    # The impact: a few milliseconds of noise in the coins' own range ...
    k = int(SR * 0.012)
    hit = band(rng.uniform(-1, 1, k), 1500, 9000) * np.exp(-np.arange(k) / (SR * 0.0025))
    out[:k] += hit * 4.0
    # ... and a short, dull knock of the metal's weight.
    k = int(SR * 0.025)
    tk = np.arange(k) / SR
    knock = np.sin(2 * np.pi * rng.uniform(700, 1100) * tk) * np.exp(-tk / 0.006)
    out[:k] += knock * weight * 1.5
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
    # Nothing as low as a thud from the floor: this is coins only.
    x = one_pole(x, 400, True)
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


def jingle(count, spread, length, ringing=0.25):
    """`count` coins jingling over `spread` seconds: thickest at the start,
    thinning out as they settle. Most are short knocks of coin on coin;
    some (`ringing`) ring a little longer over them."""
    parts = []
    for _ in range(count):
        at = spread * rng.uniform(0, 1) ** 1.6
        base = rng.uniform(2800, 5000)
        if rng.uniform() < ringing:
            ring = rng.uniform(0.035, 0.065)
            gain = rng.uniform(0.5, 0.9)
        else:
            ring = rng.uniform(0.01, 0.025)
            gain = rng.uniform(0.35, 1.0)
        parts.append((clink(base, ring, gain, rng.uniform(0.2, 0.7)), at))
    # The first coins land clearly, with weight.
    parts.append((clink(rng.uniform(3200, 3900), 0.06, 1.0, 1.0), 0.0))
    return lay(parts, length)


def build():
    # One coin (shops, the bank): a couple of solid clinks.
    save("coin", jingle(4, 0.1, 0.4, 0.5), 0.55)
    # A coin or a few: a short jingle.
    save("coins_small_0", jingle(7, 0.16, 0.45), 0.6)
    save("coins_small_1", jingle(9, 0.2, 0.5), 0.6)
    save("coins_small_2", jingle(6, 0.14, 0.42), 0.6)
    # A handful of gold: a long, dense jingle.
    save("coins_big_0", jingle(45, 0.65, 0.95), 0.7)
    save("coins_big_1", jingle(60, 0.8, 1.1), 0.7)
    save("coins_big_2", jingle(38, 0.55, 0.85), 0.7)


if __name__ == "__main__":
    build()
