"""Builds the loot sounds from CC0 recordings: coins (coins_small_*, coins_big_*),
a chest lid opening (chest_open_*), gear clattering onto the floor (gear_*)
and the secret-passage lever being pulled (lever_pull).
Downloads the three packs from OpenGameArt into a temporary folder, trims and
layers them, and writes 22 kHz mono WAVs to assets/sounds.
Needs ffmpeg and numpy. Run: python3 tools/make_loot_sounds.py
Sources and licences: assets/sounds/CREDITS.txt."""
import glob, os, subprocess, tempfile, urllib.request, wave, zipfile
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
PACKS = {
    # Kenney, "50 RPG sound effects" (CC0)
    "kenney": "https://opengameart.org/sites/default/files/RPGsounds_Kenney.zip",
    # artisticdude, "RPG Sound Pack" (CC0)
    "artisticdude": "https://opengameart.org/sites/default/files/rpg_sound_pack.zip",
    # rubberduck, "80 CC0 RPG SFX" (CC0)
    "rubberduck": "https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip",
}
rng = np.random.default_rng(11)


def fetch(tmp):
    for name, url in PACKS.items():
        folder = os.path.join(tmp, name)
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(tmp, name + ".zip")
        urllib.request.urlretrieve(url, path)
        with zipfile.ZipFile(path) as z:
            z.extractall(folder)


def load(tmp, pack, file_name):
    """One recording as mono floats at SR, with the silence before it cut off."""
    matches = glob.glob(os.path.join(tmp, pack, "**", file_name), recursive=True)
    if not matches:
        raise FileNotFoundError(pack + "/" + file_name)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", matches[0], "-ac", "1", "-ar", str(SR),
                          "-f", "s16le", "-"], check=True, capture_output=True).stdout
    x = np.frombuffer(raw, np.int16) / 32768.0
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 0.05)[0]
    start = max(0, loud[0] - int(SR * 0.004)) if len(loud) else 0
    x = x[start:]
    return x / max(1e-6, np.max(np.abs(x)))


def fade_out(x, sec):
    n = min(len(x), int(SR * sec))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def cut(x, sec, fade=0.08):
    return fade_out(x[: int(SR * sec)], fade)


def mix(*parts):
    """parts: (sound, at seconds, gain). Lays them over each other."""
    end = max(int(SR * at) + len(x) for x, at, _ in parts)
    out = np.zeros(end)
    for x, at, gain in parts:
        s = int(SR * at)
        out[s:s + len(x)] += x * gain
    return out


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def floor_thud(sec=0.18, freq=110):
    # The dull knock of something heavy landing on stone.
    tt = np.arange(int(SR * sec)) / SR
    body = np.sin(2 * np.pi * np.cumsum(freq * np.exp(-tt * 6)) / SR) * np.exp(-tt / 0.04)
    grit = lowpass(rng.uniform(-1, 1, len(tt)), 900) * np.exp(-tt / 0.015) * 3
    return body + grit


def save(name, x, peak=0.8):
    x = np.concatenate([x, np.zeros(int(SR * 0.05))])
    x = x / max(1e-6, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def build(tmp):
    k = lambda f: load(tmp, "kenney", f)
    a = lambda f: load(tmp, "artisticdude", f)
    r = lambda f: load(tmp, "rubberduck", f)

    # A coin or two: short clinks.
    save("coins_small_0", k("handleCoins2.ogg"), 0.6)
    save("coins_small_1", a("coin3.wav"), 0.6)
    save("coins_small_2", r("item_coins_01.ogg"), 0.6)
    # A handful of gold: longer jingles.
    save("coins_big_0", a("coin2.wav"), 0.7)
    save("coins_big_1", cut(r("item_coins_04.ogg"), 1.2, 0.3), 0.7)
    save("coins_big_2", mix((k("handleCoins.ogg"), 0, 1.0), (r("item_coins_03.ogg"), 0.18, 0.5)), 0.7)

    # A chest: the latch clicks, the hinges creak, the lid falls back.
    latch = k("metalLatch.ogg")
    for i, creak in enumerate(["creak1.ogg", "creak2.ogg", "creak3.ogg"]):
        c = k(creak)
        lid = floor_thud(0.2, 140)
        save("chest_open_%d" % i, mix((latch, 0, 0.8), (c, 0.14, 0.9), (lid, 0.14 + len(c) / SR, 0.35)), 0.7)

    # Gear clattering onto the stone floor.
    # Blades, shields and metal helmets: a hit, a bounce and a settling rattle.
    m1, m2, m3 = a("metal-small1.wav"), a("metal-small2.wav"), a("metal-small3.wav")
    save("gear_metal_0", mix((floor_thud(), 0, 0.5), (m1, 0, 1.0), (m2, 0.14, 0.55), (m3, 0.26, 0.3)), 0.75)
    save("gear_metal_1", mix((floor_thud(), 0, 0.5), (m2, 0, 1.0), (m3, 0.11, 0.6), (m1, 0.23, 0.25)), 0.75)
    save("gear_metal_2", mix((floor_thud(), 0, 0.5), (m3, 0, 1.0), (r("metal_03.ogg"), 0.05, 0.4), (m2, 0.2, 0.35)), 0.75)
    # Mail and plate: a heavy thud and rattling rings.
    save("gear_chain_0", mix((floor_thud(0.25, 90), 0, 0.7), (a("chainmail1.wav"), 0, 1.0)), 0.75)
    save("gear_chain_1", mix((floor_thud(0.25, 90), 0, 0.7), (a("chainmail2.wav"), 0, 1.0), (m2, 0.05, 0.3)), 0.75)
    # Leather, cloth and fur: a soft flop.
    save("gear_soft_0", k("dropLeather.ogg"), 0.6)
    save("gear_soft_1", a("cloth-heavy.wav"), 0.6)
    # Bone: a hollow clack.
    save("gear_bone", mix((a("wood-small.wav"), 0, 1.0), (r("item_wood_02.ogg"), 0.1, 0.4)), 0.6)
    # Amulets, rings and charms: a light tinkle.
    save("gear_trinket", mix((a("beads.wav"), 0, 0.8), (m2, 0.02, 0.25)), 0.5)
    # A book landing.
    save("gear_book", k("bookPlace1.ogg"), 0.6)

    # The lever torch: a stiff creak as it is pulled down, then the iron
    # catch snapping into place with a heavy clunk.
    save("lever_pull", mix((k("creak3.ogg"), 0, 0.7), (r("lock_02.ogg"), 0.28, 1.0),
                           (floor_thud(0.22, 80), 0.3, 0.6), (r("chain_01.ogg"), 0.34, 0.3)), 0.8)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        fetch(tmp)
        build(tmp)
