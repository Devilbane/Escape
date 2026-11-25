"""Builds the village geese's voices (see GooseVoice, scripts/goose_voice.gd) from scratch (a buzzing glottal
pulse train through nasal formants, no recordings), so there is no licence to credit:

  goose_honk_0..3   one honk: a rising-then-falling "hronk", rough and nasal, a little different each time
  goose_alarm_0..1  the startled cackle of a goose bolting awake: three or four short honks, higher and sharper

Run: python3 tools/make_goose_sounds.py   (writes assets/sounds/goose_*.wav)"""
import numpy as np
from make_sounds import SR, OUT, save, noise


def formants(x, peaks):
    # Shapes the spectrum with resonant peaks (centre Hz, width Hz, gain), like a throat and a bill.
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.full(len(f), 0.04)
    for c, w, g in peaks:
        gain += g * np.exp(-0.5 * ((f - c) / w) ** 2)
    return np.fft.irfft(spec * gain, len(x))


def honk(sec, f_start, f_peak, f_end, seed, harsh=0.35):
    r = np.random.default_rng(seed)
    n = int(SR * sec)
    u = np.arange(n) / n
    # Pitch: a quick climb into the honk, a long sag out of it.
    f = np.where(u < 0.25, f_start + (f_peak - f_start) * np.sin(u / 0.25 * np.pi / 2),
                 f_peak + (f_end - f_peak) * np.clip((u - 0.25) / 0.75, 0, 1) ** 1.2)
    f = f * (1 + 0.025 * np.sin(2 * np.pi * r.uniform(18, 30) * u * sec))
    phase = np.cumsum(f) / SR
    # Glottal pulse train: a saw with its edge softened, plus noise riding on it for the rasp.
    saw = 2 * (phase % 1.0) - 1
    buzz = saw + 0.5 * np.sin(4 * np.pi * phase)
    buzz *= 1 + harsh * np.sin(2 * np.pi * r.uniform(55, 80) * np.arange(n) / SR)
    x = buzz + 0.25 * noise(sec)[:n]
    # Nasal, reedy: a low body, a loud peak near 1 kHz and a bright one near 2.4 kHz.
    x = formants(x, [(f_peak * 1.0, 160, 0.6), (950, 220, 1.0), (1700, 300, 0.45), (2500, 380, 0.5)])
    e = np.minimum(1, np.arange(n) / (SR * 0.025)) * np.minimum(1, (n - np.arange(n)) / (SR * 0.09)) ** 1.5
    e *= 0.75 + 0.25 * np.sin(np.pi * np.clip(u * 1.2, 0, 1))
    return x * e


def build():
    for i, (sec, a, b, c) in enumerate([(0.55, 330, 520, 380), (0.7, 300, 470, 330),
                                        (0.45, 360, 560, 440), (0.85, 280, 440, 300)]):
        save("goose_honk_%d" % i, honk(sec, a, b, c, 10 + i))
    for k in range(2):
        r = np.random.default_rng(50 + k)
        out = np.zeros(int(SR * 1.5))
        pos = 0.0
        for j in range(3 + k):
            h = honk(r.uniform(0.17, 0.25), 420, r.uniform(640, 760), 480, 80 + 7 * k + j, harsh=0.5)
            s = int(SR * pos)
            out[s:s + len(h)] += h
            pos += len(h) / SR + r.uniform(0.04, 0.09)
        save("goose_alarm_%d" % k, out[: int(SR * (pos + 0.05))])


if __name__ == "__main__":
    build()
