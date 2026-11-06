"""Builds the footsteps for the kinds of ground that have no recording of
their own (see Surfaces.STEPS): grass, scree and wood. Each one starts from a
real recorded step, so they all sound like the same pair of boots:

- step_*      the stone steps (recorded, see assets/sounds/CREDITS.txt),
- step_dirt_* the steps on sand and soil from the same recording session,

and adds what the ground itself does under a boot. Run from the tools folder:
python3 make_ground_steps.py"""
import os, wave
import numpy as np
from make_sounds import SR, OUT, lowpass, highpass, env


def load(name):
    with wave.open(os.path.join(OUT, name + ".wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16) / 32768.0


def rms(x):
    return float(np.sqrt(np.mean(x ** 2)))


def write(name, x, loud):
    # As loud (by RMS) as the step it was made from, so no ground is much
    # louder than another; the peak is kept below clipping.
    x = x * (loud / max(rms(x), 1e-6))
    x = x / max(1.0, np.max(np.abs(x)) / 0.95)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def onset(x):
    # Where the heel lands: the first sample above a fifth of the peak.
    return int(np.argmax(np.abs(x) > 0.2 * np.max(np.abs(x))))


def grass(src, r):
    # A muffled step, and the blades swishing round the boot.
    x = lowpass(src, 2200) * 0.9
    at = onset(src)
    for delay, size in ((0.0, 1.0), (r.uniform(0.05, 0.09), r.uniform(0.4, 0.7))):
        n = int(SR * 0.22)
        rustle = lowpass(highpass(r.uniform(-1, 1, n), 2600), 7000)
        # The rustle flutters, as many blades brush past one after another.
        flutter = 0.6 + 0.4 * np.abs(np.sin(np.arange(n) / SR * 2 * np.pi * r.uniform(35, 60)))
        rustle *= flutter * env(n, 0.012, r.uniform(0.04, 0.06)) * 0.22 * size
        a = at + int(SR * delay)
        x[a:a + n] += rustle[: max(0, len(x) - a)]
    return x


def scree(src, r):
    # A grittier step, with loose stones crunching and clicking under it.
    x = src + highpass(src, 1800) * 0.6
    at = onset(src)
    peak = np.max(np.abs(src))
    for _ in range(r.integers(22, 34)):
        # Most of the stones knock together right as the boot lands.
        a = at + int(SR * r.exponential(0.035))
        d = np.arange(int(SR * r.uniform(0.004, 0.012))) / SR
        click = np.sin(2 * np.pi * r.uniform(1800, 4800) * d) * np.exp(-d / r.uniform(0.0015, 0.004))
        x[a:a + len(click)] += click[: max(0, len(x) - a)] * peak * r.uniform(0.08, 0.3)
    return x


def wood(src, r):
    # A step on planks: a little duller than stone, with a short, dry knock of
    # the boards under it. The knock dies away fast, so it sounds solid, not
    # hollow or echoing.
    x = lowpass(src, 3000) * 0.85
    at = onset(src)
    n = len(x) - at
    d = np.arange(n) / SR
    hit = np.abs(src[at:at + int(SR * 0.03)]).max()
    base = r.uniform(170, 210)
    knock = np.zeros(n)
    for ratio, decay, amp in ((1.0, 0.022, 1.0), (2.4, 0.012, 0.5), (4.1, 0.007, 0.3)):
        knock += np.sin(2 * np.pi * base * ratio * r.uniform(0.97, 1.03) * d) * np.exp(-d / decay) * amp
    knock *= np.minimum(1, d / 0.002) * hit * 0.3
    x[at:] += knock
    return x


if __name__ == "__main__":
    for k in range(6):
        stone = load("step_%d" % k)
        dirt = load("step_dirt_%d" % k)
        write("step_grass_%d" % k, grass(dirt, np.random.default_rng(300 + k)), rms(dirt) * 0.85)
        write("step_scree_%d" % k, scree(dirt, np.random.default_rng(400 + k)), rms(dirt) * 1.1)
        write("step_wood_%d" % k, wood(stone, np.random.default_rng(500 + k)), rms(stone))
