class_name HouseGround
extends RefCounted
## The ground a built house stands on (see HouseSketch), where no grass tufts,
## twigs, leaves or moss of the open air may lie (see SurfaceLife.set_built):
## every cell with a floor (a cellar ceiling), a roof or stairs up, every cell
## closed in by the house's own walls (doors and windows count as wall), and a
## thin strip along each wall so nothing pokes out of its foot. Garden walls
## do not count: the garden keeps its grass. Only built pieces count (and those
## marked to be taken down, which still stand); once a piece is erased the
## ground it covered gets its litter back.

## How far either side of a wall's line the ground is kept clear (metres).
const WALL_STRIP := 0.35
## The cell kinds that cover the ground under them: the cellar ceiling, a slab
## or roof on any storey, and the two cells of stairs up.
const COVERING := [HouseSketch.COVER, HouseSketch.SLAB, HouseSketch.SADDLE, HouseSketch.UPSTAIRS]


## Whether a piece stands (built, or built and marked to be taken down).
static func _stands(piece: Dictionary) -> bool:
	return piece.get("state", "") != HouseSketch.SKETCH


## The cells of `house` (in its own grid) that lie inside it.
static func inside_cells(house: HouseSketch) -> Dictionary:
	var out := {}
	var walls := {}
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if not _stands(piece):
			continue
		var p := HouseSketch.parts_of(key)
		if piece.kind in COVERING:
			if piece.kind == HouseSketch.UPSTAIRS:
				for c: Vector2i in HouseSketch.stairs_cells(p[1], p[2], p[3]).slice(0, 2):
					out[c] = true
			else:
				out[Vector2i(p[1], p[2])] = true
		elif piece.kind in HouseSketch.HOUSE_WALLS and p[0] == 0:
			walls[HouseSketch.key_of(p[1], p[2], p[3])] = true
	if walls.is_empty():
		return out
	# What the walls close in: every cell that cannot be reached from outside the
	# plot without crossing one of them.
	var n := house.nodes()
	var start := Vector2i(-1, -1)
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for step: Vector2i in HouseSketch.DOWN.values():
			var next := c + step
			if next.x < -1 or next.y < -1 or next.x > n.x or next.y > n.y or seen.has(next):
				continue
			var e := HouseSketch.edge_between(c, next)
			if walls.has(HouseSketch.key_of(e[0], e[1], e[2])):
				continue
			seen[next] = true
			todo.append(next)
	for y in n.y:
		for x in n.x:
			if not seen.has(Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out


## The ground of `house` kept clear of litter, as Rect2 in world x/z: one per
## inside cell and one strip per standing house wall.
static func rects(house: HouseSketch) -> Array:
	var out := []
	for c: Vector2i in inside_cells(house):
		var at := house.node_world(c.x, c.y)
		out.append(Rect2(at.x, at.z, HouseSketch.CELL, HouseSketch.CELL))
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if not _stands(piece) or not piece.kind in HouseSketch.HOUSE_WALLS:
			continue
		var p := HouseSketch.parts_of(key)
		if p[0] != 0:
			continue
		var a := house.node_world(p[1], p[2])
		if p[3] == HouseSketch.ORIENT_X:
			out.append(Rect2(a.x - WALL_STRIP, a.z - WALL_STRIP, HouseSketch.CELL + WALL_STRIP * 2, WALL_STRIP * 2))
		else:
			out.append(Rect2(a.x - WALL_STRIP, a.z - WALL_STRIP, WALL_STRIP * 2, HouseSketch.CELL + WALL_STRIP * 2))
	return out
