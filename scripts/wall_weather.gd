class_name WallWeather
extends RefCounted
## How the weather changes a climb (see WallRules, WallStage). The names are Weather's (clear, rain, snow, storm)
## plus WIND, a dry gale. Weather turns bad while somebody hangs on the wall, and then everything gets worse
## at once, so a change is a danger and not a decoration:
## - RAIN: every hold asks more (EXTRA_LEVEL) and keeps a small risk of its own (SLIP_FLOOR), wet moss is much
##   worse; the rain also loosens stones from above (see FALL_EVERY).
## - SNOW: the cold puts a skin of ice on part of the wall (FROST_SHARE of the squares, see `frosted`), ice is
##   worse, and every hold asks a little more.
## - WIND: a gap's jump asks more levels (JUMP_LEVELS) and is less likely to land (JUMP_FACTOR).
## - STORM: all of it, and stones fall often. A gale tears loose what rain began.
## The weather of the stage may also worsen on its own while the climb lasts (see WallStage.WORSEN_EVERY).

const CLEAR := "clear"
const RAIN := "rain"
const SNOW := "snow"
const WIND := "wind"
const STORM := "storm"
## In the order the sky worsens.
const ORDER := [CLEAR, WIND, RAIN, SNOW, STORM]

const DATA := {
	CLEAR: {"name": "Klar", "level": 0, "floor": 0.0, "wet": 1.0, "ice": 1.0, "jump_levels": 0, "jump_factor": 1.0, "frost": 0.0, "fall_every": 0.0},
	WIND: {"name": "Wind", "level": 0, "floor": 0.0, "wet": 1.0, "ice": 1.0, "jump_levels": 3, "jump_factor": 0.75, "frost": 0.0, "fall_every": 0.0},
	RAIN: {"name": "Regen", "level": 2, "floor": 0.05, "wet": 2.0, "ice": 1.0, "jump_levels": 1, "jump_factor": 0.9, "frost": 0.0, "fall_every": 16.0},
	SNOW: {"name": "Schnee", "level": 1, "floor": 0.04, "wet": 1.0, "ice": 1.4, "jump_levels": 1, "jump_factor": 0.9, "frost": 0.3, "fall_every": 0.0},
	STORM: {"name": "Sturm", "level": 3, "floor": 0.08, "wet": 2.0, "ice": 1.3, "jump_levels": 4, "jump_factor": 0.6, "frost": 0.12, "fall_every": 5.0},
}


static func known(weather: String) -> bool:
	return DATA.has(weather)


static func _d(weather: String) -> Dictionary:
	return DATA.get(weather, DATA[CLEAR])


## Extra levels every hold asks.
static func extra_level(weather: String) -> int:
	return int(_d(weather).level)


## The risk every hold keeps in this weather, on top of its surface.
static func slip_floor(weather: String) -> float:
	return float(_d(weather).floor)


## The risk a surface keeps in this weather: its own, made worse by what suits it.
static func surface_risk(weather: String, kind: int) -> float:
	var base := WallRules.risk(kind)
	if kind == WallMap.WET:
		base *= float(_d(weather).wet)
	elif kind == WallMap.ICE:
		base *= float(_d(weather).ice)
	return minf(0.6, base)


static func jump_levels(weather: String) -> int:
	return int(_d(weather).jump_levels)


static func jump_factor(weather: String) -> float:
	return float(_d(weather).jump_factor)


## Seconds between two stones from above (0: none fall).
static func fall_every(weather: String) -> float:
	return float(_d(weather).fall_every)


## The wall as it is in this weather: in the cold part of the squares carry ice too (always the same squares
## for the same wall, so the 3D wall and the rules agree). Other weather leaves it as it is.
static func frosted(map: WallMap, weather: String) -> WallMap:
	var share := float(_d(weather).frost)
	if share <= 0.0:
		return map
	var out := map.duplicate_map()
	for r in out.height:
		for c in out.width:
			if out.hazard_at(c, r) == WallMap.NONE and WallBuild._hash(c * 3 + 1, r * 5 + 2) < share:
				out.set_hazard(c, r, WallMap.ICE)
	return out
