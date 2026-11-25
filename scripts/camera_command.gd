class_name CameraCommand
extends RefCounted
## The free camera of the chat line (for taking screenshots): the camera may
## pull back far beyond the normal view and tilt down to nearly ground level.
##
##   camera:free   switches the free camera on (typing it again, or camera:off, ends it)
##   camera:low    on, tilted to a near ground-level view
##   camera:top    on, looking straight down from high up
##   camera:15     on, at a tilt of 15 degrees above the horizon (3 to 89)
##
## While it is on, the mouse wheel and + and - move the camera 12 % per notch
## between FAR_MIN and FAR_MAX metres, and Page Up / Page Down (or [ and ])
## tilt it. The normal zoom is untouched once the mode is off.
##
## ENABLED is the one switch to gate it, like Godmode.ENABLED.

const ENABLED := true
const PREFIXES := ["camera:", "kamera:"]
const OFF_WORDS := ["off", "aus"]
const PITCH_MIN := 3.0
const PITCH_MAX := 89.0
const LOW_PITCH := 8.0
const TOP_PITCH := 89.0
const FAR_MIN := 4.0
const FAR_MAX := 120.0
## Degrees per press of the tilt keys.
const TILT_STEP := 3.0
## Distance factor per wheel notch.
const DISTANCE_STEP := 0.88
const ON_TEXT := "Freie Kamera an: Mausrad zoomt weit hinaus, Bild hoch und Bild runter neigen sie."
const OFF_TEXT := "Freie Kamera aus."
const HELP := "Kamera: free, low, top, off oder ein Neigungswinkel von 3 bis 89."


## What the line asks for, or null when it is no camera command: {"off": true},
## {"toggle": true} or {"pitch": degrees} (also {"pitch": -1.0} for "keep it").
static func parse(line: String) -> Variant:
	if not ENABLED:
		return null
	var s := line.strip_edges().to_lower()
	var word := ""
	for prefix in PREFIXES:
		if s.begins_with(prefix):
			word = s.substr(prefix.length()).strip_edges()
			break
	if word == "" and not _has_prefix(s):
		return null
	if word in OFF_WORDS:
		return {"off": true}
	if word == "free" or word == "frei" or word == "":
		return {"toggle": true}
	if word == "low" or word == "tief":
		return {"pitch": LOW_PITCH}
	if word == "top" or word == "oben":
		return {"pitch": TOP_PITCH}
	if word.is_valid_float():
		return {"pitch": clampf(word.to_float(), PITCH_MIN, PITCH_MAX)}
	return {"help": true}


static func _has_prefix(s: String) -> bool:
	for prefix in PREFIXES:
		if s.begins_with(prefix):
			return true
	return false


## The distance after `steps` wheel notches (positive = closer).
static func distance_after(distance: float, steps: float) -> float:
	return clampf(distance * pow(DISTANCE_STEP, steps), FAR_MIN, FAR_MAX)


## The tilt after pressing the tilt keys `presses` times (positive = higher up).
static func pitch_after(pitch: float, presses: float) -> float:
	return clampf(pitch + presses * TILT_STEP, PITCH_MIN, PITCH_MAX)
