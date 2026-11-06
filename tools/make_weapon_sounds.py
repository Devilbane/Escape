"""Builds the hero's sword and axe sounds from scratch (noise, tones and
envelopes), so there are no licences to worry about.
Run: python3 tools/make_weapon_sounds.py

Every blow has two parts: the swing through the air when the hero strikes,
and the impact when the weapon lands (see Sfx.play_swing and Sfx.play_impact).
Blades (klingen) and axes (aexte, which also covers maces and hammers) sound
apart: a blade swishes thin and high and slices into flesh with a steel ring,
an axe whooms low and heavy and bites with an iron clank and a dry knock of
the haft. Hits on a body are wet (a squelch of tiny rising bubbles over a
noisy slap), with no pitched drum-like thud in them. Each kind of blow has its
own sound, so the ear tells them apart without looking:

  swing   a plain strike at one enemy
  sweep   the wide swing into a crowd: longer, with a second rush of air
  hit     a plain blow landing
  heavy   a heavy hit (the weapon skill's roll for +1 damage): fuller and louder
  vital   a blow that finds a vital point (monster knowledge): a bright ring on top
  sneak   a sneak attack, a stab or chop in the back: a thrust, then a pull
  glance  the weapon glancing off armour that only a sneak attack gets through

Each has a few takes, so blow after blow does not sound the same.
"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def t(sec):
    return np.arange(int(SR * sec)) / SR


def biquad(x, kind, freq, q=0.707):
    # RBJ cookbook filters; `freq` may be a number or an array (a sweep).
    n = len(x)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    w = 2 * np.pi * np.clip(f, 20, SR * 0.45) / SR
    cw, sw = np.cos(w), np.sin(w)
    alpha = sw / (2 * q)
    if kind == "low":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "high":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # band, 0 dB peak
        b0, b1, b2 = alpha, np.zeros(n), -alpha
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        v = b0[i] * x[i] + b1[i] * x1 + b2[i] * x2 - a1[i] * y1 - a2[i] * y2
        x2, x1, y2, y1 = x1, x[i], y1, v
        y[i] = v
    return y


def env(n, attack, decay):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / (SR * decay))
    return e


def at(out, x, sec, gain=1.0):
    s = int(SR * sec)
    e = min(len(out), s + len(x))
    out[s:e] += x[: e - s] * gain


def fade_out(x, sec=0.02):
    n = min(len(x), int(SR * sec))
    x[-n:] *= np.linspace(1, 0, n)
    return x


class Take:
    """The random numbers of one take, so each take is its own."""

    def __init__(self, seed):
        self.r = np.random.default_rng(seed)

    def noise(self, sec):
        return self.r.uniform(-1, 1, int(SR * sec))

    def u(self, a, b):
        return self.r.uniform(a, b)

    def ring(self, partials, sec, decay, spread=0.03):
        # A struck piece of metal: a few inharmonic partials, each fading at
        # its own pace (the higher, the quicker), slightly detuned per take.
        tt = t(sec)
        out = np.zeros(len(tt))
        for f, amp in partials:
            f *= 1 + self.u(-spread, spread)
            d = decay * (600.0 / f) ** 0.35
            out += np.sin(2 * np.pi * f * tt + self.u(0, 6.28)) * np.exp(-tt / d) * amp
        out *= env(len(tt), 0.0008, 10.0)
        return out

    def whoosh(self, sec, lo, hi, q, peak_at=0.5, power=2.0):
        # Air rushing past a moving edge: a band of noise whose centre rises
        # as the weapon speeds up and falls as it passes, loudest at `peak_at`.
        tt = np.linspace(0, 1, int(SR * sec))
        shape = np.where(tt < peak_at, tt / peak_at, (1 - tt) / (1 - peak_at))
        shape = np.clip(shape, 0, 1) ** power
        centre = lo + (hi - lo) * shape
        x = biquad(self.noise(sec), "band", centre, q)
        return x * shape

    def slap(self, sec, decay, bright=2200):
        # Flesh taking the blow: a short, broad burst of noise with no pitch
        # in it, a little weight below and a smack on top.
        n = int(SR * sec)
        x = biquad(biquad(self.noise(sec), "low", bright), "high", 140)
        body = biquad(self.noise(sec), "low", 380) * 1.4
        return (x + body * env(n, 0.0015, decay * 0.7)) * env(n, 0.0005, decay)

    def squelch(self, sec, count, lo=350, hi=1400):
        # Something wet giving way: tiny bubbles that rise in pitch as they
        # burst, over a band of noise whose colour wobbles like a squish.
        n = int(SR * sec)
        out = np.zeros(n)
        for i in range(count):
            life = self.u(0.008, 0.028)
            tt = t(life)
            f0 = self.u(lo, hi)
            f = f0 * (1 + self.u(0.6, 1.6) * tt / life)
            b = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (life * 0.35))
            at(out, b, self.u(0, sec * 0.75), self.u(0.4, 1.0) * (1 - i / (count + 3)))
        wobble = np.cumsum(self.r.normal(0, 1, n))
        wobble = (wobble - wobble.min()) / max(1e-9, np.ptp(wobble))
        squish = biquad(self.noise(sec), "band", lo + (hi - lo) * wobble, 2.5)
        squish *= env(n, 0.004, sec * 0.3)
        return out + squish * 0.9

    def wood(self, sec=0.05, decay=0.007):
        # Dry, dense wood (the haft, or a splitting bone): several short,
        # bright resonances that die at once, nothing left to boom.
        n = int(SR * sec)
        burst = self.noise(sec) * env(n, 0.0002, 0.002)
        out = np.zeros(n)
        for f, amp in [(self.u(1100, 1400), 1.0), (self.u(1900, 2400), 0.8), (self.u(3000, 3800), 0.5)]:
            out += biquad(burst, "band", f, 9.0) * amp
        return out * env(n, 0.0002, decay) * 6.0

    def crack(self, sec, cutoff, decay):
        return biquad(self.noise(sec), "high", cutoff) * env(int(SR * sec), 0.0003, decay)

    def crunch(self, sec, count, lo, hi):
        # Splintering bone or wood: a burst of tiny clicks.
        out = np.zeros(int(SR * sec))
        for i in range(count):
            c = biquad(self.noise(0.012), "band", self.u(lo, hi), 2.0) * env(int(SR * 0.012), 0.0002, 0.0025)
            at(out, c, self.u(0, sec * 0.7), (1 - i / (count + 2)) * self.u(0.5, 1.0))
        return out


# --- Blades --------------------------------------------------------------

def sword_swing(k):
    # A thin, quick swish: high air and a faint whistle along the edge.
    sec = k.u(0.2, 0.25)
    out = k.whoosh(sec, 1800, 5200, 2.2, k.u(0.45, 0.6), 1.6)
    tt = t(sec)
    whistle = np.sin(2 * np.pi * np.cumsum(k.u(2600, 3200) + 900 * np.sin(np.pi * tt / sec)) / SR)
    out += whistle * np.sin(np.pi * tt / sec) ** 4 * 0.05
    return out


def sword_sweep(k):
    # A wide arc: longer, lower, with a second rush as the blade turns.
    out = np.zeros(int(SR * 0.46))
    at(out, k.whoosh(0.34, 1200, 4200, 1.8, 0.4, 1.5), 0)
    at(out, k.whoosh(0.26, 1600, 4800, 2.0, 0.55, 1.8), 0.17, 0.75)
    return out


def sword_hit(k):
    # Steel slicing into flesh: a bright slash, the wet give of the cut and a
    # short ring of the blade.
    out = np.zeros(int(SR * 0.3))
    at(out, biquad(k.noise(0.07), "band", np.linspace(6500, 2500, int(SR * 0.07)), 1.2) * env(int(SR * 0.07), 0.001, 0.018), 0)
    at(out, k.slap(0.06, 0.014), 0.002, 0.7)
    at(out, k.squelch(0.11, 6, 500, 1700), 0.008, 0.55)
    at(out, k.ring([(2350, 0.5), (3720, 0.35), (5480, 0.2)], 0.28, 0.06), 0.004, 0.2)
    return out


def sword_heavy(k):
    # The same cut, driven in harder: a longer slash, a fuller, wetter give
    # and a second bite as the blade goes through.
    out = np.zeros(int(SR * 0.4))
    at(out, biquad(k.noise(0.1), "band", np.linspace(7000, 1800, int(SR * 0.1)), 1.0) * env(int(SR * 0.1), 0.001, 0.03), 0)
    at(out, k.slap(0.09, 0.022, 1800), 0.002, 1.0)
    at(out, k.squelch(0.18, 10, 400, 1500), 0.01, 0.75)
    at(out, k.ring([(2200, 0.5), (3480, 0.35), (5150, 0.2)], 0.35, 0.09), 0.004, 0.22)
    at(out, k.wood(0.04, 0.005), 0.05, 0.35)
    return out


def sword_vital(k):
    # A clean, exact cut with a ringing "shing" that rises: the sound of the
    # weak spot found, unlike any plain blow.
    out = np.zeros(int(SR * 0.65))
    at(out, biquad(k.noise(0.06), "band", np.linspace(8000, 3500, int(SR * 0.06)), 1.4) * env(int(SR * 0.06), 0.0008, 0.015), 0)
    at(out, k.slap(0.07, 0.016), 0.002, 0.7)
    at(out, k.squelch(0.16, 9, 450, 1600), 0.01, 0.6)
    tt = t(0.6)
    shing = np.zeros(len(tt))
    for f, amp in [(1760, 0.6), (2640, 0.4), (3520, 0.3), (5280, 0.15)]:
        sweep = f * (1 + 0.06 * (1 - np.exp(-tt / 0.08)))
        shing += np.sin(2 * np.pi * np.cumsum(sweep) / SR) * amp
    at(out, shing * env(len(tt), 0.004, 0.16), 0.01, 0.3)
    return out


def sword_sneak(k):
    # A thrust into the back: a short hiss in, the blade sinking wet into
    # flesh, and drawn out again with a scrape of steel.
    out = np.zeros(int(SR * 0.5))
    at(out, k.whoosh(0.08, 2500, 6000, 2.0, 0.8, 1.2), 0, 0.6)
    at(out, k.slap(0.08, 0.02, 1500), 0.07, 0.9)
    at(out, k.squelch(0.22, 12, 300, 1200), 0.075, 0.9)
    draw = biquad(k.noise(0.18), "band", np.linspace(1800, 4500, int(SR * 0.18)), 3.0)
    draw *= np.sin(np.pi * np.linspace(0, 1, len(draw))) ** 2
    at(out, draw, 0.22, 0.4)
    at(out, k.squelch(0.12, 5, 600, 1800), 0.24, 0.4)
    return out


def sword_glance(k):
    # Steel off steel: a loud clang, a skid of the edge and no thud at all.
    out = np.zeros(int(SR * 0.55))
    at(out, k.crack(0.02, 2500, 0.003), 0, 0.8)
    at(out, k.ring([(1180, 0.6), (2870, 0.45), (4410, 0.3), (6020, 0.15)], 0.5, 0.18, 0.05), 0.001, 0.6)
    skid = biquad(k.noise(0.12), "band", np.linspace(5000, 2500, int(SR * 0.12)), 4.0)
    skid *= np.sin(np.pi * np.linspace(0, 1, len(skid)))
    at(out, skid, 0.02, 0.35)
    return out


# --- Axes ----------------------------------------------------------------

def axe_swing(k):
    # A heavy head through the air: a low "whoom" that swells late, as the
    # weight comes round.
    sec = k.u(0.3, 0.36)
    out = k.whoosh(sec, 260, 1100, 1.3, k.u(0.6, 0.72), 1.8)
    out += k.whoosh(sec, 900, 2200, 2.0, 0.68, 2.5) * 0.25
    return out


def axe_sweep(k):
    # A wide, heavy round swing: a long, deep rush.
    out = np.zeros(int(SR * 0.55))
    at(out, k.whoosh(0.5, 200, 950, 1.2, 0.62, 1.6), 0)
    at(out, k.whoosh(0.5, 700, 1900, 2.0, 0.65, 2.2), 0, 0.25)
    return out


def axe_hit(k):
    # A chop: the iron head bites with a short clank, the flesh gives wetly
    # under it and the haft knocks dry in the hand.
    out = np.zeros(int(SR * 0.35))
    at(out, k.crack(0.02, 2200, 0.004), 0, 0.5)
    at(out, k.slap(0.08, 0.02, 1600), 0, 1.0)
    at(out, k.squelch(0.14, 8, 300, 1200), 0.006, 0.75)
    at(out, k.ring([(940, 0.5), (2150, 0.35), (3300, 0.2)], 0.2, 0.035, 0.05), 0.001, 0.3)
    at(out, k.wood(0.05, 0.006), 0.003, 0.5)
    return out


def axe_heavy(k):
    # A chop with all the weight behind it: a bigger, wetter give and a
    # crunch of bone.
    out = np.zeros(int(SR * 0.5))
    at(out, k.crack(0.03, 1800, 0.006), 0, 0.6)
    at(out, k.slap(0.12, 0.03, 1400), 0, 1.0)
    at(out, k.squelch(0.22, 13, 280, 1100), 0.008, 0.85)
    at(out, k.ring([(880, 0.5), (2020, 0.35), (3150, 0.2)], 0.25, 0.04, 0.05), 0.001, 0.3)
    at(out, k.wood(0.05, 0.007), 0.004, 0.6)
    at(out, k.crunch(0.14, 10, 1200, 3200), 0.015, 0.5)
    return out


def axe_vital(k):
    # The axe splits the weak spot open: a heavy, wet chop and a sharp crack
    # of bone, then the iron ringing on.
    out = np.zeros(int(SR * 0.7))
    at(out, k.slap(0.12, 0.03, 1400), 0, 1.0)
    at(out, k.squelch(0.26, 15, 280, 1200), 0.008, 0.9)
    for i in range(3):
        at(out, k.wood(0.04, 0.005), 0.006 + i * k.u(0.018, 0.03), 0.8 - i * 0.2)
    at(out, k.crunch(0.2, 14, 1500, 4200), 0.02, 0.6)
    at(out, k.ring([(880, 0.5), (2020, 0.35), (3150, 0.25)], 0.5, 0.12, 0.03), 0.01, 0.3)
    return out


def axe_sneak(k):
    # A chop into an unguarded back: a short rush of air, a deep, wet bite,
    # and the axe wrenched free with a squelch.
    out = np.zeros(int(SR * 0.55))
    at(out, k.whoosh(0.1, 500, 1600, 1.5, 0.85, 1.4), 0, 0.6)
    at(out, k.slap(0.12, 0.03, 1300), 0.09, 1.0)
    at(out, k.squelch(0.24, 14, 250, 1000), 0.095, 0.95)
    at(out, k.wood(0.05, 0.006), 0.092, 0.45)
    at(out, k.crunch(0.12, 8, 1000, 2500), 0.1, 0.5)
    wrench = biquad(k.noise(0.14), "band", np.linspace(700, 1500, int(SR * 0.14)), 2.5)
    wrench *= np.sin(np.pi * np.linspace(0, 1, len(wrench))) ** 2
    at(out, wrench, 0.3, 0.35)
    at(out, k.squelch(0.14, 7, 400, 1300), 0.32, 0.6)
    return out


def axe_glance(k):
    # Iron off plate: a heavy clank, a short shudder of the haft, no bite.
    out = np.zeros(int(SR * 0.5))
    at(out, k.crack(0.02, 1500, 0.004), 0, 0.6)
    at(out, k.ring([(620, 0.6), (1460, 0.45), (2330, 0.3), (3510, 0.15)], 0.45, 0.13, 0.05), 0.001, 0.75)
    at(out, k.wood(0.05, 0.008), 0.002, 0.6)
    at(out, k.wood(0.04, 0.005), 0.03, 0.3)
    return out


SOUNDS = {
    "sword_swing": (sword_swing, 3, 0.55), "sword_sweep": (sword_sweep, 2, 0.6),
    "sword_hit": (sword_hit, 3, 0.75), "sword_heavy": (sword_heavy, 2, 0.85),
    "sword_vital": (sword_vital, 2, 0.85), "sword_sneak": (sword_sneak, 2, 0.85),
    "sword_glance": (sword_glance, 2, 0.7),
    "axe_swing": (axe_swing, 3, 0.65), "axe_sweep": (axe_sweep, 2, 0.7),
    "axe_hit": (axe_hit, 3, 0.8), "axe_heavy": (axe_heavy, 2, 0.9),
    "axe_vital": (axe_vital, 2, 0.9), "axe_sneak": (axe_sneak, 2, 0.9),
    "axe_glance": (axe_glance, 2, 0.75),
}


def save(name, x, peak):
    x = fade_out(np.concatenate([x, np.zeros(int(SR * 0.03))]))
    x = x / np.max(np.abs(x)) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for seed, (name, (make, takes, peak)) in enumerate(SOUNDS.items()):
        for i in range(takes):
            save("%s_%d" % (name, i), make(Take(1000 + seed * 10 + i)), peak)
