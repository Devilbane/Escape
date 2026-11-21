class_name MerchantRaven
extends Node3D
## Zarek's familiar: a raven that travels with him and keeps him company on
## his nights in the village (see Outdoor._wanderer_arrives). It sits on his
## wagon (on the skylight strip, the porch rail, the barrel on the rack, see
## MerchantWagon) or on the brim of his hat, looks about, cocks its head, preens,
## ruffles its wings and now and then caws; every little while it flaps over
## to another of its spots. When the hero comes near it keeps an eye on them.
##
## It is a few simple shapes in glossy blue-black with amber eyes that catch
## the lantern light, moved by hand each frame (no physics, no collision: it
## is only company). It never fights and cannot be hurt.

## How long it sits (seconds) before flying to another spot, and how long a
## flight takes for each metre (with a least time), and how high the arc is.
const SIT := Vector2(6.0, 14.0)
const FLIGHT_PER_METRE := 0.28
const FLIGHT_MIN := 0.7
const ARC := 0.6
## Its wing beats a second while flying.
const FLAP := 7.0
## The hero within this range (metres) gets watched.
const WATCH := 6.0
## Where on the merchant it sits, from his feet: on the wide brim of his hat,
## over his left shoulder (his shoulder itself is under the brim).
const SHOULDER := Vector3(0.8, 1.62, 0.25)

## A big raven, a little bigger than life so it reads from the hero's view.
const SIZE := 1.3

const FEATHER := Color(0.06, 0.06, 0.09)
const SHEEN := Color(0.12, 0.14, 0.24)
const BEAK := Color(0.1, 0.09, 0.09)
const EYE := Color(1.0, 0.7, 0.25)

## The spots it sits on, in world space, and the merchant (his hat is
## spot -1).
var spots: Array[Vector3] = []
var master: Node3D
var level: Node

var _spot := -1
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flying := 0.0
var _flight := 0.0
var _sit := 3.0
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _look := 0.0
var _look_to := 0.0
var _look_timer := 1.0
var _tilt := 0.0
var _caw := 0.0
var _preen := 0.0
var _ruffle := 0.0

var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _wings: Array[Node3D] = []
var _tail: Node3D
var _legs: Node3D


## Sets it on the merchant's hat, with `perches` to fly between.
func setup(at_level: Node, merchant: Node3D, perches: Array[Vector3], seed_value: int) -> void:
	level = at_level
	master = merchant
	spots = perches
	_rng.seed = seed_value
	_build()
	scale = Vector3.ONE * SIZE
	_spot = -1
	global_position = _spot_at(_spot)
	_sit = _rng.randf_range(2.0, 5.0)


func _spot_at(i: int) -> Vector3:
	if i < 0 or i >= spots.size():
		if master and is_instance_valid(master):
			return master.global_position + master.global_basis * SHOULDER
		return global_position
	return spots[i]


func _process(delta: float) -> void:
	_time += delta
	if _flying > 0.0:
		_fly(delta)
	else:
		_sit_about(delta)
	_animate(delta)


func _sit_about(delta: float) -> void:
	# Ride along on his hat.
	global_position = _spot_at(_spot)
	if _spot < 0 and master and is_instance_valid(master):
		rotation.y = master.rotation.y
	_sit -= delta
	if _sit <= 0.0:
		_take_off()
		return
	_look_timer -= delta
	var hero: Node3D = level.get("player") if level else null
	if hero and hero.global_position.distance_to(global_position) < WATCH:
		var to := to_local(hero.global_position)
		_look_to = clampf(atan2(to.x, to.z), -1.6, 1.6)
	elif _look_timer <= 0.0:
		_look_timer = _rng.randf_range(0.6, 2.2)
		_look_to = _rng.randf_range(-1.4, 1.4)
		var roll := _rng.randf()
		if roll < 0.18:
			_caw = 0.6
		elif roll < 0.3:
			_preen = 1.2
		elif roll < 0.42:
			_ruffle = 0.5
		elif roll < 0.55 and _spot >= 0:
			# A little hop round on the spot.
			rotation.y += _rng.randf_range(-1.2, 1.2)
		_tilt = _rng.randf_range(-0.35, 0.35) if _rng.randf() < 0.5 else 0.0


func _take_off() -> void:
	var options: Array[int] = [-1]
	for i in spots.size():
		options.append(i)
	options.erase(_spot)
	if options.is_empty():
		_sit = SIT.y
		return
	_spot = options[_rng.randi() % options.size()]
	_from = global_position
	_to = _spot_at(_spot)
	_flight = maxf(FLIGHT_MIN, _from.distance_to(_to) * FLIGHT_PER_METRE)
	_flying = _flight
	var dir := _to - _from
	rotation.y = atan2(dir.x, dir.z)


func _fly(delta: float) -> void:
	_flying = maxf(_flying - delta, 0.0)
	var t := 1.0 - _flying / _flight
	var ease_t := t * t * (3.0 - 2.0 * t)
	_to = _spot_at(_spot)
	var pos := _from.lerp(_to, ease_t)
	pos.y += sin(t * PI) * (ARC + _from.distance_to(_to) * 0.08)
	global_position = pos
	if _flying <= 0.0:
		_sit = _rng.randf_range(SIT.x, SIT.y)
		_ruffle = 0.4
		if _spot < 0:
			rotation.y = master.rotation.y if master and is_instance_valid(master) else rotation.y
		else:
			rotation.y += _rng.randf_range(-2.0, 2.0)


func _animate(delta: float) -> void:
	_look = lerpf(_look, _look_to, minf(delta * 6.0, 1.0))
	var flying := _flying > 0.0
	_head.rotation = Vector3(0.0, _look, _tilt)
	_caw = maxf(_caw - delta, 0.0)
	_preen = maxf(_preen - delta, 0.0)
	_ruffle = maxf(_ruffle - delta, 0.0)
	# Caw: the head thrusts forward and the beak opens twice.
	var beak := 0.0
	if _caw > 0.0:
		beak = absf(sin(_caw * TAU * 1.6)) * 0.5
		_head.rotation.x = -0.25
	_jaw.rotation.x = beak
	if _preen > 0.0:
		# The head down into the wing.
		_head.rotation = Vector3(0.6, 1.2, 0.3)
	var spread := 0.0
	var beat := 0.0
	if flying:
		spread = 1.0
		beat = sin(_time * TAU * FLAP)
	elif _ruffle > 0.0:
		spread = 0.25
		beat = sin(_ruffle * TAU * 4.0) * 0.6
	for i in _wings.size():
		var s := -1.0 if i == 0 else 1.0
		_wings[i].rotation = Vector3(0.0, 0.0, s * (spread * (0.2 + beat * 0.9)))
		_wings[i].scale = Vector3(1.0 + spread * 1.3, 1, 1.0)
	_body.rotation.x = -0.15 if flying else 0.12 + sin(_time * 1.3) * 0.02
	_legs.visible = not flying or (_flight - _flying < 0.15) or _flying < 0.2
	_tail.rotation.x = 0.1 + (0.2 if flying else sin(_time * 0.9) * 0.05)


# --- The bird ---------------------------------------------------------------------

func _mat(c: Color, rough: float, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.2
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, s := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = s
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _egg(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return m


## About 0.45 m from beak to tail, like a real raven. Faces +z.
func _build() -> void:
	var plume := _mat(FEATHER, 0.35)
	var sheen := _mat(SHEEN, 0.3)
	var beak := _mat(BEAK, 0.4)
	var eye := _mat(EYE, 0.3, 1.6)
	_legs = Node3D.new()
	add_child(_legs)
	for s: float in [-1.0, 1.0]:
		_part(_legs, _cone(0.012, 0.09), beak, Vector3(s * 0.035, 0.045, 0.0), Vector3.ONE, Vector3(PI, 0, 0))
		for a: float in [-0.5, 0.0, 0.5]:
			_part(_legs, _cone(0.006, 0.05), beak, Vector3(s * 0.035 + sin(a) * 0.02, 0.004, cos(a) * 0.02), Vector3.ONE, Vector3(PI * 0.5, a, 0))
	_body = Node3D.new()
	_body.position = Vector3(0, 0.1, 0)
	add_child(_body)
	_part(_body, _egg(0.09), plume, Vector3(0, 0.07, 0), Vector3(0.85, 0.85, 1.35))
	_part(_body, _egg(0.07), sheen, Vector3(0, 0.1, 0.06), Vector3(0.9, 0.9, 1.0))
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.06, -0.1)
	_body.add_child(_tail)
	_part(_tail, BoxMesh.new(), plume, Vector3(0, -0.02, -0.08), Vector3(0.09, 0.015, 0.17), Vector3(0.25, 0, 0))
	for s: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(s * 0.07, 0.11, 0.02)
		_body.add_child(wing)
		_part(wing, _egg(0.06), sheen, Vector3(s * 0.03, -0.01, -0.06), Vector3(0.35, 0.55, 2.2), Vector3(0.1, 0, s * -0.2))
		_wings.append(wing)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.17, 0.1)
	_body.add_child(_head)
	_part(_head, _egg(0.055), plume, Vector3(0, 0.0, 0.0), Vector3(0.9, 0.9, 1.1))
	# The heavy beak, its upper half and the jaw that opens to caw.
	_part(_head, _cone(0.022, 0.09), beak, Vector3(0, 0.0, 0.085), Vector3(1, 1, 0.8), Vector3(PI * 0.5, 0, 0))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.012, 0.04)
	_head.add_child(_jaw)
	_part(_jaw, _cone(0.016, 0.07), beak, Vector3(0, -0.004, 0.035), Vector3(1, 0.6, 1), Vector3(PI * 0.5, 0, 0))
	for s: float in [-1.0, 1.0]:
		_part(_head, _egg(0.011), eye, Vector3(s * 0.04, 0.012, 0.03))
