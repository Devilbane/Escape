"""Builds the sounds of the owl clock riddle (see scripts/owl_clock.gd):

  deathringer  one toll of the Deathringer: a bell cast far too deep, its partials slightly sour and
               its ring dying slowly, with a cold breath of noise under it
  owl_clock    the clear, round "hoo" of the owl that keeps the hours at the graveyard: one note
               a little higher and shorter than the woods' calls, so each can be counted

Synthesised from scratch (no recordings, nothing to credit).
Run from the tools folder: python3 make_deathringer_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, save

# (frequency ratio to the prime, loudness, ring time in seconds): a bell that rings sourly.
PARTIALS = [(0.5, 0.9, 3.4), (1.0, 1.0, 3.0), (1.17, 0.55, 2.2), (1.48, 0.4, 1.8),
            (2.0, 0.5, 1.5), (2.43, 0.3, 1.0), (2.97, 0.2, 0.7), (4.2, 0.12, 0.45)]
PRIME = 174.0


def deathringer(sec=5.0):
    tt = t(sec)
    out = np.zeros(len(tt))
    for ratio, vol, ring in PARTIALS:
        beat = 1 + 0.003 * np.sin(2 * np.pi * 1.3 * tt * ratio)
        out += vol * np.sin(2 * np.pi * PRIME * ratio * tt * beat) * np.exp(-tt / ring)
    clang = lowpass(highpass(noise(sec), 400), 2400) * np.exp(-tt / 0.07)
    breath = lowpass(noise(sec), 500) * np.exp(-tt / 1.6) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.8 * tt))
    out = out / np.abs(out).max() + 0.3 * clang + 0.12 * breath
    out[: int(SR * 0.004)] *= np.linspace(0, 1, int(SR * 0.004))
    return out


def owl_clock(dur=0.55):
    tt = t(dur)
    f = 520 - 60 * (tt / dur) ** 0.8
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase + 0.4) + 0.12 * np.sin(3 * phase + 1.1)
    env = np.minimum(1.0, tt / 0.05) * np.minimum(1.0, (dur - tt) / 0.22)
    out = (tone + lowpass(noise(dur), 900) * 0.25) * env ** 1.4
    pad = np.zeros(int(SR * 0.9))
    pad[: len(out)] = out
    for delay, gain in ((0.2, 0.2), (0.42, 0.09)):
        k = int(SR * delay)
        e = np.zeros_like(pad)
        e[k:] = pad[:-k] * gain
        pad = pad + e
    return lowpass(pad, 3200)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("deathringer", deathringer(), 0.85)
    save("owl_clock", owl_clock(), 0.8)
