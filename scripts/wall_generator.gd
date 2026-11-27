class_name WallGenerator
extends RefCounted
## Makes a random climbing wall (see WallMap, used by the wall workshop's "Zufallswand" button).
## `fill` (0..1) is the share of all squares that become a hold, so 1.0 gives a wall with a hold on every
## square. One winding route from the foot to the summit is always laid first, so the wall can be climbed;
## when `fill` is smaller than that route needs, the route alone is what is left. The same seed gives the
## same wall.

## The hardest hold on the guaranteed route (the rest of the wall may be harder).
const ROUTE_MAX_MALUS := 5
## The chance that a hold off the route drops one of its directions (one-way slides, dead ends).
const DIR_DROP := 0.15


## A new wall of the base wall's size, name, level, summit and door, with `fill` of its squares as holds.
static func generate(base: WallMap, fill: float, seed_value: int) -> WallMap:
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
		var mal := int(pow(rng.randf(), 1.6) * (WallMap.MAX_MALUS + 1))
		if on_route:
			mal = mini(mal, ROUTE_MAX_MALUS)
		m.set_hold(cell.x, cell.y, mal, 0)
	for cell: Vector2i in cells:
		var mask := 0
		for d: int in WallMap.DIR_ORDER:
			var to: Vector2i = cell + WallMap.DIR_STEP[d]
			if not m.has_hold(to.x, to.y):
				continue
			if not cells[cell] and rng.randf() < DIR_DROP:
				continue
			mask |= d
		m.set_dirs(cell.x, cell.y, mask)
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
