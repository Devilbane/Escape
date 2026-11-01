"""Builds the weather sounds from noise, like tools/make_sounds.py (whose
helpers it uses): the rain that patters in a loop while it rains, and the
thunder after a stroke of lightning. Run: python3 tools/make_weather_sounds.py"""
import os, subprocess
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, env, save

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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("thunder", thunder(), 0.9)
    save("rain", rain(), 0.5)
    wav = os.path.join(OUT, "rain.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)
