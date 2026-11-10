class_name TownsfolkSteps
## The footsteps of the townsfolk: each villager's step sounds like the hero's
## on the ground they walk on (see Surfaces.STEPS), and splashes in a puddle.
## Steps are quiet, come from the villager's spot (so they fade with the
## distance, see Sfx.play), and a crowded village stays calm: nobody far from
## the camera is heard at all, and only a few steps may sound per moment.

## Metres of walking between two steps, for a stroll and for a run.
const STRIDE_WALK := 0.75
const STRIDE_RUN := 1.2
## Volume (dB) of a step: well below the hero's own (-17 walking).
const WALK_DB := -29.0
const RUN_DB := -25.0
## Further from the camera than this (metres), a step is not played at all.
const HEARD_FROM := 22.0
## At most this many steps sound within one STEP_WINDOW (seconds), however many walk.
const MAX_PER_WINDOW := 4
const STEP_WINDOW := 0.25

static var _window_start := -1.0
static var _in_window := 0


## Tells whether a step may sound now at `at`, seen from `cam_pos`, and counts it.
## `now` is the time in seconds.
static func allowed(cam_pos: Vector3, at: Vector3, now: float) -> bool:
	if cam_pos.distance_to(at) > HEARD_FROM:
		return false
	if now < _window_start or now - _window_start >= STEP_WINDOW:
		_window_start = now
		_in_window = 0
	if _in_window >= MAX_PER_WINDOW:
		return false
	_in_window += 1
	return true


## The sound and volume of a step at `p` of `level`: [name, dB].
static func sound_at(level: Level, p: Vector3, running: bool) -> Array:
	var db := RUN_DB if running else WALK_DB
	if level != null and level.in_puddle(p):
		var fill: float = level.puddle_fill(p)
		return [Puddles.splash_sound(fill), db - 4.0 + Puddles.splash_volume(fill)]
	return [Surfaces.step_sound(Surfaces.ground(level, p)), db]


## Counts the ground a villager has walked (`covered`, kept by the villager)
## and plays a step each stride. Returns the new `covered`.
static func walk(who: Node3D, level: Level, covered: float, moved: float, running: bool) -> float:
	covered += moved
	var stride := STRIDE_RUN if running else STRIDE_WALK
	if covered < stride:
		return covered
	covered = fmod(covered, stride)
	if not who.visible or not who.is_inside_tree():
		return covered
	var cam := who.get_viewport().get_camera_3d()
	if cam == null or not allowed(cam.global_position, who.global_position, Time.get_ticks_msec() / 1000.0):
		return covered
	var s := sound_at(level, who.global_position, running)
	Sfx.play(who, s[0], s[1], who.global_position)
	if level != null and level.in_puddle(who.global_position):
		level.splash_puddle(who.global_position, false)
	return covered
