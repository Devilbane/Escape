class_name WindGusts
extends Node
## Now and then a gust of wind stirs the light litter lying around the hero: fallen leaves tumble
## along the ground for a few metres, straw and wood chips skid, and a heap of autumn leaves
## shifts a little before it settles again. Not constant jitter: a gust comes every half minute or
## so, lifts a dozen or so pieces near the hero and is over in four seconds.
##
## It is cheap. Nothing new is drawn: the pieces are the litter's own MultiMesh instances (see
## SurfaceLife), moved a little each frame while a gust lasts and left where they land (the next
## gust may take them on). Only the pieces of one gust are touched, and nothing runs between gusts
## but a timer. The Performance preset has no gusts, Quality has more of them.
##
## The weather tells the wind (see FlagWind.WINDS): rare, weak gusts in fog, frequent, strong ones
## in a storm. Pieces only land on open ground (never in water, under a wall, in a dug hole, in a
## built house or on a tree's tile).

## Seconds between gusts under clear skies (at a wind strength of 1), at random in this range.
const EVERY := Vector2(30.0, 70.0)
## Pieces one gust moves, before the wind's strength and the quality preset.
const PIECES := Vector2i(10, 18)
const MAX_PIECES := 40
## Pieces are taken from this far round the hero (metres).
const NEAR := 2.5
const FAR := 15.0
## How far a piece travels in a breeze (metres), by what it is: leaves fly, chips skid.
const TRAVEL := {"leaf": Vector2(6.0, 14.0), "straw": Vector2(3.0, 8.0), "chip": Vector2(0.6, 1.5), "fallen": Vector2(0.4, 1.1)}
## How high it is thrown (metres) and how long it takes (seconds).
const LIFT := {"leaf": Vector2(1.0, 2.2), "straw": Vector2(0.6, 1.5), "chip": Vector2(0.05, 0.2), "fallen": Vector2(0.02, 0.06)}
const DURATION := Vector2(2.4, 3.6)
## The gust sweeps along the wind: the furthest piece starts this long after the nearest (seconds).
const SWEEP := 1.2
## How much the wind's direction turns between gusts (radians, at most).
const TURN := 0.7
## The tiles pieces may fly over and land on.
const OPEN := SurfaceLife.GROUND + SurfaceLife.PATH + SurfaceLife.SQUARE

var life: SurfaceLife
## The pieces in the air: {entry, from, to, delay, dur, lift, axis, spin, yaw}.
var _moving: Array = []
var _clock := 0.0
var _timer := 0.0
## The way the wind blows now (angle on the ground plane).
var _angle := 0.0
var _rng := RandomNumberGenerator.new()
## Gusts so far and pieces they moved (for the tests).
var gusts := 0
var moved := 0


func _init(owner_life: SurfaceLife) -> void:
	life = owner_life
	name = "WindGusts"


func _ready() -> void:
	_rng.seed = hash(life.level.level_name + ":gusts")
	_angle = _rng.randf() * TAU
	_timer = _rng.randf_range(EVERY.x * 0.4, EVERY.y * 0.6)


## Whether this quality preset has gusts at all.
static func enabled() -> bool:
	return Graphics.preset != Graphics.PERFORMANCE


## The share of the usual number of pieces a gust moves in this preset.
static func quality_scale() -> float:
	return 1.5 if Graphics.preset == Graphics.QUALITY else 1.0


## How hard the wind blows in the level's weather (1 is a breeze).
func strength() -> float:
	return FlagWind.wind_for(life.level.get("weather") if "weather" in life.level else "").x


func active() -> int:
	return _moving.size()


func _process(delta: float) -> void:
	if not _moving.is_empty():
		_clock += delta
		_move()
	if not enabled() or life.level.player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var s := strength()
	# Fog lies still; a storm blows often.
	_timer = _rng.randf_range(EVERY.x, EVERY.y) / clampf(s, 0.35, 2.6)
	if s >= 0.5:
		gust(s)


## Blows one gust now, with the wind at strength `s`: picks pieces of litter near the hero and sets
## them flying. Returns how many it set flying.
func gust(s: float) -> int:
	if life.level.player == null or not _moving.is_empty():
		return 0
	_angle += _rng.randf_range(-TURN, TURN)
	var dir := Vector3(cos(_angle), 0, sin(_angle))
	var hero: Vector3 = life.level.player.global_position
	var want := mini(MAX_PIECES, roundi(_rng.randi_range(PIECES.x, PIECES.y) * s * quality_scale()))
	var pool := _pool(hero)
	_clock = 0.0
	while want > 0 and not pool.is_empty():
		var at := _rng.randi() % pool.size()
		var e: Array = pool[at]
		pool.remove_at(at)
		if _launch(e, dir, s, hero):
			want -= 1
			moved += 1
	gusts += 1
	return _moving.size()


## The litter that may be stirred: leaves, straw, chips and heaps of fallen leaves round the hero.
func _pool(hero: Vector3) -> Array:
	var pool: Array = []
	var c: Vector2i = life.level.world_to_cell(hero)
	var reach := ceili(FAR / Level.TILE)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for e: Array in life._cell_litter.get(c + Vector2i(dx, dy), []):
				if not TRAVEL.has(e[4]) or (e[4] == "fallen" and not life._autumn):
					continue
				var o: Vector3 = e[2]
				var d := Vector2(o.x - hero.x, o.z - hero.z).length()
				if d < NEAR or d > FAR or not is_instance_valid(e[0]):
					continue
				if life._lifted.has("%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]):
					continue
				pool.append(e)
	return pool


func _launch(e: Array, dir: Vector3, s: float, hero: Vector3) -> bool:
	var kind: String = e[4]
	var from: Vector3 = e[2]
	var span: Vector2 = TRAVEL[kind]
	var dist := _rng.randf_range(span.x, span.y) * (0.6 + 0.4 * s)
	# A little off the wind's own way, as every piece catches it differently.
	var way := dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var to := from + way * dist
	if not _clear_way(from, to):
		return false
	var lift: Vector2 = LIFT[kind]
	var light := kind == "leaf" or kind == "straw"
	_moving.append({
		"entry": e, "from": from, "to": to,
		"delay": clampf((from - hero).dot(dir) / FAR * 0.5 + 0.5, 0.0, 1.0) * SWEEP + _rng.randf_range(0.0, 0.25),
		"dur": _rng.randf_range(DURATION.x, DURATION.y),
		"lift": _rng.randf_range(lift.x, lift.y) * (0.7 + 0.3 * s),
		"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)).normalized(),
		"spin": _rng.randf_range(5.0, 11.0) if light else _rng.randf_range(0.05, 0.3),
		"flutter": _rng.randf_range(5.0, 9.0),
		"yaw": _rng.randf_range(-2.5, 2.5) if light else _rng.randf_range(-0.5, 0.5),
	})
	return true


## Whether the piece may fly from `a` to `b`: open ground all the way, and not into a hole or a house.
func _clear_way(a: Vector3, b: Vector3) -> bool:
	var steps := ceili(a.distance_to(b))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if not OPEN.contains(life.level.cell_char(life.level.world_to_cell(p))):
			return false
	for r: Rect2 in life._holes + life._built:
		if r.grow(0.4).has_point(Vector2(b.x, b.z)):
			return false
	return true


func _move() -> void:
	var left: Array = []
	for m: Dictionary in _moving:
		var e: Array = m.entry
		if not is_instance_valid(e[0]):
			continue
		var t := clampf((_clock - m.delay) / m.dur, 0.0, 1.0)
		var flat: Transform3D = e[3]
		var yawed := Basis(Vector3.UP, m.yaw)
		var key := "%d:%d" % [(e[0] as MultiMesh).get_instance_id(), e[1]]
		var lifted: bool = life._lifted.has(key)
		if t >= 1.0:
			# Lands: this is where the piece lies now.
			var home := Transform3D(yawed * flat.basis, flat.origin + (m.to - m.from))
			e[2] = home.origin
			e[3] = home
			if not lifted:
				(e[0] as MultiMesh).set_instance_transform(e[1], home)
			continue
		left.append(m)
		if t <= 0.0 or lifted:
			continue
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var up: float = pow(sin(PI * t), 0.8) * m.lift * (1.0 + 0.18 * sin(t * m.flutter * 3.0))
		var tumble := Basis(m.axis, sin(PI * t) * m.spin)
		var basis := tumble * Basis(Vector3.UP, m.yaw * eased) * flat.basis
		var side: Vector3 = Vector3.UP.cross((m.to as Vector3) - (m.from as Vector3)).normalized() * sin(t * m.flutter * 2.0) * 0.8 * sin(PI * t)
		var origin: Vector3 = (m.from as Vector3).lerp(m.to, pow(t, 0.8)) + side + Vector3(0, up, 0) + (flat.origin - m.from)
		(e[0] as MultiMesh).set_instance_transform(e[1], Transform3D(basis, origin))
	_moving = left
