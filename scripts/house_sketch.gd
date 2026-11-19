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
			var after := {"kind": before.kind, "state": DEMOLISH}
			pieces[key] = after
			step.append({"key": key, "before": before, "after": after})
		elif before.state == DEMOLISH:
			var kept := {"kind": before.kind, "state": BUILT}
			pieces[key] = kept
			step.append({"key": key, "before": before, "after": kept})
	_push(step)
	return step.size()


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
			for id in COST[pieces[key].kind]:
				need[id] = int(need.get(id, 0)) + int(COST[pieces[key].kind][id])
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
			for id in COST[pieces[key].kind]:
				need[id] = int(need.get(id, 0)) + int(COST[pieces[key].kind][id])
	return need


func deposit(id: String, count: int) -> void:
	if MATERIALS.has(id) and count > 0:
		stock[id] = int(stock.get(id, 0)) + count


func _affordable(kind: String) -> bool:
	for id in COST[kind]:
		if int(stock.get(id, 0)) < int(COST[kind][id]):
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
			for id in COST[kind]:
				stock[id] = int(stock.get(id, 0)) + int(COST[kind][id])
			pieces.erase(key)
			var p := parts_of(key)
			result = {"edge": [p[1], p[2], p[3]], "kind": kind, "did": "demolished"}
			break
	if result.is_empty():
		var chosen := ""
		for kind in KINDS:
			for key in pieces:
				if pieces[key].state == SKETCH and pieces[key].kind == kind and _affordable(kind):
					chosen = key
					break
			if chosen != "":
				break
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
		for id in COST[kind]:
			stock[id] = int(stock.get(id, 0)) - int(COST[kind][id])
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
				if p is Array and p.size() == 2 and KINDS.has(str(p[0])):
					var parts := parts_of(str(key))
					if s.in_plot(parts[1], parts[2], parts[3]):
						s.pieces[str(key)] = {"kind": str(p[0]), "state": str(p[1])}
	return s


## Writes the plan into the books.
func save(hero: String) -> void:
	_load()
	var raw := {}
	for key in pieces:
		raw[key] = [pieces[key].kind, pieces[key].state]
	_books[Homes.deed_name(hero)] = {"pieces": raw, "ordered": ordered, "stock": stock}
	Storage.write(RECORD, {"houses": _books})
