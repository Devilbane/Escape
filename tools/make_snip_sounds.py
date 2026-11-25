"""Builds the scissor snips of the barber (snip_0 to snip_2) from scratch: the blades slide
across each other (a short rasp of bright noise), meet (a tick) and ring for a moment (two thin
metallic modes). Three takes, each a little different. No recordings, so no licences. Needs numpy.
Run: python3 tools/make_snip_sounds.py"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(5)


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def highpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return x - y


def snip(variant):
    n = int(SR * 0.2)
    out = np.zeros(n)
    t = np.arange(n) / SR
    # The blades sliding: a rasp that swells as they close.
    rasp_len = int(SR * (0.05 + 0.01 * variant))
    rasp = highpass(rng.normal(size=rasp_len), 3500) * np.linspace(0.2, 1.0, rasp_len) ** 2
    out[:rasp_len] += rasp * 0.55
    # The tick when they meet and the thin ring that follows.
    hit = rasp_len - int(SR * 0.004)
    f1 = 3300 + 260 * variant
    f2 = 5600 - 180 * variant
    tick = (np.sin(2 * np.pi * f1 * t) * 0.5 + np.sin(2 * np.pi * f2 * t) * 0.35) * env(n, 0.0004, 0.028)
    click = highpass(rng.normal(size=n), 6000) * env(n, 0.0002, 0.004)
    out[hit:] += (tick + click * 0.9)[: n - hit]
    out /= np.abs(out).max()
    return out * 0.8


for i in range(3):
    data = snip(i)
    path = os.path.join(OUT, "snip_%d.wav" % i)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())
    print("wrote", path)
