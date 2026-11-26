"""Builds the town guard's shouts (see GuardChase, scripts/guard_chase.gd) from scratch (a buzzing glottal pulse
train through vowel formants plus a little breath noise, no recordings), so there is no licence to credit:

  guard_shout_0  "Heeey!"   a rough male shout that rises and sags, e -> a
  guard_shout_1  "Halt!"    short and hard, a -> a with a clipped end
  guard_shout_2  "Stooop!"  long and hoarse, o -> a

Run: python3 tools/make_guard_shout.py   (writes assets/sounds/guard_shout_*.wav)"""
import numpy as np
from make_sounds import SR, save, noise
from make_goose_sounds import formants

# Two vowel colours as formant peaks (centre Hz, width Hz, gain): a throat that is wide open for a shout.
VOWELS = {
    "e": [(550, 90, 1.0), (1850, 160, 0.55), (2600, 220, 0.3)],
    "a": [(780, 110, 1.0), (1200, 140, 0.7), (2500, 220, 0.3)],
    "o": [(500, 90, 1.0), (850, 120, 0.6), (2400, 220, 0.2)],
}


def shout(sec, f_start, f_peak, f_end, v_from, v_to, seed, rasp=0.45, clip=0.0):
    r = np.random.default_rng(seed)
    n = int(SR * sec)
    u = np.arange(n) / n
    # Pitch: a hard push up into the shout, then a slow sag; a slight shake in the voice.
    f = np.where(u < 0.2, f_start + (f_peak - f_start) * np.sin(u / 0.2 * np.pi / 2),
                 f_peak + (f_end - f_peak) * np.clip((u - 0.2) / 0.8, 0, 1))
    f = f * (1 + 0.02 * np.sin(2 * np.pi * r.uniform(5, 8) * u * sec))
    phase = np.cumsum(f) / SR
    buzz = 2 * (phase % 1.0) - 1
    buzz += 0.4 * np.sin(4 * np.pi * phase)
    x = buzz + rasp * noise(sec)[:n]
    # The vowel slides from one colour to the other over the shout.
    a = formants(x, VOWELS[v_from])
    b = formants(x, VOWELS[v_to])
    mix = np.clip((u - 0.25) / 0.5, 0, 1)
    x = a * (1 - mix) + b * mix
    e = np.minimum(1, np.arange(n) / (SR * 0.02)) * np.minimum(1, (n - np.arange(n)) / (SR * (0.04 if clip else 0.14))) ** 1.3
    e *= 0.8 + 0.2 * np.sin(np.pi * np.clip(u * 1.1, 0, 1))
    out = x * e
    return out / (np.abs(out).max() + 1e-9) * 0.85


def build():
    save("guard_shout_0", shout(0.75, 120, 190, 140, "e", "a", 11))
    save("guard_shout_1", shout(0.42, 130, 200, 150, "a", "a", 12, rasp=0.55, clip=1.0))
    save("guard_shout_2", shout(0.95, 110, 175, 120, "o", "a", 13, rasp=0.5))


if __name__ == "__main__":
    build()
