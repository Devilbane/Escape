class_name LeafSweep
extends RefCounted
## In autumn the street sweeper (see StreetSweeper) sweeps the fallen leaves off the village's walkways with
## the same birch broom he clears the snow with (see SnowSweep).
##
## The leaves that lie on the ground are clusters in MultiMeshes (see SurfaceLife.set_autumn): the ones the wind
## strewed over the walkways ("lane") and the ones along their edges ("fallen"). A stroke of the broom takes
## every cluster within its reach on a walkway and heaps it up on the grass at the edge of the way, a little
## bigger and thicker than it lay. After BACK_HOURS (between about five and twelve hours, so the walkways are strewn again by the next morning and not all at once, so they do not all
## come at once) the wind carries the heap back over the way and the walkway is strewn again.
##
## Nothing is made or freed: a swept cluster is the same instance, moved. Its litter entry (see
## SurfaceLife._cell_litter) is changed in place, so the wind and the loot check see it where it lies now.

## The hours of the day he sweeps in: the same as for the snow (SnowSweep.SHIFTS).
const SHIFTS := SnowSweep.SHIFTS
## Half the width of the swept strip (metres): a path tile is 4 m across, the broom swings from side to side
## over all of it, so the strip is nearly the whole way.
const LANE := 2.0
## How far a stroke of the broom reaches round its head (metres), how wide the head swings to either side of
## him, and how fast he walks (the leaves are heavier than the snow).
const REACH := 0.95
const SWING := 1.1
## How near a cluster must lie to a point of his route for the point to want sweeping.
const CLEAR_RADIUS := 1.5
const PACE := 1.0
## The heap lies this far beyond the swept strip, and a little closer or farther for each cluster (metres).
const PILE_GAP := Vector2(0.15, 0.75)
## How much bigger than it lay a swept cluster is in the heap, and how much higher the heaps lie.
const PILE_SCALE := 1.35
const PILE_RISE := 0.035
## Game hours until the wind has carried a swept cluster back.
const BACK_HOURS := 9.0
## Where the dust of the broom is brown, and the leaves' own colours the crumbs take.
const DUST := Color(0.78, 0.66, 0.42)

## Swept clusters by "multimesh id:index": [entry, its origin, its transform, the hour it returns].
static var _swept := {}
static var _life: SurfaceLife
static var _rng := RandomNumberGenerator.new()


## Whether the leaves are there to sweep: autumn, daylight, no storm, the leaves laid.
static func leaves(level: Node) -> bool:
	if not (level is Outdoor) or level.surface_life == null or level.night:
		return false
	return Weather.is_autumn(level.season_day) and level.surface_life.fallen != null \
		and level.surface_life.fallen.visible and level.weather != Weather.STORM


## Whether he goes out sweeping leaves now.
static func wants(level: Node) -> bool:
	return leaves(level) and SnowSweep.in_shift(level.hour) and not level.village_alarm.raised


## The litter entries (see SurfaceLife._cell_litter) of the fallen leaves within `radius` metres of `at`.
static func _near(life: SurfaceLife, level: Node, at: Vector3, radius: float) -> Array:
	var found: Array = []
	var c: Vector2i = level.world_to_cell(at)
	var reach := ceili((radius + SurfaceLife.CLUSTER_SPREAD) / Level.TILE)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for e: Array in life._cell_litter.get(c + Vector2i(dx, dy), []):
				if e[4] != "fallen" and e[4] != "lane":
					continue
				var o: Vector3 = e[2]
				if Vector2(o.x - at.x, o.z - at.z).length() < radius:
					found.append(e)
	return found


## Whether `e` has been swept and not returned yet.
static func is_swept(e: Array) -> bool:
	return _swept.has(_key(e))


static func _key(e: Array) -> String:
	return "%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]


## Whether a cluster at `o` lies on a walkway (a footpath, a gate or the square): only those are swept.
static func _on_walkway(level: Node, o: Vector3) -> bool:
	var under: String = level.cell_char(level.world_to_cell(o))
	return SurfaceLife.PATH.contains(under) or under == SurfaceLife.SQUARE or under == SnowSweep.GATE


## How many clusters of leaves still lie within `radius` metres of `at`, for the route and the tests.
static func leaves_near(level: Node, at: Vector3, radius := LANE) -> int:
	var life: SurfaceLife = level.surface_life
	if life == null:
		return 0
	var count := 0
	for e: Array in _near(life, level, at, radius):
		if not is_swept(e) and is_instance_valid(e[0]) and _on_walkway(level, e[2]):
			count += 1
	return count


## Whether the strip round `at` is clean: not a cluster of leaves lies within CLEAR_RADIUS of it.
static func is_clear(at: Vector3, level: Node) -> bool:
	return leaves_near(level, at, CLEAR_RADIUS) == 0


## One stroke of the broom at `head`, the sweeper walking at `feet` along `heading`: every cluster within reach
## on the way is heaped up at its edge, on the side of the way it lay. Returns how many it moved.
static func stamp(level: Node, head: Vector3, feet: Vector3, heading: Vector3) -> int:
	var life: SurfaceLife = level.surface_life
	if life == null or heading.length() < 0.01:
		return 0
	if life != _life:
		_swept.clear()
		_life = life
	var side := heading.cross(Vector3.UP).normalized()
	var moved := 0
	for e: Array in _near(life, level, head, REACH):
		if is_swept(e) or not is_instance_valid(e[0]):
			continue
		var o: Vector3 = e[2]
		# Only what lies on a walkway: a heap on the grass beside it stays.
		if not _on_walkway(level, o):
			continue
		var lateral := (o - feet).dot(side)
		if absf(lateral) > LANE:
			continue
		# To the side of the way it lay, a little beyond the strip.
		var way := 1.0 if lateral >= 0.0 else -1.0
		var to_lat := way * (LANE + _rng.randf_range(PILE_GAP.x, PILE_GAP.y))
		var pile := o + side * (to_lat - lateral)
		# Heaps do not climb walls: a spot that is not open ground stays in the strip's edge.
		if not level.is_open(level.world_to_cell(pile)):
			pile = o + side * (way * LANE - lateral)
		pile.y = o.y + PILE_RISE * _rng.randf_range(0.5, 1.5)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * PILE_SCALE)
		var t := Transform3D(basis, pile)
		var back: float = level.world_hours + BACK_HOURS * _rng.randf_range(0.6, 1.4)
		_swept[_key(e)] = [e, o, e[3], back]
		e[2] = pile
		e[3] = t
		_place(life, e, t)
		moved += 1
	return moved


## Puts a cluster's transform on its instance (unless the loot check has lifted it away right now).
static func _place(life: SurfaceLife, e: Array, t: Transform3D) -> void:
	if life._lifted.has("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]):
		return
	(e[0] as MultiMesh).set_instance_transform(e[1], t)


## The wind's turn: the clusters whose hour has come are carried back where they lay.
static func advance(level: Node) -> void:
	if _swept.is_empty():
		return
	var life: SurfaceLife = level.surface_life
	if life != _life:
		_swept.clear()
		return
	var now: float = level.world_hours
	for k: String in _swept.keys():
		var s: Array = _swept[k]
		if now >= float(s[3]) or not is_instance_valid(s[0][0]):
			_return(life, s)
			_swept.erase(k)


static func _return(life: SurfaceLife, s: Array) -> void:
	var e: Array = s[0]
	if not is_instance_valid(e[0]):
		return
	e[2] = s[1]
	e[3] = s[2]
	_place(life, e, s[2])


## Every swept cluster is back where it lay (autumn is over, or the world is built again).
static func restore_all() -> void:
	if _life != null and is_instance_valid(_life):
		for s: Array in _swept.values():
			_return(_life, s)
	_swept.clear()


## How many clusters lie swept into heaps right now.
static func swept_count() -> int:
	return _swept.size()
