"""Builds the far-off scream of the dragon that now and then flies over the open
air (see scripts/dragon_flyover.gd), from tones and noise like
tools/make_sounds.py (whose helpers it uses), so there is no licence to worry about.
Run: python3 tools/make_dragon_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, save

rng = np.random.default_rng(41)


def glide(points, sec):
    # A pitch curve through (time, Hz) points, eased between them.
    tt = t(sec)
    times = np.array([p[0] for p in points])
    freqs = np.array([p[1] for p in points])
    return np.interp(tt, times, freqs)


def voice(freq, sec, harmonics=14, rasp=0.55):
    # A harsh, reedy cry: many harmonics on a gliding pitch, shaken by a
    # throaty rattle (noise at the speed of a growl) and a slow vibrato.
    tt = t(sec)
    wobble = 1.0 + 0.025 * np.sin(2 * np.pi * 5.5 * tt) + 0.012 * lowpass(noise(sec), 8) * 8
    phase = 2 * np.pi * np.cumsum(freq * wobble) / SR
    x = np.zeros_like(tt)
    for k in range(1, harmonics + 1):
        # The middle harmonics a little stronger: a nasal, screeching colour.
        weight = (1.0 / k) * (1.4 if 3 <= k <= 6 else 1.0)
        x += weight * np.sin(k * phase + rng.uniform(0, 2 * np.pi))
    growl = lowpass(noise(sec), 60) * 6
    x *= 1.0 - rasp + rasp * np.clip(0.5 + growl, 0.0, 1.0)
    return x


def shape(sec, attack, hold, release):
    # Swell in, hold, die away.
    tt = t(sec)
    e = np.clip(tt / attack, 0, 1)
    fall = np.clip(1 - (tt - attack - hold) / release, 0, 1)
    return e * np.where(tt > attack + hold, fall, 1.0) ** 1.5


def dragon_scream():
    # A long, rising and falling scream far away across the mountains: the
    # cry itself, a shriller second voice inside it, rasping breath, all of
    # it dulled by the distance and thrown back by the rocks.
    cry = 2.8
    main = voice(glide([(0, 230), (0.5, 470), (1.2, 540), (1.9, 430), (2.8, 170)], cry), cry)
    main *= shape(cry, 0.25, 1.3, 1.25)
    high = voice(glide([(0, 600), (0.55, 980), (1.3, 1050), (2.0, 820), (2.8, 420)], cry), cry, 8, 0.7)
    high *= shape(cry, 0.4, 1.0, 1.2) * 0.35
    breath = (lowpass(noise(cry), 2400) - lowpass(noise(cry), 500)) * shape(cry, 0.3, 1.2, 1.3) * 0.8
    x = main + high + breath
    # Far off: the high end is gone.
    x = lowpass(x, 1500)
    # The mountains answer: echoes, each later one softer and duller.
    sec = 6.5
    out = np.zeros(int(SR * sec))
    out[: len(x)] += x
    late = lowpass(x, 700)
    for delay, gain in [(0.09, 0.45), (0.21, 0.35), (0.38, 0.28), (0.6, 0.22), (0.95, 0.3), (1.45, 0.2), (2.1, 0.12)]:
        at = int(SR * delay)
        src = x if delay < 0.4 else late
        end = min(len(out), at + len(src))
        out[at:end] += src[: end - at] * gain
    # A gentle fade at the very end, so the last echo does not stop short.
    tail = int(SR * 1.0)
    out[-tail:] *= np.linspace(1, 0, tail)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("dragon_scream", dragon_scream(), 0.85)
