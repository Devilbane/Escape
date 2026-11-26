class_name WallRules
extends RefCounted
## The rules of climbing a WallMap, pure numbers with no scene (tests/wall_map.gd plays them through).
## They build on RockClimb: the chance of a hold is the same curve, asked for the wall's level plus the
## hold's malus. On top of it:
## - a hold's SURFACE (ice, loose stones, wet moss) has a failure risk of its own, taken after the skill's
##   chance, so it stays no matter how skilled the climber is, and such a failure is always a fall;
## - a JUMP across a gap needs a level that rises with the gap's width; below it the jump cannot be tried,
##   at it the chance is JUMP_BASE, better with every level above; a missed jump is always a fall.

## The risk each surface keeps, whatever the skill, and its German name and colour.
const SURFACES := {
	WallMap.ICE: {"name": "Eis", "risk": 0.18, "colour": Color(0.62, 0.84, 0.95)},
	WallMap.LOOSE: {"name": "Loses Gestein", "risk": 0.14, "colour": Color(0.72, 0.62, 0.5)},
	WallMap.WET: {"name": "Nasses Moos", "risk": 0.09, "colour": Color(0.3, 0.55, 0.28)},
}
## Levels a jump asks for per metre of gap width, and the chance at exactly that level and per level above.
const JUMP_LEVELS_PER_METRE := 3.0
const JUMP_BASE := 0.55
const JUMP_PER_LEVEL := 0.06
const JUMP_MAX := 0.92


## The Klettern level that just manages the hold at (c, r): the wall's level plus the hold's malus, and what
## the weather adds (see WallWeather).
static func required(map: WallMap, c: int, r: int, weather := "") -> int:
	return map.level + maxi(0, map.malus_at(c, r)) + WallWeather.extra_level(weather)


## The risk of a surface that stays whatever the skill (0 for plain rock).
static func risk(kind: int) -> float:
	return float(SURFACES[kind].risk) if SURFACES.has(kind) else 0.0


## The chance of the skill alone to take the hold (RockClimb's curve).
static func skill_chance(map: WallMap, c: int, r: int, skill: int, weather := "") -> float:
	return clampf(RockClimb.CHANCE_BASE + RockClimb.CHANCE_PER_LEVEL * (skill - required(map, c, r, weather)),
			RockClimb.CHANCE_MIN, RockClimb.CHANCE_MAX)


## The risk the square at (c, r) keeps whatever the skill: its surface in this weather or the weather's own.
static func square_risk(map: WallMap, c: int, r: int, weather := "") -> float:
	return maxf(WallWeather.surface_risk(weather, map.hazard_at(c, r)), WallWeather.slip_floor(weather))


## The chance that a move onto the hold at (c, r) holds: the skill's chance, less the surface's risk.
static func step_chance(map: WallMap, c: int, r: int, skill: int, weather := "") -> float:
	return skill_chance(map, c, r, skill, weather) * (1.0 - square_risk(map, c, r, weather))


## The level a jump across the gap needs.
static func jump_required(map: WallMap, gap: int, weather := "") -> int:
	return map.level + int(ceil(JUMP_LEVELS_PER_METRE * map.gap_span(gap))) + WallWeather.jump_levels(weather)


## The chance of a jump (0 below the level it needs), less the surface's risk of the landing hold.
static func jump_chance(map: WallMap, gap: int, landing: Vector2i, skill: int, weather := "") -> float:
	var need := jump_required(map, gap, weather)
	if skill < need:
		return 0.0
	var base := minf(JUMP_MAX, JUMP_BASE + JUMP_PER_LEVEL * (skill - need)) * WallWeather.jump_factor(weather)
	return base * (1.0 - square_risk(map, landing.x, landing.y, weather))


## The chance of a move from `moves_from` at a skill level.
static func move_chance(map: WallMap, move: Dictionary, skill: int, weather := "") -> float:
	var to: Vector2i = move.to
	if move.kind == "jump":
		return jump_chance(map, int(move.gap), to, skill, weather)
	return step_chance(map, to.x, to.y, skill, weather)
