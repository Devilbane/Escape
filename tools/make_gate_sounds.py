"""Builds the rusty iron gate sound of the graveyard gates (GraveGate) from scratch
(noise, resonances and a stick-slip run of ticks), so there is no licence to worry about
(it is our own work, free to use). A long, grating screech of dry hinges, with the dull clang
of the leaf coming to rest at the end of the opening, and a shorter one for closing.
Run: python3 tools/make_gate_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, lowpass, highpass, norm
from make_dungeon_sounds import bandpass, cave, save_ogg, t

rng = np.random.default_rng(97)


def screech(sec, slow, fast, pitch):
    # Rust on an iron pin: the leaf sticks and slips, so the sound is a run of ticks
    # whose rate wanders, each ringing through high, narrow metal resonances.
    tt = t(sec)
    wander = lowpass(rng.uniform(-1, 1, len(tt)), 3) * 60
    rate = slow + (fast - slow) * np.sin(np.pi * tt / sec) ** 1.5
    rate = np.maximum(rate * (1 + 0.35 * wander), 8)
    phase = np.cumsum(rate) / SR
    ticks = np.zeros(len(tt))
    ticks[1:][np.diff(np.floor(phase)) > 0] = 1
    ticks *= rng.uniform(0.4, 1.0, len(tt))
    body = (bandpass(ticks, 520 * pitch, 14) * 0.8 + bandpass(ticks, 1180 * pitch, 18)
            + bandpass(ticks, 1960 * pitch, 22) * 0.7 + bandpass(ticks, 3100 * pitch, 26) * 0.4)
    # A thin squeal that glides with the speed of the swing.
    glide = 780 * pitch * (1 + 0.5 * np.sin(np.pi * tt / sec) + 0.08 * wander)
    squeal = np.sin(2 * np.pi * np.cumsum(glide) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * tt))
    squeal *= np.sin(np.pi * tt / sec) ** 2 * 0.25
    shape = np.minimum(1, tt / 0.15) * np.minimum(1, (sec - tt) / 0.3)
    return (body / np.max(np.abs(body)) + squeal) * shape


def clang(strength):
    # Iron settling against its post: a short dull knock with a faint ring.
    tt = t(0.5)
    knock = bandpass(rng.uniform(-1, 1, len(tt)) * np.exp(-tt / 0.012), 240, 3)
    ring = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) * g
               for f, d, g in [(310, 0.12, 0.6), (730, 0.09, 0.4), (1290, 0.06, 0.3)])
    return (knock * 2 + ring * 0.5) * strength


def gate(sec, slow, fast, pitch, clang_at, strength):
    out = np.zeros(int((sec + 0.7) * SR))
    s = screech(sec, slow, fast, pitch)
    out[:len(s)] += s
    c = clang(strength)
    i = int(clang_at * SR)
    out[i:i + len(c)] += c[:len(out) - i]
    return cave(out, 1.2, 0.3)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save_ogg("gate_open_0", gate(2.0, 18, 110, 1.0, 1.95, 0.5), 0.85)
    save_ogg("gate_open_1", gate(1.7, 24, 95, 0.9, 1.65, 0.5), 0.85)
    save_ogg("gate_close_0", gate(1.5, 20, 100, 1.05, 1.1, 0.9), 0.85)
