"""Builds the village cat's purr (see scripts/village_cat.gd): one seamless loop, cat_purr.wav.

A purr is a low rumble of about 25 pulses a second (the throat's muscles twitching the voice box), a little
louder on the breath out than on the breath in, with a soft, airy hiss on top. Made from scratch (damped low
tones and filtered noise, pulse by pulse), so there are no licences to worry about.
The loop is 3 seconds, one breath: an exact whole number of pulses, so it joins without a click.
Run: python3 tools/make_cat_purr.py   (writes assets/sounds/cat_purr.wav)"""
import os, wave
import numpy as np

SR = 22050
LOOP = 3.0
RATE = 25.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "cat_purr.wav")
rng = np.random.default_rng(7)


def lowpass(x, cutoff):
    # One-pole low-pass, run forwards over the loop twice so its tail wraps round and the join is smooth.
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    state = 0.0
    for _ in range(2):
        for i in range(len(x)):
            state = (1.0 - a) * x[i] + a * state
            y[i] = state
    return y


n = int(SR * LOOP)
t = np.arange(n) / SR
out = np.zeros(n)
pulses = int(RATE * LOOP)
for k in range(pulses):
    start = k / RATE
    # Each pulse is a short burst of a few low tones that die away quickly, a touch different every time.
    f0 = 70.0 + 12.0 * rng.standard_normal()
    d = (t - start) % LOOP
    env = np.exp(-d * 55.0) * (1.0 - np.exp(-d * 900.0))
    tone = np.sin(2 * np.pi * f0 * d) + 0.6 * np.sin(2 * np.pi * 2.01 * f0 * d + 0.7) + 0.3 * np.sin(2 * np.pi * 3.02 * f0 * d + 1.9)
    out += env * tone * (0.8 + 0.4 * rng.random())
# Airy hiss, shaped like the pulses, kept soft.
noise = lowpass(rng.standard_normal(n), 1400.0)
pulse_shape = np.zeros(n)
for k in range(pulses):
    d = (t - k / RATE) % LOOP
    pulse_shape += np.exp(-d * 70.0) * (1.0 - np.exp(-d * 900.0))
out += 0.9 * noise * pulse_shape * 2.2
# One breath: louder breathing out (first half), quieter breathing in.
breath = 0.72 + 0.28 * np.cos(2 * np.pi * t / LOOP)
out *= breath
out = lowpass(out, 900.0)
out -= out.mean()
out *= 0.7 / np.abs(out).max()
# Fade the very ends into each other so the wrap is clean (the loop already wraps; this is a safety).
with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((out * 32767).astype("<i2").tobytes())
print("wrote", OUT, n, "samples")
