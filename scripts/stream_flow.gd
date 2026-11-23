class_name StreamFlow
extends Node3D
## Things drifting along a stretch of water: leaves, foam, bits of rubbish. They move at the pace of the
## current from one end of the stretch to the other, fade in and out at the ends and start over, so a
## stream or a channel visibly flows (the ground's water itself is a still picture). One MultiMesh, one
## draw call; the bits are flat on the surface and moved every frame (not physics bodies, see CLAUDE.md
## "Smooth motion": nothing here is interpolated).
##
## `from` and `to` are the middle line of the stretch (the surface height is `from.y`), `width` how far
## across it the bits spread, `kinds` the colours the bits take.

const LEAVES := [Color(0.62, 0.36, 0.12), Color(0.5, 0.3, 0.1), Color(0.42, 0.45, 0.14), Color(0.7, 0.5, 0.15)]
const FOAM := [Color(0.62, 0.66, 0.62), Color(0.56, 0.6, 0.58)]
const RUBBISH := [Color(0.34, 0.26, 0.16), Color(0.45, 0.4, 0.3), Color(0.27, 0.3, 0.2), Color(0.55, 0.5, 0.4), Color(0.3, 0.22, 0.14)]
## How far from each end the bits fade (fraction of the length).
const FADE := 0.08

var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 3.0
var speed := 0.5
var count := 60
var palette: Array = LEAVES
## Every `foam_every`-th bit is a long streak of foam instead.
var foam_every := 4
## Whether the bits are small bits of rubbish (bigger, squarer) instead of leaves.
var rubbish := false

var _mm: MultiMesh
var _phase: Array[float] = []
var _across: Array[float] = []
var _size: Array[Vector2] = []
var _spin: Array[float] = []
var _wobble: Array[float] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [from, to, count])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = count
	for i in count:
		_phase.append(rng.randf())
		_across.append(rng.randf_range(-0.5, 0.5))
		_spin.append(rng.randf_range(-0.6, 0.6))
		_wobble.append(rng.randf() * TAU)
		var streak := foam_every > 0 and i % foam_every == 0
		if streak:
			_size.append(Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.08, 0.14)))
			_mm.set_instance_color(i, FOAM[rng.randi() % FOAM.size()])
		elif rubbish:
			_size.append(Vector2(rng.randf_range(0.14, 0.36), rng.randf_range(0.1, 0.26)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
		else:
			_size.append(Vector2(rng.randf_range(0.16, 0.3), rng.randf_range(0.1, 0.18)))
			_mm.set_instance_color(i, palette[rng.randi() % palette.size()])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	_place()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_place()


## Puts every bit where it is `_time` seconds into its journey.
func _place() -> void:
	var line := to - from
	var length := line.length()
	if length < 0.01 or _mm == null:
		return
	var along := line / length
	var side := Vector3(-along.z, 0, along.x)
	var angle := atan2(along.x, along.z)
	for i in count:
		var t := fposmod(_phase[i] + _time * speed / length, 1.0)
		var fade := smoothstep(0.0, FADE, t) * smoothstep(1.0, 1.0 - FADE, t)
		var sway := sin(_time * 0.7 + _wobble[i]) * 0.12
		var at := from + along * (t * length) + side * (_across[i] * width + sway)
		var turn := angle + _spin[i] * sin(_time * 0.5 + _wobble[i]) + (0.0 if i % foam_every == 0 and foam_every > 0 else _spin[i])
		var basis := Basis(Vector3.UP, turn) * Basis.from_scale(Vector3(_size[i].y, 1.0, _size[i].x) * fade)
		_mm.set_instance_transform(i, Transform3D(basis, at))
