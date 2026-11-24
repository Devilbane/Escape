class_name Climbing
extends RefCounted
## The Klettern (climbing) skill: how long a hand-over-hand climb takes and how
## high the hero can get. Written for any height, so a wall or a mountain face can
## use it later: ask `can_climb(height, level)` and `seconds(height, level)`, then
## train the skill with `Training.CLIMB_PER_METRE` for each metre.
## Today it is the hero scrambling out of a dug pit (see Player._try_climb_out).

## Everybody climbs at least at this level, so no hero is ever stuck in a pit.
const MIN_LEVEL := 1
## The chance that one attempt to pull up succeeds: at level 1 about every other
## try, better with skill, and every failed try in a row adds PITY to the next
## one, so a few attempts always get the hero out.
const CHANCE_BASE := 0.45
const CHANCE_PER_LEVEL := 0.05
const CHANCE_MAX := 0.95
const PITY := 0.2

## A climb at the first level takes this many times as long as walking the same
## distance on foot.
const SLOWDOWN := 5.0
## Each level makes the climb this much faster, down to MIN_FACTOR of the base time.
const SPEEDUP_PER_LEVEL := 0.035
const MIN_FACTOR := 0.4
## The highest face a hero without training can climb, and what each level adds.
const REACH_BASE := 3.5
const REACH_PER_LEVEL := 0.4


## The climbing gear the shopkeeper always has (id -> how many): see RockClimb.
const GEAR_FOR_SALE := {"kletterhammer": 1, "kletterseil": 1, "kletterhaken": 6, "kletterhelm": 1}


## Seconds for climbing `height` metres at skill `level` by a hero who walks
## `walk_speed` metres a second: SLOWDOWN times the walk at level 1, a little less
## with each level.
static func seconds(height: float, level: int, walk_speed: float) -> float:
	var factor := maxf(MIN_FACTOR, 1.0 - SPEEDUP_PER_LEVEL * (level - MIN_LEVEL))
	return maxf(0.3, height / maxf(0.1, walk_speed) * SLOWDOWN * factor)


## The most metres the hero can climb in one go at skill `level`.
static func reach(level: int) -> float:
	return REACH_BASE + REACH_PER_LEVEL * level


static func can_climb(height: float, level: int) -> bool:
	return height <= reach(level)


## The chance for an attempt at skill `level` after `failures` slips in a row.
static func chance(level: int, failures: int) -> float:
	return minf(1.0, minf(CHANCE_MAX, CHANCE_BASE + CHANCE_PER_LEVEL * (level - MIN_LEVEL)) + PITY * failures)
