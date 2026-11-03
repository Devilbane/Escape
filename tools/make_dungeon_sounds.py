"""Builds the eerie dungeon sounds from scratch (noise, tones, filters and a
cave echo), so there are no licences to worry about: distant drips, moans,
rattling chains, whispers, creaking wood, howling wind and skittering
cockroaches. DungeonSounds (scripts/dungeon_sounds.gd) plays them now and
then somewhere around the hero. They are saved as small Ogg Vorbis files to
keep the browser version light.
Run: python3 tools/make_dungeon_sounds.py"""
import math, os, subprocess, wave
import numpy as np
from make_sounds import SR, OUT, lowpass, highpass, env, norm

rng = np.random.default_rng(41)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def place(out, x, sec):
    s = int(SR * sec)
    n = min(len(x), len(out) - s)
    if n > 0:
        out[s:s + n] += x[:n]
    return out


def bandpass(x, freq, q):
    # A resonant band-pass (RBJ biquad, 0 dB at the peak).
    w = 2 * math.pi * freq / SR
    alpha = math.sin(w) / (2 * q)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def sweep_bandpass(x, freqs, q):
    # Like bandpass, but the centre moves with every sample (freqs[i]).
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        w = 2 * math.pi * freqs[i] / SR
        alpha = math.sin(w) / (2 * q)
        a0 = 1 + alpha
        o = (alpha * v - alpha * x2 + 2 * math.cos(w) * y1 - (1 - alpha) * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def cave(x, sec=1.6, wet=0.4, dark=2500):
    # The stone hall around the sound: a few early echoes off the walls,
    # then a long, dark tail (noise that dies away, used as an impulse response).
    tt = t(sec)
    ir = lowpass(noise(sec), dark) * np.exp(-tt / (sec / 5))
    ir[0] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) * 2
    for d, g in [(0.031, 0.5), (0.057, 0.35), (0.089, 0.25)]:
        ir[int(SR * d)] += g
    # Scaled so the echo carries about as much energy as the sound itself:
    # a short knock leaves a soft tail, not a ringing one.
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(x) + len(ir)
    size = 1 << (n - 1).bit_length()
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
    dry = np.concatenate([x, np.zeros(len(ir))])
    return dry * (1 - wet) + tail * wet


def fade_out(x, sec=0.3):
    n = min(len(x), int(SR * sec))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save_ogg(name, x, peak=0.8):
    # Through a .wav to ffmpeg, then only the small .ogg is kept.
    x = norm(fade_out(x), peak)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                    "-q:a", "1", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


# --- The sounds -------------------------------------------------------------

def drop(freq):
    # One drop into a puddle: the rising "plink" of the air bubble, a splash.
    tt = t(0.3)
    f = freq * (1 + np.minimum(tt, 0.04) * 16)
    plink = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 0.045)
    splash = highpass(noise(0.3), 2200) * env(len(tt), 0.001, 0.01) * 0.2
    return plink + splash


def drips(times, base):
    # Drops falling one after another into a pool far down a corridor.
    x = np.zeros(int(SR * (times[-1] + 0.4)))
    for i, s in enumerate(times):
        place(x, drop(base * rng.uniform(0.9, 1.12)) * rng.uniform(0.6, 1.0), s)
    return cave(lowpass(x, 3500), 2.2, 0.4)


def moan(f_from, f_to, sec, vowels):
    # A hollow, wordless moan: a voice-like buzz gliding down, with a slow
    # wobble, shaped by two vowels ("oo" into "oh") and some breath.
    tt = t(sec)
    f0 = np.linspace(f_from, f_to, len(tt)) ** 1.0
    f0 = f0 * (1 + 0.025 * np.sin(2 * np.pi * 4.6 * tt) + 0.01 * np.sin(2 * np.pi * 0.7 * tt))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    buzz = sum(np.sin(phase * k) / k ** 1.3 for k in range(1, 12))
    buzz = buzz + lowpass(noise(sec), 1500) * 0.5
    shapes = []
    for formants in vowels:
        shapes.append(sum(bandpass(buzz, f, 6) * g for f, g in formants))
    blend = np.linspace(0, 1, len(tt))
    x = shapes[0] * (1 - blend) + shapes[1] * blend
    swell = np.minimum(1, tt / (sec * 0.3)) * np.minimum(1, (sec - tt) / (sec * 0.45))
    return cave(lowpass(x * swell, 1400), 2.4, 0.5, 1600)


OO = [(300, 1.0), (870, 0.45), (2240, 0.1)]
OH = [(430, 1.0), (820, 0.5), (2400, 0.1)]
AH = [(700, 1.0), (1100, 0.5), (2450, 0.12)]


def clink(heavy=False):
    # One chain link knocking against the next: thin metal that rings briefly.
    sec = 0.25
    tt = t(sec)
    x = np.zeros(len(tt))
    base = rng.uniform(1400, 2200) * (0.6 if heavy else 1.0)
    for ratio, a in [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2)]:
        f = min(base * ratio * rng.uniform(0.97, 1.03), SR / 2 - 400)
        x += np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * a * np.exp(-tt / rng.uniform(0.02, 0.06))
    x += highpass(noise(sec), 1500) * env(len(tt), 0.0005, 0.004) * 0.8
    return x


def chains(sec, links):
    # A chain swinging on a wall hook: a heavy clank, then links rattling in
    # bunches that grow sparse as it settles.
    x = np.zeros(int(SR * (sec + 0.3)))
    place(x, clink(True) * 1.0, 0.0)
    for _ in range(links):
        s = rng.uniform(0, 1) ** 1.8 * sec
        place(x, clink() * rng.uniform(0.25, 0.8) * (1 - s / sec * 0.6), s)
    return cave(lowpass(x, 4200), 1.8, 0.45)


VOWELS = [OO, OH, AH, [(400, 1.0), (2000, 0.5), (2550, 0.2)], [(300, 1.0), (2300, 0.4), (3000, 0.15)]]


def whisper(syllables, voice=1.0):
    # Breathy, unvoiced syllables (shaped noise) and a hiss or two: words
    # that cannot quite be made out.
    x = np.zeros(int(SR * (syllables * 0.3 + 0.6)))
    pos = 0.05
    for i in range(syllables):
        sec = rng.uniform(0.12, 0.26)
        n = noise(sec)
        v = VOWELS[rng.integers(len(VOWELS))]
        syl = sum(bandpass(n, f * voice, 5) * g for f, g in v)
        tt = t(sec)
        syl *= np.sin(np.pi * tt / sec) ** 1.5
        if rng.uniform() < 0.35:
            # An "s" or "sh" in front of the syllable.
            hs = rng.uniform(0.06, 0.12)
            hiss = bandpass(noise(hs), rng.uniform(3500, 5500), 2.5) * np.sin(np.pi * t(hs) / hs) * 0.7
            place(x, hiss, pos)
            pos += hs * 0.8
        place(x, syl * rng.uniform(0.6, 1.0), pos)
        pos += sec * rng.uniform(0.8, 1.05)
        if rng.uniform() < 0.25:
            pos += rng.uniform(0.08, 0.2)
    x = x[: int(SR * (pos + 0.1))]
    arc = np.sin(np.pi * np.linspace(0, 1, len(x))) ** 0.6
    return cave(x * arc, 1.4, 0.35, 3000)


def creak(sec, slow, fast):
    # Old wood bending under a weight (a door, a beam): the stick-slip of
    # fibres rubbing, a run of ticks whose rate climbs and falls, ringing in
    # the wood's own body tones.
    tt = t(sec)
    rate = slow + (fast - slow) * np.sin(np.pi * tt / sec) ** 2
    rate *= 1 + 0.12 * lowpass(rng.uniform(-1, 1, len(tt)), 8) * 30
    phase = np.cumsum(np.maximum(rate, 5)) / SR
    ticks = np.zeros(len(tt))
    ticks[1:][np.diff(np.floor(phase)) > 0] = 1
    ticks *= rng.uniform(0.5, 1.0, len(tt))
    body = bandpass(ticks, 380, 9) + bandpass(ticks, 910, 10) * 0.7 + bandpass(ticks, 1650, 12) * 0.4
    body += highpass(ticks, 2500) * 0.15
    shape = np.minimum(1, tt / 0.12) * np.minimum(1, (sec - tt) / 0.25)
    return cave(body * shape, 1.4, 0.4)


def wind(sec, low, high):
    # Wind howling through a crack somewhere far off: noise that sings in a
    # narrow band, rising and falling, over a soft rush.
    tt = t(sec)
    drift = lowpass(rng.uniform(-1, 1, len(tt)), 2) * 40
    centre = low + (high - low) * (0.5 - 0.5 * np.cos(2 * np.pi * tt / sec * 1.5)) * (0.8 + 0.2 * drift)
    centre = np.clip(centre, 120, 2000)
    n = noise(sec)
    howl = sweep_bandpass(n, centre, 28) + sweep_bandpass(n, centre * 2.01, 30) * 0.25
    rush = lowpass(noise(sec), 300) * 1.5
    swell = np.sin(np.pi * tt / sec) ** 1.4
    return cave((howl * 10 + rush * 0.6) * swell, 2.0, 0.35, 1500)


def scuttle(sec):
    # One beetle's run: tiny legs ticking fast over the stone.
    x = np.zeros(int(SR * sec))
    s = 0.0
    while s < sec - 0.01:
        tick = highpass(noise(0.004), 3000) * env(int(SR * 0.004), 0.0002, 0.0008)
        place(x, tick * rng.uniform(0.3, 1.0), s)
        s += rng.uniform(0.012, 0.035)
    return x * np.sin(np.pi * t(sec)[: len(x)] / sec) ** 0.5


def skitter(runs):
    # Cockroaches scurrying in the dark: a few quick runs with pauses, a
    # scratch of a shell, the swarm's dry rustle.
    x = np.zeros(int(SR * 2.4))
    s = 0.0
    for _ in range(runs):
        for _ in range(rng.integers(2, 4)):
            place(x, scuttle(rng.uniform(0.25, 0.6)) * rng.uniform(0.5, 1.0), s + rng.uniform(0, 0.1))
        s += rng.uniform(0.45, 0.8)
    x = x[: int(SR * (s + 0.3))]
    rustle = bandpass(noise(len(x) / SR), 5000, 1.5) * 0.04
    return cave(x + rustle, 0.8, 0.3, 5000)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save_ogg("dungeon_drip_0", drips([0.0], 1250), 0.7)
    save_ogg("dungeon_drip_1", drips([0.0, 0.85], 950), 0.7)
    save_ogg("dungeon_drip_2", drips([0.0, 0.6, 1.5], 1550), 0.7)
    save_ogg("dungeon_moan_0", moan(120, 82, 3.4, [OO, OH]), 0.8)
    save_ogg("dungeon_moan_1", moan(230, 165, 3.0, [AH, OO]), 0.8)
    save_ogg("dungeon_chains_0", chains(1.1, 16), 0.8)
    save_ogg("dungeon_chains_1", chains(0.7, 10), 0.8)
    save_ogg("dungeon_whisper_0", whisper(6, 1.0), 0.8)
    save_ogg("dungeon_whisper_1", whisper(4, 1.25), 0.8)
    save_ogg("dungeon_whisper_2", whisper(8, 0.85), 0.8)
    save_ogg("dungeon_creak_0", creak(1.5, 25, 140), 0.8)
    save_ogg("dungeon_creak_1", creak(1.0, 40, 90), 0.8)
    save_ogg("dungeon_wind_0", wind(5.0, 280, 620), 0.8)
    save_ogg("dungeon_wind_1", wind(4.2, 420, 900), 0.8)
    save_ogg("dungeon_skitter_0", skitter(2), 0.8)
    save_ogg("dungeon_skitter_1", skitter(3), 0.8)
