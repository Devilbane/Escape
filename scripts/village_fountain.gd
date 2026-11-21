class_name VillageFountain
## The healing fountain on the village square: a large, round basin of pale carved stone on two
## round steps, with a turned pedestal carrying a wide bowl, a small upper bowl on a slim stem, and
## on top a little marble goddess in a light, belted gown in the classical manner. She holds an urn
## at her hip that pours into the upper bowl; the water runs over the bowls' lips in rings of drops
## drops back into the basin. Its water glows faintly and breathes, as it heals.
##
## Everything is turned on a lathe (see lathe_mesh), so the stone is smoothly round. The dungeon's
## forgotten fountains keep their own, smaller eight-sided look (Level._build_fountain).

## The basin's measures (m): the water's radius and height, the coping's outer radius and top.
const WATER_RADIUS := 2.26
const WATER := 0.92
const RIM_RADIUS := 2.72
const RIM_TOP := 1.1
## The outermost step: the fountain's footprint.
const STEP_RADIUS := 3.0
## The wide bowl on the pedestal: its water's radius and height.
const BOWL_RADIUS := 1.32
const BOWL_WATER := 2.42
## The small upper bowl.
const TOP_BOWL_RADIUS := 0.56
const TOP_BOWL_WATER := 3.21
## Where the goddess stands (the top of her plinth) and how tall she is.
const STATUE_FOOT := 3.55
const STATUE_HEIGHT := 1.55
## How much larger than FountainGoddess builds her.
const STATUE_SCALE := 1.2
## Round as the lathe turns the stone.
const SIDES := 48

const STONE := Color(0.62, 0.6, 0.56)
const MARBLE := Color(0.7, 0.68, 0.64)


## Builds the fountain into `level` (a Level) at `pos`, with its round collision.
static func build(level: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "VillageFountain"
	root.position = pos
	level.add_child(root)
	var stone := _stone(level, STONE)
	var wet := _stone(level, Color(0.32, 0.33, 0.34))
	var water := _water(WATER_RADIUS, 1.0, 22.0)
	var bowl_water := _water(BOWL_RADIUS, 0.45, 40.0)
	var top_water := _water(TOP_BOWL_RADIUS, 0.3, 45.0)
	# Two round steps.
	_add(root, lathe_mesh(_steps(), SIDES, stone))
	# The basin's floor, under the water.
	_add(root, Effects.ring_mesh(0.0, 2.28, 0.28, 0.4, SIDES, wet))
	_add(root, lathe_mesh(_basin(), SIDES, stone))
	_add(root, Effects.ring_mesh(0.0, WATER_RADIUS + 0.01, 0.4, WATER, SIDES, water), false)
	# The pedestal and the wide bowl it carries, the stem and the small bowl, the goddess's plinth.
	_add(root, lathe_mesh(_pedestal(), SIDES, stone))
	_add(root, Effects.ring_mesh(0.0, BOWL_RADIUS, BOWL_WATER - 0.08, BOWL_WATER, SIDES, bowl_water), false)
	_add(root, lathe_mesh(_upper(), SIDES, stone))
	_add(root, Effects.ring_mesh(0.0, TOP_BOWL_RADIUS, TOP_BOWL_WATER - 0.05, TOP_BOWL_WATER, 32, top_water), false)
	_add(root, lathe_mesh(_plinth(), 32, stone))
	var goddess := FountainGoddess.build(_marble())
	goddess.position = Vector3(0, STATUE_FOOT, 0)
	goddess.scale = Vector3.ONE * STATUE_SCALE
	root.add_child(goddess)
	_add_falling_water(root, goddess)
	# The healing glow.
	var motes := Effects.make_sparkles(Color(0.6, 0.9, 0.9))
	motes.amount = 12
	motes.emission_sphere_radius = 1.9
	motes.position = Vector3(0, 1.3, 0)
	root.add_child(motes)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.85, 0.85)
	glow.light_energy = 0.9
	glow.omni_range = 8.0
	glow.position = Vector3(0, 1.8, 0)
	root.add_child(glow)
	var tween := glow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow, "light_energy", 1.15, 2.4)
	tween.tween_property(glow, "light_energy", 0.75, 2.4)
	# Round, as it is drawn: the hero walks along the rim, not along a box round it.
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RIM_RADIUS
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = pos + Vector3(0, 1.0, 0)
	level._walls_body.add_child(shape)


static func _add(root: Node3D, mesh: Mesh, shadow := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if not shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node


## The square's weathered stone (see Level._decayed_stone), its lime lines where this fountain's
## water stands.
static func _stone(level: Node3D, colour: Color) -> ShaderMaterial:
	var stone: ShaderMaterial = level._decayed_stone(colour, 0.2).duplicate()
	stone.set_shader_parameter("water_line_a", WATER)
	stone.set_shader_parameter("water_radius_a", WATER_RADIUS + 0.04)
	stone.set_shader_parameter("water_floor_a", 0.28)
	stone.set_shader_parameter("water_line_b", BOWL_WATER)
	stone.set_shader_parameter("water_radius_b", BOWL_RADIUS + 0.04)
	stone.set_shader_parameter("water_floor_b", BOWL_WATER - 0.1)
	return stone


static func _water(radius: float, rings: float, spacing: float) -> ShaderMaterial:
	var water := ShaderMaterial.new()
	water.shader = Level.WATER_SHADER
	water.set_shader_parameter("radius", radius)
	water.set_shader_parameter("rings", rings)
	water.set_shader_parameter("ring_spacing", spacing)
	return water


## Polished marble, a little warm, for the goddess.
static func _marble() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = MARBLE
	m.roughness = 0.55
	return m


## The profiles the lathe turns, as (radius, height) points from bottom to top, the outside on
## the right when walking along them (so the normals face out).
static func _steps() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(STEP_RADIUS, 0.0), Vector2(STEP_RADIUS, 0.11), Vector2(STEP_RADIUS - 0.05, 0.15),
		Vector2(2.82, 0.15), Vector2(2.82, 0.25), Vector2(2.78, 0.29), Vector2(0.0, 0.29),
	])


## The basin's wall: a moulded foot, a gently swelling belly and a broad rounded coping, then
## down the inside to the floor.
static func _basin() -> PackedVector2Array:
	var p := PackedVector2Array([Vector2(2.62, 0.28), Vector2(2.64, 0.34), Vector2(2.6, 0.4), Vector2(2.53, 0.43)])
	for i in 9:
		var t := float(i + 1) / 10.0
		p.append(Vector2(2.53 + sin(t * PI) * 0.06, lerpf(0.43, 0.86, t)))
	p.append_array([Vector2(2.53, 0.86), Vector2(2.58, 0.9), Vector2(2.66, 0.93)])
	# The coping's rounded top, a half round.
	for i in 9:
		var a := -PI * 0.5 + PI * float(i) / 8.0
		p.append(Vector2(2.5 + cos(a) * 0.22, 0.99 + sin(a) * 0.11 + 0.05))
	p.append_array([Vector2(2.3, 1.08), Vector2(2.26, 1.02), Vector2(2.25, 0.3)])
	return p


## The pedestal in the basin: a round foot, a slim vase-shaped body, and the wide bowl on top,
## its underside curving out to a rolled lip, then its inside down to the middle.
static func _pedestal() -> PackedVector2Array:
	var p := PackedVector2Array([
		Vector2(0.86, 0.28), Vector2(0.86, 0.42), Vector2(0.78, 0.46), Vector2(0.66, 0.54),
		Vector2(0.56, 0.66), Vector2(0.48, 0.82), Vector2(0.42, 1.0), Vector2(0.38, 1.18),
		Vector2(0.4, 1.32), Vector2(0.48, 1.44), Vector2(0.5, 1.52), Vector2(0.44, 1.58),
		Vector2(0.3, 1.64), Vector2(0.26, 1.76), Vector2(0.28, 1.84),
	])
	# The bowl's underside, a smooth curve out to the lip.
	for i in 10:
		var t := float(i + 1) / 10.0
		p.append(Vector2(lerpf(0.28, 1.44, t), 1.84 + 0.5 * pow(t, 1.6)))
	for i in 7:
		var a := -PI * 0.5 + PI * float(i) / 6.0
		p.append(Vector2(1.42 + cos(a) * 0.07, 2.4 + sin(a) * 0.06))
	p.append_array([Vector2(1.34, 2.44), Vector2(1.32, 2.36), Vector2(0.9, 2.34), Vector2(0.0, 2.34)])
	return p


## The slim stem out of the wide bowl and the small bowl on it.
static func _upper() -> PackedVector2Array:
	var p := PackedVector2Array([
		Vector2(0.24, 2.3), Vector2(0.24, 2.44), Vector2(0.18, 2.52), Vector2(0.14, 2.7),
		Vector2(0.17, 2.8), Vector2(0.2, 2.86), Vector2(0.14, 2.92),
	])
	for i in 8:
		var t := float(i + 1) / 8.0
		p.append(Vector2(lerpf(0.14, 0.6, t), 2.92 + 0.26 * pow(t, 1.5)))
	p.append_array([Vector2(0.63, 3.2), Vector2(0.62, 3.25), Vector2(0.57, 3.25), Vector2(0.56, 3.17), Vector2(0.0, 3.17)])
	return p


## The goddess's little round plinth in the small bowl.
static func _plinth() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.2, 3.1), Vector2(0.2, 3.3), Vector2(0.17, 3.36), Vector2(0.17, 3.44),
		Vector2(0.25, 3.46), Vector2(0.27, 3.5), Vector2(0.26, 3.55), Vector2(0.0, 3.55),
	])


## The water running over the bowls' lips in a ring of falling drops; the stream from the goddess's urn into the small bowl.
static func _add_falling_water(root: Node3D, goddess: Node3D) -> void:
	# [lip radius, lip height, the water it falls into]
	for fall in [[0.64, 3.25, BOWL_WATER], [1.5, 2.42, WATER]]:
		var drops := Effects.make_spray(Color(0.78, 0.94, 0.97))
		drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		drops.emission_ring_axis = Vector3.UP
		drops.emission_ring_radius = fall[0] + 0.05
		drops.emission_ring_inner_radius = fall[0]
		drops.emission_ring_height = 0.0
		drops.direction = Vector3.DOWN
		drops.spread = 8.0
		drops.radial_accel_min = 0.4
		drops.radial_accel_max = 0.8
		drops.initial_velocity_min = 0.2
		drops.initial_velocity_max = 0.5
		drops.lifetime = sqrt(2.0 * (fall[1] - fall[2]) / 9.0)
		drops.amount = 90 if fall[0] > 1.0 else 40
		drops.scale_amount_min = 0.35
		drops.scale_amount_max = 0.7
		drops.position = Vector3(0, fall[1], 0)
		root.add_child(drops)
	var stream := Effects.make_spray(Color(0.8, 0.95, 0.98))
	stream.amount = 36
	stream.emission_sphere_radius = 0.02
	stream.direction = goddess.basis.orthonormalized() * FountainGoddess.URN_POUR
	stream.spread = 6.0
	stream.initial_velocity_min = 0.3
	stream.initial_velocity_max = 0.4
	stream.scale_amount_min = 0.35
	stream.scale_amount_max = 0.6
	stream.lifetime = 0.45
	stream.position = goddess.transform * (goddess.get_meta("urn_mouth") as Vector3)
	root.add_child(stream)


## A smooth body of revolution: `profile` (radius, height) turned round the Y axis in `sides`
## steps. Normals are smooth round the axis, and along the profile wherever it bends by less
## than about 40 degrees, so the curves read round and the edges of mouldings stay crisp. UVs
## run in metres round the circumference and along the profile.
static func lathe_mesh(profile: PackedVector2Array, sides: int, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	# Each segment's outward normal in the profile plane (radius, height).
	var seg_normals: Array[Vector2] = []
	for i in n - 1:
		var d := (profile[i + 1] - profile[i]).normalized()
		seg_normals.append(Vector2(d.y, -d.x))
	var along := [0.0]
	for i in n - 1:
		along.append(along[i] + profile[i].distance_to(profile[i + 1]))
	for i in n - 1:
		var n0 := seg_normals[i]
		var n1 := seg_normals[i]
		if i > 0 and seg_normals[i - 1].dot(seg_normals[i]) > 0.76:
			n0 = (seg_normals[i - 1] + seg_normals[i]).normalized()
		if i < n - 2 and seg_normals[i + 1].dot(seg_normals[i]) > 0.76:
			n1 = (seg_normals[i + 1] + seg_normals[i]).normalized()
		var a := profile[i]
		var b := profile[i + 1]
		for k in sides:
			var t0 := TAU * k / sides
			var t1 := TAU * (k + 1) / sides
			var d0 := Vector3(cos(t0), 0, sin(t0))
			var d1 := Vector3(cos(t1), 0, sin(t1))
			var verts := [
				[d0 * a.x + Vector3(0, a.y, 0), d0 * n0.x + Vector3(0, n0.y, 0), Vector2(t0 * maxf(a.x, 0.05), along[i])],
				[d1 * a.x + Vector3(0, a.y, 0), d1 * n0.x + Vector3(0, n0.y, 0), Vector2(t1 * maxf(a.x, 0.05), along[i])],
				[d1 * b.x + Vector3(0, b.y, 0), d1 * n1.x + Vector3(0, n1.y, 0), Vector2(t1 * maxf(b.x, 0.05), along[i + 1])],
				[d0 * b.x + Vector3(0, b.y, 0), d0 * n1.x + Vector3(0, n1.y, 0), Vector2(t0 * maxf(b.x, 0.05), along[i + 1])],
			]
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_normal(verts[j][1])
				st.set_uv(verts[j][2])
				st.add_vertex(verts[j][0])
	st.set_material(material)
	return st.commit()
