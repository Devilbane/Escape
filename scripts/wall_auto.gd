class_name WallAuto
extends RefCounted
## Wolfram climbs by himself (the "watch him" mode of the wall stage): he plans the likeliest route, goes up it
## move by move, catches his breath when he tires, spends the evening at a rest place, looks at every crack
## before he jumps and turns back when it looks too deadly. He uses the same rules as the hero (WallClimb).

enum Do { MOVE, REST, CAMP, LOOK, STOP }

var route: Array[Vector2i] = []
var rests := 0
## Why he stopped: "top", "turned", "gave_up" or "" while he climbs.
var ended := ""


## The route for a climber of `skill`: the likeliest, or the shortest without jumps from the first start hold.
func plan(map: WallMap, skill: int, weather: String, first_start: Vector2i) -> void:
	route = WallRoutes.easiest(map, skill, weather)
	if route.is_empty() or route[0] != first_start:
		route = _walk(map, first_start)


## What to do now: {"do": Do, "dir": int}. `read` is the stage's last look at a crack ({} before one).
func decide(climb: WallClimb, read: Dictionary) -> Dictionary:
	var idx := -1 if climb.on_ground() else route.find(climb.cell)
	if idx + 1 >= route.size() or idx < -1:
		ended = "top" if idx + 1 >= route.size() else "gave_up"
		return {"do": Do.STOP, "dir": 0}
	var mv := {}
	for m: Dictionary in climb.options():
		if m.to == route[idx + 1]:
			mv = m
	if mv.is_empty():
		ended = "gave_up"
		return {"do": Do.STOP, "dir": 0}
	if climb.at_camp() and (climb.hour() >= 17.0 or climb.stamina < 0.45 * climb.stamina_max):
		return {"do": Do.CAMP, "dir": 0}
	if not climb.on_ground() and climb.stamina < climb.cost(mv) + 0.25 * climb.stamina_max and rests < 4:
		rests += 1
		return {"do": Do.REST, "dir": 0}
	rests = 0
	if mv.kind == "jump":
		if read.is_empty():
			return {"do": Do.LOOK, "dir": mv.dir}
		if float(read.shown) < 0.3:
			ended = "turned"
			return {"do": Do.STOP, "dir": 0}
	return {"do": Do.MOVE, "dir": mv.dir}


func _walk(map: WallMap, a: Vector2i) -> Array[Vector2i]:
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if map.is_top(c.x, c.y):
			var path: Array[Vector2i] = [c]
			while c != a:
				c = prev[c]
				path.push_front(c)
			return path
		for mv: Dictionary in map.moves_from(c.x, c.y):
			if mv.kind == "step" and not prev.has(mv.to):
				prev[mv.to] = c
				q.append(mv.to)
	return []
