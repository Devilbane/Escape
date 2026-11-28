class_name SweepDust
extends Node3D
## The snow dust (or, in autumn, the dry dust and crumbs of leaf) a broom kicks up (see SnowSweep, LeafSweep): the same soft, foggy puffs and few fine flakes the wind's flurries
## carry (see WindGusts), only a handful at a time and short-lived. They rise a little, drift away from the
## broom's stroke and thin out within a couple of seconds.
##
## Two MultiMeshes, one for the puffs and one for the flakes, drawn only while any are in the air.

const PUFFS := 60
const FLAKES := 120
## Leaves the broom flings up when it sweeps leaves (see kick_leaves).
const LEAVES := 70
const LEAF_SIZE := Vector2(0.14, 0.24)
const PUFF_ALPHA := WindGusts.PUFF_ALPHA
const PUFF_SIZE := Vector2(0.5, 1.1)
const FLAKE_SIZE := 0.05

var _puffs: Array = []
var _flakes: Array = []
var _soft: MultiMeshInstance3D
var _fine: MultiMeshInstance3D
var _flung: MultiMeshInstance3D
var _leaves: Array = []
var _now := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "SweepDust"
	_rng.randomize()


func _ready() -> void:
	_soft = _layer(PUFFS, true)
	_fine = _layer(FLAKES, false)
	_flung = _leaf_layer()
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


## The layer of flying leaves: flat quads that tumble, in the leaves' autumn colours.
func _leaf_layer() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = LEAVES
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Weather._leaf_texture()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = Graphics.vertex_colours_srgb()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 8.0
	inst.visible = false
	for i in LEAVES:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_color(i, Color.WHITE)
	add_child(inst)
	return inst


## The broom sweeps leaves at `at`: a burst of them flies up, tumbling, and flutters down again away from
## `away` (the way the stroke goes, a unit vector on the ground).
func kick_leaves(at: Vector3, away: Vector3) -> void:
	if _flung == null:
		return
	var scale_by := WindGusts.quality_scale()
	for i in maxi(2, roundi(6.0 * scale_by)):
		if _leaves.size() >= LEAVES:
			break
		var way := away.rotated(Vector3.UP, _rng.randf_range(-1.1, 1.1)) * _rng.randf_range(0.5, 1.6)
		_leaves.append({
			"from": at + Vector3(_rng.randf_range(-0.3, 0.3), 0.06, _rng.randf_range(-0.3, 0.3)),
			"vel": way + Vector3(0, _rng.randf_range(1.8, 3.4), 0),
			"start": _now, "dur": _rng.randf_range(0.9, 1.7), "size": _rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y),
			"spin": Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9)),
			"tint": LeafFall.TINTS[_rng.randi() % LeafFall.TINTS.size()],
		})
	_flung.visible = true
	set_process(true)


## The broom sweeps at `at`: a puff or two and a few flakes fly up, away from `away` (the way the
## stroke goes, a unit vector on the ground). `tint` colours the puffs and flakes (white for snow).
func kick(at: Vector3, away: Vector3, tint := Color.WHITE) -> void:
	if _soft == null:
		return
	var scale_by := WindGusts.quality_scale()
	for i in maxi(2, roundi(4.0 * scale_by)):
		if _puffs.size() >= PUFFS:
			break
		var way := away.rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0)) * _rng.randf_range(0.2, 0.7)
		_puffs.append({
			"from": at + Vector3(_rng.randf_range(-0.2, 0.2), 0.08, _rng.randf_range(-0.2, 0.2)),
			"drift": way * 1.4 + Vector3(0, _rng.randf_range(0.5, 1.1), 0),
			"start": _now, "dur": _rng.randf_range(1.4, 2.6), "size": _rng.randf_range(PUFF_SIZE.x, PUFF_SIZE.y), "tint": tint,
		})
	for i in maxi(3, roundi(9.0 * scale_by)):
		if _flakes.size() >= FLAKES:
			break
		var way := away.rotated(Vector3.UP, _rng.randf_range(-1.3, 1.3)) * _rng.randf_range(0.4, 1.4)
		_flakes.append({
			"from": at + Vector3(_rng.randf_range(-0.25, 0.25), 0.05, _rng.randf_range(-0.25, 0.25)),
			"drift": way + Vector3(0, _rng.randf_range(0.8, 1.8), 0),
			"start": _now, "dur": _rng.randf_range(0.8, 1.6), "tint": tint,
		})
	_soft.visible = true
	_fine.visible = true
	set_process(true)


func _process(delta: float) -> void:
	_now += delta
	_puffs = _puffs.filter(func(m: Dictionary) -> bool: return _now - float(m.start) < float(m.dur))
	_flakes = _flakes.filter(func(m: Dictionary) -> bool: return _now - float(m.start) < float(m.dur))
	_leaves = _leaves.filter(func(m: Dictionary) -> bool: return _now - float(m.start) < float(m.dur))
	_fly_leaves()
	var soft := _soft.multimesh
	var i := 0
	for m: Dictionary in _puffs:
		var t := (_now - float(m.start)) / float(m.dur)
		var rise := 1.0 - (1.0 - t) * (1.0 - t)
		var at: Vector3 = (m.from as Vector3) + (m.drift as Vector3) * rise * float(m.dur) * 0.5
		var fade := smoothstep(0.0, 0.15, t) * smoothstep(0.0, 0.6, 1.0 - t)
		var size: float = float(m.size) * (0.6 + 1.0 * t)
		soft.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), at))
		var tone: Color = m.tint
		soft.set_instance_color(i, Color(tone.r, tone.g, tone.b, PUFF_ALPHA * 1.8 * fade))
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
		var shade: Color = m.tint
		fine.set_instance_color(i, Color(shade.r, shade.g, shade.b, 0.85 * smoothstep(0.0, 0.1, t) * (1.0 - t)))
		i += 1
	for k in range(i, fine.instance_count):
		fine.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	if _puffs.is_empty() and _flakes.is_empty() and _leaves.is_empty():
		_soft.visible = false
		_fine.visible = false
		_flung.visible = false
		set_process(false)


## The flung leaves: thrown up, pulled down, they flutter on the way (sideways sway, a slow fall) and tumble.
func _fly_leaves() -> void:
	var mm := _flung.multimesh
	var i := 0
	for m: Dictionary in _leaves:
		var t := _now - float(m.start)
		var vel: Vector3 = m.vel
		# Up and away, then a slow flutter down (a leaf falls slower than a stone).
		var up := vel.y * t - 2.6 * t * t
		var at: Vector3 = (m.from as Vector3) + Vector3(vel.x * t, maxf(up, 0.0), vel.z * t)
		at += Vector3(sin(t * 7.0 + float(m.size) * 30.0), 0, cos(t * 6.0)) * 0.08 * minf(t, 1.0)
		var spin: Vector3 = m.spin
		var basis := Basis.from_euler(spin * t) * Basis().scaled(Vector3.ONE * float(m.size))
		# A leaf is gone by the time it lands: tumbling on the ground it cut through the paving and flickered.
		var life := minf(float(m.dur), maxf(vel.y / 2.6, 0.2))
		var fade := smoothstep(0.0, 0.08, t / life) * (1.0 - smoothstep(0.7, 1.0, t / life))
		if t >= life:
			fade = 0.0
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * maxf(fade, 0.01)), at))
		mm.set_instance_color(i, m.tint)
		i += 1
	for k in range(i, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
