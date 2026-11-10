"""Builds the footsteps on grass, scree (gravel), wood, paving, paths and soil from the recorded steps of
"Footsteps Sound Effects" by Soundza (see assets/sounds/CREDITS.txt). Each ground gets six steps,
step_<ground>_0 to step_<ground>_5 (see Surfaces.STEPS); each is one single step cut out of a recording (a file
with several steps is cut at its heel strikes), faded at the ends and set to the loudness of the steps the ground
had before, so the volumes tuned in the game still hold.

Run from the tools folder, naming the folder that holds the sound libraries (the user's Desktop/assets/audio):
  python3 make_soundza_steps.py "<audio library folder>"
Needs ffmpeg and numpy. tools/make_footstep_preview.py builds the page to listen to all candidates."""
import os, sys, wave
import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
PACK = "foley/Soundza - Footsteps Sound Effects/"

## ground -> (loudness (RMS) of the steps it had, step length in s, six (recording, number of the step in it))
GROUNDS = {
	"grass": (0.0505, 0.40, [
		("grass/soundza-footstep-on-grass.wav", 0), ("grass/soundza-soft-grass-footstep.wav", 0),
		("grass/soundza-crisp-footstep-on-grass.wav", 0), ("grass/soundza-crisp-footstep-on-grass.wav", 1),
		("grass/soundza-footstep-on-grass-1.wav", 0), ("grass/soundza-footstep-on-grass-2.wav", 1)]),
	"scree": (0.0628, 0.40, [
		("gravel/soundza-boots-gravel-footstep-1.wav", 0), ("gravel/soundza-boots-gravel-footstep-2.wav", 0),
		("gravel/soundza-boots-gravel-footstep-3.wav", 0), ("gravel/soundza-crisp-footstep-on-gravel.wav", 0),
		("gravel/soundza-footstep-on-gravel.wav", 0), ("gravel/soundza-gravel-footstep.wav", 0)]),
	"wood": (0.0718, 0.40, [
		("wood/soundza-wood-heel-footstep-1.wav", 0), ("wood/soundza-footstep-wood-toe.wav", 0),
		("wood/soundza-heavy-footstep-on-wood.wav", 0), ("wood/soundza-heavy-footstep-on-wood-short.wav", 0),
		("wood/soundza-hiking-boot-footsteps-on-wooden-planks.wav", 1), ("wood/soundza-hiking-boot-footsteps-on-wooden-planks.wav", 3)]),
	"paving": (0.0718, 0.40, [
		("stone/soundza-single-footstep-on-pavement-1.wav", 0), ("stone/soundza-single-footstep-on-pavement-1.wav", 1),
		("stone/soundza-single-footstep-on-pavement-2.wav", 0), ("stone/soundza-single-footstep-on-pavement-2.wav", 1),
		("stone/soundza-footsteps-on-pavement-scuff.wav", 0), ("stone/soundza-footsteps-on-pavement-scuff.wav", 1)]),
	"path": (0.0594, 0.40, [
		("dirt/soundza-boots-slow-dirt-footstep-1.wav", 0), ("dirt/soundza-boots-slow-dirt-footstep-2.wav", 0),
		("dirt/soundza-dirt-footstep.wav", 0), ("dirt/soundza-footstep-on-dirt.wav", 0),
		("dirt/soundza-dirt-gravel-footstep-short.wav", 0), ("dirt/soundza-running-footsteps-on-forest-ground-single.wav", 0)]),
	"soil": (0.0594, 0.40, [
		("dirt/soundza-wet-soil-footstep.wav", 0), ("mud/soundza-footstep-on-mud.wav", 0),
		("mud/soundza-footstep-on-mud-2.wav", 0), ("mud/soundza-muddy-boots-squishing.wav", 0),
		("mud/soundza-muddy-boots-squishing.wav", 1), ("dirt/soundza-short-single-footstep-on-dirt-3.wav", 0)]),
}


def read(path):
	import subprocess
	raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
						 capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).copy()


def heel_strikes(x):
	"""The moments (in samples) where a step lands: the energy rises over a quarter of the loudest."""
	h = int(RATE * 0.01)
	e = np.sqrt(np.convolve(x ** 2, np.ones(h) / h, "same"))[::h]
	found, i = [], 0
	while i < len(e):
		if e[i] > 0.25 * e.max():
			# Back up to where the rise starts.
			j = i
			while j > 0 and e[j - 1] < e[j] and e[j - 1] > 0.05 * e.max():
				j -= 1
			found.append(j * h)
			i += int(0.25 * RATE / h)
		else:
			i += 1
	return found


def step(x, number, length):
	"""One step: from just before its heel strike, `length` s long (or up to the next step), faded in and out."""
	hits = heel_strikes(x)
	a = max(0, hits[min(number, len(hits) - 1)] - int(0.008 * RATE))
	b = a + int(length * RATE)
	if number + 1 < len(hits):
		b = min(b, hits[number + 1] - int(0.02 * RATE))
	y = x[a:b].copy()
	fin, fout = int(0.003 * RATE), min(len(y) // 2, int(0.12 * RATE))
	y[:fin] *= np.linspace(0, 1, fin)
	y[-fout:] *= np.linspace(1, 0, fout)
	return y


def save(name, y, loud):
	y = y * (loud / max(float(np.sqrt(np.mean(y ** 2))), 1e-6))
	# A sharp heel strike is far above the rest of the step; round it off softly instead of turning the whole
	# step down, so the steps stay as loud as the ones they replace.
	y = np.where(np.abs(y) > 0.6, np.sign(y) * (0.6 + 0.35 * np.tanh((np.abs(y) - 0.6) / 0.35)), y)
	y = y / max(1.0, np.abs(y).max() / 0.95)
	with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((y * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
	folder = os.path.join(sys.argv[1], PACK)
	for ground, (loud, length, steps) in GROUNDS.items():
		for k, (file, number) in enumerate(steps):
			save("step_%s_%d" % (ground, k), step(read(folder + file), number, length), loud)
		print(ground, "built")
