"""Builds the game's sound effects (and one sound per comic word) from scratch (noise, tones and envelopes),
so there are no licences to worry about. Run: python3 tools/make_sounds.py
The footsteps (step_*, sneak_*) and the door are real recordings instead, see
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


# --- Comic words: each word in a comic bubble gets its own sound. ---

def at(out, x, sec):
    s = int(SR * sec)
    n = min(len(x), len(out) - s)
    out[s:s + n] += x[:n]
    return out


def thud(freq, sec, drop=3.0, decay=0.08):
    # A deep body blow: a sine that falls in pitch.
    tt = t(sec)
    f = freq * np.exp(-tt * drop)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.002, decay)


def ring(partials, sec, decay):
    # Metal: a few out-of-tune partials that ring out.
    tt = t(sec)
    out = np.zeros(len(tt))
    for i, (f, a) in enumerate(partials):
        out += np.sin(2 * np.pi * f * tt) * a * np.exp(-tt / (decay / (1 + i * 0.4)))
    return out * env(len(tt), 0.0008, sec)


def word_zack():
    # A snappy, sharp smack.
    out = np.zeros(int(SR * 0.25))
    at(out, highpass(noise(0.05), 2500) * env(int(SR * 0.05), 0.0003, 0.008) * 1.4, 0)
    at(out, thud(260, 0.2, 6, 0.04), 0.003)
    return out


def word_klonk():
    # A hollow knock on a skull.
    tt = t(0.35)
    x = (np.sin(2 * np.pi * 330 * tt) + 0.6 * np.sin(2 * np.pi * 495 * tt) + 0.3 * np.sin(2 * np.pi * 760 * tt))
    x *= env(len(tt), 0.001, 0.06)
    return x + lowpass(noise(0.35), 1500) * env(len(tt), 0.0005, 0.01) * 2


def word_wumm():
    # A dull, deep blow.
    return thud(110, 0.45, 2.5, 0.12) * 1.2 + lowpass(noise(0.45), 400) * env(int(SR * 0.45), 0.002, 0.05) * 3


def word_krach():
    # A big crash: a hard hit with splintering crackle.
    out = np.zeros(int(SR * 0.6))
    at(out, thud(150, 0.4, 3, 0.1), 0)
    at(out, lowpass(noise(0.6), 2500) * env(int(SR * 0.6), 0.001, 0.12) * 1.5, 0)
    for i in range(10):
        c = highpass(noise(0.02), 2000) * env(int(SR * 0.02), 0.0003, 0.004) * rng.uniform(0.5, 1.0)
        at(out, c, 0.02 + i * 0.03 + rng.uniform(0, 0.02))
    return out


def word_boing():
    # A springy wobble.
    tt = t(0.7)
    f = 180 + 120 * np.exp(-tt * 3) + 45 * np.sin(2 * np.pi * 11 * tt) * np.exp(-tt * 2.5)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return x * env(len(tt), 0.003, 0.25)


def word_wamm():
    # A heavy slam: deep thud with a flat smack on top.
    out = thud(90, 0.5, 2, 0.14) * 1.3
    at(out, (lowpass(noise(0.15), 1800) - lowpass(noise(0.15), 300)) * env(int(SR * 0.15), 0.0005, 0.03) * 3, 0)
    return out


def word_zing():
    # A thrown blade singing through the air and biting.
    tt = t(0.5)
    f = 2400 + 600 * np.exp(-tt * 8)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 + ring([(3150, 0.4), (4380, 0.25)], 0.5, 0.12)
    return x * env(len(tt), 0.002, 0.13)


def word_tschak():
    # "Tsch" of the blade, then the dry "ack" as it lands.
    out = np.zeros(int(SR * 0.3))
    at(out, highpass(noise(0.1), 3000) * np.sin(np.pi * t(0.1) / 0.1) ** 2 * 0.8, 0)
    at(out, word_zack()[: int(SR * 0.15)], 0.08)
    return out


def word_knack():
    # A bone snapping.
    out = np.zeros(int(SR * 0.3))
    at(out, highpass(noise(0.04), 1200) * env(int(SR * 0.04), 0.0002, 0.006) * 1.5, 0)
    at(out, knock(900, 0.008) * 0.8, 0.002)
    at(out, highpass(noise(0.03), 1800) * env(int(SR * 0.03), 0.0002, 0.005), 0.05)
    return out


def word_klapper():
    # Loose bones clattering to the floor.
    r = np.random.default_rng(11)
    out = np.zeros(int(SR * 0.8))
    for i in range(18):
        k = knock(r.uniform(700, 1800), 0.006) * (1 - i / 22)
        at(out, k, i * 0.035 + r.uniform(0, 0.025))
    return out


def word_wusch():
    # A blade cutting only air: a long, airy whoosh.
    n = noise(0.4)
    tt = t(0.4)
    return (lowpass(n, 2500) - lowpass(n, 300)) * np.sin(np.pi * tt / 0.4) ** 2


def click(freq, sec=0.08):
    out = highpass(noise(sec), 2500) * env(int(SR * sec), 0.0002, 0.004)
    return at(out, knock(freq, 0.006), 0)


def word_klack():
    out = np.zeros(int(SR * 0.3))
    at(out, click(1200), 0)
    at(out, knock(380, 0.025), 0.06)
    return out


def word_klick():
    out = np.zeros(int(SR * 0.2))
    at(out, click(2600), 0)
    at(out, click(1900) * 0.6, 0.05)
    return out


def word_rumms():
    # Stone dropping into place.
    return thud(70, 0.8, 1.5, 0.2) * 1.4 + lowpass(noise(0.8), 250) * env(int(SR * 0.8), 0.002, 0.15) * 4


def word_grumpel():
    # Stones tumbling and grinding.
    r = np.random.default_rng(13)
    out = lowpass(noise(1.0), 300) * env(int(SR * 1.0), 0.05, 0.4) * 2
    for i in range(9):
        at(out, thud(r.uniform(80, 160), 0.2, 4, 0.05) * r.uniform(0.4, 0.9), i * 0.09 + r.uniform(0, 0.04))
    return out


def word_stich():
    # A quick thrust: a hiss and a sharp, wet bite.
    out = np.zeros(int(SR * 0.35))
    at(out, highpass(noise(0.08), 4000) * np.linspace(0, 1, int(SR * 0.08)) * 0.7, 0)
    at(out, thud(400, 0.15, 10, 0.03), 0.07)
    at(out, highpass(noise(0.05), 1500) * env(int(SR * 0.05), 0.0002, 0.01), 0.07)
    return out


def word_ratsch():
    # Cloth and leather tearing: rough noise with a rasping buzz.
    tt = t(0.4)
    n = lowpass(noise(0.4), 5000) - lowpass(noise(0.4), 900)
    buzz = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (60 + 80 * tt) * tt))
    return n * buzz * np.sin(np.pi * tt / 0.4) ** 0.5


def word_klong():
    # A blade bouncing off armour: a bright clang.
    return at(ring([(620, 0.8), (1480, 0.5), (2390, 0.35), (3510, 0.2)], 0.9, 0.3), click(3000) * 0.5, 0)


def word_plong():
    # A duller clang off a shield.
    return at(ring([(310, 0.9), (745, 0.4), (1190, 0.2)], 0.7, 0.18), knock(200, 0.02) * 0.5, 0)


WORDS = ["zack", "klonk", "wumm", "krach", "boing", "wamm", "zing", "tschak", "knack",
         "klapper", "wusch", "klack", "klick", "rumms", "grumpel", "stich", "ratsch",
         "klong", "plong"]


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
    save("lever", lever(), 0.8)
    save("rumble", rumble(), 0.9)
    save("drink", drink(), 0.5)
    save("magic", magic(), 0.5)
    save("secret", chime([523, 659, 784, 1047], 0.12, 0.25), 0.5)
    save("level_done", chime([392, 523, 659, 784], 0.15, 0.3), 0.5)
    save("gift", chime([784, 988, 1175], 0.1, 0.3), 0.45)
    amb = ambience()
    save("ambience", amb, 0.35)
    wav = os.path.join(OUT, "ambience.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", wav[:-4] + ".ogg"], check=True)
    os.remove(wav)
    for w in WORDS:
        save("word_" + w, globals()["word_" + w](), 0.7)
