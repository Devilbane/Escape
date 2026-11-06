"""Builds the windmill's sounds from noise, like tools/make_sounds.py (whose
helpers it uses): the whoosh of a canvas sail sweeping past in the wind,
with the cloth fluttering on its frame, and the groan of the old wooden
axle. Windmill (scripts/windmill.gd) plays a whoosh each time a sail sweeps
down past the tower, and now and then a groan. Saved as small Ogg Vorbis
files to keep the browser version light.
Run: python3 tools/make_windmill_sounds.py"""
import math, os, subprocess
import numpy as np
from make_sounds import SR, OUT, t, lowpass, save
from make_dungeon_sounds import sweep_bandpass

rng = np.random.default_rng(57)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def whoosh(sec, low, high, flutter):
    # Air rushing past a sail: noise through a band that rises as the sail
    # comes and falls as it goes, swelling and fading with it. The canvas
    # flutters on its frame: a quick, uneven ripple in the loudness, and a
    # soft low flap of cloth under it.
    tt = t(sec)
    phase = tt / sec
    swell = np.sin(np.pi * phase) ** 1.6
    freqs = low + (high - low) * np.sin(np.pi * phase) ** 2
    air = sweep_bandpass(noise(sec), freqs, 0.9)
    ripple = 1 + 0.35 * np.sin(2 * np.pi * flutter * tt + 2.5 * np.sin(2 * np.pi * 3.1 * tt))
    flap = lowpass(noise(sec), 160) * 5 * (0.5 + 0.5 * np.sin(2 * np.pi * flutter * 0.5 * tt))
    return (air * ripple + flap * 0.6) * swell


def groan(sec, freq, bend):
    # Old wood straining on the axle: a rough, deep tone made of quick
    # little clicks (wood rubbing on wood) that slowly bends in pitch and
    # wavers, swelling and dying away.
    tt = t(sec)
    glide = 1 + bend * np.sin(np.pi * tt / sec)
    wobble = freq * glide * (1 + 0.06 * np.sin(2 * np.pi * 1.7 * tt) + 0.04 * rng.uniform(-1, 1, len(tt)))
    phase = np.cumsum(wobble) / SR
    clicks = np.maximum(0, np.sin(2 * np.pi * phase)) ** 6
    body = sweep_bandpass(clicks + noise(sec) * 0.05, freq * glide * 5.0, 3.0)
    body += lowpass(clicks, 300) * 0.8
    shape = np.sin(np.pi * tt / sec) ** 0.7
    return body * shape


def to_ogg(name):
    wav = os.path.join(OUT, name + ".wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    takes = [(1.1, 260, 900, 17.0), (1.0, 300, 1000, 21.0), (1.2, 240, 820, 14.0)]
    for i, (sec, low, high, flutter) in enumerate(takes):
        save("windmill_whoosh_%d" % i, whoosh(sec, low, high, flutter), 0.8)
        to_ogg("windmill_whoosh_%d" % i)
    for i, (sec, freq, bend) in enumerate([(1.8, 70.0, 0.25), (2.3, 58.0, -0.2), (1.5, 85.0, 0.35)]):
        save("windmill_groan_%d" % i, groan(sec, freq, bend), 0.7)
        to_ogg("windmill_groan_%d" % i)
