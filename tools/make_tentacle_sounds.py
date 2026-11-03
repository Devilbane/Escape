"""Builds the gurgle that warns of a tentacle under a floor grate (see
GrateTentacles, scripts/grate_tentacles.gd): bubbles rising through dark
water, each a little "blop" whose pitch climbs, over a low wet slosh, with a
faint echo off the pit's stone. Made from scratch, so there are no licences
to worry about. Run: python3 tools/make_tentacle_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, t, noise, lowpass, env, save, at

rng = np.random.default_rng(23)


def blop(freq, sec):
    # One bubble bursting: a short sine whose pitch rises as it shrinks.
    tt = t(sec)
    f = freq * (1 + tt / sec * 1.6)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.004, sec * 0.35)


def gurgle(sec=1.4):
    x = np.zeros(int(SR * sec))
    s = 0.0
    while s < sec - 0.15:
        at(x, blop(rng.uniform(160, 420), rng.uniform(0.06, 0.13)) * rng.uniform(0.4, 1.0), s)
        s += rng.uniform(0.04, 0.14)
    # The slosh of the water below, swelling and fading.
    slosh = lowpass(noise(sec), 260) * np.sin(np.pi * t(sec) / sec) * 3.0
    x = x + slosh[: len(x)]
    echo = np.zeros(len(x))
    at(echo, x * 0.3, 0.09)
    at(echo, x * 0.12, 0.2)
    return x + lowpass(echo, 900)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("tentacle_gurgle", gurgle(), 0.8)
