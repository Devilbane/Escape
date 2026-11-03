"""Builds the fanfares that ring out when loot finer than rare turns up
(see Sfx.play_rarity): loot_epic for epic gear and loot_godborn for god-born
gear. Each one is bigger than the one below it, so the ear knows the tier
before the eye reads it:
- epic: a soft swell, a sparkling run of bells upwards and a shimmer;
- god-born: a deep boom, a swelling chord like a choir, a fast two-octave
  run of bells and one big bright bell that rings out with a long shimmer.
Made from scratch (tones, noise and envelopes), so there are no licences.
Needs numpy. Run: python3 tools/make_rarity_sounds.py"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(23)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack, decay):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / (SR * decay))
    return e


def at(out, x, sec, gain=1.0):
    s = int(SR * sec)
    n = min(len(x), len(out) - s)
    out[s:s + n] += x[:n] * gain
    return out


def bell(freq, sec, decay):
    # A glassy bell: the note, a ringing octave and two bright, slightly
    # out-of-tune partials that die away first.
    tt = t(sec)
    x = np.sin(2 * np.pi * freq * tt) * np.exp(-tt / decay)
    x += 0.5 * np.sin(2 * np.pi * freq * 2.0 * tt) * np.exp(-tt / (decay * 0.6))
    x += 0.25 * np.sin(2 * np.pi * freq * 2.76 * tt) * np.exp(-tt / (decay * 0.35))
    x += 0.15 * np.sin(2 * np.pi * freq * 5.4 * tt) * np.exp(-tt / (decay * 0.2))
    return x * env(len(tt), 0.002, sec * 10)


def shimmer(sec, low, high, attack, decay):
    # Fine glitter: a band of noise that flickers.
    n = noise(sec)
    band = lowpass(n, high) - lowpass(n, low)
    flicker = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t(sec)) * np.sin(2 * np.pi * 7 * t(sec))
    return band * flicker * env(len(n), attack, decay)


def swell(sec, peak_at):
    # Rising air, like a breath drawn in before the reveal.
    n = lowpass(noise(sec), 2500) - lowpass(noise(sec), 400)
    tt = t(sec)
    shape = np.where(tt < peak_at, (tt / peak_at) ** 2, np.exp(-(tt - peak_at) / 0.08))
    return n * shape


def boom(sec):
    # A deep, falling thump with a little grit on top.
    tt = t(sec)
    f = 75 * np.exp(-tt * 2.5) + 38
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.004, 0.35)
    grit = lowpass(noise(sec), 300) * env(len(tt), 0.002, 0.05) * 2
    return body + grit


def choir(freqs, sec, attack):
    # A swelling chord of soft, detuned voices with a slow vibrato.
    tt = t(sec)
    out = np.zeros(len(tt))
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt)
    for f in freqs:
        for detune in (0.997, 1.0, 1.003):
            ph = 2 * np.pi * np.cumsum(f * detune * vib) / SR
            out += np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    shape = np.minimum(1, tt / attack) * np.exp(-np.maximum(0, tt - attack) / (sec * 0.35))
    return lowpass(out, 2200) * shape


def epic():
    # E major, bright and magical: a breath in, then four bells upwards.
    out = np.zeros(int(SR * 1.7))
    at(out, swell(0.35, 0.3), 0.0, 0.25)
    for i, f in enumerate([659, 831, 988, 1319]):
        at(out, bell(f, 1.2, 0.35 + i * 0.08), 0.28 + i * 0.09, 0.9 - i * 0.1)
    at(out, shimmer(1.2, 3000, 7000, 0.15, 0.35), 0.4, 0.35)
    return out


def godborn():
    # A major, grand: a boom, a choir swelling up, a fast run of bells
    # over two octaves and one big bell that rings out for a long time.
    out = np.zeros(int(SR * 3.2))
    at(out, boom(1.2), 0.0, 1.0)
    at(out, swell(0.5, 0.45), 0.0, 0.3)
    at(out, choir([220, 277, 330, 440], 2.8, 0.6), 0.05, 0.12)
    run = [440, 554, 659, 880, 1109, 1319, 1760]
    for i, f in enumerate(run):
        at(out, bell(f, 1.0, 0.3), 0.35 + i * 0.06, 0.55)
    crown = 0.35 + len(run) * 0.06 + 0.05
    at(out, bell(880, 2.4, 0.9), crown, 1.1)
    at(out, bell(1760, 2.0, 0.6), crown, 0.45)
    at(out, boom(0.8), crown, 0.45)
    at(out, shimmer(2.2, 3500, 8000, 0.05, 0.7), crown, 0.45)
    return out


def save(name, x, peak):
    fade = int(SR * 0.08)
    x = x.copy()
    x[-fade:] *= np.linspace(1, 0, fade)
    x = np.concatenate([x, np.zeros(int(SR * 0.05))])
    x = x / max(1e-6, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    save("loot_epic", epic(), 0.6)
    save("loot_godborn", godborn(), 0.75)
