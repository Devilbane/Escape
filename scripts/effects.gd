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


## A round cord following a list of line segments ([from, to] pairs).
static func cord_mesh(segments: Array, radius: float, material: Material) -> ArrayMesh:
	const SIDES := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in segments:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var along := (b - a).normalized()
		var side := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(along)
		# Overlap each piece a little so the joints stay closed.
		a -= along * radius * 0.6
		b += along * radius * 0.6
		for i in SIDES:
			var t0 := TAU * i / SIDES
			var t1 := TAU * (i + 1) / SIDES
			var n0 := side * cos(t0) + up * sin(t0)
			var n1 := side * cos(t1) + up * sin(t1)
			for p in [[a, n0], [b, n0], [b, n1], [a, n0], [b, n1], [a, n1]]:
				st.set_normal(p[1])
				st.add_vertex(p[0] + p[1] * radius)
	st.set_material(material)
	return st.commit()


## The open edges of a mesh: edges that belong to only one triangle.
static func open_edges(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := {}
	var ends := {}
	for t in range(0, index.size(), 3):
		for k in 3:
			var a := verts[index[t + k]]
			var b := verts[index[t + (k + 1) % 3]]
			var ka := Vector3i((a * 1000.0).round())
			var kb := Vector3i((b * 1000.0).round())
			var key := [ka, kb] if str(ka) < str(kb) else [kb, ka]
			count[key] = count.get(key, 0) + 1
			ends[key] = [a, b]
	var result := []
	for key in count:
		if count[key] == 1:
			result.append(ends[key])
	return result


## A soft white feather, about 0.7 m long, growing along +Y and curling back.
static func feather_mesh() -> ArrayMesh:
	const STEPS := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := []
	for i in STEPS + 1:
		var t := float(i) / STEPS
		spine.append(Vector3(0, t * 0.7, -t * t * 0.22))
	for i in STEPS:
		var t0 := float(i) / STEPS
		var t1 := float(i + 1) / STEPS
		# Narrow at the quill, widest past the middle, pointed at the tip.
		# Every other step is a little narrower, which reads as separate barbs.
		var w0 := 0.1 * sin(pow(t0, 0.8) * PI) * (1.0 if i % 2 == 0 else 0.8)
		var w1 := 0.1 * sin(pow(t1, 0.8) * PI) * (0.8 if i % 2 == 0 else 1.0)
		var p0: Vector3 = spine[i]
		var p1: Vector3 = spine[i + 1]
		# The vane droops a little towards its edges.
		var l0 := p0 + Vector3(-w0, -w0 * 0.25, 0)
		var r0 := p0 + Vector3(w0, -w0 * 0.25, 0)
		var l1 := p1 + Vector3(-w1, -w1 * 0.25, 0)
		var r1 := p1 + Vector3(w1, -w1 * 0.25, 0)
		var n := (p1 - p0).cross(Vector3.RIGHT).normalized()
		for p in [p0, l0, l1, p0, l1, p1, p0, p1, r1, p0, r1, r0]:
			st.set_normal(n)
			st.add_vertex(p)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.96, 0.92)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.55, 0.52)
	st.set_material(mat)
	var mesh := st.commit()
	# A thin pale quill down the middle.
	var quill := StandardMaterial3D.new()
	quill.albedo_color = Color(0.85, 0.82, 0.75)
	var segments := []
	for i in STEPS:
		segments.append([spine[i] + Vector3(0, 0, 0.004), spine[i + 1] + Vector3(0, 0, 0.004)])
	var quill_mesh := cord_mesh(segments, 0.008, quill)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quill_mesh.surface_get_arrays(0))
	mesh.surface_set_material(1, quill)
	return mesh
