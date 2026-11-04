"""Builds the weather sounds from noise, like tools/make_sounds.py (whose
helpers it uses): the rain that patters in a loop while it rains, the
thunder after a stroke of lightning, and the splash of a step into a rain
puddle (splash_*, see Puddles). Run: python3 tools/make_weather_sounds.py"""
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


def splash(k):
    # A boot landing in a puddle: a wet slap of water, a short spray hissing
    # out and a few drops plopping back. Each one has its own random draw
    # (its own seed), so the rain and thunder above stay as they were.
    r = np.random.default_rng(101 + k)
    sec = 0.42
    n = r.uniform(-1, 1, int(SR * sec))
    tt = t(sec)
    slap = (lowpass(n, r.uniform(1300, 1900)) - lowpass(n, 180)) * env(len(n), 0.003, r.uniform(0.03, 0.045))
    thud = lowpass(r.uniform(-1, 1, len(n)), 160) * env(len(n), 0.004, 0.05) * 2.5
    spray = highpass(r.uniform(-1, 1, len(n)), 2600) * env(len(n), 0.01, 0.07) * 0.35
    x = slap * 1.4 + thud + spray
    for _ in range(r.integers(3, 6)):
        at = int(r.uniform(0.04, 0.26) * SR)
        f0 = r.uniform(500, 1100)
        d = t(r.uniform(0.025, 0.05))
        # A drop: a little tone that glides up, like a bubble popping.
        f = f0 * (1 + 2.2 * d / d[-1])
        blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(d), 0.001, 0.012) * r.uniform(0.15, 0.4)
        x[at:at + len(blip)] += blip[: len(x) - at]
    return x * np.minimum(1, (sec - tt) / 0.05)


if __name__ == "__main__":
    if "--splash" in os.sys.argv:
        for k in range(4):
            save("splash_%d" % k, splash(k), 0.85)
        raise SystemExit
    os.makedirs(OUT, exist_ok=True)
    save("thunder", thunder(), 0.9)
    save("rain", rain(), 0.5)
    wav = os.path.join(OUT, "rain.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)
    for k in range(4):
        save("splash_%d" % k, splash(k), 0.85)
