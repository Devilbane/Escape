class_name WallRoutes
extends RefCounted
## The ways up a WallMap: the likeliest route for a skill level (Dijkstra over the moves, each costing
## -ln of its chance, so the cost of a route is the log of how unlikely the whole climb is).

const NO_ROUTE: Array[Vector2i] = []


## The likeliest route from a hold at the foot to a hold at the top for a climber of `skill`, as the list
## of squares from the foot up, or empty when there is none (a jump the skill is too low for is no move).
static func easiest(map: WallMap, skill: int, weather := "") -> Array[Vector2i]:
	var dist := {}
	var came := {}
	var open: Array[Vector2i] = []
	for c in map.width:
		if map.is_start(c, map.height - 1):
			var p := Vector2i(c, map.height - 1)
			dist[p] = _cost(WallRules.step_chance(map, p.x, p.y, skill, weather))
			open.append(p)
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var here: Vector2i = open[best]
		open.remove_at(best)
		if done.has(here):
			continue
		done[here] = true
		if map.is_top(here.x, here.y):
			var path: Array[Vector2i] = [here]
			while came.has(path[0]):
				path.push_front(came[path[0]])
			return path
		for mv: Dictionary in map.moves_from(here.x, here.y):
			var chance := WallRules.move_chance(map, mv, skill, weather)
			if chance <= 0.0:
				continue
			var to: Vector2i = mv.to
			var d: float = dist[here] + _cost(chance)
			if not dist.has(to) or d < dist[to]:
				dist[to] = d
				came[to] = here
				open.append(to)
	return NO_ROUTE


static func _cost(chance: float) -> float:
	return -log(maxf(chance, 0.0001))


## The chance that a climb along `route` goes without a single failed move.
static func success_chance(map: WallMap, route: Array[Vector2i], skill: int, weather := "") -> float:
	if route.is_empty():
		return 0.0
	var p := WallRules.step_chance(map, route[0].x, route[0].y, skill, weather)
	for i in range(1, route.size()):
		var mv := _move(map, route[i - 1], route[i])
		p *= WallRules.move_chance(map, mv, skill, weather) if not mv.is_empty() else 0.0
	return p


## The chance of the weakest move of a route (the one that most likely fails).
static func weakest(map: WallMap, route: Array[Vector2i], skill: int, weather := "") -> float:
	if route.is_empty():
		return 0.0
	var worst := WallRules.step_chance(map, route[0].x, route[0].y, skill, weather)
	for i in range(1, route.size()):
		var mv := _move(map, route[i - 1], route[i])
		worst = minf(worst, WallRules.move_chance(map, mv, skill, weather) if not mv.is_empty() else 0.0)
	return worst


## The move between two neighbouring squares of a route, or an empty Dictionary.
static func _move(map: WallMap, a: Vector2i, b: Vector2i) -> Dictionary:
	for mv: Dictionary in map.moves_from(a.x, a.y):
		if mv.to == b:
			return mv
	return {}


## What a route is made of: {"steps", "jumps", "hardest" (highest malus), "hazards" (squares with a surface)}.
static func describe(map: WallMap, route: Array[Vector2i]) -> Dictionary:
	var out := {"steps": maxi(0, route.size() - 1), "jumps": 0, "hardest": 0, "hazards": 0}
	for i in route.size():
		var p := route[i]
		out.hardest = maxi(int(out.hardest), map.malus_at(p.x, p.y))
		if map.hazard_at(p.x, p.y) != WallMap.NONE:
			out.hazards = int(out.hazards) + 1
		if i > 0 and not _move(map, route[i - 1], p).is_empty() and _move(map, route[i - 1], p).kind == "jump":
			out.jumps = int(out.jumps) + 1
	return out
