class_name Surfaces
## How fast feet carry over the ground: paving, roads and stone floors keep
## the full pace, grass and soil slow a little, loose scree and rain puddles
## more. The hero and the monsters that walk share the same table; flyers
## (bats, dragons, brood drakes) skim over it all.
##
## The ground of a tile comes from its map letter (Level.ground_at and its
## outdoor version), a puddle from the rain (see Puddles). The pace does not
## jump at a tile's edge but eases into the new ground (see ease_pace).

const STONE := "stone"
const WOOD := "wood"
const PAVING := "paving"
const PATH := "path"
const DIRT := "dirt"
const GRASS := "grass"
const SOIL := "soil"
const SCREE := "scree"
const PUDDLE := "puddle"
## A patch of slime on the sewers' floors (see SewerSlime): a squelch with every step.
const SLIME := "slime"
## Snow is not a ground of its own (it does not change the pace): while it lies thick enough to
## take prints (see Weather.PRINT_FROM), every step in the open air crunches (see step_ground).
const SNOW := "snow"

## Each ground and the share of the full pace it allows.
const PACE := {
	STONE: 1.0,
	WOOD: 1.0,
	PAVING: 1.0,
	PATH: 1.0,
	DIRT: 0.95,
	GRASS: 0.92,
	SOIL: 0.88,
	SCREE: 0.82,
	PUDDLE: 0.75,
	SLIME: SewerSlime.PACE,
}

## Each ground and the footsteps heard on it: the sounds step_<name>_0 to
## step_<name>_5 (an empty name is the plain step_0 to step_5, the stone steps).
## Stone (step_0 to step_5, recorded by Fantozzi) and dirt floors keep their own steps; paving rings
## brighter, paths and fields crunch softly, grass swishes, scree (gravel) crackles and planks give a
## short, dry knock, snow crunches. A puddle splashes instead (see Player._footsteps). Grass, scree,
## wood, paving, path, soil and snow are cut from the Soundza recordings by tools/make_soundza_steps.py.
const STEPS := {
	STONE: "",
	PAVING: "paving",
	WOOD: "wood",
	PATH: "path",
	DIRT: "dirt",
	SOIL: "soil",
	GRASS: "grass",
	SCREE: "scree",
	SNOW: "snow",
}
## How many recorded steps each ground has.
const STEP_SOUNDS := 6

## How quickly the pace eases into a new ground (share of the pace per second).
const EASE := 2.5


## The ground under a spot of `level`: a puddle if one lies there, otherwise
## the ground of its tile.
static func ground(level: Level, p: Vector3) -> String:
	if level == null:
		return STONE
	var outdoor := level as Outdoor
	if outdoor and outdoor.in_puddle(p):
		return PUDDLE
	if SewerSlime.at(p):
		return SLIME
	return level.ground_at(level.world_to_cell(p))


## The ground a step at `p` sounds like: the ground itself, but snow crunches over all of it in
## the open air while the snow lies thick (not over planks, which only stand under a roof, and not
## in a puddle, nor inside a built house).
static func step_ground(level: Level, p: Vector3) -> String:
	var kind := ground(level, p)
	var outdoor := level as Outdoor
	if outdoor and kind != WOOD and kind != PUDDLE and kind != SLIME and outdoor.snow != null and outdoor.snow.amount >= Weather.PRINT_FROM and not outdoor.is_roofed(p):
		return SNOW
	return kind


## The share of the full pace at a spot.
static func pace_at(level: Level, p: Vector3) -> float:
	return float(PACE.get(ground(level, p), 1.0))


## Moves a pace (`now`) toward that of the ground at `p`, a bit each tick.
static func ease_pace(now: float, level: Level, p: Vector3, delta: float) -> float:
	return move_toward(now, pace_at(level, p), EASE * delta)


## A footstep that fits a ground (one of the grounds above), one of the six
## for that ground.
static func step_sound(kind: String) -> String:
	if kind == SLIME:
		return SewerSlime.step_sound()
	var sounds: String = STEPS.get(kind, "")
	var k := randi() % STEP_SOUNDS
	return "step_%d" % k if sounds.is_empty() else "step_%s_%d" % [sounds, k]


## Whether a ground is hard (stone, paving): the plain stone steps.
static func hard(kind: String) -> bool:
	return kind == STONE or kind == PAVING
