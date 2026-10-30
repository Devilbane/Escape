"""Builds the game's sound effects from scratch (noise, tones and envelopes),
so there are no licences to worry about. Run: python3 tools/make_sounds.py
The footsteps (step_*, sneak_*) are real recordings instead, see
assets/sounds/CREDITS.txt."""
import os, subprocess, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cutoff):
    # One-pole low-pass, run twice for a softer slope.
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(2):
        y = np.zeros_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack, decay):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / (SR * decay))
    return e


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def pad(x, sec=0.05):
    return np.concatenate([x, np.zeros(int(SR * sec))])


def save(name, x, peak=0.9):
    x = norm(pad(x), peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def scuff(sec, low, high, attack, decay):
    # Band of noise, like a boot sole brushing over stone.
    n = noise(sec)
    return (lowpass(n, high) - lowpass(n, low)) * env(len(n), attack, decay)


def swing():
    n = noise(0.28)
    tt = t(0.28)
    # A band of noise sweeping up then down: the whoosh of a blade.
    sweep = lowpass(n, 1800) - lowpass(n, 500)
    shape = np.sin(np.pi * tt / 0.28) ** 2
    return sweep * shape


def hit():
    n = noise(0.2)
    body = lowpass(n, 900) * env(len(n), 0.001, 0.04) * 2
    crack = highpass(noise(0.2), 3000) * env(len(n), 0.0005, 0.01)
    return body + crack


def bones():
    # Skeleton falls apart: a quick rattle of dry clicks.
    out = np.zeros(int(SR * 0.7))
    for i in range(14):
        at = int(SR * (i * 0.04 + rng.uniform(0, 0.02)))
        f = rng.uniform(900, 2200)
        c = np.sin(2 * np.pi * f * t(0.03)) * env(int(SR * 0.03), 0.0005, 0.006)
        c += highpass(noise(0.03), 2000) * env(int(SR * 0.03), 0.0005, 0.004) * 0.6
        out[at:at + len(c)] += c * (1 - i / 16)
    return out


def hurt():
    tt = t(0.3)
    f = 220 * np.exp(-tt * 3)
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3
    out = lowpass(tone, 1200) * env(len(tt), 0.005, 0.09)
    h = hit()
    out[: len(h)] += h * 0.5
    return out


def throw():
    n = noise(0.18)
    tt = t(0.18)
    return (lowpass(n, 3500) - lowpass(n, 1200)) * np.sin(np.pi * tt / 0.18) ** 3


def coin():
    tt = t(0.45)
    a = np.sin(2 * np.pi * 1975 * tt) * env(len(tt), 0.001, 0.08)
    b = np.sin(2 * np.pi * 2637 * tt) * env(len(tt), 0.001, 0.12)
    b[: int(SR * 0.07)] = 0
    return a + b


def key():
    tt = t(0.6)
    out = np.zeros(len(tt))
    for i, f in enumerate([1318, 1568, 2093]):
        s = int(SR * i * 0.07)
        out[s:] += np.sin(2 * np.pi * f * tt[: len(tt) - s]) * env(len(tt) - s, 0.001, 0.15)
    return out


def creak(sec, base):
    tt = t(sec)
    # Wood creak: a scratchy pulse train with a wobbling pitch.
    f = base * (1 + 0.25 * np.sin(2 * np.pi * 1.3 * tt) + 0.1 * np.sin(2 * np.pi * 7 * tt))
    phase = np.cumsum(f) / SR
    pulses = (np.mod(phase, 1.0) < 0.08).astype(float)
    x = lowpass(pulses - pulses.mean(), 2500)
    return x * np.sin(np.pi * tt / sec)


def knock(freq, decay):
    # A small wooden knock: a short, damped ring.
    tt = t(decay * 6)
    return np.sin(2 * np.pi * freq * tt) * np.exp(-tt / decay)


def rummage(seed=3):
    # Hands going through a barrel or crate: a few dry rustles and the
    # light knock of things bumping into wood.
    r = np.random.default_rng(seed)
    out = np.zeros(int(SR * 0.55))
    for _ in range(5):
        at = int(r.uniform(0, 0.4) * SR)
        rustle = scuff(r.uniform(0.05, 0.1), 1500, 6000, 0.008, r.uniform(0.02, 0.035)) * r.uniform(0.4, 0.8)
        out[at:at + len(rustle)] += rustle[: len(out) - at]
    for _ in range(3):
        at = int(r.uniform(0.05, 0.45) * SR)
        k = knock(r.uniform(350, 700), 0.012) * r.uniform(0.3, 0.6)
        out[at:at + len(k)] += k[: len(out) - at]
    return out


def chest():
    # A heavy lid: a short squeak of the hinge, then the rummaging.
    tt = t(0.22)
    f = 700 + 500 * tt / 0.22 + 25 * np.sin(2 * np.pi * 30 * tt)
    squeak = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.22) * 0.25
    lid = knock(180, 0.03) * 0.5
    out = np.zeros(int(SR * 0.9))
    out[: len(squeak)] += squeak
    out[int(SR * 0.22): int(SR * 0.22) + len(lid)] += lid
    r = rummage(5)
    out[int(SR * 0.3): int(SR * 0.3) + len(r)] += r[: len(out) - int(SR * 0.3)]
    return out


def door():
    c = creak(0.9, 55)
    thud = lowpass(noise(0.5), 150) * env(int(SR * 0.5), 0.002, 0.12) * 4
    out = np.zeros(len(c) + len(thud))
    out[: len(c)] += c
    out[len(c) - int(SR * 0.05):len(c) - int(SR * 0.05) + len(thud)] += thud
    return out


def lever():
    a = highpass(noise(0.05), 1500) * env(int(SR * 0.05), 0.0005, 0.008)
    b = lowpass(noise(0.15), 600) * env(int(SR * 0.15), 0.001, 0.03) * 2
    out = np.zeros(int(SR * 0.3))
    out[: len(a)] += a
    out[int(SR * 0.08): int(SR * 0.08) + len(b)] += b
    return out


def rumble():
    n = noise(2.2)
    tt = t(2.2)
    x = lowpass(n, 90) * 6
    x *= np.minimum(1, tt / 0.3) * np.minimum(1, (2.2 - tt) / 0.8)
    grind = (lowpass(noise(2.2), 700) - lowpass(noise(2.2), 250)) * 0.6
    return x + grind * np.minimum(1, (2.2 - tt) / 0.8)


def drink():
    out = np.zeros(int(SR * 0.9))
    for i in range(9):
        at = int(SR * (i * 0.09 + rng.uniform(0, 0.03)))
        d = 0.05
        tt = t(d)
        f = rng.uniform(400, 900) * (1 + tt * 12)
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.002, 0.015)
        out[at:at + len(b)] += b
    return out


def magic():
    tt = t(0.6)
    f = 500 + 900 * tt
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.25
    x += (lowpass(noise(0.6), 3000) - lowpass(noise(0.6), 800)) * 0.4
    return x * np.sin(np.pi * tt / 0.6)


def bow():
    tt = t(0.35)
    out = np.sin(2 * np.pi * 180 * tt) * env(len(tt), 0.001, 0.06)
    w = throw()
    out[: len(w)] += w * 0.5
    return out


def chime(notes, gap, decay):
    total = gap * len(notes) + decay * 4
    tt = t(total)
    out = np.zeros(len(tt))
    for i, f in enumerate(notes):
        s = int(SR * i * gap)
        seg = tt[: len(tt) - s]
        out[s:] += (np.sin(2 * np.pi * f * seg) + 0.3 * np.sin(4 * np.pi * f * seg)) * env(len(seg), 0.002, decay)
    return out


def ambience():
    # A slow cave wind with the odd drop of water. It loops seamlessly because
    # the end fades into the start.
    sec = 16.0
    n = noise(sec + 2)
    wind = lowpass(n, 220) * 3
    wobble = 0.6 + 0.4 * np.sin(2 * np.pi * t(sec + 2) / 8.0)
    wind = wind * wobble
    x = wind[: int(SR * sec)].copy()
    tail = wind[int(SR * sec):]
    fade = np.linspace(0, 1, len(tail))
    x[: len(tail)] = x[: len(tail)] * fade + tail * (1 - fade)
    for at in [1.3, 5.9, 8.2, 12.7, 14.1]:
        f = rng.uniform(900, 1500)
        d = t(0.25)
        drop = np.sin(2 * np.pi * np.cumsum(f * (1 + d * 2)) / SR) * env(len(d), 0.001, 0.04) * 0.5
        s = int(SR * at)
        x[s:s + len(drop)] += drop
    return x


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("swing", swing(), 0.6)
    save("hit", hit(), 0.8)
    save("bones", bones(), 0.7)
    save("hurt", hurt(), 0.8)
    save("throw", throw(), 0.5)
    save("coin", coin(), 0.45)
    save("key", key(), 0.5)
    save("chest", chest(), 0.6)
    save("rummage", rummage(), 0.5)
    save("door", door(), 0.8)
    save("lever", lever(), 0.8)
    save("rumble", rumble(), 0.9)
    save("drink", drink(), 0.5)
    save("magic", magic(), 0.5)
    save("bow", bow(), 0.6)
    save("secret", chime([523, 659, 784, 1047], 0.12, 0.25), 0.5)
    save("level_done", chime([392, 523, 659, 784], 0.15, 0.3), 0.5)
    save("gift", chime([784, 988, 1175], 0.1, 0.3), 0.45)
    amb = ambience()
    save("ambience", amb, 0.35)
    wav = os.path.join(OUT, "ambience.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)
