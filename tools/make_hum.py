"""Builds the tune Zecher Fritz sings his drinking songs to (see scripts/drinking_songs.gd):
four sung phrases, hum_0 to hum_3, one for each line of a verse, so a whole verse is one
little folk tune in D major, three beats to the bar. A tipsy baritone sings it on
"la", "lo" and "dum": a little off the note now and then, sliding up into some notes,
with a slow vibrato on the long ones, in a small, warm room.
Made from scratch (additive voice with vowel formants), so there are no licences to worry
about. Run: python3 tools/make_hum.py"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(23)

## D3, the tune's home note (Hz).
HOME = 146.83
## Seconds per beat: an easy swaying tempo.
BEAT = 0.4
## Vowel formants (Hz) and their strength: "a", "o" and a closed-mouth hum ("m").
VOWELS = {
    "a": [(700, 1.0), (1150, 0.55), (2600, 0.18)],
    "o": [(450, 1.0), (800, 0.5), (2700, 0.12)],
    "m": [(260, 1.0), (1000, 0.08), (2200, 0.03)],
}
## The four phrases: (semitones above D3, beats, vowel). Each lasts 8 beats.
PHRASES = [
    [(0, 1, "a"), (0, .5, "a"), (4, .5, "o"), (7, 1, "a"), (7, 1, "a"), (5, 1, "o"), (4, 1, "a"), (2, 2, "m")],
    [(4, 1, "a"), (5, .5, "o"), (4, .5, "a"), (2, 1, "a"), (0, 1, "o"), (2, 1, "a"), (4, 1, "a"), (-3, 2, "m")],
    [(7, 1, "a"), (7, .5, "a"), (9, .5, "o"), (11, 1, "a"), (12, 1, "o"), (11, 1, "a"), (9, 1, "a"), (7, 2, "m")],
    [(9, 1, "a"), (7, .5, "o"), (5, .5, "a"), (4, 1, "a"), (2, 1, "o"), (4, 1, "a"), (-3, 1, "a"), (0, 2, "m")],
]


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def phrase(notes):
    """The pitch (Hz), loudness and vowel weights of every sample of one phrase."""
    n = int(SR * BEAT * sum(b for _, b, _ in notes))
    semis = np.zeros(n)
    loud = np.zeros(n)
    weights = {v: np.zeros(n) for v in VOWELS}
    vib_depth = np.zeros(n)
    start = 0
    for i, (semi, beats, vowel) in enumerate(notes):
        length = int(SR * BEAT * beats)
        end = min(n, start + length)
        k = end - start
        tt = np.arange(k) / SR
        # A tipsy singer: a little off the note, and he scoops up into some.
        off = rng.normal(0, 0.12)
        scoop = np.zeros(k)
        if rng.random() < 0.35:
            scoop = -1.2 * np.exp(-tt / 0.05)
        semis[start:end] = semi + off + scoop
        # Each note starts with a soft consonant ("l", "d"): a short dip in loudness.
        env = np.minimum(1.0, tt / 0.045) * (0.88 + 0.12 * np.exp(-tt / 0.3))
        tail = np.minimum(1.0, (k - np.arange(k)) / (SR * (0.05 if i < len(notes) - 1 else 0.35)))
        loud[start:end] = env * tail * (1.0 if beats >= 1 else 0.85)
        weights[vowel][start:end] = 1.0
        # The vibrato grows on the held notes.
        vib_depth[start:end] = 0.28 * np.minimum(1.0, tt / 0.35) if beats >= 1 else 0.06
        start = end
    # Glide from note to note instead of jumping.
    semis = lowpass(semis, 18.0)
    for v in weights:
        weights[v] = lowpass(weights[v], 25.0)
    vib_depth = lowpass(vib_depth, 8.0)
    tt = np.arange(n) / SR
    vibrato = vib_depth * np.sin(2 * np.pi * 5.1 * tt + rng.random() * 6.0)
    # And a slow sway: the whole phrase drifts a little flat and sharp.
    sway = 0.15 * np.sin(2 * np.pi * 0.35 * tt + rng.random() * 6.0)
    f0 = HOME * 2 ** ((semis + vibrato + sway) / 12)
    return f0, loud, weights


def formant_gain(freq, vowel_weights, at):
    """How loud a harmonic at `freq` (one value per sample) comes through the mouth."""
    gain = np.zeros_like(freq)
    for vowel, formants in VOWELS.items():
        w = vowel_weights[vowel][at]
        g = np.zeros_like(freq)
        for centre, strength in formants:
            bw = 90.0 + centre * 0.06
            g += strength / (1.0 + ((freq - centre) / bw) ** 2)
        gain += w * g
    return gain


def sing(notes):
    f0, loud, weights = phrase(notes)
    n = len(f0)
    at = np.arange(n)
    phase = np.cumsum(2 * np.pi * f0 / SR)
    voice = np.zeros(n)
    for k in range(1, 28):
        freq = f0 * k
        if np.min(freq) > SR * 0.45:
            break
        amp = formant_gain(freq, weights, at) / k ** 0.9
        amp[freq > SR * 0.45] = 0.0
        voice += amp * np.sin(k * phase + rng.random() * 6.0)
    # A breath of air in the voice.
    breath = rng.uniform(-1, 1, n)
    breath = lowpass(breath, 2500) - lowpass(breath, 600)
    voice = voice * loud + breath * loud * 0.04
    return room(voice)


def room(x):
    """A small tavern room: a few short, soft echoes."""
    out = np.concatenate([x, np.zeros(int(SR * 0.4))])
    dry = out.copy()
    for delay, gain in [(0.031, 0.22), (0.047, 0.17), (0.071, 0.12), (0.113, 0.08)]:
        d = int(SR * delay)
        echo = np.zeros_like(dry)
        echo[d:] = dry[:-d]
        out += lowpass(echo, 1800) * gain
    return out


def save(name, x, peak=0.8):
    x = x / np.max(np.abs(x)) * peak
    fade = int(SR * 0.02)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    for i, notes in enumerate(PHRASES):
        save("hum_%d" % i, sing(notes))
