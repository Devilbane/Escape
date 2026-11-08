class_name WallShapes
extends RefCounted
## Sharp-edged relief for the walls of the rock, obsidian and crystal styles (see
## WallThemes): faceted shards and boulders that jut out of the wall face and
## stand up from its top, so the wall reads as raw rock or crystal and not as a
## flat block. Each is a low-poly mesh with flat faces, in the style's own
## material, so it takes the same light, glints and fade as the wall. The bone
## style stays flat. Nothing here blocks the hero: the shards stay close to the
## wall, and the collision is the wall's box.

## Per style: how many shards on the face, how many on top, how long and how
## thin they are (length is the base width times it), and how far they lean.
const LOOKS := {
	"rock": {"face": 6, "top": 2, "base": [0.45, 0.85], "long": [0.7, 1.2], "lean": 35.0, "sides": 6, "out": [68.0, 95.0]},
	"obsidian": {"face": 3, "top": 2, "base": [0.15, 0.3], "long": [3.5, 6.0], "lean": 28.0, "sides": 4},
	"crystal": {"face": 3, "top": 2, "base": [0.18, 0.34], "long": [3.0, 5.5], "lean": 30.0, "sides": 6},
}
## How many differently shaped shards a style has; each is shared by many.
const VARIANTS := 6

static var _meshes := {}


static func styled(style: String) -> bool:
	return LOOKS.has(style) or style == "bone"


## A flat-faced shard: a ring of `sides` corners (a little uneven) up to a
## point that sits off to one side.
static func shard_mesh(style: String, variant: int) -> ArrayMesh:
	var key := "%s_%d" % [style, variant]
	if _meshes.has(key):
		return _meshes[key]
	var look: Dictionary = LOOKS[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var sides: int = look.sides
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if style == "rock":
		# A boulder: a ring of corners up to one point.
		var ring := []
		for i in sides:
			var a := TAU * i / sides + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(0.75, 1.1)
			ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		var apex := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25))
		for i in sides:
			_tri(st, ring[i], apex, ring[(i + 1) % sides])
	else:
		# A crystal: an uneven ring at the foot, a second one higher up that has
		# shifted and shrunk, a ragged tip of corners at different heights, and a
		# point. Every face is flat, none is like its neighbour.
		var foot := []
		var mid := []
		var tip := []
		var shift := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		var top_shift := shift + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		for i in sides:
			var a := TAU * i / sides + rng.randf_range(-0.4, 0.4)
			var r := rng.randf_range(0.55, 1.25)
			foot.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			mid.append(Vector3(cos(a) * r * rng.randf_range(0.6, 0.95), rng.randf_range(0.55, 0.8), sin(a) * r * rng.randf_range(0.6, 0.95)) + shift)
			tip.append(Vector3(cos(a) * r * rng.randf_range(0.12, 0.35), rng.randf_range(0.88, 1.08), sin(a) * r * rng.randf_range(0.12, 0.35)) + top_shift)
		var point := Vector3(top_shift.x + rng.randf_range(-0.1, 0.1), rng.randf_range(1.12, 1.3), top_shift.z + rng.randf_range(-0.1, 0.1))
		for i in sides:
			var j := (i + 1) % sides
			_tri(st, foot[i], mid[i], foot[j])
			_tri(st, foot[j], mid[i], mid[j])
			_tri(st, mid[i], tip[i], mid[j])
			_tri(st, mid[j], tip[i], tip[j])
			_tri(st, tip[i], point, tip[j])
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot draws the clockwise side of a triangle: turn it so that side faces
	# away from the shard's middle.
	var centre := (a + b + c) / 3.0
	var outward := centre - Vector3(0.0, minf(centre.y, 0.5), 0.0)
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_uv(Vector2(v.x * 0.25 + 0.5, v.y * 0.25 + 0.5))
		st.add_vertex(v)


## Adds shards to a wall piece `wall` (local +z points into the room, x runs
## along the wall, the wall is 4 m wide and 4 m high). `material` is the
## style's wall material; `seed_value` makes each wall different but the same
## every time.
static func dress(wall: Node3D, style: String, material: Material, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if style == "bone":
		_dress_bone(wall, rng)
		return
	if not LOOKS.has(style):
		return
	var look: Dictionary = LOOKS[style]
	for i in look.face:
		# Not in the middle: that is where a wall torch hangs.
		var x := rng.randf_range(0.85, 1.85) * (1.0 if i % 2 == 0 else -1.0)
		if i >= 3:
			# Further boulders lower down, where rock piles up at a wall's foot.
			x = rng.randf_range(-1.8, 1.8)
		var y := rng.randf_range(0.5, 3.4) if i < 3 else rng.randf_range(0.25, 1.1)
		# Crystals grow in clusters of two or three, each its own size and way.
		var cluster := 1 + (rng.randi() % 3 if style == "crystal" else 0)
		for k in cluster:
			var spot := Vector3(x, y, 0.3) + (Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), 0.0) if k > 0 else Vector3.ZERO)
			_add(wall, style, material, rng, spot, look, true)
	for i in look.top:
		var x := rng.randf_range(-1.7, 1.7)
		_add(wall, style, material, rng, Vector3(x, 3.85, 0.0), look, false)


static func _add(wall: Node3D, style: String, material: Material, rng: RandomNumberGenerator, at: Vector3, look: Dictionary, outward: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = shard_mesh(style, rng.randi() % VARIANTS)
	mi.material_override = material
	var base := rng.randf_range(look.base[0], look.base[1])
	var length := base * rng.randf_range(look.long[0], look.long[1])
	mi.scale = Vector3(base, length, base)
	mi.position = at
	var lean: float = look.lean
	if outward:
		# Pointing out of the wall and up, a bit to the side.
		# (A turn about x tips the shard's tip from up (+y) towards the room (+z).)
		mi.rotation_degrees = Vector3(rng.randf_range(look.get("out", [45.0, 80.0])[0], look.get("out", [45.0, 80.0])[1]), rng.randf_range(-25.0, 25.0), 0.0)
	else:
		mi.rotation_degrees = Vector3(rng.randf_range(-lean, lean), rng.randf_range(0.0, 360.0), rng.randf_range(-lean, lean))
		mi.scale = Vector3(base, length * 1.2, base)
	wall.add_child(mi)


## The bone walls: skulls and long bones set into the face, half sunk in it.
static func _dress_bone(wall: Node3D, rng: RandomNumberGenerator) -> void:
	var mat := bone_material()
	# A skull in about every second piece, looking out into the room.
	if rng.randf() < 0.55:
		var skull := MeshInstance3D.new()
		skull.mesh = skull_mesh()
		skull.material_override = mat
		skull.position = Vector3(rng.randf_range(-1.6, 1.6) if rng.randf() < 0.7 else rng.randf_range(0.9, 1.7), rng.randf_range(0.5, 3.3), 0.12)
		skull.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(-30.0, 30.0), rng.randf_range(-15.0, 15.0))
		skull.scale = Vector3.ONE * rng.randf_range(0.9, 1.3)
		wall.add_child(skull)
	# Two or three bones jutting out, crossing the wall at all angles.
	for i in 2 + (rng.randi() % 2):
		var bone := MeshInstance3D.new()
		bone.mesh = bone_mesh()
		bone.material_override = mat
		var x := rng.randf_range(0.9, 1.8) * (1.0 if i % 2 == 0 else -1.0)
		bone.position = Vector3(x, rng.randf_range(0.4, 3.5), 0.18)
		bone.rotation_degrees = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(-30.0, 30.0), rng.randf_range(0.0, 180.0))
		bone.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		wall.add_child(bone)


## Paler bone than the wall's, with the dark parts (tone) that the meshes paint.
static func bone_material() -> ShaderMaterial:
	if not _meshes.has("bone_material"):
		var m := WallThemes.material("bone", WallThemes.WALL)
		m.set_shader_parameter("use_tone", true)
		m.set_shader_parameter("base_color", Color(0.72, 0.66, 0.52))
		m.set_shader_parameter("dark_color", Color(0.3, 0.25, 0.17))
		_meshes["bone_material"] = m
	return _meshes["bone_material"]


## Adds `mesh` to `st` moved by `at`, with every vertex coloured `tone` (1 stays
## as it is, near 0 is black).
static func _merge(st: SurfaceTool, mesh: Mesh, at: Transform3D, tone: float) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colours := PackedColorArray()
	colours.resize(count)
	colours.fill(Color(tone, tone, tone))
	arrays[Mesh.ARRAY_COLOR] = colours
	var painted := ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.append_from(painted, 0, at)


static func _ball(radius: float, squash := Vector3.ONE) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 8
	return s


## A skull looking along +z: cranium, jaw, two dark eye sockets and a nose hole,
## in one mesh.
static func skull_mesh() -> ArrayMesh:
	if _meshes.has("skull"):
		return _meshes["skull"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_merge(st, _ball(0.3), Transform3D(Basis.from_scale(Vector3(1.0, 0.95, 1.1)), Vector3.ZERO), 1.0)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.3, 0.14, 0.26)
	_merge(st, jaw, Transform3D(Basis(), Vector3(0, -0.27, 0.07)), 0.9)
	for side in [-1.0, 1.0]:
		_merge(st, _ball(0.085), Transform3D(Basis.from_scale(Vector3(1.0, 1.1, 0.7)), Vector3(side * 0.12, -0.02, 0.27)), 0.04)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.05, 0.09, 0.05)
	_merge(st, nose, Transform3D(Basis(), Vector3(0, -0.14, 0.31)), 0.04)
	var teeth := BoxMesh.new()
	teeth.size = Vector3(0.24, 0.04, 0.05)
	_merge(st, teeth, Transform3D(Basis(), Vector3(0, -0.2, 0.28)), 0.35)
	st.generate_normals()
	var mesh := st.commit()
	_meshes["skull"] = mesh
	return mesh


## A long bone along x, a knobbed end on each side.
static func bone_mesh() -> ArrayMesh:
	if _meshes.has("bone"):
		return _meshes["bone"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.045
	shaft.bottom_radius = 0.055
	shaft.height = 1.2
	shaft.radial_segments = 8
	shaft.rings = 1
	_merge(st, shaft, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO), 1.0)
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_merge(st, _ball(0.1), Transform3D(Basis(), Vector3(end * 0.62, 0.0, side * 0.07)), 1.0)
	st.generate_normals()
	var mesh := st.commit()
	_meshes["bone"] = mesh
	return mesh
