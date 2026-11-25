"""Builds the squelch of a foot in the sewers' slime patches (see SewerSlime, scripts/sewer_slime.gd).
Synthesised from scratch (noise, sine bubbles and envelopes), so there is no licence to note:

  slime_squelch_0..3  a wet, ugly squelch: a low smack as the boot lands, a suction that rises
                      and breaks into a handful of popping bubbles, and a drawn-out slurp as
                      the foot lifts out of the muck

Run from the tools folder: python3 make_slime_squelch.py"""
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, highpass, env, save, at

rng = np.random.default_rng(23)


def bubble(f0, f1, sec, bend=0.0):
    # A bubble bursting: a sine whose pitch glides f0 -> f1 and that dies away fast.
    tt = t(sec)
    f = f0 + (f1 - f0) * (tt / sec) ** (1.0 + bend)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.004, sec * 0.3)


def squelch(i):
    r = np.random.default_rng(100 + i)
    sec = r.uniform(0.38, 0.5)
    n = int(SR * sec)
    out = np.zeros(n)
    # The smack: a low thud and a burst of wet noise as the sole lands.
    at(out, bubble(150, 60, 0.12) * 0.9, 0.0)
    smack = lowpass(highpass(noise(0.08), 400), 2400) * env(int(SR * 0.08), 0.002, 0.03)
    at(out, smack * 0.7, 0.0)
    # The suction: band-limited noise, chopped by an uneven crackle, swelling then falling.
    tt = np.arange(n) / SR
    body = lowpass(highpass(noise(sec), 250), 1500)
    crackle = np.clip(np.sin(2 * np.pi * (28 + 14 * np.sin(tt * r.uniform(9, 15))) * tt + r.uniform(0, 6)), 0, 1) ** 1.5
    swell = np.sin(np.pi * np.clip(tt / sec, 0, 1)) ** 1.3
    at(out, body * (0.35 + 0.65 * crackle) * swell * 0.55, 0.03)
    # The bubbles: rising pops, a few early, a few trailing.
    for k in range(int(r.integers(4, 8))):
        start = r.uniform(0.03, sec * 0.8)
        f0 = r.uniform(180, 420)
        at(out, bubble(f0, f0 * r.uniform(1.8, 3.2), r.uniform(0.025, 0.07), r.uniform(0, 0.6)) * r.uniform(0.25, 0.6), start)
    # The slurp as the foot comes out: a long downward glide, soft at both ends.
    slurp = bubble(r.uniform(520, 700), r.uniform(120, 180), 0.2, 0.5) * np.sin(np.pi * np.linspace(0, 1, int(SR * 0.2))) ** 0.7
    at(out, slurp * 0.45, sec * 0.45)
    out = lowpass(out, 5200)
    return out


if __name__ == "__main__":
    for i in range(4):
        save("slime_squelch_%d" % i, squelch(i), 0.9)
