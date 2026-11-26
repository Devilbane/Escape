class_name NaturalRock
extends RefCounted
## The loose boulders of the open air (map letter r, the rings of stones round a camp and the pit's rim, the
## treasure map's boulder). The kit's rock_single models are a handful of flat hexagonal facets: seen from above
## in winter each one was a plain white slab with hard straight edges. These are real rocks instead: an uneven
## dome with a lopsided outline, bulges and hollows, a few chiselled flats, a flat sunk bottom, and the
## mountain's weathered rock (AgedStone.rock_material) on it, so the snow cover (see snow_cover.gdshader) lies on
## the tops only and the stone shows through on the flanks.
##
## They keep the footprint of the models they replace (KIND), so every reach, collision and scale used for the
## old ones still fits.

## Per model name: half extents (x, z) and height (metres, before the placement's scale) and how boxy the
## outline is (1 round, higher squarer).
const KIND := {
	"rock_single_A": {"half": Vector2(0.15, 0.15), "height": 0.085, "box": 1.5, "seed": 101},
	"rock_single_C": {"half": Vector2(0.18, 0.17), "height": 0.19, "box": 1.3, "seed": 202},
	"rock_single_E": {"half": Vector2(0.245, 0.175), "height": 0.19, "box": 1.4, "seed": 303},
}
## How many rings from the crown to the rim and sides round it.
const RINGS := 11
const SIDES := 22

static var _meshes := {}


## Whether `model` is one of the kit's rocks this replaces.
static func replaces(model: String) -> bool:
	return KIND.has(model)


## A node the size and place of the kit's `model`, holding its stand-in.
static func node(model: String) -> Node3D:
	var root := Node3D.new()
	root.name = model
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = mesh(model)
	mi.material_override = AgedStone.rock_material()
	# The snow's skirt up the foot of steep faces (snow_cover.gdshader) would bury a low rock whole.
	mi.set_instance_shader_parameter("skirt_scale", 0.0)
	root.add_child(mi)
	return root


## The mesh of a kind of rock, shared.
static func mesh(model: String) -> ArrayMesh:
	if _meshes.has(model):
		return _meshes[model]
	var kind: Dictionary = KIND[model]
	var made := _build(kind.half, float(kind.height), float(kind.box), int(kind.seed))
	_meshes[model] = made
	return made


static func _build(half: Vector2, height: float, boxy: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var big := FastNoiseLite.new()
	big.seed = seed_value
	big.frequency = 1.3
	var fine := FastNoiseLite.new()
	fine.seed = seed_value + 7
	fine.frequency = 4.5
	# A few flats cut across the rock, each leaning its own way: not a mirror of each other.
	var cuts: Array[Vector4] = []
	for i in 3:
		var yaw := rng.randf() * TAU
		var lean := rng.randf_range(0.25, 0.75)
		var dir := Vector3(cos(yaw) * (1.0 - lean), lean, sin(yaw) * (1.0 - lean)).normalized()
		cuts.append(Vector4(dir.x, dir.y, dir.z, rng.randf_range(0.74, 0.88)))
	var skew := rng.randf_range(-0.25, 0.25)
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	# Ring 0 is the crown (one point); the last ring is a skirt sunk below the ground.
	for i in RINGS + 1:
		var sides := 1 if i == 0 else SIDES
		for j in sides:
			var phi := float(i) / RINGS * PI * 0.5
			var theta := float(j) / SIDES * TAU
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			# A squarer outline than a circle, with a lopsided radius.
			# Steep flanks and a flatter crown (a rounded block rather than a dome), so snow settles on the top only.
			var p := Vector3(_pow_keep(dir.x, 2.0 / boxy), pow(dir.y, 0.45), _pow_keep(dir.z, 2.0 / boxy))
			var wobble := 1.0 + 0.3 * big.get_noise_3d(dir.x * 2.0 + 5.0, dir.y * 2.0, dir.z * 2.0) + skew * dir.x
			p.x *= wobble
			p.z *= wobble * (1.0 + 0.2 * big.get_noise_3d(dir.z * 3.0, 9.0, dir.x * 3.0))
			p.y *= 1.0 + 0.35 * big.get_noise_3d(dir.x * 2.3, 4.0, dir.z * 2.3)
			p += dir * 0.07 * fine.get_noise_3d(dir.x * 3.0, dir.y * 3.0, dir.z * 3.0)
			for c in cuts:
				var n := Vector3(c.x, c.y, c.z)
				var over := p.dot(n) - c.w
				if over > 0.0:
					p -= n * over
			if i == RINGS:
				p.y = -0.16
			else:
				p.y = maxf(p.y, 0.0)
			points.append(Vector3(p.x * half.x, p.y * height, p.z * half.y))
			var up := clampf(dir.y, 0.0, 1.0)
			var shade := rng.randf_range(0.9, 1.06) * (0.84 + 0.2 * up)
			var colour := Mountains.ROCK.lerp(Mountains.ROCK_DARK, (1.0 - up) * 0.45) * shade
			colour = colour.lerp(Mountains.MOSS, clampf(up - 0.7, 0.0, 0.3) * 0.5)
			colour.a = 1.0
			colours.append(colour)
	var index_of := func(i: int, j: int) -> int:
		return 0 if i == 0 else 1 + (i - 1) * SIDES + posmod(j, SIDES)
	var indices := PackedInt32Array()
	for j in SIDES:
		_tri(indices, points, index_of.call(0, 0), index_of.call(1, j), index_of.call(1, j + 1))
	for i in range(1, RINGS):
		for j in SIDES:
			var a: int = index_of.call(i, j)
			var b: int = index_of.call(i, j + 1)
			var c: int = index_of.call(i + 1, j)
			var d: int = index_of.call(i + 1, j + 1)
			_tri(indices, points, a, c, b)
			_tri(indices, points, b, c, d)
	# Smooth normals: each point takes the faces round it.
	var normals := PackedVector3Array()
	normals.resize(points.size())
	for t in indices.size() / 3:
		var a := indices[t * 3]
		var b := indices[t * 3 + 1]
		var c := indices[t * 3 + 2]
		var face := (points[c] - points[a]).cross(points[b] - points[a])
		normals[a] += face
		normals[b] += face
		normals[c] += face
	for k in normals.size():
		normals[k] = normals[k].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Adds a triangle wound so that its front (clockwise) side faces away from the middle of the rock.
static func _tri(indices: PackedInt32Array, points: PackedVector3Array, a: int, b: int, c: int) -> void:
	var centre := (points[a] + points[b] + points[c]) / 3.0 - Vector3(0, 0.02, 0)
	var face := (points[b] - points[a]).cross(points[c] - points[a])
	if face.dot(centre) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


static func _pow_keep(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)
