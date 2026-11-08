"""Builds the village's alarm horn (see WarHorn, scripts/war_horn.gd):

  war_horn  two long, deep blasts like the fog horn of a big ship, a low hum with
            a rich stack of overtones, swelling in slowly and fading out slowly

The note sits near 58 Hz with a second voice a hair off it (the slow throb of a big
horn), plus a breath of air in the mouth. Nothing is downloaded: it is all
synthesised here.

Run from the tools folder: python3 make_horn_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, save

BASE = 58.0
# (overtone, loudness): a horn's tube gives the odd ones a little extra.
OVERTONES = [(1, 1.0), (2, 0.8), (3, 0.7), (4, 0.45), (5, 0.38), (6, 0.22), (7, 0.18), (8, 0.1), (10, 0.06)]


def blast(sec=3.0, attack=0.45, release=1.0):
    tt = t(sec)
    # The pitch sags in as the horn fills, then holds, then dips a little as the air runs out.
    pitch = 1.0 + 0.05 * np.exp(-tt / 0.25) - 0.02 * np.clip((tt - (sec - release)) / release, 0, 1)
    out = np.zeros(len(tt))
    for detune in (1.0, 1.012):
        phase = 2 * np.pi * np.cumsum(BASE * detune * pitch) / SR
        for n, vol in OVERTONES:
            out += vol * np.sin(n * phase)
    out = np.tanh(out / 3.0 * 1.6)  # a soft push into the brass
    air = lowpass(noise(sec), 400) * 0.35
    out += air * np.clip(tt / attack, 0, 1)
    swell = np.clip(tt / attack, 0, 1) ** 1.6
    fade = np.clip((sec - tt) / release, 0, 1) ** 1.3
    return out * swell * fade


def horn(blasts=2, gap=0.5):
    one = blast()
    n = len(one)
    out = np.zeros(int((n + SR * gap) * (blasts - 1)) + n)
    for i in range(blasts):
        a = int((n + SR * gap) * i)
        out[a:a + n] += one * (1.0 - 0.06 * i)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("war_horn", horn(), 0.85)
