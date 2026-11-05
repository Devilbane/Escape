"""Builds the cruel, howling voices of the dungeon's ghosts and ghouls from
scratch (tones, noise, filters and the cave echo of make_dungeon_sounds), so
there are no licences to worry about:
  voice_totengeist_0/1  a wraith's hollow, gliding howl, several voices at once
  voice_banshee_0/1     a banshee's shrill, keening wail that rises and breaks
  banshee_shriek        her scream when she sees the hero (wakes the monsters)
  voice_ghul_0/1        a ghoul's wet, guttural snarl and gnashing
  ghost_scare           the howl that runs through the hero when frightened
Enemy plays the voices (KINDS "voice"), the shriek and the fright.
Run: python3 tools/make_ghost_sounds.py"""
import os
import numpy as np
from make_sounds import SR, OUT, lowpass, highpass, env
from make_dungeon_sounds import t, noise, bandpass, sweep_bandpass, cave, save_ogg

rng = np.random.default_rng(77)

OO = [(300, 1.0), (870, 0.45), (2240, 0.1)]
OH = [(430, 1.0), (820, 0.5), (2400, 0.1)]
AH = [(700, 1.0), (1100, 0.5), (2450, 0.12)]
EE = [(270, 0.8), (2300, 0.6), (3000, 0.25)]


def glide(points, sec):
    # A pitch curve through (time share, Hz) points.
    tt = np.linspace(0, 1, int(SR * sec))
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return np.interp(tt, xs, ys)


def voice(f0, sec, vowels, breath=0.4, rough=0.0):
    # A voice-like buzz on the pitch curve f0, shaped from one vowel into the
    # next, with breath and, for a cruel edge, a rough flutter (rough).
    tt = t(sec)
    f0 = f0[: len(tt)]
    if rough > 0:
        f0 = f0 * (1 + rough * lowpass(noise(sec), 30) * 6)
    phase = 2 * np.pi * np.cumsum(f0) / SR
    buzz = sum(np.sin(phase * k) / k ** 1.2 for k in range(1, 14))
    buzz = buzz + lowpass(noise(sec), 2000) * breath
    shapes = [sum(bandpass(buzz, f, 6) * g for f, g in formants) for formants in vowels]
    blend = np.linspace(0, 1, len(tt))
    return shapes[0] * (1 - blend) + shapes[1] * blend


def swell(sec, rise=0.25, fall=0.4):
    tt = t(sec)
    return np.minimum(1, tt / (sec * rise)) * np.minimum(1, (sec - tt) / (sec * fall))


def wraith(f_top, sec, seed):
    # Three hollow voices howl together, slightly apart in pitch and time,
    # gliding up into the howl and sinking away, over a cold wind.
    global rng
    rng = np.random.default_rng(seed)
    x = np.zeros(int(SR * sec))
    for detune, delay in [(1.0, 0.0), (0.985, 0.06), (1.02, 0.11)]:
        f0 = glide([(0, f_top * 0.55), (0.3, f_top), (0.55, f_top * 0.92), (1, f_top * 0.4)], sec) * detune
        tt = t(sec)
        f0 = f0 * (1 + 0.03 * np.sin(2 * np.pi * 5.2 * tt + detune * 9))
        v = voice(f0, sec, [OO, OH], 0.5) * swell(sec)
        s = int(SR * delay)
        x[s:] += v[: len(x) - s] * 0.6
    wind = sweep_bandpass(noise(sec), glide([(0, 500), (0.4, 1100), (1, 380)], sec), 4) * 0.35 * swell(sec, 0.4, 0.5)
    return cave(lowpass(x + wind, 1800), 2.6, 0.55, 1800)


def banshee(f_top, sec, seed):
    # A thin, shrill wail that climbs, trembles hard and breaks off at the top.
    global rng
    rng = np.random.default_rng(seed)
    tt = t(sec)
    f0 = glide([(0, f_top * 0.6), (0.45, f_top), (0.7, f_top * 1.08), (0.82, f_top * 0.7), (1, f_top * 0.5)], sec)
    f0 = f0 * (1 + 0.045 * np.sin(2 * np.pi * 7.5 * tt))
    v = voice(f0, sec, [EE, AH], 0.6, 0.002)
    v = highpass(v, 400) * swell(sec, 0.3, 0.3)
    return cave(v, 2.2, 0.5, 4000)


def shriek():
    # The banshee's scream: piercing, rough and loud, two voices clashing.
    sec = 1.5
    tt = t(sec)
    f_a = glide([(0, 900), (0.15, 1500), (0.7, 1400), (1, 700)], sec)
    f_b = f_a * 1.06
    x = voice(f_a, sec, [EE, AH], 0.9, 0.004) + voice(f_b, sec, [AH, EE], 0.9, 0.004) * 0.7
    hiss = bandpass(noise(sec), 3200, 1.2) * 0.5
    x = highpass(x + hiss, 500) * swell(sec, 0.05, 0.5) * (1 + 0.3 * np.sin(2 * np.pi * 11 * tt))
    return cave(np.tanh(x * 2.5), 2.0, 0.45, 4500)


def ghoul(f, sec, seed):
    # A wet, guttural snarl: a low rough growl with a gnash of teeth.
    global rng
    rng = np.random.default_rng(seed)
    tt = t(sec)
    f0 = glide([(0, f * 0.8), (0.3, f * 1.15), (1, f * 0.7)], sec)
    growl = voice(f0, sec, [AH, OH], 0.8, 0.012)
    growl = np.tanh(growl * 3.0) * swell(sec, 0.1, 0.4)
    # Saliva and teeth: short clicks and wet noise bursts.
    wet = np.zeros(len(tt))
    for s in rng.uniform(0.1, sec - 0.15, 5):
        n = int(SR * 0.05)
        i = int(SR * s)
        wet[i:i + n] += bandpass(noise(0.05), rng.uniform(1800, 3200), 3) * env(n, 0.001, 0.012)
    return cave(lowpass(growl, 2200) + wet * 0.8, 1.2, 0.35, 2500)


def scare():
    # The fright: a sudden rush of howling voices that dive past the hero.
    sec = 2.2
    x = np.zeros(int(SR * sec))
    for f, delay, g in [(420, 0.0, 1.0), (560, 0.05, 0.7), (300, 0.12, 0.8)]:
        f0 = glide([(0, f * 1.5), (0.2, f * 1.7), (1, f * 0.45)], sec)
        v = voice(f0, sec, [OO, AH], 0.6, 0.004) * swell(sec, 0.04, 0.6)
        s = int(SR * delay)
        x[s:] += v[: len(x) - s] * g
    rush = sweep_bandpass(noise(sec), glide([(0, 3000), (1, 400)], sec), 2) * 0.6 * swell(sec, 0.02, 0.7)
    return cave(np.tanh((x + rush) * 1.6), 2.4, 0.5, 3000)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save_ogg("voice_totengeist_0", wraith(240, 2.4, 1), 0.8)
    save_ogg("voice_totengeist_1", wraith(190, 2.8, 2), 0.8)
    save_ogg("voice_banshee_0", banshee(820, 2.0, 3), 0.75)
    save_ogg("voice_banshee_1", banshee(700, 2.4, 4), 0.75)
    save_ogg("banshee_shriek", shriek(), 0.85)
    save_ogg("voice_ghul_0", ghoul(85, 1.1, 5), 0.8)
    save_ogg("voice_ghul_1", ghoul(70, 1.4, 6), 0.8)
    save_ogg("ghost_scare", scare(), 0.85)
