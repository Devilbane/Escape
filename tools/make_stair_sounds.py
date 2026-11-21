"""Builds the footsteps on the wooden stairs of the houses (stair_up_0 to stair_up_5 and
stair_down_0 to stair_down_5) from scratch (noise, wood resonances and a stick-slip creak), so
there is no licence to worry about (it is our own work, free to use). StairSteps
(scripts/stair_steps.gd) plays them while the hero climbs a flight.

A tread is a board over a hollow box, so a step on it booms low and hollow, with a short knock
of the sole on top. Going up the foot presses the board down slowly: a softer, deeper boom, and
the old board often creaks as it takes the weight. Going down the heel drops onto it: a sharper,
brighter knock, a shorter boom and only now and then a short squeak.
The steps are levelled to the loudness of the other footsteps (step_wood_*).
Run: python3 tools/make_stair_sounds.py"""
import os, wave
import numpy as np
from make_sounds import SR, OUT, lowpass, highpass
from make_dungeon_sounds import bandpass, cave, place, t

rng = np.random.default_rng(1847)

## The loudness (RMS) of the recorded footsteps, so the stairs sit with them.
STEP_RMS = 0.072
LENGTH = 0.42


def knock(sec, bright):
    # The sole meeting the board: a few milliseconds of noise through the board's upper tones.
    tt = t(sec)
    burst = rng.uniform(-1, 1, len(tt)) * np.exp(-tt / (0.004 if bright > 1.0 else 0.007))
    return bandpass(burst, 1400 * bright, 2.5) + highpass(burst, 3000) * 0.25 * bright


def boom(sec, base, decay):
    # The hollow box under the tread: a few low wooden modes (not harmonic, like a plank),
    # and a puff of low noise for the air pushed out of the box.
    tt = t(sec)
    modes = [(1.0, 1.0, 1.0), (2.31, 0.6, 0.55), (3.87, 0.4, 0.3), (6.2, 0.25, 0.15)]
    out = np.zeros(len(tt))
    for ratio, dec, gain in modes:
        f = base * ratio * rng.uniform(0.97, 1.03)
        out += np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.3)) * np.exp(-tt / (decay * dec)) * gain
    # A tiny dip in pitch as the board springs back.
    puff = bandpass(rng.uniform(-1, 1, len(tt)) * np.exp(-tt / 0.03), base * 1.6, 3)
    return out * np.minimum(1, tt / 0.002) + puff * 0.8


def creak(sec, slow, fast, pitch):
    # Old wood rubbing at its nails under the weight: a run of ticks whose rate swells and falls,
    # ringing through the wood's own body tones.
    tt = t(sec)
    rate = slow + (fast - slow) * np.sin(np.pi * tt / sec) ** 2
    rate *= 1 + 3.5 * lowpass(rng.uniform(-1, 1, len(tt)), 8)
    phase = np.cumsum(np.maximum(rate, 5)) / SR
    ticks = np.zeros(len(tt))
    ticks[1:][np.diff(np.floor(phase)) > 0] = 1
    ticks *= rng.uniform(0.5, 1.0, len(tt))
    body = (bandpass(ticks, 420 * pitch, 9) + bandpass(ticks, 960 * pitch, 11) * 0.7
            + bandpass(ticks, 1720 * pitch, 13) * 0.35)
    shape = np.minimum(1, tt / 0.04) * np.minimum(1, (sec - tt) / 0.06)
    return body / (np.max(np.abs(body)) + 1e-9) * shape


def step(up, i):
    out = np.zeros(int(LENGTH * SR))
    if up:
        # A pressing foot: deep, soft and slower to die away; the board creaks in four of six.
        base = rng.uniform(98, 118)
        place(out, knock(0.05, 0.8) * 0.45, 0.0)
        place(out, boom(0.35, base, 0.11), 0.004)
        if i % 3 != 2:
            place(out, creak(rng.uniform(0.16, 0.26), 30, rng.uniform(140, 200), rng.uniform(0.85, 1.0)) * 0.22,
                  rng.uniform(0.04, 0.08))
    else:
        # A dropping heel: brighter, harder and short; a squeak in two of six.
        base = rng.uniform(132, 156)
        place(out, knock(0.04, 1.35) * 0.8, 0.0)
        place(out, boom(0.28, base, 0.07), 0.002)
        if i % 3 == 0:
            place(out, creak(rng.uniform(0.08, 0.12), 60, rng.uniform(220, 280), rng.uniform(1.05, 1.2)) * 0.16,
                  rng.uniform(0.02, 0.04))
    # Inside a small timber house: only a short, soft room.
    out = cave(out, 0.35, 0.12, 3500)[:len(out)]
    n = int(SR * 0.08)
    out[-n:] *= np.linspace(1, 0, n)
    return out


def save(name, x):
    x = x / np.sqrt(np.mean(x ** 2)) * STEP_RMS
    peak = np.max(np.abs(x))
    if peak > 0.95:
        x *= 0.95 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i in range(6):
        save("stair_up_%d" % i, step(True, i))
        save("stair_down_%d" % i, step(False, i))
