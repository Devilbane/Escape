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
}

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
	return level.ground_at(level.world_to_cell(p))


## The share of the full pace at a spot.
static func pace_at(level: Level, p: Vector3) -> float:
	return float(PACE.get(ground(level, p), 1.0))


## Moves a pace (`now`) toward that of the ground at `p`, a bit each tick.
static func ease_pace(now: float, level: Level, p: Vector3, delta: float) -> float:
	return move_toward(now, pace_at(level, p), EASE * delta)
