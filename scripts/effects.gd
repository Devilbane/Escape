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


## Text that floats up from a point in the world and fades away.
## With `above_fog`, it is drawn even over walls and the fog of war, so
## what you just looted can never hide behind a wall.
## Texts at one spot, or over one creature, stack like damage numbers and
## never cover each other (see DamageNumber.show_at).
static func float_text(parent: Node, pos: Vector3, text: String, color: Color, above_fog := false) -> void:
	DamageNumber.show_at(parent, pos, text, color, above_fog)


## A damage number or a short word over `target`'s head. Unlike float_text it
## follows the head, and numbers over one head stack without overlapping.
static func head_text(parent: Node, target: Node3D, height: float, text: String, color: Color) -> void:
	DamageNumber.show_over(parent, target, Vector3(0, height, 0), text, color)


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


## A ring of flat-faced stone, like a carved basin or a block with `sides`
## faces, standing between the heights y0 and y1: outer wall, top, bottom and
## (if inner is above 0) the inner wall, with the normals of each face flat
## so the facets catch the light like cut stone. UVs run in metres along the
## circumference and up the height. The mesh's origin is the ring's centre at
## the floor.
static func ring_mesh(inner: float, outer: float, y0: float, y1: float, sides: int, material: Material, gaps: Array = []) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		if i in gaps:
			# A side left out (a broken-off piece): close the cut ends.
			for k in 2:
				var a := TAU * (i + k) / sides
				var turn := 1.0 if k == 0 else -1.0
				var d := Vector3(cos(a), 0, sin(a))
				var n := Vector3(-sin(a), 0, cos(a)) * turn
				var c := [d * inner + Vector3(0, y0, 0), d * inner + Vector3(0, y1, 0), d * outer + Vector3(0, y1, 0), d * outer + Vector3(0, y0, 0)]
				if k == 0:
					c.reverse()
				_face(st, c, n, [Vector2(0, y0), Vector2(0, y1), Vector2(1, y1), Vector2(1, y0)])
			continue
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := outer * a0
		var u1 := outer * a1
		var lo := Vector3(0, y0, 0)
		var hi := Vector3(0, y1, 0)
		# Outer wall, facing out.
		_face(st, [d0 * outer + lo, d0 * outer + hi, d1 * outer + hi, d1 * outer + lo],
				(d0 + d1).normalized(), [Vector2(u0, y0), Vector2(u0, y1), Vector2(u1, y1), Vector2(u1, y0)])
		# Top and bottom, each an octagon or a ring.
		var top := [d1 * inner + hi, d1 * outer + hi, d0 * outer + hi, d0 * inner + hi]
		var bottom := [d0 * inner + lo, d0 * outer + lo, d1 * outer + lo, d1 * inner + lo]
		var uv_top := top.map(func(v: Vector3): return Vector2(v.x, v.z))
		var uv_bottom := bottom.map(func(v: Vector3): return Vector2(v.x, v.z))
		_face(st, top, Vector3.UP, uv_top)
		_face(st, bottom, Vector3.DOWN, uv_bottom)
		if inner > 0.0:
			# Inner wall, facing the middle.
			_face(st, [d1 * inner + lo, d1 * inner + hi, d0 * inner + hi, d0 * inner + lo],
					-(d0 + d1).normalized(), [Vector2(u1, y0), Vector2(u1, y1), Vector2(u0, y1), Vector2(u0, y0)])
	st.set_material(material)
	return st.commit()


## One flat face of four corners (counter-clockwise seen from outside) as two triangles.
static func _face(st: SurfaceTool, corners: Array, normal: Vector3, uvs: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])


## Drops of water thrown up by a fountain's spout: soft, pale glints that rise
## a little and fall back into the basin.
static func make_spray(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 1.1
	p.mesh = _quad(0.13, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.direction = Vector3.UP
	p.spread = 22.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 2.4
	p.initial_velocity_max = 3.3
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.9))
	ramp.add_point(0.7, Color(color, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = ramp
	return p


## Wood chips that fly off where an axe bites into a trunk: a burst of pale
## splinters thrown up and to the sides, tumbling down again. Waits until
## restart() is called for each blow.
static func make_wood_chips() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	var chip := BoxMesh.new()
	chip.size = Vector3(0.1, 0.02, 0.06)
	chip.material = _paint(Color(0.86, 0.7, 0.48), 0.9)
	p.mesh = chip
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 3.4
	p.particle_flag_rotate_y = true
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.75, 1))
	shrink.add_point(Vector2(1, 0))
	p.scale_amount_curve = shrink
	return p


## Sparks that fly off hot iron under the smith's hammer: a quick burst of
## tiny glowing bits, thrown out low and wide, that fall and fade. Waits until
## restart() is called for each blow.
static func make_forge_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.mesh = _quad(0.06, Color(1, 1, 1))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6))
	ramp.add_point(0.4, Color(1.0, 0.6, 0.15))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = ramp
	return p


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


## A plain coloured, slightly matt material for built props.
static func _paint(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


static func _part(mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	return mi


## A barber's pole: a slim post with a spiral of red, white and blue
## stripes under a gold knob, about 2.6 m high, standing on the ground.
static func barber_pole() -> Node3D:
	var pole := Node3D.new()
	pole.name = "BarberPole"
	var wood := _paint(Color(0.3, 0.2, 0.12))
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.09
	post.height = 2.6
	pole.add_child(_part(post, wood, Vector3(0, 1.3, 0)))
	var colors := [Color(0.85, 0.1, 0.1), Color(0.95, 0.95, 0.95), Color(0.15, 0.25, 0.8)]
	var mats := [_paint(colors[0], 0.5), _paint(colors[1], 0.5), _paint(colors[2], 0.5)]
	# The stripes: short slanted rings stacked up the post, each turned a
	# little further round, so they wind up it like a ribbon.
	const RINGS := 18
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.2
	ring.rings = 24
	ring.ring_segments = 8
	for i in RINGS:
		var y := 1.45 + i * 0.07
		var tilt := Vector3(0.45, i * 0.7, 0.0)
		pole.add_child(_part(ring, mats[i % 3], Vector3(0, y, 0), tilt))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.2
	cap.bottom_radius = 0.2
	cap.height = 0.06
	var gold := _paint(Color(1.0, 0.78, 0.3), 0.35, 0.7)
	pole.add_child(_part(cap, gold, Vector3(0, 1.42, 0)))
	pole.add_child(_part(cap, gold, Vector3(0, 2.72, 0)))
	var knob := SphereMesh.new()
	knob.radius = 0.17
	knob.height = 0.34
	pole.add_child(_part(knob, gold, Vector3(0, 2.88, 0)))
	return pole


## A hanging shop sign: a wooden board on a post with the shop's name and a
## pair of scissors above it, facing +Z. About 2.6 m high.
static func shop_sign(text: String, font: Font) -> Node3D:
	var board_sign := Node3D.new()
	board_sign.name = "ShopSign"
	var wood := _paint(Color(0.3, 0.2, 0.12))
	var board_wood := _paint(Color(0.55, 0.38, 0.2))
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.09
	post.height = 2.6
	board_sign.add_child(_part(post, wood, Vector3(0, 1.3, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(1.2, 0.08, 0.08)
	board_sign.add_child(_part(arm, wood, Vector3(0.5, 2.55, 0)))
	var board := BoxMesh.new()
	board.size = Vector3(1.1, 0.7, 0.06)
	board_sign.add_child(_part(board, board_wood, Vector3(0.55, 2.05, 0)))
	for x in [0.15, 0.95]:
		var chain := CylinderMesh.new()
		chain.top_radius = 0.015
		chain.bottom_radius = 0.015
		chain.height = 0.16
		board_sign.add_child(_part(chain, _paint(Color(0.5, 0.5, 0.55), 0.4, 0.8), Vector3(x, 2.47, 0)))
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 56
	label.pixel_size = 0.004
	label.modulate = Color(0.1, 0.06, 0.03)
	label.position = Vector3(0.55, 1.9, 0.035)
	label.no_depth_test = false
	board_sign.add_child(label)
	# Scissors: two crossed blades with a ring handle each, painted on the board.
	var steel := _paint(Color(0.8, 0.82, 0.86), 0.3, 0.9)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 0.3, 0.02)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.04
	handle.outer_radius = 0.07
	handle.rings = 16
	handle.ring_segments = 6
	for side in [-1.0, 1.0]:
		var a: float = side * 0.35
		board_sign.add_child(_part(blade, steel, Vector3(0.55 + sin(a) * 0.03, 2.24, 0.04), Vector3(0, 0, a)))
		board_sign.add_child(_part(handle, steel, Vector3(0.55 - sin(a) * 0.17, 2.1, 0.04), Vector3(PI * 0.5, 0, 0)))
	return board_sign
