class_name CoinShine
extends RefCounted
## Makes gold look like gold: coins on the floor, the heaps of gold in the
## dragons' lairs and the gold in an opened treasure chest are a polished,
## warm gold, and little four-pointed stars blink on them now and then, as
## if they caught the torchlight.
##
## Kept cheap, because it is everywhere there is gold: the materials are
## shared (one per source material), the glints of a heap are one particle
## system with a handful of particles that never move (they only flash),
## nothing casts a shadow or adds a light, and glints further away than
## GLINT_RANGE are not drawn at all.

## Every glint emitter is called this (the tests look for it).
const NAME := "Glints"
## The most glints one heap has blinking at once.
const MAX_GLINTS := 8
## How far off (metres) glints are still drawn.
const GLINT_RANGE := 22.0
## The colour of a glint: white, warmed by the gold.
const GLINT := Color(1.0, 0.95, 0.75)
## The polished gold of a heap (the lair models come plain and matt).
const GOLD := Color(1.0, 0.76, 0.3)

static var _star_mesh: QuadMesh
static var _pop: Curve
static var _polished := {}
static var _faces := {}
static var _chest_gold := {}


## Polishes every mesh of `node` (a coin, a stack or a heap of gold): a
## little metallic, smooth and with a faint glow of its own, so it reads as
## gold even in a dark corner.
static func polish(node: Node) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		var source := mi.get_active_material(0) as StandardMaterial3D
		if source == null:
			continue
		if not _polished.has(source):
			_polished[source] = _polish(source)
		mi.material_override = _polished[source]


static func _polish(source: StandardMaterial3D) -> StandardMaterial3D:
	var m := source.duplicate() as StandardMaterial3D
	m.metallic = 0.45
	m.metallic_specular = 0.8
	m.roughness = 0.3
	m.emission_enabled = true
	if source.albedo_texture == null:
		# The lair's heaps: one flat, dull colour, made a rich gold.
		m.albedo_color = GOLD
		m.emission = GOLD
		m.emission_energy_multiplier = 0.18
	else:
		# The coins: their own texture, a deeper gold (the shine pales it),
		# glowing faintly in its own colours.
		m.albedo_color = source.albedo_color * Color(1.0, 0.88, 0.62)
		m.emission = Color(1.0, 0.85, 0.5)
		m.emission_texture = source.albedo_texture
		m.emission_energy_multiplier = 0.1
	return m


## The gold heaped up in a treasure chest (KayKit's chest_gold): its body
## keeps the worn look, but the coins above HEAP_HEIGHT stay bright, and a few
## glints blink on them. The glints are returned switched off: they start
## once the chest is open (the lid hides the coins until then).
const HEAP_HEIGHT := 0.62


static func add_to_chest(chest: Node3D) -> CPUParticles3D:
	var body := chest.find_child("chest_gold", true, false) as MeshInstance3D
	if body == null:
		return null
	var worn := body.material_override as ShaderMaterial
	if worn != null:
		if not _chest_gold.has(worn):
			var m := worn.duplicate() as ShaderMaterial
			m.set_shader_parameter("shiny_gold_above", HEAP_HEIGHT)
			_chest_gold[worn] = m
		body.material_override = _chest_gold[worn]
	var to_chest := chest.global_transform.affine_inverse() * body.global_transform
	var points := _top_points(body.mesh, to_chest, HEAP_HEIGHT)
	var glints := make(points, 5, 0.9)
	glints.emitting = false
	chest.add_child(glints)
	return glints


## Glints over a heap of gold placed with Level._place_lair (`pile`, scaled
## by `s`): a few stars blinking on the top of the coins.
static func add_to_pile(pile: Node3D, s: float) -> CPUParticles3D:
	var points := PackedVector3Array()
	var inverse := pile.global_transform.affine_inverse()
	for mi: MeshInstance3D in pile.find_children("*", "MeshInstance3D", true, false):
		var to_pile := inverse * mi.global_transform
		for p in _top_points(mi.mesh, to_pile, _floor_of(mi.mesh, to_pile)):
			points.append(p * s)
	# The bigger the heap, the more glints (a dragon's bed of gold has the most).
	var glints := make(points, clampi(int(s / 2.0), 3, MAX_GLINTS))
	# The pile is scaled up a lot (its model is tiny); the glints are not.
	glints.scale = Vector3.ONE / s
	pile.add_child(glints)
	return glints


## A lone coin on the floor: a glint now and then, not all the time, so a
## floor strewn with coins does not flicker.
static func add_to_coin(holder: Node3D) -> CPUParticles3D:
	var glints := make(PackedVector3Array([Vector3(0, 0.12, 0)]), 1, 1.8, 0.35)
	holder.add_child(glints)
	return glints


## The glint emitter itself: `amount` stars, each popping up and fading
## within `lifetime` seconds at one of `points` (or anywhere, if empty).
## A long lifetime with the pop at its start makes rare, lone glints.
static func make(points: PackedVector3Array, amount := 5, lifetime := 0.8, pop_part := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = NAME
	p.amount = clampi(amount, 1, MAX_GLINTS)
	p.lifetime = lifetime
	# Each starts somewhere else in its round, so coins dropped together do
	# not all blink at once.
	p.preprocess = lifetime * (1.0 + randf())
	p.randomness = 1.0
	p.mesh = _star()
	p.local_coords = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = GLINT_RANGE
	p.visibility_range_end_margin = 2.0
	p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not points.is_empty():
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = points
	p.direction = Vector3.UP
	p.spread = 0.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.angle_min = -20.0
	p.angle_max = 20.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.3
	# The pop twice over: in size, and in brightness (the compatibility
	# renderer keeps camera-facing particles at one size).
	p.scale_amount_curve = _pop_curve(pop_part)
	p.color_ramp = _pop_ramp(pop_part)
	return p


## A soft four-pointed star on a camera-facing quad, added onto what is
## behind it, so it reads as a flash of light.
static func _star() -> QuadMesh:
	if _star_mesh == null:
		const SIZE := 64
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_LA8)
		for y in SIZE:
			for x in SIZE:
				var u := (x + 0.5) / SIZE * 2.0 - 1.0
				var v := (y + 0.5) / SIZE * 2.0 - 1.0
				# Two thin rays across, and a small round core.
				var rays := maxf(exp(-absf(u) * 22.0) * (1.0 - absf(v)), exp(-absf(v) * 22.0) * (1.0 - absf(u)))
				var core := exp(-(u * u + v * v) * 30.0)
				var a := clampf(rays * 1.1 + core, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.albedo_color = GLINT
		mat.vertex_color_use_as_albedo = true
		# A glint is light: it does not hide in the fog of the dungeon.
		mat.disable_fog = true
		_star_mesh = QuadMesh.new()
		_star_mesh.size = Vector2(0.45, 0.45)
		_star_mesh.material = mat
	return _star_mesh


## Grows quickly from nothing, flashes and shrinks away, within the first
## `part` of a particle's life (nothing for the rest of it).
static func _pop_curve(part: float) -> Curve:
	if is_equal_approx(part, 1.0) and _pop != null:
		return _pop
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(part * 0.3, 1.0))
	c.add_point(Vector2(part, 0.0))
	if part < 1.0:
		c.add_point(Vector2(1.0, 0.0))
	if is_equal_approx(part, 1.0):
		_pop = c
	return c


## The height under which a heap's glints would hide among the coins at its
## foot: a third of the way up.
static func _floor_of(mesh: Mesh, to_parent: Transform3D) -> float:
	var box := to_parent * mesh.get_aabb()
	return box.position.y + box.size.y * 0.3


## The same pop as a fade: dark, a flash of light, dark again.
static func _pop_ramp(part: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_offset(1, part)
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(part * 0.3, Color.WHITE)
	if part < 1.0:
		g.add_point(1.0, Color(0, 0, 0, 0))
	return g


## Points on the top of a mesh (faces turned up, higher than `floor_y`), in
## the space `to_parent` takes it to, lifted a little above it so the glints
## are not cut by the coins. Kept per mesh.
static func _top_points(mesh: Mesh, to_parent: Transform3D, floor_y: float) -> PackedVector3Array:
	if mesh == null:
		return PackedVector3Array()
	if _faces.has(mesh):
		return _faces[mesh]
	var faces := mesh.get_faces()
	for i in faces.size():
		faces[i] = to_parent * faces[i]
	var lift := (to_parent * mesh.get_aabb()).size.length() * 0.015
	var tops := PackedVector3Array()
	for i in range(0, faces.size() - 2, 3):
		var n := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		if n.length_squared() <= 0.0:
			continue
		var mid := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if absf(n.normalized().y) < 0.35 or mid.y < floor_y:
			continue
		tops.append(mid + Vector3.UP * lift)
	# A few hundred are plenty to pick from.
	var step := maxi(1, tops.size() / 300)
	var picked := PackedVector3Array()
	for i in range(0, tops.size(), step):
		picked.append(tops[i])
	_faces[mesh] = picked
	return picked
