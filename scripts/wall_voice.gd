class_name WallVoice
extends RefCounted
## What the climber shouts on the wall, and the sounds that go with it (made in code, no sound files):
## a grunt when a hold slips, a curse when a jump or pull is missed, a scream in a fall, a cheer at a landing.
## The lines are mild and fantasy-flavoured; each is a German source text with an English entry in `Lang`.

const LINES := {
	"slip": ["Verdammter Fels!", "Elender Griff!", "Rutsch nicht, du Mistding!", "Bei Gorgas Bart!"],
	"jump_miss": ["Aaaaaah!", "Ich hasse Spalten!", "Bei den Zähnen des Drachen!", "Das war zu weit, du Narr!"],
	"fall": ["Neeeiiin!", "Aaaaaaargh!", "Hilfeeeee!", "Beim Barte des Berggeists!"],
	"graze": ["Au! Verfluchter Stein!", "Wer wirft da Steine?!"],
	"cheer": ["Ha! Na also!", "Das hat gesessen!", "Und weiter!"],
	"turn": ["Nein, da springe ich nicht!", "Das ist Wahnsinn!"],
	"tired": ["Puh... Luft...", "Meine Arme brennen!"],
}
const RATE := 22050
static var _cache := {}


## A line for `kind` (German source text, translate with Lang.t).
static func line(kind: String, rng: RandomNumberGenerator) -> String:
	var options: Array = LINES.get(kind, [])
	if options.is_empty():
		return ""
	return String(options[rng.randi() % options.size()])


## The sound for `kind`: "fall" and "jump_miss" scream, "slip" and "graze" grunt, "cheer" whoops.
static func sound(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var secs := 0.18
	match kind:
		"fall", "jump_miss":
			secs = 0.9
		"cheer":
			secs = 0.35
		"tired":
			secs = 0.3
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var v := 0.0
		match kind:
			"fall", "jump_miss":
				# A scream: a pitch that starts high and sinks, with a wobble and some rasp.
				var f := lerpf(1100.0, 380.0, t) * (1.0 + 0.04 * sin(t * 40.0))
				phase += TAU * f / RATE
				v = (sin(phase) + 0.5 * sin(phase * 2.0) + 0.25 * sin(phase * 3.0)) * 0.4 + rng.randf_range(-0.15, 0.15)
				v *= minf(1.0, t * 12.0) * (1.0 - t * 0.7)
			"cheer":
				var f2 := lerpf(420.0, 760.0, minf(1.0, t * 2.0)) if t < 0.5 else lerpf(760.0, 520.0, (t - 0.5) * 2.0)
				phase += TAU * f2 / RATE
				v = (sin(phase) + 0.3 * sin(phase * 2.0)) * 0.45 * (1.0 - t)
			"tired":
				phase += TAU * lerpf(260.0, 200.0, t) / RATE
				v = (sin(phase) * 0.35 + rng.randf_range(-0.2, 0.2)) * sin(t * PI)
			_:
				# A grunt: a low thump with breath in it.
				phase += TAU * lerpf(170.0, 110.0, t) / RATE
				v = (sin(phase) * 0.6 + rng.randf_range(-0.2, 0.2)) * (1.0 - t) * minf(1.0, t * 30.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[kind] = wav
	return wav
