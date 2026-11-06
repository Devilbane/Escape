"""Builds the slimes' sounds (see SlimeSounds, scripts/slime_sounds.gd) from the
eight slime recordings in "80 CC0 creture SFX #2" by rubberduck (CC0, see
assets/sounds/CREDITS.txt), so there is nothing to license but the pack itself:

  slime_glide_0..3  the wet slurp of a body gliding over the floor, soft at
                    both ends like a snail's trail: the gentler recordings,
                    low-passed, stretched and slowed a little, over a thin
                    layer of wet sliding that flutters
  slime_attack_0..2 the lash: a sharp squelch with a low gloop under it

Run from the tools folder: python3 make_slime_sounds.py
It downloads the pack once into ~/.cache/escape_slime_sounds and needs ffmpeg."""
import os, subprocess, urllib.request, zipfile
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, env, save, at

CACHE = os.path.expanduser("~/.cache/escape_slime_sounds")
PACK = "80-CC0-creature-sfx-2.zip"
URL = "https://opengameart.org/sites/default/files/" + PACK
rng = np.random.default_rng(41)


def fetch():
    """Every slime recording of the pack as mono floats, by number."""
    os.makedirs(CACHE, exist_ok=True)
    zpath = os.path.join(CACHE, PACK)
    if not os.path.exists(zpath):
        print("downloading", PACK)
        urllib.request.urlretrieve(URL, zpath)
    out = {}
    with zipfile.ZipFile(zpath) as z:
        for i in range(1, 9):
            name = "slime_%02d.ogg" % i
            z.extract(name, CACHE)
            raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", os.path.join(CACHE, name),
                                  "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                                 capture_output=True, check=True).stdout
            out[i] = np.frombuffer(raw, np.int16) / 32768.0
    return out


def slow(x, factor):
    # Plays it slower and lower by this factor (resampling).
    n = int(len(x) * factor)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def fade(x, a, b):
    x = x.copy()
    na, nb = int(SR * a), int(SR * b)
    x[:na] *= np.linspace(0, 1, na) ** 1.5
    x[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return x


def glide(src, factor, cutoff, seed):
    r = np.random.default_rng(seed)
    x = fade(lowpass(slow(src, factor), cutoff), 0.07, 0.16)
    sec = len(x) / SR
    # The wet sliding under it: a hiss that flutters as the skin drags.
    drag = lowpass(highpass(noise(sec)[: len(x)], 500), 2600)
    flutter = 0.55 + 0.45 * np.abs(np.sin(np.arange(len(x)) / SR * 2 * np.pi * r.uniform(9, 14)))
    drag = drag * flutter * np.sin(np.pi * np.arange(len(x)) / len(x)) ** 1.5
    return x / max(np.abs(x).max(), 1e-6) + drag * 0.35


def gloop(freq, sec):
    # A bubble swelling and bursting: a sine whose pitch climbs.
    tt = t(sec)
    f = freq * (1 + tt / sec * 1.2)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.006, sec * 0.4)


def attack(src, factor, freq):
    x = slow(src, factor)
    x = x / max(np.abs(x).max(), 1e-6)
    x = x[: int(SR * 0.55)]
    x = fade(x, 0.002, 0.12)
    out = np.zeros(len(x) + int(SR * 0.2))
    out[: len(x)] += x
    at(out, gloop(freq, 0.16) * 0.45, 0.02)
    at(out, gloop(freq * 1.5, 0.1) * 0.25, 0.1)
    return out


if __name__ == "__main__":
    s = fetch()
    os.makedirs(OUT, exist_ok=True)
    # The gentle recordings (2, 4, 8) glide; the sharp ones (1, 3, 6, 7) lash.
    for i, (n, f, c) in enumerate([(2, 1.0, 3200), (4, 1.2, 2800), (8, 1.0, 3600), (4, 1.45, 2400)]):
        save("slime_glide_%d" % i, glide(s[n], f, c, i), 0.8)
    for i, (n, f, q) in enumerate([(1, 1.0, 190), (3, 1.15, 160), (7, 0.95, 220)]):
        save("slime_attack_%d" % i, attack(s[n], f, q), 0.9)
