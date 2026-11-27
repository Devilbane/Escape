class_name WallGenerator
extends RefCounted
## Makes a random climbing wall (see WallMap, used by the wall workshop's "Zufallswand" button).
## `fill` (0..1) is the share of all squares that become a hold, so 1.0 gives a wall with a hold on every
## square. One winding route from the foot to the summit is always laid first, so the wall can be climbed;
## when `fill` is smaller than that route needs, the route alone is what is left. The same seed gives the
## same wall.

##
## Special features (`FEATURES`): every one has a fixed `count` and a `chance`. The wall gets `count` of them, and
## the chance is rolled once per FEATURE_ROWS rows of its height for one more each (100 % adds one per roll). Danger
## zones are patches of loose stones, ice or wet moss, laid over the route first; gaps are cracks with a hold on
## each side to jump from; the rest are markers on holds a climber can reach.
##
## Options: {"fill": 0..1, "hardness": 0..1, "features": {key: {"count": int, "chance": 0..1}}}.

## One roll of a feature's chance per this many rows of the wall.
const FEATURE_ROWS := 6
## The features in the order the workshop lists them: group (German), key, kind (hazard, gap or marker), the
## surface for a hazard, and the largest fixed count.
const FEATURES := [
	{"group": "Gefahren", "key": "loose", "kind": "hazard", "surface": WallMap.LOOSE, "name": "Steinschlag-Zone", "max": 8},
	{"group": "Gefahren", "key": "ice", "kind": "hazard", "surface": WallMap.ICE, "name": "Eis", "max": 8},
	{"group": "Gefahren", "key": "wet", "kind": "hazard", "surface": WallMap.WET, "name": "Nasses Moos", "max": 8},
	{"group": "Gefahren", "key": "gap", "kind": "gap", "name": "Spalte", "max": 6},
	{"group": "Beute", "key": "edelweiss", "kind": "marker", "max": 10},
	{"group": "Beute", "key": "tar", "kind": "marker", "max": 10},
	{"group": "Beute", "key": "body", "kind": "marker", "max": 6},
	{"group": "Rast und Türen", "key": "camp", "kind": "marker", "max": 8},
	{"group": "Rast und Türen", "key": "door", "kind": "marker", "max": 4},
	{"group": "Rast und Türen", "key": "secret", "kind": "marker", "max": 4},
	{"group": "Ziele", "key": "garden", "kind": "marker", "max": 4},
	{"group": "Ziele", "key": "cave", "kind": "marker", "max": 4},
	{"group": "Ziele", "key": "nest", "kind": "marker", "max": 4},
	{"group": "Ziele", "key": "tomb", "kind": "marker", "max": 4},
]

## The hardest hold on the guaranteed route (the rest of the wall may be harder).
const ROUTE_MAX_MALUS := 5
## The chance that a hold off the route drops one of its directions (one-way slides, dead ends).
const DIR_DROP := 0.15


## A new wall of the base wall's size, name, level, summit and door, with `fill` of its squares as holds.
static func generate(base: WallMap, fill: float, seed_value: int) -> WallMap:
	return generate_with(base, {"fill": fill}, seed_value)


## The options a new random wall starts with: 60 % filled, medium hardness and no special features.
static func default_options() -> Dictionary:
	var features := {}
	for f: Dictionary in FEATURES:
		features[f.key] = {"count": 0, "chance": 0.0}
	return {"fill": 0.6, "hardness": 0.4, "features": features}


## The wall for `options` (see above); the same options and seed give the same wall.
static func generate_with(base: WallMap, options: Dictionary, seed_value: int) -> WallMap:
	var fill := float(options.get("fill", 0.6))
	var hardness := clampf(float(options.get("hardness", 0.4)), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := WallMap.blank(base.width, base.height)
	m.wall_name = base.wall_name
	m.level = base.level
	m.summit = base.summit
	m.door = base.door
	var route := _route(m, rng)
	var want := int(round(clampf(fill, 0.0, 1.0) * m.width * m.height))
	var cells := {}
	for cell: Vector2i in route:
		cells[cell] = true
	var rest: Array[Vector2i] = []
	for r in m.height:
		for c in m.width:
			if not cells.has(Vector2i(c, r)):
				rest.append(Vector2i(c, r))
	_shuffle(rest, rng)
	var extra := maxi(0, want - route.size())
	for i in mini(extra, rest.size()):
		cells[rest[i]] = false
	for cell: Vector2i in cells:
		var on_route: bool = cells[cell]
		var mal := int(pow(rng.randf(), lerpf(2.4, 0.9, hardness)) * (WallMap.MAX_MALUS + 1))
		if on_route:
			mal = mini(mal, ROUTE_MAX_MALUS)
		m.set_hold(cell.x, cell.y, mal, 0)
	var features: Dictionary = options.get("features", {})
	for f: Dictionary in FEATURES:
		if f.kind == "gap":
			for i in _amount(features, f.key, m, rng):
				_gap(m, cells, rng)
	_dirs(m, cells, rng)
	for f: Dictionary in FEATURES:
		if f.kind == "hazard":
			for i in _amount(features, f.key, m, rng):
				_patch(m, route, int(f.surface), String(f.key) == "loose", rng)
	var spots := _reachable(m)
	for f: Dictionary in FEATURES:
		if f.kind == "marker":
			for i in _amount(features, f.key, m, rng):
				_mark(m, spots, String(f.key), rng)
	return m


## The squares of a route from a random square of the bottom row to one of the top row: a step up in every
## row, with a sideways run of up to three squares before it.
static func _route(m: WallMap, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := rng.randi_range(0, m.width - 1)
	for r in range(m.height - 1, -1, -1):
		out.append(Vector2i(c, r))
		var run := rng.randi_range(0, 3)
		var step := 1 if rng.randf() < 0.5 else -1
		if c + step < 0 or c + step >= m.width:
			step = -step
		for i in run:
			var nc := c + step
			if nc < 0 or nc >= m.width:
				break
			c = nc
			out.append(Vector2i(c, r))
	return out


static func _shuffle(a: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t


## How many of a feature the wall gets: its fixed count plus a roll of its chance for every FEATURE_ROWS rows.
static func _amount(features: Dictionary, key: String, m: WallMap, rng: RandomNumberGenerator) -> int:
	var entry: Dictionary = features.get(key, {})
	var n := maxi(0, int(entry.get("count", 0)))
	var chance := clampf(float(entry.get("chance", 0.0)), 0.0, 1.0)
	for i in maxi(1, m.height / FEATURE_ROWS):
		if rng.randf() < chance:
			n += 1
	return n


## The directions out of every hold: towards each neighbouring hold, and towards a gap on its side. A hold off the
## route may drop a direction.
static func _dirs(m: WallMap, cells: Dictionary, rng: RandomNumberGenerator) -> void:
	for r in m.height:
		for c in m.width:
			if not m.has_hold(c, r):
				continue
			var on_route: bool = cells.get(Vector2i(c, r), false)
			var mask := 0
			for d: int in WallMap.DIR_ORDER:
				var to: Vector2i = Vector2i(c, r) + WallMap.DIR_STEP[d]
				var lands := m.has_hold(to.x, to.y)
				var jumps := (d == WallMap.LEFT or d == WallMap.RIGHT) and m.gap_at(to.x, to.y) >= 0
				if not lands and not jumps:
					continue
				if not on_route and not jumps and rng.randf() < DIR_DROP:
					continue
				mask |= d
			m.set_dirs(c, r, mask)


## A crack of 1-3 squares wide and 2-4 high away from the route, with a hold on each side of every row.
static func _gap(m: WallMap, cells: Dictionary, rng: RandomNumberGenerator) -> void:
	for attempt in 40:
		var w := rng.randi_range(1, 3)
		var h := rng.randi_range(2, 4)
		var rect := Rect2i(rng.randi_range(2, m.width - w - 2), rng.randi_range(2, m.height - h - 2), w, h)
		var hit := false
		for r in range(rect.position.y - 1, rect.end.y + 1):
			for c in range(rect.position.x - 1, rect.end.x + 1):
				if cells.get(Vector2i(c, r), false) or m.gap_at(c, r) >= 0:
					hit = true
		if hit:
			continue
		m.add_gap(rect)
		for r in range(rect.position.y, rect.end.y):
			for c in [rect.position.x - 1, rect.end.x]:
				m.set_hold(c, r, rng.randi_range(0, 4), 0)
				cells[Vector2i(c, r)] = false
		return


## A patch of a surface a square or two wide, on holds. Loose stones mostly sit on the route: that is the
## dangerous passage.
static func _patch(m: WallMap, route: Array[Vector2i], surface: int, on_route: bool, rng: RandomNumberGenerator) -> void:
	var holds: Array[Vector2i] = []
	for r in m.height:
		for c in m.width:
			if m.has_hold(c, r):
				holds.append(Vector2i(c, r))
	if holds.is_empty():
		return
	var centre: Vector2i = route[rng.randi_range(0, route.size() - 1)] if on_route and rng.randf() < 0.7 else holds[rng.randi_range(0, holds.size() - 1)]
	var radius := rng.randf_range(1.2, 2.6)
	for r in range(centre.y - 3, centre.y + 4):
		for c in range(centre.x - 3, centre.x + 4):
			if m.has_hold(c, r) and Vector2(c - centre.x, r - centre.y).length() <= radius:
				m.set_hazard(c, r, surface)


## The holds a climber can get to from the foot, by the steps and jumps of the wall.
static func _reachable(m: WallMap) -> Array[Vector2i]:
	var seen := {}
	var open: Array[Vector2i] = []
	for c in m.width:
		if m.is_start(c, m.height - 1):
			seen[Vector2i(c, m.height - 1)] = true
			open.append(Vector2i(c, m.height - 1))
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for mv: Dictionary in m.moves_from(cell.x, cell.y):
			var to: Vector2i = mv.to
			if not seen.has(to):
				seen[to] = true
				open.append(to)
	var out: Array[Vector2i] = []
	for r in m.height:
		for c in m.width:
			if seen.has(Vector2i(c, r)):
				out.append(Vector2i(c, r))
	return out


## Puts a marker on a reachable hold with no marker yet (not on the foot row).
static func _mark(m: WallMap, spots: Array[Vector2i], kind: String, rng: RandomNumberGenerator) -> void:
	for attempt in 30:
		var cell: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		if cell.y == m.height - 1 or m.marker_at(cell.x, cell.y) != "":
			continue
		m.set_marker(cell.x, cell.y, kind)
		return
