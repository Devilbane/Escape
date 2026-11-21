class_name StairSteps
extends RefCounted
## The footsteps on the wooden stairs of the houses: a hollow boom of the board over its box
## with a knock of the sole, and the old wood creaking under the weight. Up the stairs the foot
## presses slowly (deeper, softer, creakier); down them the heel drops (sharper and brighter).
## The sounds stair_up_0 to _5 and stair_down_0 to _5 are made by tools/make_stair_sounds.py.
##
## Two places use them: the stairs of a town house on Weavers' Lane, where the hero walks a few
## steps up or down while the screen fades to the next storey (see flight and Game._take_stairs),
## and the stairs the player builds into a house on the open-air map, which the hero walks
## step by step (see on_stairs and Player._footsteps).

## How many steps of each way there are.
const SOUNDS := 6
## When the steps of a flight land (seconds after the hero sets foot on it). Down the stairs the
## steps come a little quicker. Both end before the screen is dark (the 0.45 s fade in Game._take_stairs).
const UP_TIMES: Array[float] = [0.0, 0.15, 0.3]
const DOWN_TIMES: Array[float] = [0.0, 0.12, 0.24]
## How much louder a step on the stairs is than one on a floor: the board is hollow.
const LIFT_DB := 1.0
## How loud the steps of a flight are (a walk, see Player._footsteps, lifted by LIFT_DB).
const STEP_DB := -14.0 + LIFT_DB

static var _last := {}


## One step on wooden stairs, up or down: never the same sound twice in a row.
static func sound(up: bool) -> String:
	var way := "up" if up else "down"
	var k := randi() % SOUNDS
	if k == int(_last.get(way, -1)):
		k = (k + 1) % SOUNDS
	_last[way] = k
	return "stair_%s_%d" % [way, k]


## The steps of a short flight, heard from `node` (the hero): one at each of UP_TIMES or DOWN_TIMES.
static func flight(node: Node, up: bool, volume_db := STEP_DB) -> void:
	if node == null or not node.is_inside_tree():
		return
	for at: float in (UP_TIMES if up else DOWN_TIMES):
		if at <= 0.0:
			Sfx.play(node, sound(up), volume_db)
			continue
		node.get_tree().create_timer(at, false, true).timeout.connect(func():
			if is_instance_valid(node) and node.is_inside_tree():
				Sfx.play(node, sound(up), volume_db))


## Whether a body at `pos` with ground velocity `vel` walks on built stairs (see HouseFloors),
## and which way: 1 up, -1 down, 0 not on stairs (or standing still on them).
static func on_stairs(floors: HouseFloors, pos: Vector3, vel: Vector3) -> int:
	if floors == null:
		return 0
	var rise := floors.stairs_at(pos)
	if rise.is_empty():
		return 0
	var step: Vector2i = rise.step
	var along := vel.x * step.x + vel.z * step.y
	if absf(along) < 0.05:
		return 0
	# Walking along the ramp's way climbs by its rise (negative for a cellar's stairs).
	return 1 if (along > 0.0) == (float(rise.rise) > 0.0) else -1
