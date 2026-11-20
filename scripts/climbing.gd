class_name Climbing
extends RefCounted
## The Klettern (climbing) skill: how long a hand-over-hand climb takes and how
## high the hero can get. Written for any height, so a wall or a mountain face can
## use it later: ask `can_climb(height, level)` and `seconds(height, level)`, then
## train the skill with `Training.CLIMB_PER_METRE` for each metre.
## Today it is the hero scrambling out of a dug pit (see Player._try_climb_out).

## Seconds a climb takes per metre at skill level 0.
const SECONDS_PER_METRE := 0.45
## Each level makes the climb this much faster, down to MIN_FACTOR of the base time.
const SPEEDUP_PER_LEVEL := 0.035
const MIN_FACTOR := 0.4
## The highest face a hero without training can climb, and what each level adds.
const REACH_BASE := 3.5
const REACH_PER_LEVEL := 0.4


## Seconds for climbing `height` metres at skill `level`.
static func seconds(height: float, level: int) -> float:
	var factor := maxf(MIN_FACTOR, 1.0 - SPEEDUP_PER_LEVEL * level)
	return maxf(0.3, height * SECONDS_PER_METRE * factor)


## The most metres the hero can climb in one go at skill `level`.
static func reach(level: int) -> float:
	return REACH_BASE + REACH_PER_LEVEL * level


static func can_climb(height: float, level: int) -> bool:
	return height <= reach(level)
