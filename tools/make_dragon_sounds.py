"""Builds the sounds of the dragon that now and then flies over the open air
(see scripts/dragon_flyover.gd): its far-off scream as it comes, the heavy beats
of its huge wings (three, told apart) and its shriek as it sweeps overhead
(two, a rough, breathy throat voice through moving resonances), all from tones and noise like
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


def throat(f0, sec, r, breathiness=0.35):
    # The voice of a living throat rather than a tone: a train of glottal
    # pulses whose pitch wanders (jitter) and loudness flickers (shimmer),
    # now and then falling into a rattling every-other-pulse roughness (the
    # voice cracking under strain), with breath hissing through each pulse.
    n = len(f0)
    drift = np.cumsum(r.normal(0, 1, n)) / np.sqrt(SR) * 0.9
    drift = lowpass(drift - np.linspace(drift[0], drift[-1], n), 12)
    freq = f0 * (1 + 0.035 * drift / (np.std(drift) + 1e-9)) * (1 + 0.004 * r.normal(0, 1, n))
    phase = np.cumsum(freq) / SR
    cycle = np.floor(phase)
    frac = phase - cycle
    # A pulse that opens slowly and snaps shut: rich, not buzzy-square.
    open_q = 0.6
    pulse = np.where(frac < open_q, np.sin(0.5 * np.pi * frac / open_q) ** 2, 0.0)
    pulse = np.diff(pulse, prepend=0.0) * 20
    count = int(cycle[-1]) + 2
    shimmer = 1 + 0.18 * r.normal(0, 1, count)
    # Stretches where the voice breaks into a growling rattle.
    rough = lowpass(r.uniform(-1, 1, n), 3) * 40
    rough = np.clip(rough, 0, 1)
    odd = (cycle.astype(int) % 2 == 1)
    voiced = pulse * shimmer[cycle.astype(int)] * np.where(odd, 1 - 0.7 * rough, 1.0)
    breath = r.uniform(-1, 1, n) * (0.4 + 0.6 * np.where(frac < 0.6, 1.0, 0.3)) * breathiness
    return voiced + breath


def dragon_shriek(seed):
    # The shriek right overhead as it sweeps past: a great raptor-like
    # scream from a huge throat. A strained, rough voice through the moving
    # resonances of a long throat and open jaws: a quick rasping rise, a
    # held, cracking top, then a falling, breathy rattle as the breath runs
    # out, with the land and the air spreading it out behind.
    r = np.random.default_rng(seed)
    cry = r.uniform(2.0, 2.4)
    tt = t(cry)
    top = r.uniform(430, 520)
    f0 = glide([(0, top * 0.45), (0.14, top * 0.9), (0.35, top), (0.9, top * 1.06),
                (1.4, top * 0.92), (cry - 0.35, top * 0.6), (cry, top * 0.35)], cry)
    # A shiver in the held top: the scream strains.
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * r.uniform(6, 9) * tt) * np.clip((tt - 0.3) / 0.5, 0, 1)
    src = throat(f0, cry, r)
    # Bright as a scream is: the high harmonics brought up before the throat shapes them.
    src = highpass(src, 600) * 1.5 + src * 0.5
    # The mouth: opens wide as the cry rises (the formants climb), closes as
    # it dies away. A big beast: wide resonances.
    opening = np.interp(tt, [0, 0.25, 1.2, cry], [0.6, 1.0, 0.95, 0.55])
    x = np.zeros_like(tt)
    for base, width, gain in [(820, 260, 0.8), (1550, 320, 1.0), (2600, 420, 0.9), (3600, 600, 0.5)]:
        x += formant(src, base * (0.75 + 0.35 * opening), np.full_like(tt, width)) * gain
    # Strain: the voice driven hard, so it rasps.
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 2.6)
    x *= shape(cry, 0.08, cry * 0.45, cry * 0.5)
    # Flicker of loudness: no living voice holds steady.
    x *= 1 + 0.25 * lowpass(r.uniform(-1, 1, len(tt)), 14) * 8
    # A low, throaty undertone from the size of the chest it comes from.
    chest = formant(throat(f0 * 0.5, cry, r, 0.6), np.full_like(tt, 260.0), np.full_like(tt, 200.0))
    x += chest / (np.max(np.abs(chest)) + 1e-9) * 0.3 * shape(cry, 0.1, cry * 0.4, cry * 0.5)
    x = lowpass(x, 5200)
    # Open land: no hard echoes, a soft diffuse tail (noise that dies away),
    # darker as it lingers.
    tail_sec = 1.6
    m = int(SR * tail_sec)
    ir = r.uniform(-1, 1, m) * np.exp(-np.arange(m) / (SR * 0.35))
    ir = lowpass(ir, 1800) * 0.06
    ir[0] = 1.0
    size = len(x) + m
    out = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    fade = int(SR * 0.4)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("dragon_scream", dragon_scream(), 0.85)
    for i in range(3):
        save("dragon_wingbeat_%d" % i, wingbeat(300 + i), 0.85)
    for i in range(2):
        save("dragon_shriek_%d" % i, dragon_shriek(500 + i), 0.85)
