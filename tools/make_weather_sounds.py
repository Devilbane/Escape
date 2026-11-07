"""Builds the weather sounds from noise, like tools/make_sounds.py (whose
helpers it uses): the rain that patters in a loop while it rains, the
thunder after a stroke of lightning, and the burst of splashes of a step into
a puddle (splash_*, see Puddles). Run: python3 tools/make_weather_sounds.py"""
import os, subprocess
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, env, save

rng = np.random.default_rng(23)


def rain():
    # A hiss of falling water with many small drops on leaves and stones.
    # It loops seamlessly because the end fades into the start.
    sec = 8.0
    total = sec + 1.5
    n = noise(total)
    hiss = (lowpass(n, 5000) - lowpass(n, 900)) * 0.5
    hiss += lowpass(noise(total), 400) * 0.6
    x = hiss.copy()
    for _ in range(int(total * 90)):
        at = int(rng.uniform(0, total - 0.05) * SR)
        f = rng.uniform(1800, 4200)
        d = t(0.02)
        drop = np.sin(2 * np.pi * f * d) * env(len(d), 0.0005, 0.004) * rng.uniform(0.1, 0.35)
        x[at:at + len(drop)] += drop
    out = x[: int(SR * sec)].copy()
    tail = x[int(SR * sec):]
    fade = np.linspace(0, 1, len(tail))
    out[: len(tail)] = out[: len(tail)] * fade + tail * (1 - fade)
    return out


def thunder():
    # A sharp crack, then a long rolling rumble that swells and dies away.
    sec = 4.0
    tt = t(sec)
    crack = (lowpass(noise(sec), 3500) - lowpass(noise(sec), 300)) * env(len(tt), 0.002, 0.12)
    rumble = lowpass(noise(sec), 120) * 7
    roll = 0.6 + 0.4 * np.sin(2 * np.pi * tt * 1.7) * np.sin(2 * np.pi * tt * 0.6)
    rumble *= roll * np.minimum(1, tt / 0.25) * np.exp(-tt / 1.4)
    return crack * 0.8 + rumble


def _slosh(r, sec, size):
    # One splash of a boot in water: a wet slap, a deep slosh of water pushed
    # aside, a fizz of spray and a few drops and bubbles plopping back.
    # size (0..1) makes the later splashes of a burst smaller and shorter.
    n = r.uniform(-1, 1, int(SR * sec))
    tt = t(sec)
    slap = (lowpass(n, r.uniform(1100, 1700)) - lowpass(n, 220)) * env(len(n), 0.002, r.uniform(0.025, 0.04) * (0.6 + 0.4 * size))
    # The slosh: low water noise that wobbles, like water rolling back in.
    wob = 1 + 0.6 * np.sin(2 * np.pi * r.uniform(18, 30) * tt + r.uniform(0, 6.3))
    slosh = (lowpass(r.uniform(-1, 1, len(n)), 650) - lowpass(r.uniform(-1, 1, len(n)), 90)) * wob * env(len(n), 0.006, 0.04 * (0.6 + 0.4 * size)) * 1.6
    thud = lowpass(r.uniform(-1, 1, len(n)), 150) * env(len(n), 0.004, 0.045) * 2.0 * size
    spray = highpass(r.uniform(-1, 1, len(n)), 2800) * env(len(n), 0.01, 0.04 + 0.03 * size) * 0.45
    x = slap * 1.3 + slosh + thud + spray
    for _ in range(r.integers(4, 8)):
        at = int(r.uniform(0.02, sec * 0.6) * SR)
        f0 = r.uniform(450, 1300)
        d = t(r.uniform(0.02, 0.05))
        # A drop or a bubble: a little tone that glides up as it pops.
        f = f0 * (1 + r.uniform(1.6, 2.8) * d / d[-1])
        blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(d), 0.001, 0.01) * r.uniform(0.15, 0.4)
        x[at:at + len(blip)] += blip[: len(x) - at]
    return x * size


def splash(k):
    # A step into a puddle: not one dull slap but a burst of three or four
    # splashes in a row, each a little smaller, like water kicked up and
    # slopping back. Each sound has its own random draw (its own seed), so the
    # four differ in timing, pitch and size, and the rain and thunder above
    # stay as they were.
    r = np.random.default_rng(211 + k)
    count = 3 + k % 2
    sec = 0.64
    x = np.zeros(int(SR * sec))
    at = 0.0
    size = 1.0
    for i in range(count):
        one = _slosh(r, 0.24, size)
        a = int(at * SR)
        x[a:a + len(one)] += one[: len(x) - a]
        at += r.uniform(0.1, 0.13)
        size *= r.uniform(0.7, 0.82)
    tt = t(sec)
    return x * np.minimum(1, (sec - tt) / 0.06)


def soft_splash(k):
    # A step into a nearly dried-out puddle: a thin film of water, so no slap
    # and no spray (their sharp, bright edge read as a little firecracker),
    # only a soft, low squelch and one or two tiny drops, all rolled off above
    # 1.2 kHz. Quiet in the game too (see Puddles.splash_volume).
    r = np.random.default_rng(311 + k)
    sec = 0.3
    n = r.uniform(-1, 1, int(SR * sec))
    tt = t(sec)
    wob = 1 + 0.4 * np.sin(2 * np.pi * r.uniform(14, 22) * tt + r.uniform(0, 6.3))
    squelch = (lowpass(n, 1000) - lowpass(n, 140)) * wob * env(len(n), 0.012, 0.07) * 1.4
    x = squelch
    for _ in range(r.integers(1, 3)):
        at = int(r.uniform(0.04, 0.16) * SR)
        d = t(r.uniform(0.03, 0.05))
        f = r.uniform(400, 800) * (1 + r.uniform(0.6, 1.2) * d / d[-1])
        blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(d), 0.004, 0.015) * r.uniform(0.1, 0.2)
        x[at:at + len(blip)] += blip[: len(x) - at]
    x = lowpass(x, 1200)
    return x * np.minimum(1, (sec - tt) / 0.05)


if __name__ == "__main__":
    if "--splash" in os.sys.argv:
        for k in range(4):
            save("splash_%d" % k, splash(k), 0.85)
        for k in range(3):
            save("splash_soft_%d" % k, soft_splash(k), 0.6)
        raise SystemExit
    os.makedirs(OUT, exist_ok=True)
    save("thunder", thunder(), 0.9)
    save("rain", rain(), 0.5)
    wav = os.path.join(OUT, "rain.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)
    for k in range(4):
        save("splash_%d" % k, splash(k), 0.85)
    for k in range(3):
        save("splash_soft_%d" % k, soft_splash(k), 0.6)
