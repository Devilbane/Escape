class_name ClimbHelmet
extends RefCounted
## The climbing helmet (see RockClimb and Items "kletterhelm"): an iron cap riveted to a leather brow
## band, with a short brim, a ridge over the top and a leather chin strap. Built from parts in the hero's
## head-bone space (the head spans about x ±0.55, y -0.08..0.95, z ±0.5, the face towards +z, see
## Player._show_headgear), and shown on the ground at a smaller scale (see GroundItem).

const IRON := Color(0.43, 0.44, 0.47)
const IRON_DARK := Color(0.28, 0.29, 0.32)
const LEATHER := Color(0.42, 0.26, 0.14)
const LEATHER_DARK := Color(0.28, 0.17, 0.09)
const BRASS := Color(0.72, 0.56, 0.24)


## A material with a grain: noise over the colour, so no part looks like plain plastic.
static func _material(base: Color, grain: float, metal: float, rough: float, frequency := 0.08) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, base.darkened(grain))
	ramp.set_color(1, base.lightened(grain * 0.7))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_scale = Vector3(3, 3, 3)
	m.metallic = metal
	m.roughness = rough
	return m


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	node.scale = scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## The helmet as a Node3D whose origin is the head bone.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Headgear"
	var iron := _material(IRON, 0.22, 0.7, 0.42)
	var dark := _material(IRON_DARK, 0.25, 0.7, 0.5)
	var leather := _material(LEATHER, 0.3, 0.0, 0.8, 0.2)
	var strap := _material(LEATHER_DARK, 0.25, 0.0, 0.85, 0.25)
	var brass := _material(BRASS, 0.18, 0.8, 0.35)
	# The cap: a dome a little wider than the head, with a faint point on top.
	var dome := SphereMesh.new()
	dome.radius = 0.56
	dome.height = 0.62
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 10
	_part(root, dome, Vector3(0, 0.46, 0), iron, Vector3.ZERO, Vector3(1.0, 1.0, 1.04))
	var tip := SphereMesh.new()
	tip.radius = 0.07
	tip.height = 0.14
	_part(root, tip, Vector3(0, 1.07, 0), brass)
	# The leather band round the brow, with a row of brass rivets.
	var band := TorusMesh.new()
	band.inner_radius = 0.535
	band.outer_radius = 0.615
	band.rings = 24
	band.ring_segments = 8
	_part(root, band, Vector3(0, 0.5, 0), leather, Vector3.ZERO, Vector3(1.0, 1.4, 1.04))
	var rivet := SphereMesh.new()
	rivet.radius = 0.03
	rivet.height = 0.06
	rivet.radial_segments = 8
	rivet.rings = 4
	for i in 11:
		var a := deg_to_rad(-100.0 + i * 20.0) + PI * 0.0
		_part(root, rivet, Vector3(sin(a) * 0.62, 0.5, cos(a) * 0.65), brass)
	# A short crest on top, and a short brim at the front.
	_part(root, _box(Vector3(0.09, 0.05, 0.5)), Vector3(0, 1.04, 0), dark, Vector3(0, 0, 0))
	_part(root, _box(Vector3(0.62, 0.05, 0.3)), Vector3(0, 0.46, 0.7), dark, Vector3(-12, 0, 0))
	# The chin strap: a strap down in front of each ear, and a cup under the chin.
	for side in [-1.0, 1.0]:
		_part(root, _box(Vector3(0.06, 0.62, 0.14)), Vector3(0.55 * side, 0.2, 0.1), strap, Vector3(0, 0, -6.0 * side))
		_part(root, _box(Vector3(0.05, 0.05, 0.05)), Vector3(0.58 * side, 0.2, 0.18), brass)
	_part(root, _box(Vector3(1.04, 0.06, 0.16)), Vector3(0, -0.12, 0.22), strap)
	return root
