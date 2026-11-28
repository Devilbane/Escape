class_name SnowSweep
extends RefCounted
## The street sweeper (see StreetSweeper) sweeps the snow off the village's walkways with a birch broom (a besom).
## In autumn the same broom sweeps the fallen leaves (see LeafSweep).
##
## In winter, while snow lies and no more is falling, he leaves his spot twice a day (SHIFTS, kept clear
## of the meals and of the morning in the temple), walks out along a footpath of the village and sweeps it on
## the way out and on the way back: slowly, the broom swishing from side to side ahead of him and
## kicking up soft puffs of snow dust (see SweepDust). What he leaves is a narrow, uneven footpath bare
## of snow, with a few small patches left standing.
##
## The swept ground is remembered in one fine mask (a pixel every STEP metres, see snow_cover.gdshader):
## red is the amount of snowfall (hours, plus one) when the pixel was last swept, green how close it
## lies to the middle of the broom's stroke. It outlives the world (a trip into a house does not undo
## it) and slowly fills in again while it snows (REFILL_HOURS of snowfall bring a strip back to white); when
## the snow melts away the mask is cleared.

const ROLE := StreetSweeper.ROLE
## The hours of the day (see DayNight) he sweeps in: after the morning, and an afternoon stretch.
## The meals call the village together from 11 (see TownMeals), and the morning belongs to the temple.
const SHIFTS := [[7.9, 11.0], [13.0, 18.0]]
## Snow must lie at least this thick (0 to 1, see SnowCover) to be worth sweeping.
const SNOW_MIN := 0.35
## How far from his spot he sweeps (tiles), and the shortest and longest footpath he takes on (tiles).
const REACH_TILES := 14
const RUN_MIN := 3
const RUN_MAX := 12
## How fast he walks while he sweeps (metres per second).
const PACE := 1.1
## Metres between the points of his route.
const POINT_GAP := 1.0
## How wide a stroke of the broom is (half-width, metres), how far its head swings to either side and
## how far ahead of him it reaches.
const REACH := 0.5
const SWING := 0.3
const AHEAD := 0.85
## The mask: metres per pixel.
const STEP := 0.3
## Hours of snowfall that fill a swept strip in again.
const REFILL_HOURS := 1.5
## How much of an hour's snowfall an hour without snow still brings back (drifting snow).
const DRIFT_RATE := 0.1
## A swept pixel counts as bare (for footprints) above this strength.
const BARE := 0.5
## Game hours he rests after a stretch of sweeping before he sets out again.
const REST_HOURS := 0.1

static var _img: Image
static var _tex: ImageTexture
## Hours of snowfall so far (the clock every stamp in the mask is told by), and the world hour it was last advanced to.
static var _fall := 0.0
static var _last_hours := -1.0
static var _dirty := false
static var _flushed := 0


## Whether `hour` lies in one of his sweeping stretches.
static func in_shift(hour: float) -> bool:
	return SHIFTS.any(func(s: Array) -> bool: return hour >= float(s[0]) and hour < float(s[1]))


## Whether the snow lies thick enough and the day is right: winter, snow on the ground, none falling, in daylight.
static func snowed(level: Node) -> bool:
	if not (level is Outdoor) or level.snow == null or level.night:
		return false
	return Weather.is_winter(level.season_day) and level.snow.amount >= SNOW_MIN and level.weather != Weather.SNOW \
		and level.weather != Weather.STORM


## Whether he goes out sweeping now.
static func wants(level: Node) -> bool:
	return snowed(level) and in_shift(level.hour) and not level.village_alarm.raised


## Whether he may keep sweeping (the shift or the snow is not over, no alarm).
static func keeps_on(level: Node) -> bool:
	return wants(level)


# --- The mask ---------------------------------------------------------------------------------

static func _ensure(level: Node) -> void:
	var size := Vector2i(ceili(level.width * Level.TILE / STEP), ceili(level.height * Level.TILE / STEP))
	if _img != null and _img.get_size() == size:
		return
	_img = Image.create(size.x, size.y, false, Image.FORMAT_RGH)
	_tex = ImageTexture.create_from_image(_img)
	_dirty = false
	if level.snow != null:
		level.snow.set_swept(_tex)


## Hands the mask (if any stroke was ever made) to the snow's shader; called when a world is built.
static func attach(level: Node) -> void:
	if level.snow != null and _tex != null and _img != null:
		level.snow.set_swept(_tex)


## The weather's turn: counts the snowfall, folds the mask away once the snow has melted, and
## uploads strokes made since the last time (at most five times a second).
static func advance(level: Node, cover: float) -> void:
	var hours: float = level.world_hours
	if _last_hours >= 0.0:
		# Snowfall fills a swept strip in; with none, the wind drifts snow back over it slowly, so a strip swept
		# in the afternoon is mostly white again by morning.
		# Only in the night: by day a swept strip stays bare.
		if DayNight.is_night(level.hour):
			_fall += clampf(hours - _last_hours, 0.0, 6.0) * (1.0 if level.weather == Weather.SNOW else DRIFT_RATE)
	_last_hours = hours
	if level.snow == null:
		return
	if cover < 0.02 and _img != null:
		reset()
		level.snow.set_swept(null)
	level.snow.set_swept_fall(_fall)
	if _dirty and Time.get_ticks_msec() - _flushed > 200:
		_flushed = Time.get_ticks_msec()
		_dirty = false
		_tex.update(_img)


## Everything is white again (the snow melted away).
static func reset() -> void:
	_img = null
	_tex = null
	_fall = 0.0
	_dirty = false


static func _strength(px: Color) -> float:
	if px.r < 0.5:
		return 0.0
	return px.g * (1.0 - clampf((_fall - (px.r - 1.0)) / REFILL_HOURS, 0.0, 1.0))


static func _pixel(level: Node, at: Vector3) -> Vector2:
	return Vector2((at.x + Level.TILE * 0.5) / STEP, (at.z + Level.TILE * 0.5) / STEP)


## How bare the ground is at `at` now, 0 (covered) to 1 (the middle of a fresh stroke).
static func bareness(level: Node, at: Vector3) -> float:
	if _img == null:
		return 0.0
	var p := _pixel(level, at)
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= _img.get_width() or y >= _img.get_height():
		return 0.0
	return _strength(_img.get_pixel(x, y))


## Whether the ground at `at` is swept bare (no footprints are pressed there).
static func is_bare(level: Node, at: Vector3) -> bool:
	return bareness(level, at) > BARE


## One stroke of the broom at `at`: the ground within `reach` metres is swept, strongest in the middle.
## Footprints pressed there before are wiped out (see SnowPrints.wipe).
static func stamp(level: Node, at: Vector3, reach := REACH) -> void:
	_ensure(level)
	var p := _pixel(level, at)
	var r := ceili(reach / STEP)
	var cx := int(p.x)
	var cy := int(p.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= _img.get_width() or y >= _img.get_height():
				continue
			var d := Vector2(x + 0.5 - p.x, y + 0.5 - p.y).length() * STEP
			var g := 1.0 - smoothstep(reach * 0.35, reach, d)
			if g <= 0.0:
				continue
			# A stroke that is not as clean as what is there leaves it be.
			if g > _strength(_img.get_pixel(x, y)):
				_img.set_pixel(x, y, Color(_fall + 1.0, g, 0.0))
				_dirty = true
	SnowPrints.wipe(at, reach * 0.8)


# --- The route --------------------------------------------------------------------------------

## The footpath tiles (see SurfaceLife.PATH) he may sweep.
static func _is_path(level: Node, c: Vector2i) -> bool:
	var ch: String = level.cell_char(c)
	return SurfaceLife.PATH.contains(ch) and ch != "#"


## The village gates (see VillageWall) are path tiles with a gate: the road runs on through them.
const GATE := "\\"
## How far from his spot (tiles) he looks for walkways to sweep.
const RANGE_TILES := 70


## Whether `c` is a tile of the paved square's rim: a square tile with open ground that is not square beside it.
## He sweeps only that rim, which is built like the walkways, not the whole village centre.
static func is_rim(level: Node, c: Vector2i) -> bool:
	if level.cell_char(c) != SurfaceLife.SQUARE:
		return false
	for n: Vector2i in [c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]:
		if level.cell_char(n) != SurfaceLife.SQUARE and level.is_open(n):
			return true
	return false


## Whether `c` is a tile he may walk and sweep: a footpath, a gate in the village wall, or the rim of the
## paved square.
static func _is_walkway(level: Node, c: Vector2i) -> bool:
	if StreetSweeper.is_marked(level, c):
		return true
	var ch: String = level.cell_char(c)
	if ch == SurfaceLife.SQUARE:
		return level.is_open(c) and is_rim(level, c)
	return ch == GATE or (_is_path(level, c) and level.is_open(c))


## The points of the next stretch of walkway to sweep. He works through the whole connected network of
## walkways from `start` (his spot): the stretch nearest to him (by the way he walks) that still has snow or
## leaves left, one footpath after the other, and the rim of the paved square in the village centre last. The stretch
## runs RUN_MIN to RUN_MAX tiles on from there; each point is a metre on, swaying a little to either side of the
## tile's middle so the footpath is not ruler-straight. Empty when no walkway is near or all is swept.
## `swept` (a Callable taking a point, true when it is clean already) says what is left to do; by default the
## snow's mask does.
static func route(level: Node, start: Vector2i, rng: RandomNumberGenerator, swept := Callable()) -> Array[Vector3]:
	var seed_cell := Vector2i(-1, -1)
	var best := 1e9
	for dy in range(-REACH_TILES, REACH_TILES + 1):
		for dx in range(-REACH_TILES, REACH_TILES + 1):
			var c := start + Vector2i(dx, dy)
			var d := float(dx * dx + dy * dy)
			if d < best and _is_path(level, c) and level.is_open(c):
				best = d
				seed_cell = c
	var none: Array[Vector3] = []
	if seed_cell.x < 0:
		return none
	if not swept.is_valid():
		swept = func(p: Vector3) -> bool: return is_bare(level, p)
	# The way marked by hand comes first, stretch by stretch (see StreetSweeper.MARKED).
	var marked_stretches := StreetSweeper.marked(level)
	# Round robin: he carries on after the stretch he swept last, so the upper lane is not always first.
	var count := marked_stretches.size()
	for step in count:
		var k: int = (StreetSweeper.cursor + step) % count
		var cells: Array = marked_stretches[k]
		if level.world_hours < float(StreetSweeper.rested.get(k, -1e9)) + StreetSweeper.MARKED_REST:
			continue
		var typed: Array[Vector2i] = []
		typed.assign(cells)
		var points := _points(level, typed, rng)
		var left := 0.0
		for p in points:
			if not swept.call(p):
				left += 1.0
		if left >= 3.0:
			StreetSweeper.rested[k] = level.world_hours
			StreetSweeper.cursor = k + 1
			return points
	# The whole walkway network, nearest first.
	var came := {}
	var order := _flood(level, seed_cell, came)
	var dirty: Array[Vector2i] = []
	for c: Vector2i in order:
		if not swept.call(level.cell_to_world(c)):
			dirty.append(c)
	# Footpaths before the square (the sort is stable, so each group stays nearest first).
	var paths := dirty.filter(func(c: Vector2i) -> bool: return level.cell_char(c) != SurfaceLife.SQUARE)
	var squares := dirty.filter(func(c: Vector2i) -> bool: return level.cell_char(c) == SurfaceLife.SQUARE)
	for target: Vector2i in paths.slice(0, 40) + squares.slice(0, 12):
		var way := _stretch(level, target, came.get(target, target), rng, swept)
		if not way.is_empty():
			return way
	return none


## The walkway cells (footpaths, gates and the rim of the square) within RANGE_TILES of `from`, nearest first by the way
## on foot: the search crosses grass and gates too, so a gap between two footpaths does not cut one off.
static func _flood(level: Node, from: Vector2i, parent := {}) -> Array[Vector2i]:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var found: Array[Vector2i] = []
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		if _is_walkway(level, c):
			found.append(c)
		for n: Vector2i in [c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]:
			if seen.has(n) or maxi(absi(n.x - from.x), absi(n.y - from.y)) > RANGE_TILES:
				continue
			if level.is_open(n) or level.cell_char(n) == GATE:
				seen[n] = true
				parent[n] = c
				queue.append(n)
	return found


## A stretch of RUN_MIN to RUN_MAX tiles starting at `target`, the one with the most left to sweep of the few he
## looks at (it begins on the tile before, on his way there). On a footpath it stays on footpaths (the square waits); on the square it stays on the square.
## Empty when too little is left on it.
static func _stretch(level: Node, target: Vector2i, before: Vector2i, rng: RandomNumberGenerator, swept: Callable) -> Array[Vector3]:
	var none: Array[Vector3] = []
	var on_square: bool = level.cell_char(target) == SurfaceLife.SQUARE
	var depth := {target: 0}
	var parent := {}
	var queue: Array[Vector2i] = [target]
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		if depth[c] >= RUN_MAX:
			continue
		for n: Vector2i in [c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]:
			if depth.has(n) or not _is_walkway(level, n):
				continue
			var square: bool = level.cell_char(n) == SurfaceLife.SQUARE
			if square == on_square:
				depth[n] = depth[c] + 1
				parent[n] = c
				queue.append(n)
	var ends: Array = depth.keys().filter(func(c: Vector2i) -> bool: return depth[c] >= mini(RUN_MIN, depth.values().max()))
	if ends.is_empty():
		return none
	var chosen: Array[Vector3] = []
	var most := 0.0
	for k in mini(4, ends.size()):
		var end: Vector2i = ends[rng.randi() % ends.size()]
		var cells: Array[Vector2i] = []
		var c := end
		while true:
			cells.push_front(c)
			if not parent.has(c):
				break
			c = parent[c]
		# He starts a tile before it, on the way he came: the broom reaches ahead of him.
		if before != target and _is_walkway(level, before):
			cells.push_front(before)
		if cells.size() < 2:
			continue
		var points := _points(level, cells, rng)
		var left := 0.0
		for p in points:
			if not swept.call(p):
				left += 1.0
		if left > most:
			most = left
			chosen = points
	return chosen if most >= 3.0 else none


## The cells' middles joined into points a metre apart, swaying to either side.
static func _points(level: Node, cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var phase := rng.randf() * TAU
	var along := 0.0
	for k in cells.size() - 1:
		var a: Vector3 = level.cell_to_world(cells[k])
		var b: Vector3 = level.cell_to_world(cells[k + 1])
		var steps := maxi(1, roundi(a.distance_to(b) / POINT_GAP))
		var side := (b - a).normalized().cross(Vector3.UP)
		for s in steps:
			var sway := sin(along * 0.7 + phase) * 0.4 + sin(along * 1.9 + phase * 2.3) * 0.15
			out.append(a.lerp(b, float(s) / steps) + side * sway)
			along += POINT_GAP
	out.append(level.cell_to_world(cells.back()))
	return out


## One stretch of sweeping: out along the route and back again.
class Job:
	extends RefCounted
	var points: Array[Vector3]
	var index := 0
	var back := false
	## Seconds of broom swing, and how long it has been blocked.
	var swing := 0.0
	var blocked := 0.0
	var heading := Vector3.BACK

	func _init(route: Array[Vector3]) -> void:
		points = route

	func aim() -> Vector3:
		return points[clampi(index, 0, points.size() - 1)]

	## On to the next point; false once the way back is walked as well.
	func advance() -> bool:
		if not back:
			if index + 1 < points.size():
				index += 1
				return true
			back = true
			return index > 0
		if index > 0:
			index -= 1
			return true
		return false


## The broom's head `swing` seconds into the stroke: ahead of `pos` along `heading`, swung to either side.
static func broom_head(pos: Vector3, heading: Vector3, swing: float, width := SWING) -> Vector3:
	var side := heading.cross(Vector3.UP)
	return pos + heading * AHEAD + side * sin(swing * 4.2) * width


# --- The broom --------------------------------------------------------------------------------

const BIRCH := Color(0.9, 0.87, 0.78)
const TWIG := Color(0.66, 0.48, 0.27)
const BINDING := Color(0.38, 0.27, 0.16)
## From the grip down to the tips of the twigs (metres): a long-handled besom.
const LENGTH := 1.3


## A besom: a pale birch pole with a bundle of twigs tied to its lower end, in `parent`. The grip is at
## the origin, the pole runs up along +y and the twigs fan out below, their tips LENGTH down.
static func build_broom(parent: Node3D) -> MeshInstance3D:
	var b := VillageProps.W.Builder.new()
	var w := VillageProps.W.WOOD
	b.bar(Vector3(0, -0.95, 0), Vector3(0, 0.5, 0), 0.02, BIRCH, w, 6)
	# The birch's dark rings on the pole.
	for y in [0.25, -0.1, -0.5]:
		b.cylinder(Vector3(0, y, 0), 0.023, 0.023, 0.03, Color(0.3, 0.27, 0.24), w, 6)
	b.cylinder(Vector3(0, -0.98, 0), 0.05, 0.1, 0.1, BINDING, w, 8)
	# The twigs: a bushy bundle widening to the tips, with a few stiff ones sticking out at the sides.
	b.cylinder(Vector3(0, -LENGTH, 0), 0.15, 0.06, LENGTH - 0.98, TWIG, w, 10)
	for k in 8:
		var a := TAU * k / 8.0
		var out := Vector3(cos(a), 0, sin(a))
		b.cylinder(Vector3(out.x * 0.15, -LENGTH, out.z * 0.15), 0.025, 0.012, 0.18, TWIG * 0.85, w, 5, Basis(out.cross(Vector3.UP).normalized(), -0.35 * (1 if k % 2 == 0 else -1)))
	b.cylinder(Vector3(0, -1.12, 0), 0.07, 0.11, 0.03, BINDING, w, 8)
	return b.finish(parent, Vector3.ZERO, true, true)


## Lays the besom from `hand` down to the ground at `head`: the pole's top in the fist, the twigs' tips on the
## snow (the pole is stretched or squeezed a little to reach, as the hand rises and falls in the stride).
static func lay_broom(broom: Node3D, hand: Vector3, head: Vector3) -> void:
	var up := hand - head
	var reach := up.length()
	if reach < 0.2:
		return
	var y := up / reach
	var x := y.cross(Vector3.UP)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	var z := x.cross(y)
	broom.global_transform = Transform3D(Basis(x, y * (reach / LENGTH), z), hand)
