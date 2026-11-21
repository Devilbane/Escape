"""Builds the cellar's ambient loop from scratch (noise, tones and a small
stone echo), so there are no licences to worry about: a low, still room tone,
the outside world as a faint muffled rumble through the earth and the walls,
and now and then a drip of water on damp stone. Soundscape (scripts/soundscape.gd)
plays it while the hero is down in a house's cellar.

Every layer is made round (filtered and echoed in a circle, drips that run past
the end wrap round to the start), so the loop has no seam.
Run: python3 tools/make_cellar_sounds.py"""
import os, subprocess, wave
import numpy as np
from make_sounds import SR, OUT, norm

rng = np.random.default_rng(73)
SECONDS = 48
N = SR * SECONDS


def shaped_noise(low, high, tilt=1.0):
    # White noise shaped in one go over the whole loop (so it loops seamlessly):
    # only `low` to `high` Hz pass, with soft edges, and the spectrum falls by
    # `tilt` (1 is brown-ish, 0 is flat).
    spec = np.fft.rfft(rng.standard_normal(N))
    f = np.fft.rfftfreq(N, 1 / SR)
    gain = np.ones_like(f)
    gain *= 1 / (1 + (low / np.maximum(f, 1e-3)) ** 4)
    gain *= 1 / (1 + (f / high) ** 4)
    gain /= np.maximum(f, 20.0) ** (tilt * 0.5)
    return norm(np.fft.irfft(spec * gain, N), 1.0)


def swells(cycles, depth):
    # A slow rise and fall in loudness that fits the loop a whole number of times.
    x = np.arange(N) / N
    m = np.zeros(N)
    for c, phase in zip(cycles, rng.uniform(0, 2 * np.pi, len(cycles))):
        m += np.sin(2 * np.pi * c * x + phase)
    m /= len(cycles)
    return 1 - depth * 0.5 + depth * 0.5 * m


def drip(pitch, size):
    # One drop: a quick falling plink with a soft wet tick in front.
    n = int(SR * 0.22)
    tt = np.arange(n) / SR
    freq = pitch * (1 + 0.6 * np.exp(-tt / 0.012))
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-tt / (0.03 + 0.03 * size))
    tick = rng.standard_normal(n) * np.exp(-tt / 0.002) * 0.25
    return tone + tick


def place_round(out, x, at):
    # Adds `x` at sample `at`, wrapping what runs past the end to the start.
    idx = (at + np.arange(len(x))) % N
    np.add.at(out, idx, x)


def stone_echo(x, seconds=1.1, decay=0.28, cutoff=2400.0):
    # A small, damp stone room: a short, dark tail of echoes, in a circle.
    n = int(SR * seconds)
    tt = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-tt / decay)
    ir[:int(SR * 0.012)] = 0.0  # the first wall is a few metres away
    spec = np.fft.rfft(ir, N)
    f = np.fft.rfftfreq(N, 1 / SR)
    spec /= 1 + (f / cutoff) ** 2  # damp stone swallows the highs
    wet = np.fft.irfft(np.fft.rfft(x) * spec, N)
    return x * 0.55 + norm(wet, np.max(np.abs(x)) * 0.6)


def cellar():
    # The still air of a closed room under the earth.
    room = shaped_noise(35, 180, 1.0) * swells([1, 3], 0.25) * 0.55
    # The world outside, muffled to a dull rumble: wind and the village far off.
    outside = shaped_noise(60, 420, 0.6) * swells([2, 5, 7], 0.8) * 0.32
    # Drips: two spots that drip again and again, and now and then a stray drop.
    drops = np.zeros(N)
    for pitch, every, loud in [(1350.0, 5.3, 0.55), (980.0, 8.9, 0.42)]:
        at = rng.uniform(0, every)
        while at < SECONDS:
            place_round(drops, drip(pitch * rng.uniform(0.97, 1.03), 1.0) * loud * rng.uniform(0.7, 1.0), int(at * SR))
            at += every * rng.uniform(0.8, 1.25)
    for _ in range(4):
        place_round(drops, drip(rng.uniform(800, 1800), rng.uniform(0.5, 1.5)) * rng.uniform(0.15, 0.3), int(rng.uniform(0, SECONDS) * SR))
    drops = stone_echo(drops)
    return room + outside + drops


def save_loop(name, x, peak=0.8):
    # Through a .wav to ffmpeg, then only the small .ogg is kept (no fade: it loops).
    x = norm(x, peak)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                    "-q:a", "2", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


if __name__ == "__main__":
    save_loop("amb_cellar", cellar())
    print("amb_cellar.ogg")
