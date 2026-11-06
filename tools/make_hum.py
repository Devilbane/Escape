"""Builds the tune Zecher Fritz sings his drinking songs to (see scripts/drinking_songs.gd):
four sung phrases, hum_0 to hum_3, one for each line of a verse, so a whole verse is one
little folk tune in G major, three beats to the bar, one sung syllable for every syllable
of a line ("Der Krug ist leer, der Wirt ist taub": eight syllables, eight notes).

Fritz is an old, tipsy bass. He sings "la la la" (now and then "lo"): a deep, worn voice
that crackles and rasps (vocal fry at the start and the end of a phrase, an uneven,
shaky tone in between), a little off the note, scooping up into some notes, with a slow,
wide old man's wobble on the long ones, in a small, warm tavern room.

Made from scratch with a source-filter voice (a glottal pulse train, cycle by cycle, through
five vocal-tract resonances), so there are no licences to worry about.
Run: python3 tools/make_hum.py   (writes assets/sounds/hum_*.wav; --demo also writes
the whole verse as one file to the path given after it)"""
import os, sys, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(23)

## G2, the tune's home note (Hz): a deep bass.
HOME = 98.0
## Seconds per beat: an easy swaying tempo (8 beats = DrinkingSongs.LINE_TIME).
BEAT = 0.4
## Vocal-tract resonances (formants) of a bass: (Hz, bandwidth Hz) for F1 to F5, and how
## loud the sound comes out. "l" is the tongue against the teeth: low, muffled, a little nasal.
SOUNDS = {
    "a": ([(640, 80), (1080, 90), (2350, 120), (2900, 160), (3400, 200)], 1.0),
    "o": ([(430, 70), (760, 80), (2350, 120), (2850, 160), (3350, 200)], 0.95),
    "l": ([(330, 70), (1050, 140), (2600, 180), (3100, 220), (3500, 250)], 0.28),
}
## The four phrases: (semitones above G2, beats, vowel). Each lasts 8 beats. Every note is
## sung "l" + vowel.
PHRASES = [
    [(0, 1, "a"), (0, .5, "a"), (4, .5, "o"), (7, 1, "a"), (7, 1, "a"), (5, 1, "o"), (4, 1, "a"), (2, 2, "a")],
    [(4, 1, "a"), (5, .5, "o"), (4, .5, "a"), (2, 1, "a"), (0, 1, "o"), (2, 1, "a"), (4, 1, "a"), (-3, 2, "o")],
    [(7, 1, "a"), (7, .5, "a"), (9, .5, "o"), (11, 1, "a"), (12, 1, "o"), (11, 1, "a"), (9, 1, "a"), (7, 2, "a")],
    [(9, 1, "a"), (7, .5, "o"), (5, .5, "a"), (4, 1, "a"), (2, 1, "o"), (4, 1, "a"), (-3, 1, "a"), (0, 2, "a")],
]
## How long the "l" of a syllable lasts and how long the tongue takes to the vowel (s).
L_HOLD = 0.035
L_GLIDE = 0.06


def smooth(x, cutoff):
    """A one-pole low-pass: lets a control curve glide instead of jump."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = x[0]
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def score(notes):
    """Per sample: pitch (semitones), loudness, how far into the vowel the mouth is
    (0 = "l", 1 = vowel), which vowel, and how much the voice creaks."""
    n = int(SR * BEAT * sum(b for _, b, _ in notes))
    semis = np.zeros(n)
    loud = np.zeros(n)
    open_ = np.zeros(n)
    vowel_o = np.zeros(n)
    vib = np.zeros(n)
    start = 0
    for i, (semi, beats, vowel) in enumerate(notes):
        k = min(n, start + int(SR * BEAT * beats)) - start
        tt = np.arange(k) / SR
        # A tipsy singer: a little off the note, and he scoops up into some.
        scoop = -1.4 * np.exp(-tt / 0.06) if rng.random() < 0.4 else 0.0
        semis[start:start + k] = semi + rng.normal(0, 0.15) + scoop
        # "l" (voiced, but quiet and muffled), then the tongue slides into the vowel.
        open_[start:start + k] = np.clip((tt - L_HOLD) / L_GLIDE, 0.0, 1.0)
        vowel_o[start:start + k] = 1.0 if vowel == "o" else 0.0
        last = i == len(notes) - 1
        swell = 0.9 + 0.1 * np.minimum(1.0, tt / 0.15)
        tail = np.minimum(1.0, (k - np.arange(k)) / (SR * (0.5 if last else 0.03)))
        loud[start:start + k] = swell * tail * (1.0 if beats >= 1 else 0.88)
        # The wobble grows on the held notes.
        vib[start:start + k] = 0.4 * np.minimum(1.0, tt / 0.4) if beats >= 1 else 0.08
        start += k
    # Voice onset: the very first "l" comes out of nothing.
    on = int(SR * 0.04)
    loud[:on] *= np.linspace(0, 1, on)
    semis = smooth(semis, 16.0)
    vib = smooth(vib, 6.0)
    tt = np.arange(n) / SR
    # An old man's wobble: slow, wide and not quite even.
    rate = 4.6 + 0.6 * np.sin(2 * np.pi * 0.5 * tt + rng.random() * 6)
    wobble = vib * np.sin(np.cumsum(2 * np.pi * rate / SR) + rng.random() * 6)
    sway = 0.15 * np.sin(2 * np.pi * 0.33 * tt + rng.random() * 6)
    # Creak: strong as he starts a phrase and as his breath runs out at its end,
    # a steady rasp in between, more on the low notes.
    creak = 0.18 + 0.55 * np.exp(-tt / 0.25) + 0.75 * np.clip((tt - (n / SR - 0.9)) / 0.9, 0, 1)
    creak += 0.15 * np.clip(-semis / 4.0, 0, 1)
    return semis + wobble + sway, loud, smooth(open_, 60.0), smooth(vowel_o, 30.0), np.clip(creak, 0, 1)


def glottis(semis, creak):
    """The voice source: one glottal pulse per vocal-fold cycle. Each cycle gets its own
    length (jitter) and strength (shimmer); a creaking voice skips about, pairs its pulses
    (one strong, one weak: vocal fry) and rasps with air while the folds are open."""
    n = len(semis)
    f0 = HOME * 2 ** (semis / 12)
    src = np.zeros(n)
    air = np.zeros(n)
    i = 0
    odd = False
    while i < n:
        c = creak[i]
        period = SR / f0[i] * (1.0 + rng.normal(0, 0.012 + 0.07 * c))
        amp = 1.0 + rng.normal(0, 0.06 + 0.25 * c)
        # Fry: every other pulse weak and late, so the pitch "rattles" below the note.
        odd = not odd
        if c > 0.45 and rng.random() < c:
            if odd:
                amp *= 0.35 + 0.3 * rng.random()
            period *= 1.0 + 0.5 * c * rng.random()
        length = max(8, int(period))
        # Rosenberg pulse: the folds open (rise), close fast (fall), stay shut. A tight,
        # creaky voice opens for a shorter time and closes harder.
        oq = 0.62 - 0.22 * c
        rise = max(2, int(length * oq * 0.68))
        fall = max(2, int(length * oq * 0.32))
        flow = np.zeros(length)
        flow[:rise] = 0.5 * (1 - np.cos(np.pi * np.arange(rise) / rise))
        flow[rise:rise + fall] = np.cos(0.5 * np.pi * np.arange(fall) / fall)
        end = min(n, i + length)
        src[i:end] += (amp * flow)[:end - i]
        air[i:end] += (flow > 0.05)[:end - i] * (0.25 + 0.75 * c)
        i += length
    # The mouth radiates the change of the flow.
    src = np.diff(src, prepend=0.0)
    src /= np.max(np.abs(src)) + 1e-9
    # Breath and rasp: noise that comes out while the folds are open.
    noise = rng.normal(0, 1, n)
    noise = noise - smooth(noise, 500.0)
    return src + 0.09 * air * noise


def resonate(x, freq, bw):
    """A two-pole resonator (Klatt) whose frequency and bandwidth change per sample."""
    t = 1.0 / SR
    c = -np.exp(-2 * np.pi * bw * t)
    b = 2 * np.exp(-np.pi * bw * t) * np.cos(2 * np.pi * freq * t)
    a = 1 - b - c
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i in range(len(x)):
        v = a[i] * x[i] + b[i] * y1 + c[i] * y2
        y2 = y1
        y1 = v
        y[i] = v
    return y


def tract(src, open_, vowel_o):
    """The source through the vocal tract: five resonances that glide from "l" to the vowel."""
    v = SOUNDS["a"][0], SOUNDS["o"][0]
    l_f = SOUNDS["l"][0]
    out = src
    for f in range(5):
        vf = v[0][f][0] * (1 - vowel_o) + v[1][f][0] * vowel_o
        vb = v[0][f][1] * (1 - vowel_o) + v[1][f][1] * vowel_o
        freq = l_f[f][0] * (1 - open_) + vf * open_
        bw = l_f[f][1] * (1 - open_) + vb * open_
        out = resonate(out, freq, bw)
    gain = SOUNDS["l"][1] * (1 - open_) + open_ * (1 - 0.05 * vowel_o)
    return out * gain


def sing(notes):
    semis, loud, open_, vowel_o, creak = score(notes)
    voice = tract(glottis(semis, creak), open_, vowel_o) * loud
    # An old voice: the top is dull, and there is no boom below the voice.
    voice = smooth(voice, 3800.0)
    voice = voice - smooth(voice, 70.0)
    return room(voice)


def room(x):
    """A small tavern room: a few short, soft echoes."""
    out = np.concatenate([x, np.zeros(int(SR * 0.4))])
    dry = out.copy()
    for delay, gain in [(0.029, 0.2), (0.043, 0.16), (0.067, 0.12), (0.109, 0.08), (0.157, 0.05)]:
        d = int(SR * delay)
        echo = np.zeros_like(dry)
        echo[d:] = dry[:-d]
        out += smooth(echo, 1600) * gain
    return out


def save(path, x, peak=0.8):
    x = x / np.max(np.abs(x)) * peak
    fade = int(SR * 0.02)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    phrases = [sing(notes) for notes in PHRASES]
    for i, x in enumerate(phrases):
        save(os.path.join(OUT, "hum_%d.wav" % i), x)
    if "--demo" in sys.argv:
        # The verse as the game plays it: a new phrase every 8 beats, the last ringing out.
        step = int(SR * BEAT * 8)
        verse = np.zeros(step * 3 + len(phrases[-1]))
        for i, x in enumerate(phrases):
            x = x / np.max(np.abs(x))
            verse[i * step:i * step + len(x)] += x
        save(sys.argv[sys.argv.index("--demo") + 1], verse)
