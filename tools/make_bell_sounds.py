"""Builds the village's warning bell (see VillageBell, scripts/village_bell.gd):

  village_bell  three tolls of a classic church bell, struck about a second and
                a half apart, each ringing on under the next

A bell is a handful of inharmonic partials (hum, prime, tierce, quint, nominal,
...) that die away at different speeds, with a short clang of noise at the
strike. Nothing is downloaded: it is all synthesised here.

Run from the tools folder: python3 make_bell_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, save

# (frequency ratio to the prime, loudness, ring time in seconds)
PARTIALS = [(0.5, 0.8, 2.6), (1.0, 1.0, 2.2), (1.19, 0.6, 1.6), (1.5, 0.45, 1.3),
            (2.0, 0.55, 1.1), (2.51, 0.3, 0.8), (3.0, 0.25, 0.6), (4.07, 0.15, 0.4)]
PRIME = 392.0


def toll(sec=3.4):
    tt = t(sec)
    out = np.zeros(len(tt))
    for ratio, vol, ring in PARTIALS:
        beat = 1 + 0.0015 * np.sin(2 * np.pi * 1.7 * tt * ratio)  # the slow wobble of a cast bell
        out += vol * np.sin(2 * np.pi * PRIME * ratio * tt * beat) * np.exp(-tt / ring)
    # The clang of the clapper.
    clang = lowpass(highpass(noise(sec), 1200), 5000) * np.exp(-tt / 0.04)
    out = out / np.abs(out).max() + 0.25 * clang
    out[: int(SR * 0.003)] *= np.linspace(0, 1, int(SR * 0.003))
    return out


def bell(strokes=3, gap=1.5):
    one = toll()
    out = np.zeros(int(SR * (gap * (strokes - 1))) + len(one))
    for i in range(strokes):
        a = int(SR * gap * i)
        out[a:a + len(one)] += one * (1.0 - 0.08 * i)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("village_bell", bell(), 0.8)
