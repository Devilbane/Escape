class_name ClimbSpots
extends RefCounted
## Hidden footholds in the mountain face, found by pushing against the rock (see Player._try_climb_rock).
## A spot is one rock tile of the open-air map, north of open ground, whose top is a flat terrace a few
## metres up: a hero with enough Klettern pulls up onto it (see Climbing), then steps off to come down.
##
## Nobody may tell a spot from plain rock before they can climb it: pushing against ANY rock face for
## HOLD seconds ends the same way (the one message TOO_STEEP) whether there is a spot, the Klettern
## level is too low, or there is only rock. The mesh shows only a quiet terrace (see Mountains.build).

## Seconds of pushing against the rock before the hero tries the face.
const HOLD := 1.0
## The only thing a hero is ever told when the face does not give.
const TOO_STEEP := "Hier ist es zu steil."

## Per map (Level.level_name): the rock tile, the Klettern level a hero needs and the height of the terrace
## (metres, well above what a stack of crates and a jump reach, and within Climbing.reach of the level).
const SPOTS := {
	"Apfeltal": [
		{"cell": Vector2i(123, 23), "level": 1, "height": 3.6},
		{"cell": Vector2i(136, 26), "level": 6, "height": 5.4},
		{"cell": Vector2i(84, 54), "level": 12, "height": 6.6},
		# The one the climber shows (see ClimberNpc): on the mountainside east of the stream.
		{"cell": Vector2i(55, 57), "level": 9, "height": 7.0},
		# The hidden one (see SummitGarden): a ledge high in the north rim of the high valley, with a garden on it.
		{"cell": Vector2i(151, 4), "level": 16, "height": 9.6, "viper": true},
	],
}


## The spots of `level`.
static func spots(level: Level) -> Array:
	return SPOTS.get(level.level_name, [])


## The spot on tile `c` of `level`, or an empty Dictionary.
static func at(level: Level, c: Vector2i) -> Dictionary:
	for s: Dictionary in spots(level):
		if s.cell == c:
			return s
	return {}


## The terraces as rectangles on the ground (metres) with their height, for the rock's mesh.
static func shelves(level: Level) -> Array:
	var out := []
	for s: Dictionary in spots(level):
		var mid := level.cell_to_world(s.cell)
		var half := Level.TILE * 0.5
		out.append({"rect": Rect2(mid.x - half, mid.z - half, Level.TILE, Level.TILE), "height": s.height})
	return out


## Rock tiles round a terrace that keep their full-height wall so nobody walks on from it into the rock.
static func wall_cells(level: Level) -> Array:
	var out := []
	for s: Dictionary in spots(level):
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
			out.append(s.cell + d)
	return out


## Where the hero ends up on top of a spot (feet).
static func top(level: Level, s: Dictionary) -> Vector3:
	return level.cell_to_world(s.cell) + Vector3(0, s.height + 0.02, 0)
