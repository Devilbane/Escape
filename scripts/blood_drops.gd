class_name BloodDrops
extends Node3D
## Blood from a bleeding body (see Bleeding): small drops fall to the floor and
## leave spots there, a mover leaves a trail of them, one who stands still
## bleeds a stain that grows, and one who bleeds out leaves a pool.
##
## It stays cheap: one BloodDrops per level holds a fixed number of spots
## (MAX_SPLATS; the oldest is reused when they are all down) and of falling
## drops (MAX_DROPS), which all share one material and a few meshes. A spot
## dries and shrinks away in the last FADE seconds of its LIFE. No blood falls
## on water or into a wall.

const MAX_SPLATS := 90
const MAX_DROPS := 20
## Seconds a spot lasts, the last FADE of them it shrinks away.
const LIFE := 120.0
const FADE := 40.0
const GRAVITY := 9.8
## Height of the blood above the floor (the dungeon's cobbles stick up a little).
const FLOOR_Y_DUNGEON := 0.075
const FLOOR_Y_OUTDOOR := 0.035
## How big the spot of one drop is (metres), and the most a stain grows to.
const SPOT := 0.07
const STAIN_MAX := 0.32
## A drop landing this close to a fresh spot makes that stain grow instead.
const MERGE := 0.3
const VARIANTS := 4
## The tiles of open water (see Tiles.OUTDOOR): the ponds.
const WATER_LETTERS := "~;"

static var _meshes: Array[ArrayMesh] = []
static var _drop_mesh: SphereMesh

var _level: Level
var _splats: Array = []  # {node, born, radius, flat, size}
var _next := 0
var _drops: Array = []  # {node, speed, size, heading, active}
var _fade_timer := 0.0


## The blood of `level`, made when it is first needed.
static func of(level: Level) -> BloodDrops:
	var found := level.get_node_or_null("BloodDrops")
	if found:
		return found
	var b := BloodDrops.new()
	b.name = "BloodDrops"
	b._level = level
	level.add_child(b)
	return b


## A drop of blood leaves a body at `at` (its feet) and falls from `height`
## above. `heading` is the way it moves (zero when it stands); `size` scales
## the spot with the body.
static func drip(level: Level, at: Vector3, height: float, heading := Vector3.ZERO, size := 1.0) -> void:
	if level == null:
		return
	of(level)._start_drop(at, height, heading, size)


## Blood spreads where a body bleeds out: a pool of `radius` metres.
static func pool(level: Level, at: Vector3, radius: float) -> void:
	if level == null:
		return
	of(level)._splat(at, radius, Vector3.ZERO, true)


## Whether blood can lie at `at`: open floor, not water, not stone.
func can_lie(at: Vector3) -> bool:
	var ch := _level.cell_char(_level.world_to_cell(at))
	if ch == "#":
		return false
	return not (_level.outdoor and WATER_LETTERS.contains(ch))


func _floor_y() -> float:
	return FLOOR_Y_OUTDOOR if _level.outdoor else FLOOR_Y_DUNGEON


func _start_drop(at: Vector3, height: float, heading: Vector3, size: float) -> void:
	if not can_lie(at):
		return
	var d: Dictionary
	if _drops.size() < MAX_DROPS:
		var mi := MeshInstance3D.new()
		mi.mesh = _drop_shape()
		mi.material_override = BloodStains.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		d = {"node": mi, "active": false}
		_drops.append(d)
	else:
		for e: Dictionary in _drops:
			if not e.active:
				d = e
				break
		if d.is_empty():
			return # every drop is still falling: skip this one
	var scatter := Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12)) * size
	d.active = true
	d.speed = 0.0
	d.size = size
	d.heading = heading
	d.node.visible = true
	d.node.global_position = Vector3(at.x, _floor_y() + maxf(height, 0.2), at.z) + scatter
	set_process(true)


func _process(delta: float) -> void:
	var busy := false
	for d: Dictionary in _drops:
		if not d.active:
			continue
		var node: MeshInstance3D = d.node
		d.speed += GRAVITY * delta
		var y: float = node.global_position.y - d.speed * delta
		if y <= _floor_y():
			d.active = false
			node.visible = false
			var at := Vector3(node.global_position.x, 0, node.global_position.z)
			_land(at, d.size, d.heading)
		else:
			node.global_position.y = y
			busy = true
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_fade_timer = 0.5
		_age_splats()
	set_process(busy or not _splats.is_empty())


## A drop lands: it grows a fresh stain close by, or leaves a new spot.
func _land(at: Vector3, size: float, heading: Vector3) -> void:
	if not can_lie(at):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in mini(_splats.size(), 8):
		var s: Dictionary = _splats[(_next - 1 - i + _splats.size() * 2) % _splats.size()]
		var near: Vector3 = s.node.global_position
		if now - s.born < 30.0 and Vector2(near.x - at.x, near.z - at.z).length() < MERGE * size and s.radius < STAIN_MAX * size:
			s.radius = minf(s.radius + 0.025 * size, STAIN_MAX * size)
			s.born = now
			_shape(s)
			return
	_splat(at, SPOT * size * randf_range(0.8, 1.3), heading, false)


## Puts a spot of `radius` down at `at`, stretched along `heading` if it moves.
func _splat(at: Vector3, radius: float, heading: Vector3, wide: bool) -> void:
	if not can_lie(at):
		return
	var s: Dictionary
	if _splats.size() < MAX_SPLATS:
		var mi := MeshInstance3D.new()
		mi.mesh = _blob_shape(randi() % VARIANTS)
		mi.material_override = BloodStains.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		s = {"node": mi}
		_splats.append(s)
		_next = _splats.size() % MAX_SPLATS
	else:
		s = _splats[_next]  # the oldest
		_next = (_next + 1) % MAX_SPLATS
	s.born = Time.get_ticks_msec() / 1000.0
	s.radius = radius
	s.flat = Vector2.ONE
	if heading.length_squared() > 0.01:
		s.flat = Vector2(1.6, 0.8)  # smeared along the way it ran
	s.node.rotation.y = atan2(-heading.z, heading.x) if heading.length_squared() > 0.01 else randf() * TAU
	# Newer spots lie a hair above older ones, so they never flicker together.
	s.node.global_position = Vector3(at.x, _floor_y() + (s.born - floorf(s.born / 8.0) * 8.0) * 0.0004, at.z)
	s.node.visible = true
	_shape(s)
	set_process(true)


func _shape(s: Dictionary) -> void:
	s.node.scale = Vector3(s.radius * s.flat.x, 1.0, s.radius * s.flat.y)


## Old spots shrink away at the end of their life and free their place.
func _age_splats() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for s: Dictionary in _splats:
		if not s.node.visible:
			continue
		var age: float = now - s.born
		if age >= LIFE:
			s.node.visible = false
		elif age > LIFE - FADE:
			var k := (LIFE - age) / FADE
			s.node.scale = Vector3(s.radius * s.flat.x * k, 1.0, s.radius * s.flat.y * k)


static func _drop_shape() -> SphereMesh:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.025
		_drop_mesh.height = 0.07
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
	return _drop_mesh


## One of a few ragged blobs of radius 1, shared by every spot.
static func _blob_shape(i: int) -> ArrayMesh:
	if _meshes.is_empty():
		for k in VARIANTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4100 + k
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			BloodStains._blob(st, rng, Vector2.ZERO, 1.0, 0, 12, 0.3)
			_meshes.append(st.commit())
	return _meshes[i]
