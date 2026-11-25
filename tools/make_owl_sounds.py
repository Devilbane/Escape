"""Builds the tawny owl's calls (see scripts/owls.gd): owl_hoot_0.wav, owl_hoot_1.wav and owl_hoot_2.wav.

Made from scratch (a gliding voice tone with a few harmonics, a soft breath of noise and a slow quaver), so
there is no recording and no licence to credit.
 0: the long, quavering "hoo-oo-oooo" of a male tawny owl.
 1: the "hu... hu-hoooo" call: a short note, a pause, a short note and a long falling one.
 2: a soft, short "hoo" (the answer of a second owl).
Run: python3 tools/make_owl_sounds.py   (writes assets/sounds/owl_hoot_*.wav)"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(11)


def lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1.0 - a) * x[i] + a * s
        y[i] = s
    return y


def note(dur, f_start, f_end, quaver=0.0, quaver_hz=9.0, breath=0.05, attack=0.08, release=0.25):
    """One hoot: pitch glides from f_start to f_end; an optional quaver wobbles pitch and loudness."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    u = t / dur
    f = f_start + (f_end - f_start) * u ** 0.8
    f = f * (1.0 + 0.012 * quaver * np.sin(2 * np.pi * quaver_hz * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.38 * np.sin(2 * phase + 0.4) + 0.14 * np.sin(3 * phase + 1.1) + 0.05 * np.sin(4 * phase)
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (dur - t) / release)
    env = env ** 1.5
    env *= 1.0 - 0.22 * quaver * (0.5 + 0.5 * np.sin(2 * np.pi * quaver_hz * t + 1.0))
    air = lowpass(rng.standard_normal(n), 900.0) * breath * 6.0
    return (tone + air) * env


def silence(d):
    return np.zeros(int(SR * d))


def finish(parts, name):
    x = np.concatenate(parts)
    # A touch of room: two faint echoes, as if the call carried across the woods.
    for delay, gain in ((0.23, 0.22), (0.47, 0.1)):
        k = int(SR * delay)
        e = np.zeros_like(x)
        e[k:] = x[:-k] * gain
        x = x + e
    x = lowpass(x, 3200.0)
    x -= x.mean()
    x *= 0.8 / np.abs(x).max()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


finish([note(0.9, 470, 430, 0.1), silence(0.12), note(1.8, 440, 360, 1.0, 8.0)], "owl_hoot_0.wav")
finish([note(0.28, 420, 410, 0.0, attack=0.04, release=0.1), silence(0.55),
        note(0.26, 420, 410, 0.0, attack=0.04, release=0.1), silence(0.1),
        note(1.9, 450, 330, 1.0, 7.0)], "owl_hoot_1.wav")
finish([note(0.7, 500, 470, 0.15)], "owl_hoot_2.wav")
