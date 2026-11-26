class_name WallSounds
extends RefCounted
## The sounds of the climbing wall that are made in code (no sound files), next to the recorded ones from `assets/sounds`:
## grip scrape, boot scuff, pebbles trickling, rope creak and twang, effort breath, cloth rustle and a stone knock.
## Each kind has several variants (so the same sound never repeats exactly); `stream(kind, variant)` builds one once.
## `cues(key)` says when in a move (0..1) which sound plays, so the sound follows the animation.

const RATE := 22050
const VARIANTS := 4
static var _cache := {}

## When each sound of a move plays: `at` is the point of the move (0..1), `kind` the sound,
## `db` its volume, `tired` true when it grows with the fatigue.
const CUES := {
	"pull": [
		{"at": 0.12, "kind": "scuff", "db": -14.0},
		{"at": 0.30, "kind": "breath", "db": -12.0, "tired": true},
		{"at": 0.52, "kind": "grip", "db": -11.0},
		{"at": 0.78, "kind": "boot", "db": -12.0},
	],
	"side": [
		{"at": 0.12, "kind": "scuff", "db": -14.0},
		{"at": 0.34, "kind": "grip", "db": -11.0},
		{"at": 0.45, "kind": "breath", "db": -13.0, "tired": true},
		{"at": 0.76, "kind": "boot", "db": -12.0},
	],
	"desc": [
		{"at": 0.20, "kind": "boot", "db": -13.0},
		{"at": 0.55, "kind": "grip", "db": -13.0},
		{"at": 0.80, "kind": "boot", "db": -13.0},
	],
	"leap": [
		{"at": 0.10, "kind": "breath", "db": -10.0, "tired": true},
		{"at": 0.36, "kind": "scuff", "db": -8.0},
		{"at": 0.82, "kind": "grip", "db": -7.0},
		{"at": 0.86, "kind": "boot", "db": -8.0},
	],
	"slip": [{"at": 0.02, "kind": "scrape", "db": -6.0}, {"at": 0.30, "kind": "pebbles", "db": -10.0}],
	"arrest": [{"at": 0.04, "kind": "twang", "db": -5.0}, {"at": 0.30, "kind": "creak", "db": -9.0}],
	"hammer": [
		{"at": 0.20, "kind": "tap", "db": -6.0}, {"at": 0.45, "kind": "tap", "db": -5.0}, {"at": 0.70, "kind": "tap", "db": -4.0},
	],
	"bed": [{"at": 0.01, "kind": "rustle", "db": -8.0}, {"at": 0.03, "kind": "creak", "db": -12.0}],
	"wake": [{"at": 0.45, "kind": "rustle", "db": -8.0}, {"at": 0.90, "kind": "creak", "db": -12.0}],
	"stand": [{"at": 0.05, "kind": "boot", "db": -14.0}],
}

## What a special spot sounds like when the climber reaches it: `after` is the delay in seconds.
const SPOTS := {
	"tar": [{"after": 0.1, "kind": "scrape", "db": -12.0}, {"after": 0.5, "kind": "grip", "db": -10.0}, {"after": 0.9, "kind": "scrape", "db": -14.0}],
	"edelweiss": [{"after": 0.1, "kind": "rustle", "db": -10.0}, {"after": 0.45, "kind": "rustle", "db": -12.0}, {"after": 0.8, "kind": "tap", "db": -16.0}],
	"door": [{"after": 0.1, "kind": "tap", "db": -8.0}, {"after": 0.5, "kind": "tap", "db": -8.0}, {"after": 1.0, "kind": "creak", "db": -6.0}, {"after": 1.6, "kind": "creak", "db": -8.0}, {"after": 2.0, "kind": "boot", "db": -10.0}],
}


## The cues for a move named `key` (`pull_l` and `pull_r` share the "pull" list).
static func cues(key: String) -> Array:
	for family in ["pull", "side", "desc"]:
		if key.begins_with(family):
			return CUES[family]
	return CUES.get(key, [])


## A stream of `kind`; `variant` 0..VARIANTS-1 picks one of several takes.
static func stream(kind: String, variant: int) -> AudioStreamWAV:
	var id := "%s%d" % [kind, variant % VARIANTS]
	if not _cache.has(id):
		_cache[id] = _make(kind, id.hash())
	return _cache[id]


static func _length(kind: String) -> float:
	match kind:
		"scuff":
			return 0.14
		"grip":
			return 0.18
		"boot":
			return 0.12
		"scrape":
			return 0.55
		"pebbles":
			return 0.9
		"twang":
			return 0.7
		"creak":
			return 0.6
		"breath":
			return 0.7
		"rustle":
			return 0.8
		"tap":
			return 0.2
	return 0.2


static func _make(kind: String, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var secs := _length(kind)
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0      # one-pole low-pass state
	var low2 := 0.0
	var phase := 0.0
	var base := rng.randf_range(0.85, 1.15)
	var clicks := []
	if kind == "pebbles":
		for i in 9:
			clicks.append({"t": rng.randf_range(0.0, 0.8), "f": rng.randf_range(1800.0, 4200.0), "a": rng.randf_range(0.3, 1.0)})
	for i in n:
		var t := float(i) / float(n)
		var noise := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match kind:
			"scuff", "boot":
				# A boot on stone: a short thump plus gritty noise.
				low += (noise - low) * (0.25 if kind == "scuff" else 0.12)
				var thump := sin(TAU * 95.0 * base * float(i) / RATE) * exp(-t * 18.0) if kind == "boot" else 0.0
				v = (low * 0.9 + thump * 0.8) * exp(-t * (14.0 if kind == "boot" else 9.0))
			"grip":
				# Skin and chalk on rock: a short rasp with a rising edge.
				low += (noise - low) * 0.45
				v = (noise - low) * 0.5 * minf(1.0, t * 14.0) * (1.0 - t) * (0.6 + 0.4 * sin(t * 60.0 * base))
			"scrape":
				low += (noise - low) * 0.3
				v = low * (1.0 - t) * (0.7 + 0.3 * sin(t * 90.0 * base)) * minf(1.0, t * 20.0)
			"pebbles":
				for c in clicks:
					var dt: float = t * secs - c.t
					if dt > 0.0 and dt < 0.05:
						v += sin(TAU * c.f * dt) * exp(-dt * 120.0) * c.a * 0.5
			"twang":
				# The rope goes taut: a low note that decays, with a creak on top.
				phase += TAU * (110.0 * base + 30.0 * exp(-t * 12.0)) / RATE
				v = (sin(phase) + 0.4 * sin(phase * 2.0)) * exp(-t * 5.0) * 0.6
				low += (noise - low) * 0.1
				v += low * exp(-t * 9.0) * 0.4
			"creak":
				# Fibres rubbing: a wavering squeal with a rough edge.
				phase += TAU * (260.0 * base + 90.0 * sin(t * 9.0 * base) + 60.0 * t) / RATE
				v = (sin(phase) * 0.5 + signf(sin(phase * 0.5)) * 0.1 + noise * 0.12) * sin(t * PI) * 0.7
			"breath":
				# A breath out through the nose and mouth: filtered noise that swells and fades.
				low += (noise - low) * 0.18
				low2 += (low - low2) * 0.3
				v = (low - low2 * 0.6) * sin(pow(t, 0.7) * PI) * 1.4
			"rustle":
				# Cloth folding: crackly noise in bursts.
				low += (noise - low) * 0.35
				var burst := 0.5 + 0.5 * sin(t * 37.0 * base + sin(t * 11.0) * 3.0)
				v = (noise - low) * burst * burst * sin(t * PI) * 0.7
			"tap":
				# A hammer on an iron nail: a ring over a click.
				phase += TAU * 1650.0 * base / RATE
				v = sin(phase) * exp(-t * 22.0) * 0.6 + noise * exp(-t * 90.0) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
