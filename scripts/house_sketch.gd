class_name HouseSketch
extends RefCounted
## The plan of a hero's house on their plot (see Plots): which pieces of wall,
## door and window stand where. The data is separate from how it is drawn
## (see HouseSketcher), so undo, redo and saving stay simple.
##
## The house is drawn on a grid laid over the plot: every map tile (4 m) is
## two grid cells (CELL, 2 m) wide. A piece lies on one cell edge, between two
## grid nodes: it starts at node (x, y) and runs east (ORIENT_X) or south
## (ORIENT_Y). A wall piece can be turned into a door or a window; a door
## or window always sits in a wall.
##
## Every piece is either a sketch (planned, not built yet) or built (the
## character has built it, see the construction phase). The house can be much
## smaller than the plot: pieces may lie anywhere inside it.
##
## Pieces are kept in Storage apart from the saved games, like the plot deeds.

const RECORD := "houses"
const CELL := 2.0
const CELLS_PER_TILE := 2
const WALL := "wall"
const DOOR := "door"
const WINDOW := "window"
const KINDS := [WALL, DOOR, WINDOW]
## The cellar (storey CELLAR_STOREY): a "dig" piece is one grid cell dug out of
## the ground, DEPTH metres deep; a "stairs" piece is a ramp of two cells from the
## ground down to a dug cell. Cell pieces are keyed by the cell (x, y) and the
## orient letter CELL for a dug cell, or the direction the stairs go down.
const DIG := "dig"
const STAIRS := "stairs"
const CELLAR_KINDS := [DIG, STAIRS]
## Above ground. A "slab" is the floor between two storeys, or a flat roof
## you can walk on, over one grid cell; it belongs to the storey below it (key
## storey 0: it is the ceiling of the ground floor and the floor of the upper
## storey). A "saddle" is a pitched roof over one cell, its ridge running east
## to west (orient "rx") or north to south ("ry"). "upstairs" is a ramp of two
## cells from the ground up to a slab cell, keyed like the cellar stairs.
const SLAB := "slab"
const SADDLE := "saddle"
const UPSTAIRS := "upstairs"
const CELL_KINDS := [DIG, STAIRS, SLAB, SADDLE, UPSTAIRS]
const MAX_STOREY := 1
## From the floor of a storey to the floor of the next, and how thick a slab is.
## 3.2 m is four layers of stone blocks, so blocks stack evenly on a roof.
const STOREY_HEIGHT := 3.2
const SLAB_THICK := 0.6
const ROOF_RISE := 1.6
const SADDLE_ORIENTS := ["rx", "ry"]
const CELLAR_STOREY := -1
const CELL_ORIENT := "c"
const DEPTH := 2.6
## Stairs go down towards east, west, north or south: letter -> step in cells.
const DOWN := {"e": Vector2i(1, 0), "w": Vector2i(-1, 0), "n": Vector2i(0, -1), "s": Vector2i(0, 1)}
## Building order: dig first, then stairs, then walls before doors and windows.
const BUILD_ORDER := [DIG, STAIRS, WALL, DOOR, WINDOW, SLAB, UPSTAIRS, SADDLE]
## What covers the floor and the walls of dug cells: "" is the bare earth.
const SURFACES := ["", "stone", "wood"]
const SURFACE_COST := {"": {}, "stone": {"steinblock": 1}, "wood": {"bauholz": 1}}
const SKETCH := "sketch"
const BUILT := "built"
## A built piece the hero has marked to be taken down (see erase).
const DEMOLISH := "demolish"
## What a piece costs in building materials, and how much of it comes back
## when it is taken down again.
const STONE := "steinblock"
const TIMBER := "bauholz"
const COST := {
	WALL: {STONE: 2},
	DOOR: {STONE: 1, TIMBER: 2},
	WINDOW: {STONE: 1, TIMBER: 1},
	# Digging costs work, not material; the stairs are timber, the surfaces
	# of a dug cell are added by cost_of.
	DIG: {},
	STAIRS: {TIMBER: 2},
	SLAB: {TIMBER: 1},
	SADDLE: {TIMBER: 2},
	UPSTAIRS: {TIMBER: 3},
}
const MATERIALS := [STONE, TIMBER]
const ORIENT_X := "x"
const ORIENT_Y := "y"
## How many edits undo remembers.
const UNDO_LIMIT := 50

static var _books := {}
static var _loaded := false

## The plot, in map tiles.
var plot := Rect2i()
## key -> {"kind": WALL / DOOR / WINDOW, "state": SKETCH / BUILT}
var pieces := {}
## The hero told the character to build (see build_next).
var ordered := false
## The materials delivered to the plot (id -> count), used up as pieces are built.
var stock := {}
## What the next dug cells get on their floor and walls (see SURFACES).
var floor_surface := ""
var wall_surface := ""
var _undo: Array = []
var _redo: Array = []


## The key of the piece on the edge that starts at node (x, y).
static func key_of(x: int, y: int, orient: String, storey := 0) -> String:
	return "%d:%d:%d:%s" % [storey, x, y, orient]


## Splits a key into [storey, x, y, orient].
static func parts_of(key: String) -> Array:
	var p := key.split(":")
	return [int(p[0]), int(p[1]), int(p[2]), p[3]]


## The grid nodes of a plot: nodes run from 0 to this many in x and y.
func nodes() -> Vector2i:
	return plot.size * CELLS_PER_TILE


## The world position of node (x, y), at ground level.
func node_world(x: int, y: int) -> Vector3:
	return Vector3((plot.position.x - 0.5) * Level.TILE + x * CELL, 0.0, (plot.position.y - 0.5) * Level.TILE + y * CELL)


## The node nearest to a world point, clamped into the plot.
func node_at(point: Vector3) -> Vector2i:
	var origin := node_world(0, 0)
	var n := nodes()
	return Vector2i(clampi(roundi((point.x - origin.x) / CELL), 0, n.x), clampi(roundi((point.z - origin.z) / CELL), 0, n.y))


## Whether an edge lies inside the plot.
func in_plot(x: int, y: int, orient: String) -> bool:
	var n := nodes()
	if orient == ORIENT_X:
		return x >= 0 and x < n.x and y >= 0 and y <= n.y
	return x >= 0 and x <= n.x and y >= 0 and y < n.y


## The edge nearest to a world point that is at most `reach` metres away, as
## [x, y, orient], or [] when none is.
func edge_near(point: Vector3, reach := CELL * 0.6) -> Array:
	var origin := node_world(0, 0)
	var fx := (point.x - origin.x) / CELL
	var fy := (point.z - origin.z) / CELL
	var best := []
	var best_d := reach / CELL
	var x0 := floori(fx)
	var y0 := floori(fy)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x := x0 + dx
			var y := y0 + dy
			if in_plot(x, y, ORIENT_X):
				var d := _distance_to_segment(Vector2(fx, fy), Vector2(x, y), Vector2(x + 1, y))
				if d < best_d:
					best_d = d
					best = [x, y, ORIENT_X]
			if in_plot(x, y, ORIENT_Y):
				var d := _distance_to_segment(Vector2(fx, fy), Vector2(x, y), Vector2(x, y + 1))
				if d < best_d:
					best_d = d
					best = [x, y, ORIENT_Y]
	return best


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The straight run of edges from node `a` to node `b`: along the longer
## direction, as [x, y, orient] edges. Empty when both are the same node.
func run_between(a: Vector2i, b: Vector2i) -> Array:
	var d := b - a
	var out := []
	if d == Vector2i.ZERO:
		return out
	if absi(d.x) >= absi(d.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			out.append([x, a.y, ORIENT_X])
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			out.append([a.x, y, ORIENT_Y])
	return out


func piece(x: int, y: int, orient: String, storey := 0) -> Dictionary:
	return pieces.get(key_of(x, y, orient, storey), {})


func has_piece(x: int, y: int, orient: String, storey := 0) -> bool:
	return pieces.has(key_of(x, y, orient, storey))


## Why a piece cannot be put on an edge, or "" when it can: "outside", "kind",
## "built" (a built piece is changed by sketching its removal, see the
## construction phase) or "needs wall" (a door or window needs a wall).
func problem(x: int, y: int, orient: String, kind: String, storey := 0) -> String:
	if not in_plot(x, y, orient):
		return "outside"
	if not KINDS.has(kind):
		return "kind"
	if storey < 0 or storey > MAX_STOREY:
		return "storey"
	var had := piece(x, y, orient, storey)
	if had.get("state", SKETCH) != SKETCH:
		return "built"
	if kind != WALL and had.is_empty():
		return "needs wall"
	return ""


## Sketches pieces on edges as one step (undo takes them back together).
## `edges` are [x, y, orient]. Returns how many changed.
func sketch(edges: Array, kind: String, storey := 0) -> int:
	var step := []
	for e in edges:
		if problem(e[0], e[1], e[2], kind, storey) != "":
			continue
		var key := key_of(e[0], e[1], e[2], storey)
		var before = pieces.get(key, null)
		if before != null and before.kind == kind:
			continue
		var after := {"kind": kind, "state": SKETCH}
		pieces[key] = after
		step.append({"key": key, "before": before, "after": after})
	_push(step)
	return step.size()


## Takes sketched pieces off their edges as one step. A built piece is marked
## to be taken down instead: the character does that when ordered, and the
## materials come back (see build_next). Erasing a piece marked for demolition
## keeps it. Returns how many changed.
func erase(edges: Array, storey := 0) -> int:
	var step := []
	for e in edges:
		var key := key_of(e[0], e[1], e[2], storey)
		var before = pieces.get(key, null)
		if before == null:
			continue
		if before.state == SKETCH:
			pieces.erase(key)
			step.append({"key": key, "before": before, "after": null})
		elif before.state == BUILT:
			var after: Dictionary = before.duplicate()
			after.state = DEMOLISH
			pieces[key] = after
			step.append({"key": key, "before": before, "after": after})
		elif before.state == DEMOLISH:
			var kept: Dictionary = before.duplicate()
			kept.state = BUILT
			pieces[key] = kept
			step.append({"key": key, "before": before, "after": kept})
	_push(step)
	return step.size()


# --- The cellar ----------------------------------------------------------------

## Whether a grid cell (x, y) lies inside the plot.
func cell_in_plot(x: int, y: int) -> bool:
	var n := nodes()
	return x >= 0 and y >= 0 and x < n.x and y < n.y


## The grid cell under a world point, clamped into the plot.
func cell_at(point: Vector3) -> Vector2i:
	var origin := node_world(0, 0)
	var n := nodes()
	return Vector2i(clampi(floori((point.x - origin.x) / CELL), 0, n.x - 1), clampi(floori((point.z - origin.z) / CELL), 0, n.y - 1))


## The world position of a cell's middle, at ground level.
func cell_world(x: int, y: int) -> Vector3:
	return node_world(x, y) + Vector3(CELL * 0.5, 0, CELL * 0.5)


## The cells a rectangle between two cells covers, as [x, y, CELL_ORIENT].
func cells_between(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append([x, y, CELL_ORIENT])
	return out


## The cells a stairs piece covers: its top and the one below it, and the dug
## cell it leads down to (the third).
static func stairs_cells(x: int, y: int, dir: String) -> Array:
	var step: Vector2i = DOWN[dir]
	return [Vector2i(x, y), Vector2i(x, y) + step, Vector2i(x, y) + step * 2]


## The piece that holds a cell open (a dug cell or one of a stairs' two
## cells), as its key, or "" when the ground is whole there.
func hole_key(x: int, y: int) -> String:
	var dug := key_of(x, y, CELL_ORIENT, CELLAR_STOREY)
	if pieces.has(dug):
		return dug
	for dir in DOWN:
		for back in 2:
			var c: Vector2i = Vector2i(x, y) - (DOWN[dir] as Vector2i) * back
			var key := key_of(c.x, c.y, dir, CELLAR_STOREY)
			if pieces.has(key):
				return key
	return ""


## Whether a cell is dug out and the digging is done.
func is_dug(x: int, y: int, built_only := false) -> bool:
	var p: Dictionary = pieces.get(key_of(x, y, CELL_ORIENT, CELLAR_STOREY), {})
	return not p.is_empty() and (not built_only or p.state != SKETCH)


## The direction a stairs piece at cell (x, y) can go down, or "" when none
## can: its two cells must be free ground inside the plot and the cell after
## them must be dug.
func stairs_dir(x: int, y: int) -> String:
	for dir in DOWN:
		if problem_stairs(x, y, dir) == "":
			return dir
	return ""


## Why stairs cannot go down from cell (x, y) in a direction, or "".
func problem_stairs(x: int, y: int, dir: String) -> String:
	var cells := stairs_cells(x, y, dir)
	for i in 2:
		if not cell_in_plot(cells[i].x, cells[i].y):
			return "outside"
		if hole_key(cells[i].x, cells[i].y) != "":
			return "taken"
	if not cell_in_plot(cells[2].x, cells[2].y) or not is_dug(cells[2].x, cells[2].y):
		return "no cellar"
	return ""


## Why a cell cannot be dug, or "".
func problem_dig(x: int, y: int) -> String:
	if not cell_in_plot(x, y):
		return "outside"
	if hole_key(x, y) != "":
		return "taken"
	return ""


## Sketches dug cells (`cells` are [x, y, CELL_ORIENT]) with the current
## surfaces, as one step. Returns how many changed.
func sketch_dig(cells: Array) -> int:
	var step := []
	for c in cells:
		if problem_dig(c[0], c[1]) != "":
			continue
		var key := key_of(c[0], c[1], CELL_ORIENT, CELLAR_STOREY)
		var after := {"kind": DIG, "state": SKETCH, "floor": floor_surface, "wall": wall_surface}
		pieces[key] = after
		step.append({"key": key, "before": null, "after": after})
	_push(step)
	return step.size()


## Sketches a stairs piece from cell (x, y) going `dir`; returns whether it did.
func sketch_stairs(x: int, y: int, dir: String) -> bool:
	if problem_stairs(x, y, dir) != "":
		return false
	var key := key_of(x, y, dir, CELLAR_STOREY)
	var after := {"kind": STAIRS, "state": SKETCH}
	pieces[key] = after
	_push([{"key": key, "before": null, "after": after}])
	return true


## The stairs (a key) that lead down to a dug cell, or "".
func stairs_to(x: int, y: int) -> String:
	for key in pieces:
		var p := parts_of(key)
		if p[0] == CELLAR_STOREY and pieces[key].kind == STAIRS:
			var end: Vector2i = stairs_cells(p[1], p[2], p[3])[2]
			if end == Vector2i(x, y):
				return key
	return ""


## Takes back or marks for filling in the cellar piece at a cell (a dug cell
## or either cell of stairs). A dug cell the stairs lead down to stays until
## the stairs are gone. Returns "" when something changed, or why not:
## "empty" or "needed".
func erase_cell(x: int, y: int) -> String:
	var key := hole_key(x, y)
	if key == "":
		return "empty"
	var p := parts_of(key)
	if pieces[key].kind == DIG and stairs_to(x, y) != "":
		return "needed"
	erase([[p[1], p[2], p[3]]], CELLAR_STOREY)
	return ""


## The order pieces are built in: the cellar first, then storey by storey,
## each with its walls before doors and windows, then slab, stairs and roof.
func priority(key: String) -> int:
	var p := parts_of(key)
	return int(p[0]) * 100 + BUILD_ORDER.find(pieces[key].kind)


## Stairs are built only once the cell they lead to is.
func _can_build(key: String) -> bool:
	var p := parts_of(key)
	var end: Vector2i = stairs_cells(p[1], p[2], p[3])[2] if DOWN.has(p[3]) else Vector2i.ZERO
	if pieces[key].kind == STAIRS:
		return is_dug(end.x, end.y, true)
	if pieces[key].kind == UPSTAIRS:
		return not slab_at(end.x, end.y, p[0]).is_empty() and slab_at(end.x, end.y, p[0]).state != SKETCH
	return true


# --- Floors, roofs and the stairs up -----------------------------------------------

func slab_at(x: int, y: int, storey: int) -> Dictionary:
	return pieces.get(key_of(x, y, CELL_ORIENT, storey), {})


## The key of the slab or saddle over a cell of a storey, or "".
func roof_key(x: int, y: int, storey: int) -> String:
	for orient in [CELL_ORIENT] + SADDLE_ORIENTS:
		var key := key_of(x, y, orient, storey)
		if pieces.has(key):
			return key
	return ""


## The key of the stairs up that hold a ground cell open, or "".
func up_key(x: int, y: int) -> String:
	for dir in DOWN:
		for back in 2:
			var c: Vector2i = Vector2i(x, y) - (DOWN[dir] as Vector2i) * back
			var key := key_of(c.x, c.y, dir, 0)
			if pieces.has(key) and pieces[key].kind == UPSTAIRS:
				return key
	return ""


## Why a slab or saddle cannot go over a cell of a storey, or "".
func problem_roof(x: int, y: int, storey: int) -> String:
	if not cell_in_plot(x, y):
		return "outside"
	if storey < 0 or storey > MAX_STOREY:
		return "storey"
	if roof_key(x, y, storey) != "":
		return "taken"
	if storey == 0 and up_key(x, y) != "":
		return "taken"
	return ""


## Sketches slabs or saddles over cells (`cells` are [x, y, ...]) as one step.
## `orient` is CELL_ORIENT for a slab, or a ridge direction of SADDLE_ORIENTS.
func sketch_roof(cells: Array, kind: String, storey: int, orient := CELL_ORIENT) -> int:
	var step := []
	for c in cells:
		if problem_roof(c[0], c[1], storey) != "":
			continue
		var key := key_of(c[0], c[1], orient, storey)
		var after := {"kind": kind, "state": SKETCH}
		pieces[key] = after
		step.append({"key": key, "before": null, "after": after})
	_push(step)
	return step.size()


## Why stairs up cannot start at cell (x, y) going `dir`, or "": two free
## ground cells and a slab after them (sketched or built).
func problem_upstairs(x: int, y: int, dir: String) -> String:
	var cells := stairs_cells(x, y, dir)
	for i in 2:
		var c: Vector2i = cells[i]
		if not cell_in_plot(c.x, c.y):
			return "outside"
		if hole_key(c.x, c.y) != "" or up_key(c.x, c.y) != "" or roof_key(c.x, c.y, 0) != "":
			return "taken"
	var end: Vector2i = cells[2]
	if not cell_in_plot(end.x, end.y) or slab_at(end.x, end.y, 0).get("kind", "") != SLAB:
		return "no slab"
	return ""


func upstairs_dir(x: int, y: int) -> String:
	for dir in DOWN:
		if problem_upstairs(x, y, dir) == "":
			return dir
	return ""


func sketch_upstairs(x: int, y: int, dir: String) -> bool:
	if problem_upstairs(x, y, dir) != "":
		return false
	var key := key_of(x, y, dir, 0)
	var after := {"kind": UPSTAIRS, "state": SKETCH}
	pieces[key] = after
	_push([{"key": key, "before": null, "after": after}])
	return true


## Takes back or marks for removal the slab, saddle or stairs up at a cell of
## a storey (the stairs cover two cells). A slab the stairs lead up to stays
## until the stairs are gone. Returns "" when something changed or why not:
## "empty" or "needed".
func erase_above(x: int, y: int, storey: int) -> String:
	var key := roof_key(x, y, storey)
	if key == "" and storey == 0:
		key = up_key(x, y)
	if key == "":
		return "empty"
	var p := parts_of(key)
	if pieces[key].kind == SLAB:
		for other in pieces:
			var q := parts_of(other)
			if pieces[other].kind == UPSTAIRS and q[0] == storey:
				var end: Vector2i = stairs_cells(q[1], q[2], q[3])[2]
				if end == Vector2i(x, y):
					return "needed"
	erase([[p[1], p[2], p[3]]], p[0])
	return ""


func _push(step: Array) -> void:
	if step.is_empty():
		return
	_undo.append(step)
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var step: Array = _undo.pop_back()
	for i in range(step.size() - 1, -1, -1):
		_put(step[i].key, step[i].before)
	_redo.append(step)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Array = _redo.pop_back()
	for change in step:
		_put(change.key, change.after)
	_undo.append(step)
	return true


func _put(key: String, value) -> void:
	if value == null:
		pieces.erase(key)
	else:
		pieces[key] = value


## How many pieces of a kind, in a state (any state when empty).
func count(kind: String, state := "") -> int:
	var n := 0
	for key in pieces:
		if pieces[key].kind == kind and (state == "" or pieces[key].state == state):
			n += 1
	return n


func is_empty() -> bool:
	return pieces.is_empty()


## The pieces still to do: sketches to build and built pieces to take down.
func open_pieces() -> int:
	var open := 0
	for key in pieces:
		if pieces[key].state != BUILT:
			open += 1
	return open


## "plan" while there is something to sketch and nothing is ordered, "build"
## from the order until the last piece is done, "done" when everything
## sketched stands. A new sketch after "done" is the next "plan".
func stage() -> String:
	if open_pieces() > 0:
		return "build" if ordered else "plan"
	return "done" if not pieces.is_empty() else "plan"


## The materials the open sketches still need beyond the stock: id -> missing.
func missing() -> Dictionary:
	var need := {}
	for key in pieces:
		if pieces[key].state == SKETCH:
			var cost := cost_of(pieces[key])
			for id in cost:
				need[id] = int(need.get(id, 0)) + int(cost[id])
	var out := {}
	for id in need:
		var short: int = int(need[id]) - int(stock.get(id, 0))
		if short > 0:
			out[id] = short
	return out


## What the open sketches need in all: id -> count.
func needs() -> Dictionary:
	var need := {}
	for key in pieces:
		if pieces[key].state == SKETCH:
			var cost := cost_of(pieces[key])
			for id in cost:
				need[id] = int(need.get(id, 0)) + int(cost[id])
	return need


func deposit(id: String, count: int) -> void:
	if MATERIALS.has(id) and count > 0:
		stock[id] = int(stock.get(id, 0)) + count


## What one piece costs in materials: its kind's cost, and for a dug cell its
## floor and wall surfaces (a piece without them costs the kind's cost only).
static func cost_of(p: Dictionary) -> Dictionary:
	var out: Dictionary = COST[p.kind].duplicate()
	if p.kind == DIG:
		for surface in [p.get("floor", ""), p.get("wall", "")]:
			var extra: Dictionary = SURFACE_COST.get(surface, {})
			for id in extra:
				out[id] = int(out.get(id, 0)) + int(extra[id])
	return out


func _affordable(p: Dictionary) -> bool:
	var cost := cost_of(p)
	for id in cost:
		if int(stock.get(id, 0)) < int(cost[id]):
			return false
	return true


## The order to build: from now on the character works through the open pieces.
func order() -> bool:
	if open_pieces() == 0:
		return false
	ordered = true
	return true


## The character does one piece of work: takes down a piece marked for
## demolition (its materials go back into the stock) or builds the next
## sketch the stock pays for, walls before doors and windows. Returns
## {"edge": [x, y, orient], "kind": ..., "did": "built" / "demolished"}, or
## {"why": "materials"} when only sketches the stock cannot pay for are left,
## or {} when there is nothing to do (the order ends with the last piece).
func build_next() -> Dictionary:
	if not ordered:
		return {}
	var result := {}
	for key in pieces:
		if pieces[key].state == DEMOLISH:
			var kind: String = pieces[key].kind
			var refund := cost_of(pieces[key])
			for id in refund:
				stock[id] = int(stock.get(id, 0)) + int(refund[id])
			pieces.erase(key)
			var p := parts_of(key)
			result = {"edge": [p[1], p[2], p[3]], "kind": kind, "did": "demolished"}
			break
	if result.is_empty():
		var chosen := ""
		var best := 1 << 30
		for key in pieces:
			if pieces[key].state == SKETCH and _affordable(pieces[key]) and _can_build(key) and priority(key) < best:
				best = priority(key)
				chosen = key
		if chosen == "":
			var waiting := false
			for key in pieces:
				if pieces[key].state == SKETCH:
					waiting = true
			if not waiting:
				ordered = false
				return {}
			return {"why": "materials"}
		var kind: String = pieces[chosen].kind
		var price := cost_of(pieces[chosen])
		for id in price:
			stock[id] = int(stock.get(id, 0)) - int(price[id])
		pieces[chosen].state = BUILT
		var p := parts_of(chosen)
		result = {"edge": [p[1], p[2], p[3]], "kind": kind, "did": "built"}
	# What was done cannot be undone with the plan's undo.
	_undo.clear()
	_redo.clear()
	if open_pieces() == 0:
		ordered = false
	return result


# --- The books ----------------------------------------------------------------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_books = {}
	var parsed = Storage.read(RECORD)
	if parsed is Dictionary and parsed.get("houses", {}) is Dictionary:
		_books = parsed.houses


static func reload() -> void:
	_loaded = false


## The hero's house on their plot, read from the books (an empty plan when
## they have none yet).
static func of(hero: String, on_plot: Rect2i) -> HouseSketch:
	_load()
	var s := HouseSketch.new()
	s.plot = on_plot
	var saved = _books.get(Homes.deed_name(hero), {})
	if saved is Dictionary:
		s.ordered = bool(saved.get("ordered", false))
		var raw_stock = saved.get("stock", {})
		if raw_stock is Dictionary:
			for id in raw_stock:
				if MATERIALS.has(str(id)):
					s.stock[str(id)] = maxi(0, int(raw_stock[id]))
		var raw = saved.get("pieces", {})
		if raw is Dictionary:
			for key in raw:
				var p = raw[key]
				if p is Array and p.size() >= 2:
					var parts := parts_of(str(key))
					if KINDS.has(str(p[0])) and p.size() == 2 and parts[0] >= 0 and parts[0] <= MAX_STOREY and s.in_plot(parts[1], parts[2], parts[3]):
						s.pieces[str(key)] = {"kind": str(p[0]), "state": str(p[1])}
					elif str(p[0]) == DIG and p.size() == 4 and parts[0] == CELLAR_STOREY and s.cell_in_plot(parts[1], parts[2]):
						s.pieces[str(key)] = {"kind": DIG, "state": str(p[1]),
								"floor": str(p[2]) if SURFACES.has(str(p[2])) else "", "wall": str(p[3]) if SURFACES.has(str(p[3])) else ""}
					elif str(p[0]) == STAIRS and p.size() == 2 and DOWN.has(parts[3]) and parts[0] == CELLAR_STOREY \
							and s.cell_in_plot(parts[1], parts[2]):
						s.pieces[str(key)] = {"kind": STAIRS, "state": str(p[1])}
					elif p.size() == 2 and s.cell_in_plot(parts[1], parts[2]) and parts[0] >= 0 and parts[0] <= MAX_STOREY \
							and ((str(p[0]) == SLAB and parts[3] == CELL_ORIENT) or (str(p[0]) == SADDLE and SADDLE_ORIENTS.has(parts[3])) \
							or (str(p[0]) == UPSTAIRS and DOWN.has(parts[3]) and parts[0] == 0)):
						s.pieces[str(key)] = {"kind": str(p[0]), "state": str(p[1])}
		s.floor_surface = str(saved.get("floor", ""))
		s.wall_surface = str(saved.get("wall", ""))
		if not SURFACES.has(s.floor_surface):
			s.floor_surface = ""
		if not SURFACES.has(s.wall_surface):
			s.wall_surface = ""
	return s


## Writes the plan into the books.
func save(hero: String) -> void:
	_load()
	var raw := {}
	for key in pieces:
		var p: Dictionary = pieces[key]
		raw[key] = [p.kind, p.state, p.get("floor", ""), p.get("wall", "")] if p.kind == DIG else [p.kind, p.state]
	_books[Homes.deed_name(hero)] = {"pieces": raw, "ordered": ordered, "stock": stock, "floor": floor_surface, "wall": wall_surface}
	Storage.write(RECORD, {"houses": _books})
