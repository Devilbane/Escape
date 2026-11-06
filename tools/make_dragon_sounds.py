"""Builds the sounds of the dragon that now and then flies over the open air
(see scripts/dragon_flyover.gd): its far-off scream as it comes, the heavy beats
of its huge wings (three, told apart) and its shriek as it sweeps overhead
(a grinding, metallic giant's roar), all
from tones and noise like
tools/make_sounds.py (whose helpers it uses), so there is no licence to worry about.
Run: python3 tools/make_dragon_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, env, save

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


def formant(x, freqs, widths):
    # A resonance of the throat: a band-pass whose centre (and width) follow
    # the curves `freqs` and `widths` (one value per sample), so the cry's
    # colour moves like a mouth opening and closing.
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    step = 32
    for s in range(0, len(x), step):
        f = freqs[s]
        w0 = 2 * np.pi * f / SR
        alpha = np.sin(w0) * widths[s] / (2 * f)
        b0, a0 = alpha, 1 + alpha
        a1, a2 = -2 * np.cos(w0), 1 - alpha
        b0, a1, a2 = b0 / a0, a1 / a0, a2 / a0
        for i in range(s, min(s + step, len(x))):
            v = x[i]
            out = b0 * v - b0 * x2 - a1 * y1 - a2 * y2
            x2, x1 = x1, v
            y2, y1 = y1, out
            y[i] = out
    return y


def dragon_shriek(seed):
    # The roar right overhead as it sweeps past, from a big old dragon with a
    # massive body: a grinding friction scream, like a bow dragged across
    # metal (a sawtooth whose cycles jitter and now and then slip), rung
    # through narrow metallic resonances, rising into a strain and sinking
    # into a groan, with a dark octave below from its chest and a long tail
    # rolling across the land.
    r = np.random.default_rng(seed)
    sec = 3.6
    n = int(SR * sec); tt = np.arange(n) / SR
    # Bow pressure: a grinding attack, a long rising strain, a groaning fall.
    f0 = glide([(0, 70), (0.25, 120), (1.1, 165), (1.9, 175), (2.6, 140), (sec, 80)], sec)
    wob = lowpass(r.normal(0, 1, n), 6); wob /= np.std(wob) + 1e-9
    f0 = f0 * (1 + 0.04 * wob)
    # Stick-slip: a sawtooth whose period jumps a little each cycle, with
    # slips that sometimes skip (grinding).
    phase = np.cumsum(f0 * (1 + 0.02 * r.normal(0, 1, n))) / SR
    frac = phase % 1.0
    saw = 1 - 2 * frac
    cyc = np.floor(phase).astype(int)
    grind = np.clip(lowpass(r.uniform(-1, 1, n), 4) * 40, 0, 1)
    skip = r.uniform(0, 1, cyc[-1] + 2) < 0.35
    saw = saw * np.where(skip[cyc], 1 - 0.8 * grind, 1.0)
    scrape = (lowpass(r.uniform(-1, 1, n), 3000) - lowpass(r.uniform(-1, 1, n), 600)) * 0.35
    src = saw + scrape * (0.5 + grind)
    # Metallic body: narrow inharmonic resonances, gliding a little with the pitch.
    bend = f0 / 140.0
    x = np.zeros(n)
    for fr, bw, g in [(310, 40, 0.35), (690, 50, 0.7), (1180, 60, 1.3), (1770, 80, 1.8), (2480, 110, 1.8), (3300, 160, 1.2)]:
        x += formant(src, fr * (0.85 + 0.15 * bend), np.full(n, float(bw))) * g
    x = x / (np.max(np.abs(x)) + 1e-9) + src * 0.25
    x = np.tanh(x * 2.5)
    # The chest: an octave below, dark.
    sub = lowpass(1 - 2 * ((phase / 2) % 1.0), 220)
    x = x + sub * 0.5
    x *= shape(sec, 0.12, 1.9, sec - 2.02)
    x = lowpass(highpass(x, 35), 5000)
    # A vast open land: a long, dark, diffuse tail.
    m = int(SR * 3.0)
    ir = r.uniform(-1, 1, m) * np.exp(-np.arange(m) / (SR * 0.8))
    ir = lowpass(ir, 2000) * 0.05; ir[0] = 1.0
    size = n + m
    out = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    fade = int(SR * 0.8); out[-fade:] *= np.linspace(1, 0, fade) ** 2
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("dragon_scream", dragon_scream(), 0.85)
    for i in range(3):
        save("dragon_wingbeat_%d" % i, wingbeat(300 + i), 0.85)
    save("dragon_shriek", dragon_shriek(7), 0.95)
