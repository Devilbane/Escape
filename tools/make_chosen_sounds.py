"""Builds the sounds chosen from the sound preview page (ratings of 2026-11-10); see docs/sound_replacements.md.

Each file keeps the name of the sound it replaces, so no code changes. Like make_pack_sounds.py, clips are cut
to the sound itself, faded, mixed down to mono and set to the peak of the old sound, so the volume tuning holds.
Families (sword_swing_*, sword_hit_*, sword_glance_*, axe_swing_*) are made from ONE chosen clip, each take
sped up or slowed down a little so the takes do not sound alike.

Run from the tools folder, naming the folder that holds the sound libraries (the user's Desktop/assets/audio):
  python3 make_chosen_sounds.py "<audio library folder>"
Needs ffmpeg and numpy."""
import os, sys
import numpy as np
from make_pack_sounds import read, cut, save, loop_ogg, OUT

PACK = "ambience/Fantasy Ambience Sounds Pack V2/"
GUILD = "combat/The Sound Guild - Anime Combat Sounds/"
DUMAIS = "weapons/David Dumais Audio - Melee Weapons Sound Effects Pack 2/"
SRC = {
	"swing": DUMAIS + "METLFric_SWING SCRAPE Swift Melee Weapon Swing With A Long Blade 14_DDUMAIS_MWP2.wav",
	"clash": DUMAIS + "METLImpt_METAL SWING HIT Weapon Swing To Metallic Body Impact And Resonant Tail 01_DDUMAIS_MWP2.wav",
	"axe": "combat/Epic Stock Media - Tower Defense Game/DSGNStngr_Action Deploy Units Sword Slice Special Move Layered Swish 04_ESM_TDG.wav",
	"loot_epic": "ui/Cinematic Sound Design - User Interface/Button Arp Twinkle.wav",
	"secret": "ui/CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/GAMEMisc_Magic Creation 23_CB Sounddesign_APPlicable Sounds.wav",
	"drink": "foley/Cinematic Sound Design - Cartoon & Animation Vol 2/Cartoon Bubbles Short.wav",
	"bones": "horror/Epic Stock Media - Halloween Game - Haunted House and Horror Audio Scare Kit/GORESplt_Gore Designed Transient Heavy Impact Smash 01_ESM_HALG.wav",
	"ui_click": "ui/Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/UIClick_UI Button Analog Vintage Double Click Neutral Dry Press 11_ESM_BG.wav",
	"hit": GUILD + "Anime_Attack_Slap_01.wav", "hurt": "voice/344 Audio - Anime Fight Voices Vol. 1/VOXMale_Male Adventurer, Active Yell 19_344 Audio_Anime Fight Voices.wav",
	"swing_small": GUILD + "Anime_Whoosh_05.wav", "throw": GUILD + "Anime_Whoosh_03.wav", "magic": GUILD + "Anime_Laser_01.wav",
	"bell": "ambience/Ivo Vicic - Church Bells/04 Church Bells, Near Distance, In Church Tower-3 Different Bell 02.wav",
	"anvil": PACK + "Blacksmith_Loop_01.wav", "rumble": PACK + "Rockfall_Loop_01.wav", "rain": PACK + "Rain_Heavy_Loop_01.wav",
}


def speed(x, f):
	"""Plays the clip f times as fast (pitch follows)."""
	return np.interp(np.arange(0, len(x) - 1, f), np.arange(len(x)), x).astype(np.float32)


def fade(x, rate, fin, fout):
	x = x.copy()
	a, b = int(fin * rate), int(fout * rate)
	x[:a] *= np.linspace(0, 1, len(x[:a]))
	x[-b:] *= np.linspace(1, 0, len(x[-b:]))
	return x


def build(lib):
	p = lambda k: os.path.join(lib, SRC[k])
	# Family takes: (output, source, kind, pitch factor, length, peak). The peaks are those of the old sounds.
	fam = []
	for i, f in enumerate((1.0, 0.93, 1.08)):
		fam.append(("sword_swing_%d" % i, "swing", "whoosh", f, 0.45, 0.60))
	for i, f in enumerate((1.0, 0.92, 1.08, 0.86)):
		fam.append(("sword_hit_%d" % i, "clash", "hit", f, 0.60, 0.80))
	for i, f in enumerate((1.3, 1.18, 1.42)):
		fam.append(("sword_glance_%d" % i, "clash", "hit", f, 0.45, 0.70))
	for i, f in enumerate((0.84, 0.92, 1.0)):
		fam.append(("axe_swing_%d" % i, "axe", "whoosh", f, 0.45, 0.65))
	for name, key, kind, f, length, peak in fam:
		x = speed(read(p(key), 44100), f)
		save(name, cut(x, 44100, kind, length), 44100, peak)
	# One-shots at 22.05 kHz: name -> (source, kind, length, peak, start in s)
	one = {
		"hit": ("hit", "hit", 0.55, 0.90, 0.0), "hurt": ("hurt", "hit", 0.55, 0.80, 0.0),
		"swing": ("swing_small", "whoosh", 0.45, 0.60, 0.0), "throw": ("throw", "whoosh", 0.45, 0.60, 0.0),
		"magic": ("magic", "hit", 0.60, 0.50, 0.0), "bones": ("bones", "hit", 0.75, 0.70, 0.0),
		"anvil": ("anvil", "hit", 0.75, 0.70, 0.0),
	}
	for name, (key, kind, length, peak, t0) in one.items():
		x = read(p(key), 22050)[int(t0 * 22050):]
		save(name, cut(x, 22050, kind, length), 22050, peak)
	# Sounds that are played whole, only trimmed and faded: name -> (source, start, length, fade in, fade out, peak)
	whole = {
		"loot_epic": ("loot_epic", 0.0, 1.75, 0.003, 0.5, 0.60), "secret": ("secret", 0.2, 1.8, 0.02, 0.7, 0.50),
		"drink": ("drink", 0.0, 0.88, 0.003, 0.15, 0.50), "ui_click": ("ui_click", 0.0, 0.17, 0.002, 0.03, 0.35),
		"rumble": ("rumble", 10.0, 2.25, 0.25, 1.0, 0.90),
		"village_bell": ("bell", 1.55, 9.5, 0.05, 1.5, 0.70),
	}
	for name, (key, t0, length, fin, fout, peak) in whole.items():
		x = read(p(key), 22050)[int(t0 * 22050):int((t0 + length) * 22050)]
		save(name, fade(x, 22050, fin, fout), 22050, peak)
	loop_ogg(p("rain"), os.path.join(OUT, "rain.ogg"))


if __name__ == "__main__":
	if len(sys.argv) != 2:
		sys.exit(__doc__)
	build(sys.argv[1])
