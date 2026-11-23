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
const ROAM := 4
## The hedgehog's size against the real thing (the world is big, like the squirrel's).
const SIZE := 1.3
## From this hour in the evening until this hour in the morning it is about.
const DUSK := 17.5
const DAWN := 7.0
## The model's ground level (the lowest foot) and how far it sinks when curled (model units).
const FOOT := 0.142
const SINK := 0.08

## "snuffle" (nose down, searching), "walk", "curl" (rolled up, scared) or
## "sleep" (rolled up by day or all winter).
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


## Whether it is its time of day: dusk to dawn, and not in winter.
func awake_time() -> bool:
	if Weather.is_winter(int(level.get("season_day"))):
		return false
	if level.get("night") == true:
		return true
	var h: float = level.get("hour")
	return h >= DUSK or (h >= 0.0 and h < DAWN)


func shy_distance() -> float:
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
	match state:
		"snuffle":
			_timer -= delta
			if near or not awake:
				_roll_up()
			elif _timer <= 0.0:
				_next()
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
				if awake:
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
	_calm = 0.0
	_begin("curl", 0.0)


## Calm again: snuffle on, or waddle to another spot.
func _next() -> void:
	if _rng.randf() < 0.35:
		_begin("snuffle", _rng.randf_range(2.0, 6.0))
		return
	if _set_path(_nearby(ROAM)):
		_begin("walk", 0.0)
	else:
		_begin("snuffle", 2.0)


## Waddles along its path.
func _walk(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _flat(_path[0] - global_position)
	var step := WALK * delta
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
	var want := 1.0 if is_curled() else 0.0
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
		"walk":
			pitch = 0.1 + sin(_phase * 2.0) * 0.03
			roll = sin(_phase) * 0.09
			bob = absf(sin(_phase)) * 0.012
	# Rolled up: the head goes down and the rump up, the body shortens and rounds.
	_tilt.rotation.x = pitch * up + 0.6 * k
	_tilt.rotation.z = roll * up
	_tilt.scale = Vector3(1.0 + 0.12 * k, 1.0 + 0.08 * k, 1.0 - 0.25 * k)
	_tilt.position.y = FOOT + bob * up - SINK * k


func _set_path(target: Vector3) -> bool:
	_path.assign(WalkRules.path(level, global_position, target, _rng))
	return not _path.is_empty()


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
