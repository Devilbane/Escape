class_name WallFrost
extends RefCounted
## The dead climber of the wall, frozen where he hangs: a skin of frost over his clothes and body (a crystalline
## noise for the albedo and for the bumps, thickest on what faces up), and icicles of many lengths hanging from
## his helmet rim, shoulders, arms, hands, belt and boots, each a glassy cone with a rough, frozen surface.

const ICICLES := 22


## Freezes `model` (a posed rig from WallClimber): a frost overlay on every mesh and the icicles under it.
static func freeze(model: Node3D, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var frost := frost_material()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = frost
	var holder := Node3D.new()
	holder.name = "Icicles"
	model.add_child(holder)
	var ice := ice_material()
	# Where they hang (model space, metres; the rig's feet are at the origin, he hangs about 1.8 m tall): the
	# helmet rim, the shoulders and arms, the hands, the belt and the boots.
	var spots := [
		Vector3(-0.16, 1.66, 0.1), Vector3(0.0, 1.7, 0.16), Vector3(0.16, 1.66, 0.1), Vector3(-0.19, 1.62, -0.05), Vector3(0.19, 1.62, -0.05),
		Vector3(-0.3, 1.45, 0.0), Vector3(0.3, 1.45, 0.0), Vector3(-0.42, 1.35, 0.05), Vector3(0.42, 1.35, 0.05),
		Vector3(-0.5, 1.15, 0.05), Vector3(0.5, 1.15, 0.05), Vector3(-0.25, 1.05, 0.12), Vector3(0.0, 1.0, 0.16),
		Vector3(0.25, 1.05, 0.12), Vector3(-0.15, 0.95, -0.12), Vector3(0.15, 0.95, -0.12), Vector3(-0.2, 0.55, 0.05),
		Vector3(0.2, 0.55, 0.05), Vector3(-0.18, 0.3, 0.1), Vector3(0.18, 0.3, 0.1), Vector3(-0.1, 1.5, -0.15), Vector3(0.1, 1.5, -0.15),
	]
	for i in ICICLES:
		var at: Vector3 = spots[i % spots.size()]
		var length := rng.randf_range(0.14, 0.5)
		if i % 5 == 0:
			length *= 1.5
		var radius := rng.randf_range(0.018, 0.05)
		var cone := CylinderMesh.new()
		cone.top_radius = radius
		cone.bottom_radius = 0.0
		cone.height = length
		cone.radial_segments = 7
		cone.rings = 2
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = ice
		mi.position = at + Vector3(rng.randf_range(-0.03, 0.03), -length * 0.5, rng.randf_range(-0.03, 0.03))
		mi.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
		holder.add_child(mi)
		# A short knob of ice where the icicle grows from, and a drip frozen at its tip on the long ones.
		var root := SphereMesh.new()
		root.radius = radius * 1.5
		root.height = radius * 2.2
		var rmi := MeshInstance3D.new()
		rmi.mesh = root
		rmi.material_override = ice
		rmi.position = at
		holder.add_child(rmi)


## The frost laid over the body and clothes: milky blue-white with a crystalline grain, bumpy, a little shiny.
static func frost_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.92, 1.0, 0.62)
	m.albedo_texture = _noise(0.07, FastNoiseLite.TYPE_CELLULAR, false)
	m.normal_enabled = true
	m.normal_texture = _noise(0.12, FastNoiseLite.TYPE_CELLULAR, true)
	m.normal_scale = 1.6
	m.roughness = 0.35
	m.metallic_specular = 0.8
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.5, 0.7)
	m.emission_energy_multiplier = 0.25
	return m


## Clear ice for the icicles: glassy and blue, with frozen veins and bubbles.
static func ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.88, 1.0, 0.78)
	m.albedo_texture = _noise(0.2, FastNoiseLite.TYPE_PERLIN, false)
	m.normal_enabled = true
	m.normal_texture = _noise(0.3, FastNoiseLite.TYPE_CELLULAR, true)
	m.normal_scale = 1.2
	m.roughness = 0.08
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.6
	m.emission_enabled = true
	m.emission = Color(0.4, 0.65, 0.95)
	m.emission_energy_multiplier = 0.45
	return m


static func _noise(freq: float, kind: int, as_normal: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 128
	t.height = 128
	t.seamless = true
	t.as_normal_map = as_normal
	t.bump_strength = 6.0
	return t
