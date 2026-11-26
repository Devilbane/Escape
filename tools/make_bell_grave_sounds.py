"""Builds the sounds of the safety-coffin grave (see scripts/bell_grave.gd):

  bell_tiny    a tiny bell rung in a hurry on a cord: bright, high and sharp, many strikes thrown together
               (a small bell is hard to hear, so it is all upper partials and a hard click, which cut
               through the night's ambience from far away)
  grave_scream the scream of someone who is already dead: a rising, rough, pressed voice
  grave_whimper what is left of the voice a little too late: a faint, breathy, falling whimper

Synthesised from scratch (no recordings, nothing to credit).
Run from the tools folder: python3 make_bell_grave_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, save

rng = np.random.default_rng(11)

# A small bronze bell: (frequency ratio to the prime, loudness, ring time in seconds). The prime is high, so the
# first partials already sit in the bright part of the ear's range.
PARTIALS = [(1.0, 0.7, 1.5), (2.0, 0.55, 1.0), (2.76, 0.9, 0.8), (4.07, 0.5, 0.5), (5.4, 0.45, 0.35)]
PRIME = 1560.0
# When the strikes fall (seconds) and how hard: a hand pulling the cord in a panic that slowly gives out.
STRIKES = [(0.0, 1.0), (0.17, 0.85), (0.29, 0.95), (0.47, 0.8), (0.60, 0.9), (0.82, 0.75), (1.0, 0.85), (1.3, 0.7),
           (1.62, 0.75), (2.05, 0.6), (2.6, 0.5), (3.3, 0.35)]


def strike(sec, pitch):
    tt = t(sec)
    out = np.zeros(len(tt))
    for ratio, vol, ring in PARTIALS:
        beat = 1 + 0.0025 * np.sin(2 * np.pi * (5.0 + ratio) * tt)
        out += vol * np.sin(2 * np.pi * PRIME * pitch * ratio * tt * beat) * np.exp(-tt / ring)
    click = highpass(noise(sec), 3000) * np.exp(-tt / 0.012)
    out = out / np.abs(out).max() + 0.55 * click
    out[: int(SR * 0.0015)] *= np.linspace(0, 1, int(SR * 0.0015))
    return out


def bell_tiny(sec=5.0):
    out = np.zeros(int(SR * sec))
    for when, gain in STRIKES:
        pitch = 1 + rng.uniform(-0.012, 0.012)
        s = strike(2.2, pitch) * gain
        k = int(SR * when)
        out[k:k + len(s)] += s[: len(out) - k]
    # The little cluck of the clapper on the post and the creak of the cord under it.
    return out


def resonator(x, freq, width):
    """Two-pole band-pass: a vowel's formant."""
    r = np.exp(-np.pi * width / SR)
    c1 = 2 * r * np.cos(2 * np.pi * freq / SR)
    c2 = -r * r
    y = np.zeros_like(x)
    a = b = 0.0
    for i, v in enumerate(x):
        n = (1 - r) * v + c1 * a + c2 * b
        y[i] = n
        b = a
        a = n
    return y


def voice(f0, dur, formants, rough, breath, seed):
    """A voiced sound whose pitch follows f0 (one value per sample): glottal pulses through the formants."""
    local = np.random.default_rng(seed)
    n = len(f0)
    phase = np.cumsum(f0) / SR
    # A pulse train with a little jitter, then smoothed into a glottal-ish shape.
    saw = (phase % 1.0)
    src = (1.0 - saw) ** 2 * 2 - 0.5
    src += rough * local.uniform(-1, 1, n) * 0.3
    out = np.zeros(n)
    for freq, width, gain in formants:
        out += gain * resonator(src, freq, width)
    out += breath * lowpass(local.uniform(-1, 1, n), 4500) * 0.5
    return out


def grave_scream(sec=1.9):
    tt = t(sec)
    n = len(tt)
    # The pitch jumps up, hangs high and shakes, then cracks down at the end.
    rise = np.minimum(1.0, tt / 0.12)
    base = 540 + 520 * rise ** 0.6 + 70 * np.sin(2 * np.pi * 6.5 * tt) * np.minimum(1.0, tt / 0.5)
    base = base * (1 - 0.22 * np.clip((tt - 1.35) / 0.55, 0, 1) ** 1.5)
    f0 = base + rng.normal(0, 7, n)
    formants = [(900, 130, 1.0), (1700, 170, 0.7), (2900, 250, 0.35), (4100, 350, 0.15)]
    out = voice(f0, sec, formants, rough=0.6, breath=0.5, seed=3)
    out = np.tanh(out * 2.6 / np.abs(out).max())
    env = np.minimum(1.0, tt / 0.03) * np.minimum(1.0, (sec - tt) / 0.5) ** 1.3
    env *= 0.85 + 0.15 * np.sin(2 * np.pi * 11 * tt)
    return highpass(out * env, 180)


def grave_whimper(sec=1.7):
    tt = t(sec)
    n = len(tt)
    out = np.zeros(n)
    # Two falling sobs, the second smaller.
    for start, length, top, gain in ((0.12, 0.65, 430, 1.0), (0.9, 0.6, 360, 0.6)):
        i0 = int(SR * start)
        m = int(SR * length)
        u = np.arange(m) / m
        f0 = top * (1 - 0.28 * u) + 14 * np.sin(2 * np.pi * 7 * u * length)
        part = voice(f0, length, [(450, 110, 1.0), (1150, 150, 0.5), (2500, 250, 0.2)], rough=0.1, breath=1.3, seed=5 + int(top))
        part *= np.minimum(1.0, u / 0.12) * (1 - u) ** 0.8 * gain
        out[i0:i0 + m] += part[: n - i0]
    return lowpass(out, 3600)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("bell_tiny", bell_tiny(), 0.97)
    save("grave_scream", grave_scream(), 0.9)
    save("grave_whimper", grave_whimper(), 0.35)
