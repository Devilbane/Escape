class_name Sowing
extends RefCounted
## A farmer sowing by hand in spring (see ValleyFolk, jobs with "sow"): with a linen seed bag at the hip he stands
## at the edge of a field, throws a handful with a wide sweep of the arm (the "Throw" clip) and the seed flies out
## over the soil in a small spray; the nearest bare tile is sown (see CropFields.sow_near) and starts to sprout.
## This holds the seed bag, the spray and the numbers; Villager runs the throwing (see Villager._sow).

## How far a handful carries: tiles whose middle is within this many metres of the sower can be sown.
const REACH := 6.5
## How far out the spray flies (metres), and how many seeds one handful has.
const THROW := 2.6
const SEEDS := 18
## The pause between two handfuls (seconds, min and max).
const PAUSE := Vector2(0.2, 0.55)
## Where the bag hangs, in the model's own space (the left hip), and how big it is.
const BAG_AT := Vector3(0.26, 0.82, 0.04)

static var _bag_mesh: ArrayMesh
static var _bag_material: StandardMaterial3D
static var _seed_material: StandardMaterial3D
static var _seed_mesh: BoxMesh


## The seed bag: a plump linen sack with a corded neck, a flap of hessian over the mouth and a few grains showing.
static func build_bag() -> Node3D:
	var root := Node3D.new()
	root.name = "SeedBag"
	var sack := MeshInstance3D.new()
	sack.mesh = _sack()
	sack.material_override = _linen()
	sack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sack)
	# The cord round the neck.
	var cord := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.052
	ring.outer_radius = 0.066
	ring.rings = 12
	ring.ring_segments = 6
	cord.mesh = ring
	cord.position = Vector3(0, 0.19, 0)
	cord.material_override = _plain(Color(0.36, 0.25, 0.14), 0.9)
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cord)
	# The mouth, a little open, with the seed heaped in it.
	var grain := MeshInstance3D.new()
	var heap := SphereMesh.new()
	heap.radius = 0.055
	heap.height = 0.07
	heap.radial_segments = 10
	heap.rings = 4
	grain.mesh = heap
	grain.position = Vector3(0, 0.215, 0)
	grain.material_override = _plain(Color(0.78, 0.63, 0.3), 0.8)
	grain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grain)
	# The strap over the shoulder, a thin leather band down to the bag.
	var strap := MeshInstance3D.new()
	var band := BoxMesh.new()
	band.size = Vector3(0.025, 0.3, 0.012)
	strap.mesh = band
	strap.position = Vector3(-0.07, 0.33, 0.0)
	strap.rotation_degrees = Vector3(0, 0, 8)
	strap.material_override = _plain(Color(0.3, 0.2, 0.12), 0.7)
	strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(strap)
	return root


## The sack's body: a lathe of a bulging pear shape, a little flattened front to back.
static func _sack() -> ArrayMesh:
	if _bag_mesh != null:
		return _bag_mesh
	var profile := [Vector2(0.0, 0.0), Vector2(0.07, 0.01), Vector2(0.115, 0.05), Vector2(0.135, 0.1), Vector2(0.12, 0.15),
			Vector2(0.085, 0.18), Vector2(0.062, 0.195), Vector2(0.066, 0.205)]
	var sides := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00 := _lathe(profile[i], a0)
			var p01 := _lathe(profile[i], a1)
			var p10 := _lathe(profile[i + 1], a0)
			var p11 := _lathe(profile[i + 1], a1)
			var u0 := float(k) / sides
			var u1 := float(k + 1) / sides
			var v0 := float(i) / (profile.size() - 1)
			var v1 := float(i + 1) / (profile.size() - 1)
			for tri: Array in [[p00, p10, p01, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v0)], [p01, p10, p11, Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1)]]:
				for j in 3:
					st.set_uv(tri[3 + j])
					st.add_vertex(tri[j])
	st.generate_normals()
	_bag_mesh = st.commit()
	return _bag_mesh


static func _lathe(p: Vector2, angle: float) -> Vector3:
	# Flattened front to back (z) so it lies against the hip.
	return Vector3(cos(angle) * p.x, p.y, sin(angle) * p.x * 0.7)


## Woven linen, painted once: warp and weft threads with slubs, a few darker patches of dust and old seed stains.
static func _linen() -> StandardMaterial3D:
	if _bag_material != null:
		return _bag_material
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var base := Color(0.74, 0.66, 0.5)
	for y in size:
		for x in size:
			var warp := 0.5 + 0.5 * sin(x * TAU / 4.0)
			var weft := 0.5 + 0.5 * sin(y * TAU / 4.0)
			var weave := 0.88 + 0.12 * (warp if (x / 4 + y / 4) % 2 == 0 else weft)
			var slub := 1.0 - 0.1 * rng.randf()
			var dust := 1.0 - 0.18 * smoothstep(0.55, 1.0, sin(x * 0.21) * sin(y * 0.17) * 0.5 + 0.5)
			var c := base * weave * slub * dust
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	img.generate_mipmaps()
	_bag_material = StandardMaterial3D.new()
	_bag_material.albedo_texture = ImageTexture.create_from_image(img)
	_bag_material.uv1_scale = Vector3(3, 2, 1)
	_bag_material.roughness = 0.95
	_bag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bag_material


static func _plain(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m


## The spray of one handful: a one-shot burst of tiny grains from `hand` out towards `to`, falling to the soil.
## `host` is the node the emitter lives under (kept, and reused for the next handful); returns the emitter.
static func spray(host: Node3D, emitter: CPUParticles3D, hand: Vector3, to: Vector3) -> CPUParticles3D:
	if emitter == null or not is_instance_valid(emitter):
		emitter = CPUParticles3D.new()
		emitter.name = "SownSeed"
		emitter.top_level = true
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.amount = SEEDS
		emitter.lifetime = 0.75
		emitter.local_coords = false
		emitter.spread = 22.0
		emitter.gravity = Vector3(0, -9.0, 0)
		emitter.initial_velocity_min = THROW * 1.1
		emitter.initial_velocity_max = THROW * 1.9
		emitter.scale_amount_min = 0.7
		emitter.scale_amount_max = 1.3
		emitter.mesh = _grain()
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(emitter)
	var out := Vector3(to.x - hand.x, 0.0, to.z - hand.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	emitter.global_position = hand
	emitter.direction = (out + Vector3(0, 0.35, 0)).normalized()
	emitter.restart()
	emitter.emitting = true
	return emitter


static func _grain() -> BoxMesh:
	if _seed_mesh == null:
		_seed_mesh = BoxMesh.new()
		_seed_mesh.size = Vector3(0.022, 0.012, 0.012)
		_seed_material = _plain(Color(0.82, 0.68, 0.34), 0.6)
		_seed_mesh.material = _seed_material
	return _seed_mesh
