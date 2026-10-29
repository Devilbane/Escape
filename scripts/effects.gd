class_name Effects
extends RefCounted
## Small particle effects built in code: torch flames, sparkles, dust.


static func _glow_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = _soft_dot()
	return mat


static var _dot: Texture2D

static func _soft_dot() -> Texture2D:
	if _dot == null:
		var tex := GradientTexture2D.new()
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		tex.gradient = g
		_dot = tex
	return _dot


static func _quad(size: float, color: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _glow_material(color)
	return q


static func make_flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.55
	p.mesh = _quad(0.32, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.07
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.6))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = scale_curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.35, 0.75))
	ramp.add_point(0.35, Color(1.0, 0.45, 0.1, 0.65))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.15, 0.05, 0.0))
	p.color_ramp = ramp
	return p


static func make_sparkles(color: Color, one_shot := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40 if one_shot else 14
	p.lifetime = 1.4
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.mesh = _quad(0.18, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 if one_shot else 0.9
	p.direction = Vector3.UP
	p.spread = 60.0 if one_shot else 180.0
	p.gravity = Vector3(0, -4.0, 0) if one_shot else Vector3(0, 0.3, 0)
	p.initial_velocity_min = 2.0 if one_shot else 0.05
	p.initial_velocity_max = 4.5 if one_shot else 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.2, color)
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = ramp
	if one_shot:
		p.emitting = true
		p.finished.connect(p.queue_free)
	return p


static func make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.mesh = _quad(0.07, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16, 3, 12)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.gravity = Vector3(0, 0.02, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.6, 0.0))
	ramp.add_point(0.5, Color(1.0, 0.85, 0.6, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.85, 0.6, 0.0))
	p.color_ramp = ramp
	return p


static var _check: Texture2D

## A small round badge with a tick, shown above searched objects.
static func searched_icon() -> Texture2D:
	if _check == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var center := Vector2(size, size) * 0.5
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
				if d < 30.0:
					var edge := clampf(30.0 - d, 0.0, 1.0)
					var ring := d > 25.0
					img.set_pixel(x, y, Color(0.85, 0.7, 0.35, edge) if ring else Color(0.12, 0.08, 0.14, 0.85 * edge))
		var tick: Array[Vector2] = [Vector2(18, 33), Vector2(28, 43), Vector2(46, 22)]
		for i in tick.size() - 1:
			var a := tick[i]
			var b := tick[i + 1]
			for s in 60:
				var p := a.lerp(b, s / 59.0)
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						if Vector2(ox, oy).length() <= 3.2:
							img.set_pixel(int(p.x) + ox, int(p.y) + oy, Color(0.55, 0.95, 0.5))
		_check = ImageTexture.create_from_image(img)
	return _check


## Text that floats up from a point in the world and fades away.
static func float_text(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.font_size = 64
	label.pixel_size = 0.012
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.02, 0.06)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	parent.add_child(label)
	label.global_position = pos
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", pos + Vector3(0, 1.6, 0), 1.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)
