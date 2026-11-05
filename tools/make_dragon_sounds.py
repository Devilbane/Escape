"""Builds the sounds of the dragon that now and then flies over the open air
(see scripts/dragon_flyover.gd): its far-off scream as it comes, the heavy beats
of its huge wings (three, told apart) and its shriek as it sweeps overhead
(two), from tones and noise like
tools/make_sounds.py (whose helpers it uses), so there is no licence to worry about.
Run: python3 tools/make_dragon_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, env, save

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


def wingbeat(seed):
    # One downstroke of a huge leathery wing, high overhead: a deep whump of
    # air pressed down, the rushing swoosh of the stroke, a slap of the
    # membrane as it snaps taut, and the creak and rustle of skin and bone.
    r = np.random.default_rng(seed)
    sec = 1.3
    tt = t(sec)
    n = len(tt)
    # The whump: a sinking low tone with a puff of low noise.
    f0 = r.uniform(62, 78)
    freq = f0 * (0.5 + 0.5 * np.exp(-tt / 0.18))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    boom = np.sin(phase) * env(n, 0.05, 0.22)
    puff = lowpass(noise(sec), 160) * 9 * env(n, 0.04, 0.28)
    # The swoosh: a band of noise swelling and fading over the stroke,
    # brighter in its middle.
    stroke = r.uniform(0.5, 0.65)
    arc = np.clip(np.sin(np.pi * np.clip(tt / stroke, 0, 1)), 0, None) ** 2
    raw = noise(sec)
    low_band = lowpass(raw, 480) - lowpass(raw, 70)
    high_band = lowpass(raw, 1300) - lowpass(raw, 450)
    swoosh = low_band * arc * 1.3 + high_band * arc ** 3 * 0.5
    # The slap: the skin snapping taut at the start of the stroke.
    slap_at = int(SR * r.uniform(0.03, 0.06))
    slap = np.zeros(n)
    burst = lowpass(noise(0.12), 2200) - lowpass(noise(0.12), 250)
    burst *= env(len(burst), 0.003, 0.03)
    slap[slap_at:slap_at + len(burst)] = burst
    # The rustle: a few small crackles of skin as the stroke ends.
    rustle = np.zeros(n)
    for _ in range(r.integers(4, 8)):
        at = int(SR * r.uniform(0.25, 0.75))
        bit = (lowpass(noise(0.05), 3000) - lowpass(noise(0.05), 800)) * env(int(SR * 0.05), 0.002, 0.012)
        rustle[at:at + len(bit)] += bit * r.uniform(0.2, 0.45)
    x = boom * 1.5 + puff * 1.2 + swoosh * 1.6 + slap * 1.0 + rustle * 0.8
    # High up: the very top is dulled, and the open land throws back a faint echo.
    x = lowpass(x, 2400)
    out = x.copy()
    at = int(SR * 0.16)
    out[at:] += lowpass(x, 900)[: n - at] * 0.25
    fade = int(SR * 0.3)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def dragon_shriek(seed):
    # The shriek right overhead as it sweeps past: the same harsh voice as
    # the far scream, but near, so piercing and bright, quicker to rise, with
    # a crackling rattle at its top and the land throwing it back.
    global rng
    rng = np.random.default_rng(seed)
    r = np.random.default_rng(seed + 1)
    cry = r.uniform(1.9, 2.3)
    top = r.uniform(820, 960)
    main = voice(glide([(0, 320), (0.18, top), (0.7, top * 1.12), (1.3, top * 0.85), (cry, 260)], cry), cry, 16, 0.6)
    main *= shape(cry, 0.12, 0.9, cry - 1.02)
    high = voice(glide([(0, 900), (0.2, top * 1.9), (0.8, top * 2.1), (1.4, top * 1.6), (cry, 700)], cry), cry, 7, 0.75)
    high *= shape(cry, 0.18, 0.7, cry - 0.88) * 0.45
    breath = (lowpass(noise(cry), 3500) - lowpass(noise(cry), 700)) * shape(cry, 0.1, 0.9, cry - 1.0) * 0.9
    # A throaty rumble under it: the size of the beast.
    tt = t(cry)
    rumble = np.sin(2 * np.pi * np.cumsum(glide([(0, 90), (0.6, 120), (cry, 70)], cry)) / SR)
    rumble *= shape(cry, 0.15, 0.8, cry - 0.95) * 0.5
    x = main + high + breath + rumble
    x = lowpass(x, 4200)
    sec = cry + 1.6
    out = np.zeros(int(SR * sec))
    out[: len(x)] += x
    late = lowpass(x, 1100)
    for delay, gain in [(0.12, 0.25), (0.33, 0.2), (0.7, 0.16), (1.2, 0.1)]:
        at = int(SR * delay)
        src = x if delay < 0.3 else late
        end = min(len(out), at + len(src))
        out[at:end] += src[: end - at] * gain
    tail = int(SR * 0.8)
    out[-tail:] *= np.linspace(1, 0, tail)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("dragon_scream", dragon_scream(), 0.85)
    for i in range(3):
        save("dragon_wingbeat_%d" % i, wingbeat(300 + i), 0.85)
    for i in range(2):
        save("dragon_shriek_%d" % i, dragon_shriek(500 + i), 0.85)
