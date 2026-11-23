class_name SweepDust
extends Node3D
## The snow dust a broom kicks up (see SnowSweep): the same soft, foggy puffs and few fine flakes the wind's flurries
## carry (see WindGusts), only a handful at a time and short-lived. They rise a little, drift away from the
## broom's stroke and thin out within a couple of seconds.
##
## Two MultiMeshes, one for the puffs and one for the flakes, drawn only while any are in the air.

const PUFFS := 36
const FLAKES := 60
const PUFF_ALPHA := WindGusts.PUFF_ALPHA
const PUFF_SIZE := Vector2(0.35, 0.8)
const FLAKE_SIZE := 0.05

var _puffs: Array = []
var _flakes: Array = []
var _soft: MultiMeshInstance3D
var _fine: MultiMeshInstance3D
var _now := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "SweepDust"
	_rng.randomize()


func _ready() -> void:
	_soft = _layer(PUFFS, true)
	_fine = _layer(FLAKES, false)
	set_process(false)


func _layer(count: int, soft: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.albedo_color = Color(0.92, 0.95, 1.0, 1.0)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if soft:
		var tex := GradientTexture2D.new()
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		tex.gradient = ramp
		mat.albedo_texture = tex
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 8.0
	inst.visible = false
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_color(i, Color(1, 1, 1, 0))
	add_child(inst)
	return inst


## The broom sweeps at `at`: a puff or two and a few flakes fly up, away from `away` (the way the
## stroke goes, a unit vector on the ground).
func kick(at: Vector3, away: Vector3) -> void:
	if _soft == null:
		return
	var scale_by := WindGusts.quality_scale()
	for i in maxi(1, roundi(2.0 * scale_by)):
		if _puffs.size() >= PUFFS:
			break
		var way := away.rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0)) * _rng.randf_range(0.2, 0.7)
		_puffs.append({
			"from": at + Vector3(_rng.randf_range(-0.2, 0.2), 0.08, _rng.randf_range(-0.2, 0.2)),
			"drift": way + Vector3(0, _rng.randf_range(0.25, 0.6), 0),
			"start": _now, "dur": _rng.randf_range(1.4, 2.6), "size": _rng.randf_range(PUFF_SIZE.x, PUFF_SIZE.y),
		})
	for i in maxi(1, roundi(3.0 * scale_by)):
		if _flakes.size() >= FLAKES:
			break
		var way := away.rotated(Vector3.UP, _rng.randf_range(-1.3, 1.3)) * _rng.randf_range(0.4, 1.4)
		_flakes.append({
			"from": at + Vector3(_rng.randf_range(-0.25, 0.25), 0.05, _rng.randf_range(-0.25, 0.25)),
			"drift": way + Vector3(0, _rng.randf_range(0.4, 1.0), 0),
			"start": _now, "dur": _rng.randf_range(0.8, 1.6),
		})
	_soft.visible = true
	_fine.visible = true
	set_process(true)


func _process(delta: float) -> void:
	_now += delta
	_puffs = _puffs.filter(func(m: Dictionary) -> bool: return _now - float(m.start) < float(m.dur))
	_flakes = _flakes.filter(func(m: Dictionary) -> bool: return _now - float(m.start) < float(m.dur))
	var soft := _soft.multimesh
	var i := 0
	for m: Dictionary in _puffs:
		var t := (_now - float(m.start)) / float(m.dur)
		var rise := 1.0 - (1.0 - t) * (1.0 - t)
		var at: Vector3 = (m.from as Vector3) + (m.drift as Vector3) * rise * float(m.dur) * 0.5
		var fade := smoothstep(0.0, 0.15, t) * smoothstep(0.0, 0.6, 1.0 - t)
		var size: float = float(m.size) * (0.6 + 1.0 * t)
		soft.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), at))
		soft.set_instance_color(i, Color(1, 1, 1, PUFF_ALPHA * 1.8 * fade))
		i += 1
	for k in range(i, soft.instance_count):
		soft.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var fine := _fine.multimesh
	i = 0
	for m: Dictionary in _flakes:
		var t := (_now - float(m.start)) / float(m.dur)
		var at: Vector3 = (m.from as Vector3) + (m.drift as Vector3) * t * float(m.dur) * 0.6 - Vector3(0, 0.9 * t * t, 0)
		at.y = maxf(at.y, 0.05)
		fine.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * FLAKE_SIZE), at))
		fine.set_instance_color(i, Color(1, 1, 1, 0.85 * smoothstep(0.0, 0.1, t) * (1.0 - t)))
		i += 1
	for k in range(i, fine.instance_count):
		fine.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	if _puffs.is_empty() and _flakes.is_empty():
		_soft.visible = false
		_fine.visible = false
		set_process(false)
