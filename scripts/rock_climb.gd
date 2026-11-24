class_name RockClimb
extends RefCounted
## The rules of one climb up a rock face (see ClimbSpots and Player._rock_step): hand over hand, one
## pull-up (PULL metres) at a time. A pull-up may slip. After FIRST pull-ups in a row from the ground
## without a fall the hero hammers an iron nail into the rock and threads the rope through it: a safe
## spot. After every NEXT pull-ups in a row from the last safe spot comes another. A fall drops the hero
## only down to the last safe spot (the ground when there is none), and the count of pull-ups starts again.
## Pure rules, no scene: tests/rock_climb.gd plays them through.

enum Result { UP, TOP, PITON, FELL }

## Metres gained by one pull-up.
const PULL := 0.9
## Pull-ups in a row to the first safe spot, and to each next one.
const FIRST := 3
const NEXT := 2
## The chance of a pull-up at the Klettern level the spot asks for, and what each level above it adds.
const CHANCE_BASE := 0.62
const CHANCE_PER_LEVEL := 0.05
const CHANCE_MIN := 0.4
const CHANCE_MAX := 0.95
## Life lost per metre fallen (a fall never kills).
const FALL_PER_METRE := 1.5

var height := 3.0
## The Klettern level the spot asks for and the hero's.
var required := 1
var skill := 1
## Metres climbed so far, the height of the last safe spot (0 = the ground), pull-ups in a row since it.
var metres := 0.0
var safe := 0.0
var streak := 0
## Heights of the safe spots set so far.
var nails: Array[float] = []


func _init(h: float, required_level: int, level: int) -> void:
	height = h
	required = required_level
	skill = level


## The chance that one pull-up holds: better with skill above what the spot asks for.
func chance() -> float:
	return clampf(CHANCE_BASE + CHANCE_PER_LEVEL * (skill - required), CHANCE_MIN, CHANCE_MAX)


## Pull-ups in a row that earn the next safe spot.
func needed() -> int:
	return FIRST if nails.is_empty() else NEXT


## One pull-up with the roll of the hands (0..1, a roll at or above the chance slips). `has_gear` is
## whether the hero carries hammer, rope and a nail for a safe spot. Returns what came of it.
func pull(roll: float, has_gear: bool) -> int:
	if roll >= chance():
		metres = safe
		streak = 0
		return Result.FELL
	metres = minf(height, metres + PULL)
	streak += 1
	if metres >= height - 0.001:
		return Result.TOP
	if streak >= needed() and has_gear:
		return Result.PITON
	return Result.UP


## Sets a safe spot where the hero hangs.
func set_nail() -> void:
	safe = metres
	nails.append(metres)
	streak = 0


## The metres of the last fall's drop given where the hero hung before it.
static func fall_damage(metres_fallen: float) -> int:
	return int(round(metres_fallen * FALL_PER_METRE))
