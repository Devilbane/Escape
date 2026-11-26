"""Builds the sounds of the summer night and the meadow in the day from tones and envelopes (no licences to
worry about): a chorus of crickets and a drone of cicadas (seamless loops played by Soundscape, see
scripts/soundscape.gd), single cricket chirps (cricket_0 to cricket_2, played from a spot near the hero by
InsectLife, scripts/insect_life.gd) and two owl hoots (owl_0, owl_1).
Run: python3 tools/make_insect_sounds.py   Needs numpy and ffmpeg."""
import os, subprocess
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(1234)


def smooth(x, n):
    k = np.hanning(n)
    return np.convolve(x, k / k.sum(), mode="same")


def band(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(f, len(x))


def add_wrapped(buf, start, sig):
    """Adds `sig` into the loop `buf` from `start`, wrapping round the end so the loop is seamless."""
    idx = (start + np.arange(len(sig))) % len(buf)
    np.add.at(buf, idx, sig)


def chirp(freq, pulses, pulse_rate, sec):
    """One cricket chirp: a few quick pulses of a high tone, each swelling and dying like a wing stroke."""
    n = int(SR * sec)
    tt = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(2 * np.pi * freq * 2 * tt + 1.3)
    pulse = np.zeros(n)
    for k in range(pulses):
        c = 0.015 + k / pulse_rate
        pulse += np.exp(-((tt - c) / 0.0075) ** 2)
    return tone * np.clip(pulse, 0, 1) * 0.5


def cricket_loop(sec, voices, base):
    buf = np.zeros(int(SR * sec))
    for v in range(voices):
        freq = base * rng.uniform(0.93, 1.07)
        pulses = int(rng.integers(3, 5))
        gap = rng.uniform(0.55, 0.95)
        rate = rng.uniform(26, 34)
        amp = rng.uniform(0.25, 1.0)
        t0 = rng.uniform(0, gap)
        while t0 < sec:
            add_wrapped(buf, int(t0 * SR), chirp(freq, pulses, rate, 0.2) * amp)
            t0 += gap * rng.uniform(0.9, 1.1)
    return buf


def cicada_loop(sec):
    n = int(SR * sec)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for freq, rate in [(5200, 170), (4700, 143), (5600, 191)]:
        # A periodic swell (whole cycles in the loop), so the loop closes without a seam.
        cycles = int(rng.integers(2, 4))
        swell = 0.55 + 0.45 * np.sin(2 * np.pi * cycles * tt / sec + rng.uniform(0, 6))
        buzz = (np.sin(2 * np.pi * rate * tt) > -0.2).astype(float)
        out += np.sin(2 * np.pi * freq * tt) * smooth(buzz, 30) * swell
    return out


def hoot(freq, sec, notes):
    n = int(SR * sec)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for start, length, f in notes:
        m = (tt >= start) & (tt < start + length)
        u = (tt[m] - start) / length
        glide = f * (1 - 0.08 * u)
        ph = 2 * np.pi * np.cumsum(glide) / SR
        env = np.sin(np.pi * np.clip(u, 0, 1)) ** 1.5
        out[m] += (np.sin(ph) + 0.3 * np.sin(2 * ph)) * env
    return out


def save(name, x, peak=0.8, loop=False):
    x = x / np.max(np.abs(x)) * peak
    if not loop:
        fade = int(SR * 0.01)
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
    raw = (x * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-nostdin", "-y", "-v", "error", "-f", "s16le", "-ac", "1", "-ar", str(SR), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, name + ".ogg")], input=raw, check=True)


if __name__ == "__main__":
    save("crickets_loop", band(cricket_loop(14.0, 26, 4300), 2500, 8000), loop=True)
    save("cicadas_loop", band(cicada_loop(12.0), 2500, 8000), loop=True)
    for i, (f, p) in enumerate([(4100, 4), (4500, 3), (3900, 5)]):
        save("cricket_%d" % i, band(np.concatenate([chirp(f, p, 30, 0.2), np.zeros(int(SR * 0.25)), chirp(f, p, 30, 0.2)]), 2500, 8000), 0.7)
    save("owl_0", hoot(380, 1.6, [(0.0, 0.28, 380), (0.4, 0.9, 340)]), 0.7)
    save("owl_1", hoot(430, 2.2, [(0.0, 0.25, 440), (0.35, 0.25, 440), (0.8, 0.9, 380)]), 0.7)
