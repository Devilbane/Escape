"""Builds the hero's sword and axe sounds from real recordings, all CC0 (public
domain), from OpenGameArt.org (see assets/sounds/CREDITS.txt for each pack).
Run: python3 tools/make_weapon_sounds.py
It downloads the packs once into ~/.cache/escape_weapon_sounds and needs
ffmpeg and the py7zr module (pip install py7zr) to unpack them.

Every blow has two parts: the swing through the air when the hero strikes,
and the impact when the weapon lands (see Sfx.play_weapon). Blades (klingen)
and axes (aexte, which also covers maces and hammers) sound apart: a blade
swishes quick and thin and slices with a hiss of steel; an axe whooms heavier
and bites with steel into wood. A blow on a body is wet: splats, squishes and
tearing meat, with only a little of a punch's smack under it. Each kind of
blow has its own sound, so the ear tells them apart without looking:

  swing   a plain strike at one enemy
  sweep   the wide swing into a crowd: two rushes of air
  hit     a plain blow landing
  heavy   a heavy hit (the weapon skill's roll for +1 damage): wetter, fuller
  vital   a blow that finds a vital point (monster knowledge): a bone cracks,
          and for the blade a ring of steel
  sneak   a sneak attack: flesh tearing as the weapon goes deep
  glance  the weapon glancing off armour that only a sneak attack gets through:
          steel on steel, no flesh

Each kind has several takes, each built from other recordings, cuts, pitches
and loudness, so blow after blow does not sound the same.
"""
import glob, os, subprocess, urllib.request, wave, zipfile
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
CACHE = os.path.expanduser("~/.cache/escape_weapon_sounds")
OGA = "https://opengameart.org/sites/default/files/"
## The packs: file on OpenGameArt and the page it comes from. All CC0.
PACKS = {
    "medieval_sfx_textures_1_of_2.7z": "medieval-sound-effects-weapon-textures",
    "medieval_sfx_textures_2_of_2.7z": "medieval-sound-effects-weapon-textures",
    "medieval_sfx_weapon_on_weapon_1_of_2.7z": "medieval-sound-effects-weapon-impacts",
    "medieval_sfx_weapon_on_weapon_2_of_2.7z": "medieval-sound-effects-weapon-impacts",
    "80-CC0-RPG-SFX_0.zip": "80-cc0-rpg-sfx",
    "independent_nu_ljudbank-wet_squish_slurp_impacts.7z": "8-wet-squish-slurp-impacts",
    "independent_nu_ljudbank-extreme_splatter.7z": "2-wooden-squish-splatter-sequences",
    "independent_nu_ljudbank-hits_and_punches.7z": "37-hitspunches",
    "qubodupImpact.7z": "impact",
    "rippingintomeat.mp3": "ripping-into-meat",
    "squish_01_0.mp3": "squish-sounds-effects", "squish_02.mp3": "squish-sounds-effects",
    "squish_03.mp3": "squish-sounds-effects", "squish_04.mp3": "squish-sounds-effects",
    "squish_05.mp3": "squish-sounds-effects", "squish_06.mp3": "squish-sounds-effects",
    "squishsplat_impact.mp3": "squish-sounds-effects",
    "swishes.zip": "swishes-sound-pack",
}


# --- Getting the recordings ------------------------------------------------

def fetch():
    """Downloads and unpacks every pack, then turns each recording into a
    mono 44.1 kHz wav under CACHE/src, named after its file."""
    os.makedirs(CACHE, exist_ok=True)
    src = os.path.join(CACHE, "src")
    if os.path.isdir(src) and len(os.listdir(src)) > 100:
        return src
    raw = os.path.join(CACHE, "raw")
    os.makedirs(raw, exist_ok=True)
    for name in PACKS:
        path = os.path.join(CACHE, name)
        if not os.path.exists(path):
            print("downloading", name)
            urllib.request.urlretrieve(OGA + name, path)
        if name.endswith(".7z"):
            import py7zr
            with py7zr.SevenZipFile(path) as z:
                z.extractall(os.path.join(raw, name[:-3]))
        elif name.endswith(".zip"):
            with zipfile.ZipFile(path) as z:
                z.extractall(os.path.join(raw, name[:-4]))
        else:
            subprocess.run(["cp", path, raw], check=True)
    os.makedirs(src, exist_ok=True)
    for f in glob.glob(os.path.join(raw, "**", "*.*"), recursive=True):
        if "__MACOSX" in f or not f.lower().endswith((".wav", ".ogg", ".flac", ".mp3")):
            continue
        base = os.path.basename(f)
        for ext in (".mp3.flac", ".flac", ".ogg", ".wav", ".mp3"):
            if base.endswith(ext):
                base = base[: -len(ext)]
                break
        dest = os.path.join(src, base.replace(" ", "_") + ".wav")
        if not os.path.exists(dest):
            subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", f,
                            "-ac", "1", "-ar", str(SR), dest], check=True)
    return src


SRC = None
_loaded = {}


def load(name):
    if name not in _loaded:
        with wave.open(os.path.join(SRC, name + ".wav")) as w:
            _loaded[name] = np.frombuffer(w.readframes(w.getnframes()), np.int16) / 32767.0
    return _loaded[name]


# --- Cutting ---------------------------------------------------------------

def peaks(x, rel=0.25, sep=0.35):
    """The loudest moments of a long recording that holds many takes (one
    swing or one clash each): local peaks of the loudness, at least `sep`
    seconds apart and at least `rel` of the loudest one."""
    hop = 441
    n = len(x) // hop
    e = np.sqrt((x[: n * hop].reshape(n, hop) ** 2).mean(1))
    out = []
    for i in np.argsort(-e):
        if e[i] < e.max() * rel:
            break
        if all(abs(i - j) * hop / SR >= sep for j in out):
            out.append(i)
    return sorted(int((i + 0.5) * hop) for i in out)


def onset(x, around, look=0.12):
    """Where a hit begins: the first sample before `around` (within `look`
    seconds) that reaches a tenth of the hit's loudest sample."""
    a = max(0, around - int(look * SR))
    b = min(len(x), around + int(0.03 * SR))
    seg = np.abs(x[a:b])
    return a + int(np.argmax(seg > seg.max() * 0.1))


def fades(x, fin=0.002, fout=0.04):
    x = x.copy()
    a, b = min(len(x), int(fin * SR)), min(len(x), int(fout * SR))
    x[:a] *= np.linspace(0, 1, a)
    x[len(x) - b:] *= np.linspace(1, 0, b)
    return x


def cut(x, start, length):
    start = max(0, start)
    return fades(x[start:start + int(length * SR)])


def hit(name, length, index=None, r=None):
    """One hit from a recording, starting right at its onset. A recording of
    many hits gives the one at `index` (or a random one)."""
    x = load(name)
    ps = peaks(x)
    p = ps[index % len(ps)] if index is not None else ps[r.integers(len(ps))]
    return cut(x, onset(x, p), length)


def single(name, length):
    """A recording of one hit, from its onset."""
    x = load(name)
    return cut(x, onset(x, int(np.argmax(np.abs(x)))), length)


def swing_take(name, index, before, after, low=250):
    """One swing, with its loudest moment `before` seconds in, so the blade
    passes where the blow lands. `index` picks a swing from a recording of
    several; None takes a recording of one swing whole. The recordings
    rumble far below the swish (wind on the microphone): all under `low` Hz
    is taken out, and the takes are found by their swish."""
    x = clean(name, low)
    if index is None:
        p = int(np.argmax(np.convolve(np.abs(x), np.ones(441), "same")))
    else:
        ps = peaks(x, 0.2, 0.5)
        p = ps[index % len(ps)]
    start = p - int(before * SR)
    if start < 0:
        x = np.concatenate([np.zeros(-start), x])
        start = 0
    return cut(x, start, before + after)


# --- Shaping ---------------------------------------------------------------

def pitch(x, factor):
    """Higher (factor > 1) and shorter, or lower and longer, like tape."""
    if abs(factor - 1) < 1e-3:
        return x
    idx = np.arange(0, len(x) - 1, factor)
    return np.interp(idx, np.arange(len(x)), x)


def onepole(x, cutoff, high=False):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return x - y if high else y


def no_boom(x, cutoff=140):
    # Takes the drum-like boom out of a thump, keeps its smack.
    return onepole(onepole(x, cutoff, True), cutoff, True)


_cleaned = {}


def clean(name, low):
    """A recording with all below `low` Hz taken out, kept for reuse."""
    if (name, low) not in _cleaned:
        _cleaned[(name, low)] = no_boom(load(name), low)
    return _cleaned[(name, low)]


def peak1(x):
    m = np.max(np.abs(x))
    return x / m if m > 0 else x


def mix(length, *layers):
    """Layers of (sound, start in seconds, gain), each brought to a peak of 1
    first so the gains say how they sit against each other."""
    out = np.zeros(int(SR * length))
    for x, at, gain in layers:
        s = int(SR * at)
        n = min(len(x), len(out) - s)
        if n > 0:
            out[s:s + n] += peak1(x)[:n] * gain
    return out


# --- The pools ---------------------------------------------------------------
# Recordings by what they are. "Blade on Blade" are two swords clashing, the
# "Haft" ones steel biting into an axe's or spear's wooden haft.

# A blade cuts the air thin and bright (a dagger's and a spear's swings, the
# spear's raised); an axe's head whooms low (short, deep swishes, lowered,
# with a spear's swing under it for the rush of air).
SWORD_SWINGS = [("Dagger_Swing", 1, 0.95), ("Spear_Swing", 1, 1.12), ("Dagger_Swing", 3, 0.9),
                ("Spear_Swing", 3, 1.15), ("Dagger_Swing", 2, 1.0), ("Spear_Swing", 0, 1.1)]
AXE_SWINGS = [("swish-4", None, 0.8), ("swish-9", None, 0.78), ("swish-5", None, 0.82),
              ("swish-6", None, 0.8), ("swish-2", None, 0.75), ("swish-1", None, 0.8)]
SPLATS = ["impactsplat01", "impactsplat02", "impactsplat03", "impactsplat04", "impactsplat05",
          "impactsplat06", "impactsplat07", "impactsplat08"]
SQUISHES = ["squish_01_0", "squish_02", "squish_03", "squish_04", "squish_05", "squish_06",
            "squishsplat_impact", "qubodupImpactMeat01", "qubodupImpactMeat02"]
THUMPS = ["hit07", "hit20", "hit22", "hit35", "hit26", "hit29"]
SLICES = ["blade_01", "blade_02", "blade_03"]
RINGS = ["metal-ringing", "metal_02", "metal_03"]
CHOPS = ["Seax_Axe_Blade_on_Haft", "Dagger_Axe_Blade_on_Haft", "Axe_Spear_Blade_on_haft",
         "Seax_Spear_Blade_on_Haft", "Spear_Spear_Blade_on_Haft"]
WOOD = ["qubodupImpactWood", "wood_01", "wood_02", "wood_03", "item_wood_01", "item_wood_02"]
BONES = ["crack11", "crack12"]
SWORD_CLASH = ["Sabre_Norse_Sword_Blade_on_Blade", "Seax_Norse_Sword_Blade_on_Blade",
               "Norse_Sword_Katana_Blade_on_Blade", "Sabre_Katana_Blade_on_Blade"]
AXE_CLASH = ["Axe_Sabre_Blade_on_Blade", "Axe_Norse_Sword_Blade_on_Blade", "Mace_Axe_Blade_and_Haft",
             "Axe_Katana_Blade_on_Blade"]


def pick(r, pool):
    return pool[r.integers(len(pool))]


def flesh(r, length, wet=1.0, thump=0.3):
    """A body taking the blow: a wet splat or squish, a little of a punch's
    smack under it (with its boom taken out)."""
    layers = [(pitch(single(pick(r, SPLATS), length), r.uniform(0.92, 1.1)), 0, wet)]
    layers.append((pitch(single(pick(r, SQUISHES), length), r.uniform(0.9, 1.15)), r.uniform(0, 0.015), wet * 0.6))
    if thump > 0:
        layers.append((no_boom(single(pick(r, THUMPS), 0.25)), 0, thump))
    return mix(length, *layers)


def bone(r, length):
    return pitch(hit(pick(r, BONES), length, r=r), r.uniform(0.95, 1.15))


# --- Blades ------------------------------------------------------------------

def sword_swing(r, i):
    name, take, tone = SWORD_SWINGS[i % len(SWORD_SWINGS)]
    return pitch(swing_take(name, take, 0.16 * tone, 0.16 * tone), tone * r.uniform(0.98, 1.03))


def sword_sweep(r, i):
    a, b = SWORD_SWINGS[(i * 2 + 3) % len(SWORD_SWINGS)], SWORD_SWINGS[(i * 2 + 4) % len(SWORD_SWINGS)]
    return mix(0.5, (pitch(swing_take(a[0], a[1], 0.2, 0.2), a[2] * 0.88), 0, 1.0),
               (pitch(swing_take(b[0], b[1], 0.14, 0.16), b[2] * 0.92), 0.12, 0.8))


def sword_hit(r, i):
    return mix(0.4, (pitch(single(SLICES[i % 3], 0.25), r.uniform(0.95, 1.08)), 0, 0.7),
               (flesh(r, 0.38, 1.0, 0.3), 0.005, 1.0))


def sword_heavy(r, i):
    return mix(0.5, (pitch(single(SLICES[(i + 1) % 3], 0.3), r.uniform(0.88, 0.96)), 0, 0.75),
               (flesh(r, 0.48, 1.0, 0.5), 0.005, 1.0),
               (flesh(r, 0.3, 0.8, 0.0), 0.05, 0.5))


def sword_vital(r, i):
    return mix(0.7, (pitch(single(SLICES[(i + 2) % 3], 0.25), 1.05), 0, 0.7),
               (flesh(r, 0.45, 1.0, 0.35), 0.005, 1.0),
               (bone(r, 0.3), 0.01, 0.45),
               (pitch(single(RINGS[i % len(RINGS)], 0.6), r.uniform(1.05, 1.15)), 0.0, 0.45))


def sword_sneak(r, i):
    rip = load("rippingintomeat")
    p = peaks(rip, 0.4, 1.0)[i * 2 % 6]
    return mix(0.65, (pitch(single(SLICES[i % 3], 0.2), 0.9), 0, 0.5),
               (cut(rip, onset(rip, p, 0.3), 0.55), 0.01, 1.0),
               (flesh(r, 0.4, 0.9, 0.35), 0.0, 0.8))


def sword_glance(r, i):
    name = SWORD_CLASH[i % len(SWORD_CLASH)]
    return pitch(hit(name, 0.45, r=r), r.uniform(0.97, 1.06))


# --- Axes --------------------------------------------------------------------

def axe_swing(r, i):
    name, take, tone = AXE_SWINGS[i % len(AXE_SWINGS)]
    air = SWORD_SWINGS[(i * 2 + 1) % len(SWORD_SWINGS)]
    return mix(0.42, (pitch(swing_take(name, take, 0.18 * tone, 0.2 * tone, 60), tone), 0, 1.0),
               (pitch(swing_take(air[0], air[1], 0.18 * 0.8, 0.18 * 0.8), 0.8), 0.0, 0.45))


def axe_sweep(r, i):
    a, b = AXE_SWINGS[(i * 2 + 3) % len(AXE_SWINGS)], AXE_SWINGS[(i * 2 + 4) % len(AXE_SWINGS)]
    air = SWORD_SWINGS[i % len(SWORD_SWINGS)]
    return mix(0.6, (pitch(swing_take(a[0], a[1], 0.2 * 0.7, 0.2 * 0.7, 60), 0.7), 0, 1.0),
               (pitch(swing_take(b[0], b[1], 0.16 * 0.75, 0.2 * 0.75, 60), 0.75), 0.14, 0.85),
               (pitch(swing_take(air[0], air[1], 0.2 * 0.75, 0.2 * 0.75), 0.75), 0.02, 0.4))


def axe_bite(r, length):
    """Steel biting into wood: the axe's edge, the haft's dry knock."""
    return mix(length, (pitch(hit(pick(r, CHOPS), length, r=r), r.uniform(0.85, 0.95)), 0, 1.0),
               (pitch(single(pick(r, WOOD), length), r.uniform(0.9, 1.05)), 0.002, 0.45))


def axe_hit(r, i):
    return mix(0.45, (axe_bite(r, 0.3), 0, 0.75), (flesh(r, 0.4, 1.0, 0.45), 0.004, 1.0))


def axe_heavy(r, i):
    return mix(0.55, (axe_bite(r, 0.35), 0, 0.8), (flesh(r, 0.5, 1.0, 0.65), 0.004, 1.0),
               (bone(r, 0.35), 0.015, 0.45))


def axe_vital(r, i):
    return mix(0.7, (axe_bite(r, 0.35), 0, 0.75), (flesh(r, 0.5, 1.0, 0.55), 0.004, 1.0),
               (bone(r, 0.5), 0.008, 0.85), (flesh(r, 0.35, 0.8, 0.0), 0.07, 0.45))


def axe_sneak(r, i):
    rip = load("rippingintomeat")
    p = peaks(rip, 0.4, 1.0)[(i * 2 + 1) % 6]
    return mix(0.7, (axe_bite(r, 0.3), 0, 0.6),
               (pitch(cut(rip, onset(rip, p, 0.3), 0.6), 0.9), 0.01, 1.0),
               (flesh(r, 0.45, 1.0, 0.5), 0.0, 0.8), (bone(r, 0.3), 0.03, 0.35))


def axe_glance(r, i):
    name = AXE_CLASH[i % len(AXE_CLASH)]
    return pitch(hit(name, 0.45, r=r), r.uniform(0.9, 1.0))


## name: (maker, takes, peak). Keep the takes in step with Sfx.WEAPON_TAKES.
SOUNDS = {
    "sword_swing": (sword_swing, 3, 0.6), "sword_sweep": (sword_sweep, 2, 0.65),
    "sword_hit": (sword_hit, 4, 0.8), "sword_heavy": (sword_heavy, 3, 0.88),
    "sword_vital": (sword_vital, 2, 0.88), "sword_sneak": (sword_sneak, 2, 0.88),
    "sword_glance": (sword_glance, 3, 0.7),
    "axe_swing": (axe_swing, 3, 0.65), "axe_sweep": (axe_sweep, 2, 0.7),
    "axe_hit": (axe_hit, 4, 0.82), "axe_heavy": (axe_heavy, 3, 0.9),
    "axe_vital": (axe_vital, 2, 0.9), "axe_sneak": (axe_sneak, 2, 0.9),
    "axe_glance": (axe_glance, 3, 0.75),
}


def trim_tail(x, floor=0.004):
    # Cuts the silence after the sound has died away.
    loud = np.where(np.abs(x) > floor * np.max(np.abs(x)) * 10)[0]
    end = min(len(x), (loud[-1] if len(loud) else len(x)) + int(0.03 * SR))
    return fades(x[:end], 0.0005, 0.03)


def save(name, x, peak):
    if not name.endswith(("swing", "sweep")) and "_swing_" not in name and "_sweep_" not in name:
        # No drum: the last of the deep boom goes, the smack stays.
        x = no_boom(x, 90)
    x = trim_tail(x)
    x = x / np.max(np.abs(x)) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    SRC = fetch()
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, "sword_*.wav")) + glob.glob(os.path.join(OUT, "axe_*.wav")):
        os.remove(f)
    for seed, (name, (make, takes, peak)) in enumerate(SOUNDS.items()):
        for i in range(takes):
            save("%s_%d" % (name, i), make(np.random.default_rng(2000 + seed * 10 + i), i), peak)
