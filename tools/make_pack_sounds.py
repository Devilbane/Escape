"""Builds the sounds that come from the two bought packs (see assets/sounds/CREDITS.txt):

  The Sound Guild - "Anime Combat Sounds": every blow of the hero's sword and
      axe (sword_* and axe_*), the generic hit, swing and spell sounds.
  "Fantasy Ambience Sounds Pack V2": the woodcutter's chop (chop) and the ambient loops.
  Some of these were later replaced by sounds chosen from other packs (make_chosen_sounds.py).

Each file keeps the name of the sound it replaces, so the game (Sfx, the
weapon tables, the .import files) needs no change. Clips are cut down to
the blow itself, faded, mixed down to mono and set to the peak of the old
sound, so the game's volume tuning (Sfx.WEAPON_DB) still holds.

Run from the tools folder, naming the two pack folders:
  python3 make_pack_sounds.py "<Anime Combat Sounds folder>" "<Fantasy Ambience Sounds Pack V2 folder>"
Needs ffmpeg and numpy."""
import os, subprocess, sys, wave
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")

# new sound -> (pack file, kind, peak, rate). Kinds: "hit" starts at the first
# strike and rings out, "whoosh" is cut around its loudest moment.
COMBAT = {
	"sword_sweep_0": ("Anime_Whirlwind_High_Pitch_01", "whoosh", 0.65), "sword_sweep_1": ("Anime_Whirlwind_High_Pitch_02", "whoosh", 0.65),
	"sword_heavy_0": ("Anime_Combat_Hit_01", "hit", 0.88), "sword_heavy_1": ("Anime_Combat_Hit_02", "hit", 0.88),
	"sword_heavy_2": ("Anime_Combat_Hit_03", "hit", 0.88),
	"sword_vital_0": ("Anime_Critical_Damage_01", "hit", 0.88), "sword_vital_1": ("Anime_Critical_Damage_02", "hit", 0.88),
	"sword_sneak_0": ("Anime_Attack_Critical", "hit", 0.88), "sword_sneak_1": ("Anime_Impact_High_Pitch_Critical", "hit", 0.88),
	"axe_sweep_0": ("Anime_Whirlwind_01", "whoosh", 0.70), "axe_sweep_1": ("Anime_Whirlwind_02", "whoosh", 0.70),
	"axe_hit_0": ("Anime_Low_Impact_01", "hit", 0.82), "axe_hit_1": ("Anime_Low_Impact_02", "hit", 0.82),
	"axe_hit_2": ("Anime_Low_Impact_03", "hit", 0.82), "axe_hit_3": ("Anime_Low_Impact_04", "hit", 0.82),
	"axe_heavy_0": ("Anime_Combat_Hit_04", "hit", 0.90), "axe_heavy_1": ("Anime_Combat_Hit_05", "hit", 0.90),
	"axe_heavy_2": ("Anime_Hit", "hit", 0.90),
	"axe_vital_0": ("Anime_Critical_Damage_03", "hit", 0.90), "axe_vital_1": ("Anime_Wound_01", "hit", 0.90),
	"axe_sneak_0": ("Anime_Wound_02", "hit", 0.90), "axe_sneak_1": ("Anime_Punch_Hard", "hit", 0.90),
	"axe_glance_0": ("Anime_Armour_Impact", "hit", 0.75), "axe_glance_1": ("Anime_Sword_&_Shield_Fight_Impact_01", "hit", 0.75),
	"axe_glance_2": ("Anime_Sword_&_Shield_Fight_Impact_02", "hit", 0.75),
}
# Short sounds played from many places, kept at the old 22.05 kHz.
COMBAT_SMALL = {}
LENGTH = {"hit": 0.55, "whoosh": 0.45}


def read(path, rate):
	raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(rate), "-"],
						 capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).copy()


def smooth(x, n):
	return np.sqrt(np.convolve(x * x, np.ones(n) / n, "same"))


def cut(x, rate, kind, length=None):
	"""The blow itself: from just before the first strike (hit) or around the
	loudest moment (whoosh), faded in a few ms and out over the last third."""
	length = length or LENGTH[kind]
	if kind == "hit":
		env = np.abs(x)
		start = max(0, int(np.argmax(env > 0.15 * env.max())) - int(0.01 * rate))
	else:
		peak = int(np.argmax(smooth(x, int(0.02 * rate))))
		start = max(0, peak - int(0.55 * length * rate))
	y = x[start:start + int(length * rate)]
	fin, fout = int(0.004 * rate), int(length * rate / 3)
	y[:fin] *= np.linspace(0, 1, min(fin, len(y)))[:len(y[:fin])]
	y[-fout:] *= np.linspace(1, 0, min(fout, len(y)))[:len(y[-fout:])]
	return y


def save(name, x, rate, peak):
	x = x / max(1e-6, np.abs(x).max()) * peak
	with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(rate)
		w.writeframes((x * 32767).astype("<i2").tobytes())


def build_combat(folder):
	for name, (src, kind, peak) in COMBAT.items():
		save(name, cut(read(os.path.join(folder, src + ".wav"), 44100), 44100, kind), 44100, peak)
	for name, (src, kind, peak) in COMBAT_SMALL.items():
		length = 0.6 if name == "magic" else None
		save(name, cut(read(os.path.join(folder, src + ".wav"), 22050), 22050, kind, length), 22050, peak)


# Ambient loops: file (without .ogg) -> pack file. Played by Soundscape (scripts/soundscape.gd).
LOOPS = {
	"rain_light": "Rain_Light_Loop_01", "rain_heavy": "Rain_Heavy_Loop_01",
	"amb_village_day": "Village_Loop_No_Chatter_No_ChurchBell_01", "amb_townspeople": "Townspeople_Chatter_Loop_01",
	"amb_blacksmith": "Blacksmith_Loop_01", "amb_farm": "Farm_Loop_01",
	"amb_fire_camp": "Fire_Loop_01", "amb_fire_glow": "Fire_Loop_02",
	"amb_forest_day": "Forest_Loop_01", "amb_forest_deep": "Forest_Loop_02", "amb_forest_night": "Enchanted_Forest_Loop_01",
	"amb_dungeon_0": "Dungeon_Loop_01", "amb_dungeon_1": "Dungeon_Loop_02", "amb_dungeon_2": "Dungeon_Loop_03",
	"amb_cave_0": "Cave_Loop_01", "amb_cave_1": "Cave_Loop_02", "amb_cave_2": "Cave_Loop_03",
	"amb_mine_0": "Rockfall_Loop_01", "amb_mine_1": "Rockfall_Loop_02",
	"amb_magic_0": "Magical_Aura_Loop_01", "amb_magic_1": "Magical_Aura_Loop_02",
	"amb_astral_0": "Astral_Plane_Loop_01", "amb_astral_1": "Astral_Plane_Loop_02",
}
# Every loop is brought to the same loudness, so Soundscape.LOOPS can set the mix in dB.
LOOP_RMS = 0.05


def loop_ogg(src, dest):
	x = read(src, 24000)
	x = x * min(LOOP_RMS / max(1e-6, float(np.sqrt((x * x).mean()))), 0.95 / max(1e-6, float(np.abs(x).max())))
	subprocess.run(["ffmpeg", "-nostdin", "-y", "-v", "error", "-f", "f32le", "-ac", "1", "-ar", "24000", "-i", "-",
					"-c:a", "libvorbis", "-q:a", "0", dest], input=x.astype("<f4").tobytes(), check=True)


def build_ambience(folder):
	d = lambda n: os.path.join(folder, n + ".wav")
	# One chop of the woodcutter: the first stroke of the loop, wood on wood.
	x = read(d("Chopping_Wood_Without_Whoosh_Loop_01"), 22050)
	save("chop", cut(x[int(0.1 * 22050):], 22050, "hit", 0.5), 22050, 0.75)
	# The loops: the village at night and every soundscape. (village_bell and rain.ogg come from
	# make_chosen_sounds.py.)
	loop_ogg(d("Village_Night_Loop_01"), os.path.join(OUT, "village_night.ogg"))
	for name, src in LOOPS.items():
		loop_ogg(d(src), os.path.join(OUT, name + ".ogg"))


if __name__ == "__main__":
	if len(sys.argv) != 3:
		sys.exit(__doc__)
	build_combat(sys.argv[1])
	build_ambience(sys.argv[2])
