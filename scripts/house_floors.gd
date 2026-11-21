class_name HouseFloors
extends RefCounted
## Where a companion (see Pet) can walk in and around the houses on the open-air
## map (see HouseSketch and HouseSketcher). The hero can jump into a dug pit and
## climb out of it (see Player._try_climb_out); a companion cannot: it never
## jumps down a pit wall and never climbs up one. It goes down into a cellar or
## up to an upper floor only by built stairs, and where there are none it stays
## at the rim.
##
## The floors are laid out on the 2 m lattice of the houses (HouseSketch.CELL),
## one node per lattice cell and storey: GROUND is the open ground (every cell
## round a plot that is not dug open, and every cellar ceiling), CELLAR the dug cells and the ramps down
## to them, UPPER the floor slabs and the ramps up to them. Nodes on one storey
## join their neighbours; a ramp joins only the cell before it and the one after
## it, so nothing walks off its side. Built from every plot on the map at once,
## each time the houses are drawn again.

const GROUND := 0
const CELLAR := -1
const UPPER := 1
const STOREYS := [CELLAR, GROUND, UPPER]
## How many lattice cells of open ground round each plot belong to the floors.
## Beyond them the map's own grid (Level.grid_path) takes over.
const MARGIN := 3
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Vector3i(x, z, storey) -> {"y": floor height, or for a ramp cell also
## "step" (the way it leads, Vector2i), "index" (0 at the top of the cellar
## stairs or the foot of the stairs up, 1 the second cell) and "rise" (what the
## whole ramp climbs over its two cells, negative going down)}.
var _nodes := {}
## Vector3i -> Array of the Vector3i it joins.
var _links := {}
## The lattice rectangles the floors cover (each plot and its margin).
var _areas: Array[Rect2i] = []


## The floors of `houses` (HouseSketch, built pieces only: sketched ones are
## still only a blueprint).
func _init(houses: Array = []) -> void:
	var holes := {}
	# Dug cells closed by a cellar ceiling (see HouseSketch.COVER): ground on top, cellar below.
	var ceilings := {}
	for house: HouseSketch in houses:
		var n := house.nodes()
		var first := cell_of(house.node_world(0, 0) + Vector3(0.1, 0, 0.1))
		_areas.append(Rect2i(first - Vector2i(MARGIN, MARGIN), n + Vector2i(MARGIN, MARGIN) * 2))
		for key in house.pieces:
			var piece: Dictionary = house.pieces[key]
			if piece.state == HouseSketch.SKETCH:
				continue
			var p := HouseSketch.parts_of(key)
			var at := first + Vector2i(p[1], p[2])
			match piece.kind:
				HouseSketch.DIG:
					holes[at] = true
					_nodes[Vector3i(at.x, at.y, CELLAR)] = {"y": -HouseSketch.DEPTH}
				HouseSketch.STAIRS:
					var step: Vector2i = HouseSketch.DOWN[p[3]]
					for i in 2:
						holes[at + step * i] = true
						_nodes[Vector3i(at.x + step.x * i, at.y + step.y * i, CELLAR)] = {"y": 0.0, "step": step, "index": i, "rise": -HouseSketch.DEPTH}
				HouseSketch.COVER:
					ceilings[at] = true
				HouseSketch.SLAB:
					if p[0] == 0:
						_nodes[Vector3i(at.x, at.y, UPPER)] = {"y": HouseSketch.STOREY_HEIGHT}
				HouseSketch.UPSTAIRS:
					var up: Vector2i = HouseSketch.DOWN[p[3]]
					for i in 2:
						_nodes[Vector3i(at.x + up.x * i, at.y + up.y * i, UPPER)] = {"y": 0.0, "step": up, "index": i, "rise": HouseSketch.STOREY_HEIGHT}
	for area in _areas:
		for z in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				if not holes.has(Vector2i(x, z)) or ceilings.has(Vector2i(x, z)):
					_nodes[Vector3i(x, z, GROUND)] = {"y": 0.0}
	for node: Vector3i in _nodes:
		_links[node] = _joined(node)


func is_empty() -> bool:
	return _areas.is_empty()


# --- Lattice -------------------------------------------------------------------

## The lattice cell under a world point.
static func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori((pos.x + Level.TILE * 0.5) / HouseSketch.CELL), floori((pos.z + Level.TILE * 0.5) / HouseSketch.CELL))


## The middle of a lattice cell, at ground level.
static func centre(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * HouseSketch.CELL - Level.TILE * 0.5, 0.0, (cell.y + 0.5) * HouseSketch.CELL - Level.TILE * 0.5)


## Whether a world point lies on the floors (inside a plot or its margin).
func covers(pos: Vector3) -> bool:
	var c := cell_of(pos)
	for area in _areas:
		if area.has_point(c):
			return true
	return false


## How high the floor of `node` lies under the world point `pos` (x and z).
func height(node: Vector3i, pos: Vector3) -> float:
	var info: Dictionary = _nodes.get(node, {})
	if info.is_empty():
		return 0.0
	if not info.has("step"):
		return info.y
	# A ramp: from the outer edge of its first cell, over two cells.
	var step: Vector2i = info.step
	var flat := Vector3(step.x, 0, step.y)
	var index: int = info.index
	var first := centre(Vector2i(node.x, node.y)) - flat * (HouseSketch.CELL * (index + 0.5))
	var t := clampf((pos - first).dot(flat) / (HouseSketch.CELL * 2.0), 0.0, 1.0)
	return info.rise * t


## The node a body standing at `pos` is on: of the floors at its cell, the one
## nearest its feet. NONE when `pos` is off the floors.
const NONE := Vector3i(0, 0, 99)


func node_at(pos: Vector3) -> Vector3i:
	var c := cell_of(pos)
	var best := NONE
	var best_d := INF
	for s in STOREYS:
		var node := Vector3i(c.x, c.y, s)
		if _nodes.has(node):
			var d := absf(height(node, pos) - pos.y)
			if d < best_d:
				best_d = d
				best = node
	return best


## The built stairs a body at `pos` stands on: {"step": the way the flight leads (Vector2i),
## "rise": what it climbs that way, negative going down to a cellar}. Empty off the stairs.
func stairs_at(pos: Vector3) -> Dictionary:
	var node := node_at(pos)
	var info: Dictionary = _nodes.get(node, {})
	if not info.has("step"):
		return {}
	return {"step": info.step, "rise": info.rise}


## The storey a body at `pos` stands on (GROUND off the floors).
func storey_at(pos: Vector3) -> int:
	var node := node_at(pos)
	return GROUND if node == NONE else node.z


## Whether the floor of `pos` is open ground, a cellar or an upper floor that
## a companion can walk to from the ground: false in a pit without stairs.
func reaches_ground(pos: Vector3) -> bool:
	var node := node_at(pos)
	if node == NONE or node.z == GROUND:
		return true
	for n: Vector3i in _search(node):
		if n.z == GROUND:
			return true
	return false


## The middle of the open-ground cell nearest to `pos`: where a companion
## waits for a hero who went down a pit without stairs.
func nearest_ground(pos: Vector3) -> Vector3:
	var c := cell_of(pos)
	var best := Vector3(pos.x, 0.0, pos.z)
	var best_d := INF
	for node: Vector3i in _nodes:
		if node.z != GROUND:
			continue
		var d := Vector2i(node.x - c.x, node.y - c.y).length_squared()
		if d < best_d:
			best_d = d
			best = centre(Vector2i(node.x, node.y))
	return best


## Whether a companion at `from` can walk to `to` (off the floors counts as
## open ground).
func reachable(from: Vector3, to: Vector3) -> bool:
	var a := node_at(from)
	var b := node_at(to)
	if a == NONE:
		return reaches_ground(to)
	if b == NONE:
		return reaches_ground(from)
	return _search(a).has(b)


## The way a companion at `from` (on the floors) walks towards `to`:
## {"reached": whether it gets there, "points": the points to walk, with the
## height of the floor in y}. When it cannot get there, the points lead to
## the spot it can reach nearest to `to`: the rim of a pit, or the foot of a
## wall it cannot climb. Off the floors, `to` is reached from the nearest open
## ground (the points end with `to` itself).
func route(from: Vector3, to: Vector3) -> Dictionary:
	var start := node_at(from)
	if start == NONE:
		return {"reached": false, "points": []}
	var goal := node_at(to)
	var came := _search(start)
	var reached := came.has(goal)
	var end := goal
	if not reached:
		# The spot nearest `to` (ground only when `to` lies off the floors).
		var best := INF
		end = start
		var target := Vector2(to.x, to.z)
		for n: Vector3i in came:
			if goal == NONE and n.z != GROUND:
				continue
			var mid := centre(Vector2i(n.x, n.y))
			var d := Vector2(mid.x, mid.z).distance_squared_to(target) + absf(height(n, mid) - to.y) * 0.01
			if d < best - 0.001:
				best = d
				end = n
		reached = goal == NONE and end.z == GROUND
	var chain: Array[Vector3i] = []
	var at := end
	while at != start:
		chain.push_front(at)
		at = came[at]
	var points: Array = []
	var before := start
	for n in chain:
		var edge := (centre(Vector2i(before.x, before.y)) + centre(Vector2i(n.x, n.y))) * 0.5
		var ramp := n if _nodes[n].has("step") else before
		edge.y = height(ramp, edge)
		points.append(edge)
		var mid := centre(Vector2i(n.x, n.y))
		mid.y = height(n, mid)
		points.append(mid)
		before = n
	if end == goal:
		var last := Vector3(to.x, height(goal, to), to.z)
		if points.is_empty():
			points.append(last)
		else:
			points[points.size() - 1] = last
	elif goal == NONE and reached:
		points.append(Vector3(to.x, 0.0, to.z))
	return {"reached": reached, "points": points}


## The nodes a walk from `start` reaches, each with the node it came from.
func _search(start: Vector3i) -> Dictionary:
	var came := {start: start}
	var queue: Array[Vector3i] = [start]
	var i := 0
	while i < queue.size():
		var at := queue[i]
		i += 1
		for n: Vector3i in _links.get(at, []):
			if not came.has(n):
				came[n] = at
				queue.append(n)
	return came


## The nodes `node` joins: its neighbours on its storey, and up or down a ramp.
func _joined(node: Vector3i) -> Array:
	var out := []
	var info: Dictionary = _nodes[node]
	var c := Vector2i(node.x, node.y)
	if info.has("step"):
		var step: Vector2i = info.step
		var back := c - step
		var on := c + step
		out.append(Vector3i(back.x, back.y, GROUND if info.index == 0 else node.z))
		out.append(Vector3i(on.x, on.y, node.z))
		return out.filter(func(n): return _nodes.has(n))
	for d in STEPS:
		var next := c + d
		var same := Vector3i(next.x, next.y, node.z)
		if _nodes.has(same):
			var other: Dictionary = _nodes[same]
			# Onto a ramp only at its ends: the cell after it, from the floor below or above.
			if not other.has("step") or (other.index == 1 and other.step == -d and node.z != GROUND):
				out.append(same)
		if node.z == GROUND:
			for s in [CELLAR, UPPER]:
				var ramp := Vector3i(next.x, next.y, s)
				if _nodes.has(ramp) and _nodes[ramp].has("step") and _nodes[ramp].index == 0 and _nodes[ramp].step == d:
					out.append(ramp)
	return out
