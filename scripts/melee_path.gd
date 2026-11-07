class_name MeleePath
## Finds a way for a melee monster to get into striking range of its target
## when the plain route to the target's own tile fails: the target stands on a
## blocked tile (behind a crate, on a ledge) or in a pocket the monster cannot
## walk into.
##
## One breadth-first flood from the monster over the walkable tiles, no wider
## than `RADIUS` tiles, finds the nearest tile from which a blow lands. When no
## tile does, the monster is stranded: it goes to the reachable tile closest to
## the target and waits there (the caller repaths only rarely then).

## How far the flood spreads from the monster (tiles, each way).
const RADIUS := 20

## The neighbours of a tile; the diagonals come last so straight steps win ties.
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## The way from `from` to a tile within `reach` tiles of `target` that passes
## `can_strike` (a Callable taking a tile, true when a blow from there lands;
## invalid means every tile in reach does). Returns {"path": tiles after `from`,
## "reached": true when the last tile is a striking spot}. With no striking spot
## in range, the path leads to the reachable tile closest to the target.
static func approach(astar: AStarGrid2D, from: Vector2i, target: Vector2i, reach: float, can_strike := Callable()) -> Dictionary:
	var parent := {from: from}
	var queue: Array[Vector2i] = [from]
	var best := from
	var best_d := _gap(from, target)
	var spot := Vector2i.ZERO
	var found := false
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d := _gap(c, target)
		if d <= reach and (not can_strike.is_valid() or can_strike.call(c)):
			spot = c
			found = true
			break
		if d < best_d:
			best = c
			best_d = d
		for s in STEPS:
			var n: Vector2i = c + s
			if parent.has(n) or absi(n.x - from.x) > RADIUS or absi(n.y - from.y) > RADIUS:
				continue
			if not astar.is_in_boundsv(n) or astar.is_point_solid(n):
				continue
			# Like the grid itself, no cutting round a corner.
			if s.x != 0 and s.y != 0 and (_blocked(astar, c + Vector2i(s.x, 0)) or _blocked(astar, c + Vector2i(0, s.y))):
				continue
			parent[n] = c
			queue.append(n)
	var goal := spot if found else best
	var path: Array[Vector2i] = []
	var at := goal
	while at != from:
		path.push_front(at)
		at = parent[at]
	return {"path": path, "reached": found}


static func _blocked(astar: AStarGrid2D, c: Vector2i) -> bool:
	return not astar.is_in_boundsv(c) or astar.is_point_solid(c)


static func _gap(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()
