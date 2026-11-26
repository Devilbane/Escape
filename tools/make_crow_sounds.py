"""Builds the crows' voices (see scripts/crows.gd) from scratch (a rough buzzing pulse train through throaty
formants, plus noise for the clatter of wings), so there are no recordings and no licence to credit:

  crow_caw_0..3    one "kraah": a harsh, falling caw, a little different each time
  crow_caw_4       a double "kah-kah", short and sharp (the startled call as the flock rises)
  crow_flutter     the clatter of a flock taking off: many wings beating hard, fading into the steady flap

Run: python3 tools/make_crow_sounds.py   (writes assets/sounds/crow_*.wav)"""
import numpy as np
from make_sounds import SR, save, noise


def formants(x, peaks):
    # Shapes the spectrum with resonant peaks (centre Hz, width Hz, gain), like a throat and a beak.
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.full(len(f), 0.03)
    for c, w, g in peaks:
        gain += g * np.exp(-0.5 * ((f - c) / w) ** 2)
    return np.fft.irfft(spec * gain, len(x))


def caw(sec, f_start, f_peak, f_end, seed, harsh=0.5):
    r = np.random.default_rng(seed)
    n = int(SR * sec)
    u = np.arange(n) / n
    # Pitch: a quick bark up, then a long fall.
    f = np.where(u < 0.18, f_start + (f_peak - f_start) * np.sin(u / 0.18 * np.pi / 2),
                 f_peak + (f_end - f_peak) * np.clip((u - 0.18) / 0.82, 0, 1) ** 0.9)
    f = f * (1 + 0.03 * np.sin(2 * np.pi * r.uniform(30, 50) * u * sec))
    phase = np.cumsum(f) / SR
    # A pulse train with a rough, stuttering edge: the crow's rattle.
    saw = 2 * (phase % 1.0) - 1
    buzz = saw + 0.6 * np.sin(4 * np.pi * phase) + 0.3 * np.sin(6 * np.pi * phase)
    buzz *= 1 + harsh * np.sin(2 * np.pi * r.uniform(70, 110) * np.arange(n) / SR)
    x = buzz + 0.3 * noise(sec)[:n]
    x = formants(x, [(f_peak, 200, 0.7), (1100, 250, 1.0), (1900, 330, 0.7), (3000, 500, 0.35)])
    e = np.minimum(1, np.arange(n) / (SR * 0.012)) * np.minimum(1, (n - np.arange(n)) / (SR * 0.11)) ** 1.4
    return x * e


def silence(sec):
    return np.zeros(int(SR * sec))


def flap_clatter(sec, rate_start, rate_end, seed):
    # Wing beats: bursts of band-limited noise, many at once so they blur into a rustling clatter.
    r = np.random.default_rng(seed)
    n = int(SR * sec)
    out = np.zeros(n)
    for _ in range(9):
        t = r.uniform(0.0, 0.06)
        rate = rate_start
        while t < sec:
            i = int(t * SR)
            burst = int(SR * r.uniform(0.03, 0.05))
            if i + burst >= n:
                break
            b = r.uniform(-1, 1, burst) * np.hanning(burst) ** 1.5
            out[i:i + burst] += b * r.uniform(0.5, 1.0)
            u = t / sec
            rate = rate_start + (rate_end - rate_start) * u
            t += 1.0 / rate * r.uniform(0.85, 1.15)
    # Hushed and breathy: keep the mids, drop the hiss.
    out = formants(out, [(700, 500, 1.0), (1800, 900, 0.5)])
    u = np.arange(n) / n
    return out * np.minimum(1, np.arange(n) / (SR * 0.03)) * (1 - u) ** 0.8


if __name__ == "__main__":
    save("crow_caw_0", caw(0.55, 520, 700, 430, 1))
    save("crow_caw_1", caw(0.7, 480, 640, 360, 2, 0.6))
    save("crow_caw_2", caw(0.45, 600, 780, 520, 3, 0.4))
    save("crow_caw_3", caw(0.62, 450, 620, 380, 4, 0.55))
    save("crow_caw_4", np.concatenate([caw(0.26, 560, 740, 470, 5), silence(0.09), caw(0.3, 540, 700, 430, 6)]))
    save("crow_flutter", flap_clatter(1.6, 16, 9, 7), 0.8)
