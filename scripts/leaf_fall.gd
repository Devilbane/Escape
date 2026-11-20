class_name LeafFall
extends MultiMeshInstance3D
## A few autumn leaves that drift down around the hero by day (see Weather.make_leaves).
## Each leaf sways and tumbles on its way down, and starts again above the hero when it
## lands or drifts too far. It moves in plain code, with its own random numbers, so the
## leaves never shift the game's rolls (the tests seed those). Keep `anchor` on the hero.

const COUNT := 36
## Half the width and depth of the box around the hero, and how high the leaves start.
const BOX := Vector3(16.0, 5.0, 11.0)
const FALL := Vector2(0.45, 0.8)
const SIZE := 0.2
## Falling leaf colours: orange, red, gold, yellow and browns (no green: these have turned).
const TINTS := [Color(0.78, 0.5, 0.16), Color(0.7, 0.28, 0.12), Color(0.62, 0.12, 0.08), Color(0.85, 0.65, 0.2),
		Color(0.88, 0.76, 0.22), Color(0.5, 0.28, 0.1), Color(0.38, 0.2, 0.08)]

var anchor := Vector3.ZERO
var material := StandardMaterial3D.new()
var _rng := RandomNumberGenerator.new()
var _pos := PackedVector3Array()
var _speed := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _time := 0.0


func _init() -> void:
	_rng.seed = 4242
	top_level = true
	visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = Weather._leaf_texture()
	material.albedo_color = Color(1, 1, 1, 0.0)
	quad.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = COUNT
	multimesh = mm
	custom_aabb = AABB(-BOX * 2.0, BOX * 4.0)
	for i in COUNT:
		_pos.append(Vector3(_rng.randf_range(-BOX.x, BOX.x), _rng.randf_range(0.2, BOX.y), _rng.randf_range(-BOX.z, BOX.z)))
		_speed.append(_rng.randf_range(FALL.x, FALL.y))
		_phase.append(_rng.randf_range(0.0, TAU))
		mm.set_instance_color(i, TINTS[_rng.randi() % TINTS.size()])


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in COUNT:
		var p := _pos[i]
		var ph := _phase[i]
		p.y -= _speed[i] * delta
		p.x += (0.5 + 0.35 * sin(_time * 0.9 + ph)) * delta
		p.z += 0.3 * cos(_time * 0.7 + ph) * delta
		if p.y < 0.1 or absf(p.x) > BOX.x or absf(p.z) > BOX.z:
			p = Vector3(_rng.randf_range(-BOX.x, BOX.x) - 4.0, BOX.y, _rng.randf_range(-BOX.z, BOX.z))
		_pos[i] = p
		var tumble := Basis.from_euler(Vector3(_time * 1.3 + ph, _time * 0.8 + ph * 2.0, _time * 1.7 + ph * 3.0))
		multimesh.set_instance_transform(i, Transform3D(tumble, anchor + p))
