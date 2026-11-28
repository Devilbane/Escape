class_name RainShield
extends Node3D
## When it rains, Priestess Elsbeth conjures a shield of magic like an umbrella above her head, so the
## rain does not wet her. It is light blue and see-through with a slow shimmer; every raindrop that
## lands on it bursts into a small puff of vapour. When the rain stops, it fades away.
##
## Cheap on purpose: one dome mesh with one shader, and one GPUParticles3D for the puffs (no node per
## drop). Villager calls `step` every physics tick, like StaffSpell: with a free moment she raises her
## staff first (the cast), on the move she conjures it at once.

## Who does it (see Villager.ROLES).
const ROLE := "O"
const POSE := "Spellcast_Raise"
## The short cast, the time the shield swells in, and the time it takes to fade out.
const CAST_TIME := 1.1
const SWELL_TIME := 0.7
const FADE_TIME := 1.6
## Size in metres (for a villager of scale 1): the radius of the dome, how high it arches and how
## far it floats over the top of the head.
const RADIUS := 0.8
const ARCH := 0.42
const FLOAT := 0.5
const RINGS := 8
const SEGMENTS := 48
const RIBS := 8
## How deep each scallop of the edge dips at a rib, as a part of the radius.
const SCALLOP := 0.07
## Vapour puffs: how many at most, how long each lives, how many points the dome offers them.
const PUFFS := 48
const PUFF_LIFE := 0.55
const POINTS := 96
const CHANT := "Schirm des Himmels, schütze mich!"
const SHADER := preload("res://shaders/rain_shield.gdshader")

var _villager: Villager
var _dome: MeshInstance3D
var _material: ShaderMaterial
var _puffs: GPUParticles3D
var _cast_left := 0.0
## 0 (gone) to 1 (fully up).
var _amount := 0.0
var _up := false
var _time := 0.0


## Hangs a RainShield on the villager. Returns it.
static func put_on(who: Villager) -> RainShield:
	var s := RainShield.new()
	s.name = "RainShield"
	s._villager = who
	who.add_child(s)
	return s


## The dome: a cap that arches up from the edge to a tip, whose edge dips into scallops at the ribs.
## UV.x runs round, UV.y from the tip (0) to the edge (1).
static func build_dome() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in RINGS + 1:
		var t := float(r) / RINGS
		# From the tip (t = 0) down to the edge (t = 1): a round cap.
		var ang := t * PI * 0.5
		var ring := sin(ang) * RADIUS
		var h := cos(ang) * ARCH
		for s in SEGMENTS + 1:
			var u := float(s) / SEGMENTS
			var a := u * TAU
			# The edge between two ribs lifts: a scallop, strongest at the rim.
			var scallop := (1.0 - absf(sin(u * RIBS * PI))) * SCALLOP * t * t * RADIUS
			var rr := ring
			var y := h + scallop
			verts.append(Vector3(cos(a) * rr, y, sin(a) * rr))
			norms.append(Vector3(cos(a) * sin(ang) * ARCH, cos(ang) * RADIUS, sin(a) * sin(ang) * ARCH).normalized())
			uvs.append(Vector2(u, t))
	for r in RINGS:
		for s in SEGMENTS:
			var i := r * (SEGMENTS + 1) + s
			var j := i + SEGMENTS + 1
			idx.append_array([i, j, i + 1, i + 1, j, j + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Points on the upper part of the dome and the way each faces, as two one-row textures for the
## particles to start from.
static func _points() -> Array[ImageTexture]:
	var pos := Image.create(POINTS, 1, false, Image.FORMAT_RGBF)
	var dir := Image.create(POINTS, 1, false, Image.FORMAT_RGBF)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in POINTS:
		# Rain comes straight down, so most drops land near the top: the angle from the tip leans
		# towards it.
		var t := pow(rng.randf(), 0.7)
		var ang := t * PI * 0.5 * 0.92
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * sin(ang) * RADIUS, cos(ang) * ARCH, sin(a) * sin(ang) * RADIUS)
		var n := Vector3(cos(a) * sin(ang) * ARCH, cos(ang) * RADIUS, sin(a) * sin(ang) * ARCH).normalized()
		pos.set_pixel(i, 0, Color(p.x, p.y, p.z))
		dir.set_pixel(i, 0, Color(n.x, n.y, n.z))
	return [ImageTexture.create_from_image(pos), ImageTexture.create_from_image(dir)]


func _ready() -> void:
	var scale_by := _villager._model.scale.x if _villager._model != null else 1.0
	position = Vector3(0, _head_top() + FLOAT * scale_by, 0)
	scale = Vector3.ONE * scale_by
	visible = false
	_dome = MeshInstance3D.new()
	_dome.name = "Dome"
	_dome.mesh = build_dome()
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("ribs", float(RIBS))
	_dome.material_override = _material
	add_child(_dome)
	_puffs = _make_puffs()
	add_child(_puffs)


## The height of the top of her head above her feet, in world metres (before our own scale).
func _head_top() -> float:
	return 1.85 * (_villager._model.scale.x if _villager._model != null else 1.0)


func _make_puffs() -> GPUParticles3D:
	var tex := _points()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	pm.emission_point_texture = tex[0]
	pm.emission_normal_texture = tex[1]
	pm.emission_point_count = POINTS
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0, 0.25, 0)
	pm.damping_min = 0.6
	pm.damping_max = 1.0
	pm.scale_min = 0.7
	pm.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.95, 1.0, 0.0))
	ramp.add_point(0.12, Color(0.9, 0.97, 1.0, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.92, 1.0, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var puff := QuadMesh.new()
	puff.size = Vector2(0.34, 0.34)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	soft.gradient = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft
	mat.billboard_keep_scale = true
	mat.no_depth_test = false
	puff.material = mat
	var p := GPUParticles3D.new()
	p.name = "Puffs"
	p.amount = PUFFS
	p.lifetime = PUFF_LIFE
	p.process_material = pm
	p.draw_pass_1 = puff
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 2, 3))
	return p


## Whether the shield is raised (or being raised) now.
func up() -> bool:
	return _up


## How much of it there is, 0 to 1.
func amount() -> float:
	return _amount


## Whether she is in the middle of the cast (her pose is held).
func casting() -> bool:
	return _cast_left > 0.0


## Whether it rains on her where she stands: rain or storm, in the open.
func rain_on_her() -> bool:
	var lvl := _villager.level as Outdoor
	if lvl == null or not (lvl.weather == Weather.RAIN or lvl.weather == Weather.STORM):
		return false
	return not lvl.is_sheltered(_villager.global_position)


## Conjures the shield at once (the end of the cast; also what she does on the move).
func conjure() -> void:
	if _up:
		return
	_up = true
	_cast_left = 0.0
	Sfx.play(_villager, "magic", -13.0, _villager.global_position, 1.6)


## Called by Villager every physics tick. `free` says she has a free moment for the cast; `here` is
## false while she is away (at home, hidden). Returns true while the cast holds her pose.
func step(delta: float, free: bool, here: bool) -> bool:
	var wanted := here and rain_on_her()
	if _cast_left > 0.0:
		if not free or not wanted:
			_cast_left = 0.0
			return false
		_cast_left -= delta
		_villager.play(POSE, 0.15)
		if _cast_left <= 0.0:
			conjure()
		return true
	if wanted and not _up:
		if free:
			_cast_left = CAST_TIME
			_villager.play(POSE, 0.15)
			_villager.say(CHANT, Vector3.INF, CAST_TIME + 0.8)
			Sfx.play(_villager, "magic", -10.0, _villager.global_position, 0.9)
			return true
		conjure()
	elif not wanted and _up:
		_up = false
	return false


func _process(delta: float) -> void:
	_time += delta
	var target := 1.0 if _up else 0.0
	var speed := 1.0 / SWELL_TIME if _up else 1.0 / FADE_TIME
	_amount = move_toward(_amount, target, speed * delta)
	visible = _amount > 0.0
	if not visible:
		_puffs.emitting = false
		return
	# Swells in from a point above her head, with an ease; fades out where it hangs.
	var swell := smoothstep(0.0, 1.0, minf(_amount * 1.0, 1.0))
	_dome.scale = Vector3.ONE * (0.25 + 0.75 * swell) if _up else Vector3.ONE
	_material.set_shader_parameter("fade", swell)
	# A little hover and sway.
	_dome.position.y = 0.025 * sin(_time * 1.8)
	var lvl := _villager.level as Outdoor
	var storm := lvl != null and lvl.weather == Weather.STORM
	_puffs.amount_ratio = 1.0 if storm else 0.6
	_puffs.emitting = _up and _amount > 0.9
