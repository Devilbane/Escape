class_name Hedgehog
extends Node3D
## A hedgehog (see WoodsLife). It lives under one tree at the edge of the forest or
## on the village's edge, among the hedges and gardens. By day it sleeps curled up
## in a ball beside its tree; from dusk till dawn it comes out, snuffling about with
## its nose to the ground and waddling from spot to spot. When the hero comes close it
## tucks in its head and feet and rolls up into a ball of spikes, and uncurls again once
## the hero has gone. In winter it hibernates: a ball under its tree all season.
##
## It never fights, cannot be hurt and has its own footprint, like the other animals of
## the woods (see Animal and Squirrel). A sneaking hero gets closer before it curls up.
##
## In autumn a hedgehog that lives near the village's apple trees (see WoodsLife.assign_hoards)
## sometimes goes to one at night and waits under it. An apple drops from the crown and lands on
## its back, where the spines pierce it, and off it waddles with the apple on its back to its
## hoard (see AppleHoard) under its own tree, shakes the apple off onto the heap and goes back
## to snuffling about.
##
## Model: "Low Poly Hedgehog" by trashart (CC-BY, see assets/hedgehog/CREDITS.txt).
## It has no animation of its own: the pose (waddle, nose bob, curling up) is laid over
## the one mesh, see _pose.

## How close (metres) the hero may come before it curls up; a sneaking hero is noticed
## only this much closer.
const SHY := 4.5
const SNEAK_FACTOR := 0.5
## The hero must be this many times SHY away, and it must have waited UNCURL_AFTER
## seconds, before it unrolls again.
const CALM_FACTOR := 1.6
const UNCURL_AFTER := 3.0
## Ground speed (m/s) and how far from its tree it roams (tiles).
const WALK := 0.8
## Its pace with an apple on its back: it is in a hurry, to be home before dawn.
const CARRY := 1.1
const ROAM := 4
## The hedgehog's size against the real thing (the world is big, like the squirrel's).
const SIZE := 1.3
## From this hour in the evening until this hour in the morning it is about.
const DUSK := 17.5
const DAWN := 7.0
## The apple run: how long it waits under the tree, how high the apple falls from (metres),
## how far from the trunk it waits, where on its back the apple sticks (model units, body
## frame) and how long it shakes it off at the hoard; and the pause between two runs (seconds).
const WAIT := 1.6
const DROP_FROM := 3.0
const UNDER := 1.1
const BACK := Vector3(0.0, 0.25, -0.08)
const SHAKE := 1.4
## The speed (m/s) of its scurry under the falling apple, at most.
const SCURRY := 3.0
## The carried apple's size against the model apple (it sits in the body's scaled frame).
const APPLE_SCALE := 0.8
const RUN_PAUSE := Vector2(40.0, 90.0)
## A hedgehog that lives near an apple tree starts a run this often (per snuffle that ends).
const RUN_CHANCE := 0.6
## The model's ground level (the lowest foot) and how far it sinks when curled (model units).
const FOOT := 0.142
const SINK := 0.08

## "snuffle" (nose down, searching), "walk", "curl" (rolled up, scared) or
## "sleep" (rolled up by day or all winter); on an apple run also "to_tree", "wait",
## "falling" (an apple drops on it), "startle", "carry" and "stash" (shakes the apple off).
var state := "sleep"
## The tree it lives under: pos (the trunk's foot), cell (the open tile beside it).
var tree: Dictionary
var level: Level
var _rng := RandomNumberGenerator.new()
var _tilt: Node3D
var _path: Array[Vector3] = []
var _waiting := 0.0
var _timer := 0.0
var _clock := 0.0
var _phase := 0.0
## How curled up it is, 0 (on its feet) to 1 (a ball).
var _curl := 0.0
var _calm := 0.0
## The apple tree it fetches apples from (the trunk's foot) and the hoard under its own tree
## (both set by WoodsLife.assign_hoards), the apple it carries or that is falling on it, how fast
## that falls, and the pause before its next run.
var apple_tree := Vector3.INF
var hoard: AppleHoard
## Where it stands to toss an apple onto the hoard: beside the trunk, on the open side.
var hoard_door := Vector3.INF
var _apple: MeshInstance3D
var _fall_speed := 0.0
## Where the falling apple lands.
var _land := Vector3.ZERO
var _toss_from := Vector3.ZERO
var _pause := 0.0
## Its small paw prints in the snow (see SnowTrail).
var _trail := SnowTrail.new("hedgehog")


func setup(owner_level: Level, home_tree: Dictionary) -> void:
	level = owner_level
	tree = home_tree
	_rng.seed = hash(Vector2(tree.pos.x, tree.pos.z)) + 17


## Called after the footprint pass moved this animal to a free spot: the way on from there is found again.
func footprint_moved() -> void:
	_path.clear()


func _ready() -> void:
	add_to_group(Footprint.GROUP)
	SmoothMotion.follow_ticks(self)
	_build()
	var spot := _nearby(2)
	global_position = Vector3(spot.x, 0.0, spot.z)
	rotation.y = _rng.randf() * TAU
	_begin("sleep", _rng.randf_range(2.0, 6.0))
	_curl = 1.0
	_pose(0.0)


## The model: one mesh of eleven parts (spikes, body, nose, four feet, two eyes, two
## ears), each with its own plain colour, the spikes and the body with their painted
## texture. The head points along +X in the file; the body turns it to +Z.
func _build() -> void:
	var mesh: Mesh = load("res://assets/hedgehog/Hedgehog.obj")
	var parts := MeshInstance3D.new()
	parts.mesh = mesh
	parts.rotation.y = -PI * 0.5
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		parts.set_surface_override_material(i, _material(i))
	_tilt = Node3D.new()
	_tilt.position.y = FOOT
	_tilt.add_child(parts)
	var root := Node3D.new()
	root.scale = Vector3.ONE * SIZE
	root.add_child(_tilt)
	add_child(root)


## The look of surface `i` of the file: 0 spikes, 1 body, 2 nose, 3 to 6 feet, 7 and 8 eyes,
## 9 and 10 ears.
static func _material(i: int) -> Material:
	var m := StandardMaterial3D.new()
	m.roughness = 0.95
	match i:
		0:
			m.albedo_texture = load("res://assets/hedgehog/hedgehog_low_SpikesMaterial_BaseColor.png")
		1:
			m.albedo_texture = load("res://assets/hedgehog/hedgehog_low_BodyMaterial_BaseColor.png")
		2:
			m.albedo_color = Color(0.08, 0.06, 0.06)
		3, 4, 5, 6:
			m.albedo_color = Color(0.62, 0.5, 0.42)
		7, 8:
			m.albedo_color = Color(0.03, 0.03, 0.03)
			m.roughness = 0.3
		_:
			m.albedo_color = Color(0.5, 0.35, 0.26)
	return m


func _begin(new_state: String, time: float) -> void:
	state = new_state
	_timer = time


## Whether it is rolled up in a ball right now.
func is_curled() -> bool:
	return state in ["curl", "sleep"]


## Whether it lives in the village, among people.
func is_village() -> bool:
	return bool(tree.get("in_village", false))


## Whether it is its time of day: dusk to dawn, and not in winter. A village hedgehog is used to
## people and is about all day long (it still hibernates in winter).
func awake_time() -> bool:
	if Weather.is_winter(int(level.get("season_day"))):
		return false
	if is_village():
		return true
	if level.get("night") == true:
		return true
	var h: float = level.get("hour")
	return h >= DUSK or (h >= 0.0 and h < DAWN)


func shy_distance() -> float:
	if is_village():
		return 0.0
	var d := SHY
	if level and level.player and level.player.get("sneaking"):
		d *= SNEAK_FACTOR
	return d


func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var hero: Node3D = level.player
	var away := _flat(global_position - hero.global_position)
	# Far from the hero it keeps still (nobody sees it).
	if away.length() > 90.0:
		return
	_clock += delta
	if not is_curled():
		_trail.follow(level, global_position)
	var near: bool = away.length() < shy_distance() and not hero.get("dead")
	var awake := awake_time()
	_pause -= delta
	match state:
		"snuffle":
			_timer -= delta
			if near or not awake:
				_roll_up()
			elif _timer <= 0.0:
				_next()
		"to_tree", "carry":
			_walk(delta)
			if near or not awake:
				_roll_up()
			elif _path.is_empty():
				if state == "to_tree":
					_begin("wait", WAIT)
				else:
					_begin("stash", SHAKE)
		"wait":
			_timer -= delta
			if near or not awake:
				_roll_up()
			elif _timer <= 0.0:
				_drop_apple()
		"falling":
			_fall(delta)
		"startle":
			_timer -= delta
			if _timer <= 0.0:
				_carry_home()
		"stash":
			_timer -= delta
			_toss(delta)
			if _timer <= 0.0:
				_set_down_apple()
		"walk":
			_walk(delta)
			if near or not awake:
				_roll_up()
			elif _path.is_empty():
				_begin("snuffle", _rng.randf_range(2.0, 6.0))
		"curl":
			if near:
				_calm = 0.0
			else:
				_calm += delta
			if _calm >= UNCURL_AFTER and away.length() > shy_distance() * CALM_FACTOR:
				if awake and _apple != null:
					_carry_home()
				elif awake:
					_begin("snuffle", _rng.randf_range(1.0, 3.0))
				else:
					_begin("sleep", 0.0)
		"sleep":
			if near and awake:
				_roll_up()
			elif awake and not near:
				_begin("snuffle", _rng.randf_range(1.0, 4.0))
	_pose(delta)


## Tucks in head and feet: a ball of spikes, where it stands.
func _roll_up() -> void:
	_path.clear()
	if _apple != null and _apple.get_parent() != _tilt:
		# An apple still on its way down or being fetched: never mind it.
		_apple.queue_free()
		_apple = null
	_calm = 0.0
	_begin("curl", 0.0)


## Calm again: snuffle on, or waddle to another spot.
func _next() -> void:
	if _may_fetch_apple() and _rng.randf() < RUN_CHANCE and _go_to_tree():
		return
	if _rng.randf() < 0.35:
		_begin("snuffle", _rng.randf_range(2.0, 6.0))
		return
	if _set_path(_nearby(ROAM)):
		_begin("walk", 0.0)
	else:
		_begin("snuffle", 2.0)


## Whether it may go for an apple now: it has a tree and a hoard, it is autumn (the apples
## fall), it carries nothing and has rested since its last run.
func _may_fetch_apple() -> bool:
	return apple_tree != Vector3.INF and hoard != null and _apple == null and _pause <= 0.0 \
			and Weather.is_autumn(int(level.get("season_day")))


## Sets off for a spot under the apple tree, on the side it comes from.
func _go_to_tree() -> bool:
	var side := _flat(global_position - apple_tree)
	var dir := side.normalized() if side.length() > 0.1 else Vector3(1, 0, 0)
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	var spot := apple_tree + dir * UNDER
	# The tree's own tile is solid for the paths: they lead to the open tile beside the spot.
	var anchor := level.cell_to_world(level.world_to_cell(spot))
	var c0 := level.world_to_cell(spot)
	var best := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := c0 + Vector2i(dx, dy)
			var w: Vector3 = level.cell_to_world(c)
			if _open(c) and w.distance_to(spot) < best:
				best = w.distance_to(spot)
				anchor = w
	if best == INF or not _set_path(anchor, Vector3(spot.x, 0.0, spot.z)):
		_pause = RUN_PAUSE.x
		return false
	_begin("to_tree", 0.0)
	return true


## An apple lets go of the crown, a little way along from where the hedgehog waits.
func _drop_apple() -> void:
	var dir := _flat(global_position - apple_tree).normalized()
	var turn := _rng.randf_range(0.8, 1.2) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var spot := apple_tree + dir.rotated(Vector3.UP, turn) * UNDER
	_land = Vector3(spot.x, 0.0, spot.z)
	_apple = AppleHoard.make_apple(_rng.randi())
	_apple.scale = Vector3.ONE * SIZE * APPLE_SCALE
	_apple.top_level = true
	add_child(_apple)
	_apple.global_position = _land + Vector3(0.0, DROP_FROM, 0.0)
	_fall_speed = 0.0
	_begin("falling", 0.0)


## The apple falls and the hedgehog scurries under it, so that it lands on its back and the
## spines pierce it.
func _fall(delta: float) -> void:
	_fall_speed += 9.8 * delta
	_apple.global_position.y -= _fall_speed * delta
	var to := _land - global_position
	to.y = 0.0
	# It must cover the way in the time the apple still needs to fall.
	var left := maxf(sqrt(2.0 * maxf(_apple.global_position.y - (FOOT + BACK.y) * SIZE, 0.0) / 9.8), 0.05)
	var step := minf(to.length(), minf(to.length() / left, SCURRY) * delta)
	if step > 0.0:
		var target := global_position + to.normalized() * step
		if WalkRules.can_step(level, global_position, target):
			global_position = target
			_phase += step * 9.0
			_turn_to(to, delta)
	if _apple.global_position.y > (FOOT + BACK.y) * SIZE:
		return
	if to.length() > 0.35:
		# Too far off: the apple thuds to the ground and the hedgehog gives up on this one.
		_apple.queue_free()
		_apple = null
		_pause = RUN_PAUSE.x
		_begin("snuffle", 2.0)
		return
	# Pierced: the apple moves on to the hedgehog's back and rides there.
	_apple.top_level = false
	_apple.reparent(_tilt, false)
	_apple.scale = Vector3.ONE * APPLE_SCALE
	_apple.position = BACK
	_apple.rotation = Vector3(0.0, _rng.randf() * TAU, 0.0)
	Effects.float_text(level, global_position + Vector3(0, 1.4, 0), "!", Color(1.0, 0.95, 0.7, 0.9))
	_begin("startle", 0.8)


## Off to the hoard with the apple on its back.
func _carry_home() -> void:
	if _set_path(hoard_door):
		_begin("carry", 0.0)
	else:
		# No way through: it shakes the apple off right here.
		_begin("stash", SHAKE)


## While it shakes, the apple flies off its back in an arc onto the heap behind the trunk.
func _toss(_delta: float) -> void:
	if _apple == null:
		return
	var shaken := SHAKE * 0.6
	if _timer > shaken:
		return
	if _apple.get_parent() == _tilt:
		_apple.reparent(self, true)
		_apple.top_level = true
		_apple.scale = Vector3.ONE * APPLE_SCALE
		_toss_from = _apple.global_position
	var f := clampf(1.0 - _timer / shaken, 0.0, 1.0)
	_apple.global_position = _toss_from.lerp(hoard.next_spot(), f) + Vector3(0, sin(f * PI) * 0.4, 0)


## Sets the apple down: it lies on the heap.
func _set_down_apple() -> void:
	if _apple != null:
		_apple.queue_free()
		_apple = null
	hoard.add_apple()
	_pause = _rng.randf_range(RUN_PAUSE.x, RUN_PAUSE.y)
	_begin("snuffle", _rng.randf_range(1.5, 4.0))


## Waddles along its path.
func _walk(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := (CARRY if state == "carry" else WALK) * delta
	var target := Vector3(_path[0].x, 0.0, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if not WalkRules.can_step(level, global_position, target):
		# A gate was shut (or a wall stands) ahead: stand still, then find the way again.
		_waiting += delta
		if _waiting >= WalkRules.MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			if not _set_path(goal):
				_path.clear()
		return
	_waiting = 0.0
	global_position = target
	if to.length() <= step:
		_path.pop_front()
	_phase += step * 7.0
	_turn_to(to, delta)


## The pose of the body from the state: on its feet it bobs its nose and waddles, rolled up
## it is a round ball sunk a little into the ground.
func _pose(delta: float) -> void:
	var want := 1.0 if is_curled() else (0.5 if state == "startle" else 0.0)
	_curl = move_toward(_curl, want, delta * 2.5) if delta > 0.0 else want
	var k := smoothstep(0.0, 1.0, _curl)
	var up := 1.0 - k
	var pitch := 0.0
	var roll := 0.0
	var bob := 0.0
	match state:
		"snuffle":
			# Nose down, sniffing.
			pitch = 0.12 + sin(_clock * 9.0) * 0.07
		"walk", "to_tree", "carry":
			pitch = 0.1 + sin(_phase * 2.0) * 0.03
			roll = sin(_phase) * 0.09
			bob = absf(sin(_phase)) * 0.012
		"wait":
			pitch = 0.12 + sin(_clock * 9.0) * 0.07
		"falling":
			# Scurrying under the apple.
			pitch = 0.1
			roll = sin(_phase) * 0.12
			bob = absf(sin(_phase)) * 0.02
		"startle":
			# A jump of fright under the apple.
			bob = sin(clampf(_timer / 0.8, 0.0, 1.0) * PI) * 0.06
		"stash":
			# Rolls from side to side, shaking the apple off its back.
			roll = sin(_clock * 14.0) * 0.3
			pitch = 0.05
	# Rolled up: the head goes down and the rump up, the body shortens and rounds.
	_tilt.rotation.x = pitch * up + 0.6 * k
	_tilt.rotation.z = roll * up
	_tilt.scale = Vector3(1.0 + 0.12 * k, 1.0 + 0.08 * k, 1.0 - 0.25 * k)
	_tilt.position.y = FOOT + bob * up - SINK * k


## Fills the path along the tiles to `target`, ending on the exact spot (also within the tile it
## stands on), or on `end` when that is given: a spot in a tile the paths do not cross.
func _set_path(target: Vector3, end := Vector3.INF) -> bool:
	var way := WalkRules.path(level, global_position, target, _rng)
	if way.is_empty() and level.world_to_cell(global_position) != level.world_to_cell(target):
		_path.clear()
		return false
	var last := target if end == Vector3.INF else end
	way.append(Vector3(last.x, 0.0, last.z))
	_path.assign(way)
	return true


## A free tile within a few tiles of its tree (the open tile beside it).
func _nearby(radius: int) -> Vector3:
	var home: Vector2i = tree.cell
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if _open(c):
			return level.cell_to_world(c) + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
	return level.cell_to_world(home)


func _open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return level.is_open(c) if level.has_method("is_open") else not level.astar.is_point_solid(c)


func _turn_to(direction: Vector3, delta: float) -> void:
	WalkRules.turn(self, direction, delta, WalkRules.TURN_RATE * 1.5)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
