class_name HairLook
extends RefCounted
## The hero's mohawk. The Rogue model's hair is one smooth shape baked into
## the head mesh, so it is shaved off: its vertices are pulled onto a bald
## skull and coloured like the forehead, with a dark stubble from the shader.
## A crest of hair locks grows along the middle of the skull, from the
## forehead to the nape. Each lock is a thin ribbon that the shader cuts into
## single strands of different lengths (shaders/hair.gdshaderinc).

const SHADER := preload("res://shaders/hair.gdshader")
const FADE_SHADER := preload("res://shaders/hair_fade.gdshader")

## The bald skull the shaved hair is pulled onto, in the head mesh's space.
const SKULL_CENTER := Vector3(0.0, 1.64, -0.06)
const SKULL_RADII := Vector3(0.425, 0.53, 0.45)
## Where the hair is painted in the texture, and a texel of forehead skin.
const HAIR_UV := Rect2(0.125, 0.0, 0.125, 0.25)
const SCALP_UV := Vector2(0.052, 0.105)

## The crest: how many locks, and where it starts and ends on the skull
## (angles along the middle of the skull: 0 is the top, positive is back).
const LOCKS := 150
const SEGMENTS := 6
const CREST_FRONT := -0.95
const CREST_BACK := 1.5


## Shaves the head and gives it the hair material.
static func shave(head: MeshInstance3D) -> void:
	if head == null or head.mesh == null or head.mesh.get_surface_count() == 0:
		return
	var source := head.mesh.surface_get_material(0) as StandardMaterial3D
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var hair := _hair_vertices(verts, uvs, index)
	# CUSTOM0: the position (for the stubble) and whether it is shaved scalp.
	var custom := PackedFloat32Array()
	custom.resize(verts.size() * 4)
	for v in verts.size():
		var p := verts[v]
		if hair[v]:
			p = on_skull(p)
			verts[v] = p
			normals[v] = skull_normal(p)
			uvs[v] = SCALP_UV
		custom[v * 4] = p.x
		custom[v * 4 + 1] = p.y
		custom[v * 4 + 2] = p.z
		custom[v * 4 + 3] = 1.0 if hair[v] else 0.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if head.mesh is ArrayMesh and (head.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var shaved := ArrayMesh.new()
	shaved.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	head.mesh = shaved
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", source.albedo_texture if source else null)
	head.material_override = mat


## The mohawk, in the head mesh's space.
static func crest() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Crest"
	mesh.mesh = crest_mesh()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("crest", true)
	mesh.material_override = mat
	return mesh


## Swaps in the shader that can fade (for a sneaking hero), or back.
static func fade(mat: ShaderMaterial, alpha: float) -> void:
	mat.shader = FADE_SHADER if alpha > 0.0 else SHADER
	mat.set_shader_parameter("fade", alpha)


static func is_hair(mat: Material) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader in [SHADER, FADE_SHADER]


## Pulls a point straight in or out from the skull's centre onto the skull.
static func on_skull(p: Vector3) -> Vector3:
	var d := p - SKULL_CENTER
	var k := (d / SKULL_RADII).length()
	if k < 0.0001:
		return SKULL_CENTER + Vector3.UP * SKULL_RADII.y
	return SKULL_CENTER + d / k


static func skull_normal(p: Vector3) -> Vector3:
	return ((p - SKULL_CENTER) / (SKULL_RADII * SKULL_RADII)).normalized()


## Locks of hair along the middle of the skull. They stand up and lean back a
## little, longest on top, and fan out slightly to the sides. Each lock is a
## tapering ribbon: UV.x runs across it, UV.y from the root (0) to the tip (1);
## COLOR.r is a random number per lock and COLOR.g its shade.
static func crest_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LOCKS:
		var t := (i + rng.randf()) / LOCKS
		var theta := lerpf(CREST_FRONT, CREST_BACK, t)
		var x := clampf(rng.randfn(0.0, 0.035), -0.09, 0.09)
		var root := SKULL_CENTER + Vector3(x / SKULL_RADII.x, cos(theta), -sin(theta)).normalized() * SKULL_RADII
		var normal := skull_normal(root)
		# Backwards along the middle of the skull.
		var back := Vector3(0.0, -sin(theta) * SKULL_RADII.y, -cos(theta) * SKULL_RADII.z).normalized()
		var lock_length := (0.12 + 0.32 * pow(sin(PI * clampf(t * 0.9 + 0.08, 0.0, 1.0)), 0.7)) * (0.8 + 0.35 * rng.randf())
		var dir := (normal + back * 0.12 + Vector3(x * 4.3, 0.0, 0.0)).normalized()
		# The ribbon lies mostly along the crest, some locks turned a little.
		var side := dir.cross(back).normalized()
		var turn := rng.randfn(0.0, 0.5)
		var across := back * cos(turn) + side * sin(turn)
		across = (across - dir * across.dot(dir)).normalized()
		var width := 0.05 + 0.02 * rng.randf()
		var color := Color(rng.randf(), rng.randf(), 0.0)
		var points: Array[Vector3] = []
		var dirs: Array[Vector3] = []
		var p := root - normal * 0.01 # Rooted just under the skin.
		for s in SEGMENTS + 1:
			points.append(p)
			dirs.append(dir)
			# Bend back and down a little, with a slight wave.
			var wobble := Vector3(rng.randfn(0.0, 0.03), rng.randfn(0.0, 0.03), rng.randfn(0.0, 0.03))
			dir = (dir + back * 0.05 + Vector3(0.0, -0.02, 0.0) + wobble).normalized()
			p += dir * lock_length / SEGMENTS
		for s in SEGMENTS:
			var v0 := float(s) / SEGMENTS
			var v1 := float(s + 1) / SEGMENTS
			var w0 := width * (1.0 - 0.85 * v0)
			var w1 := width * (1.0 - 0.85 * v1)
			var a0 := points[s] - across * w0
			var a1 := points[s] + across * w0
			var b0 := points[s + 1] - across * w1
			var b1 := points[s + 1] + across * w1
			var n0 := across.cross(dirs[s]).normalized()
			var n1 := across.cross(dirs[s + 1]).normalized()
			for corner in [[a0, 0.0, v0, n0], [a1, 1.0, v0, n0], [b1, 1.0, v1, n1], [a0, 0.0, v0, n0], [b1, 1.0, v1, n1], [b0, 0.0, v1, n1]]:
				st.set_color(color)
				st.set_uv(Vector2(corner[1], corner[2]))
				st.set_normal(corner[3])
				st.add_vertex(corner[0])
	return st.commit()


## The vertices of the hair: the biggest connected piece painted with the
## hair colour (the eyebrows are smaller pieces of the same colour).
static func _hair_vertices(verts: PackedVector3Array, uvs: PackedVector2Array, index: PackedInt32Array) -> Array[bool]:
	var n := verts.size()
	var painted: Array[bool] = []
	painted.resize(n)
	var parent: Array[int] = []
	parent.resize(n)
	for i in n:
		parent[i] = i
		painted[i] = HAIR_UV.has_point(uvs[i])
	# Vertices at the same place belong together (the mesh is split at UV seams).
	var first := {}
	for i in n:
		if not painted[i]:
			continue
		var key := Vector3i((verts[i] * 1000.0).round())
		if first.has(key):
			_join(parent, i, first[key])
		else:
			first[key] = i
	for t in range(0, index.size(), 3):
		var a := index[t]
		var b := index[t + 1]
		var c := index[t + 2]
		if painted[a] and painted[b] and painted[c]:
			_join(parent, a, b)
			_join(parent, a, c)
	var sizes := {}
	var biggest := -1
	for i in n:
		if painted[i]:
			var r := _root(parent, i)
			sizes[r] = sizes.get(r, 0) + 1
			if biggest < 0 or sizes[r] > sizes[biggest]:
				biggest = r
	var result: Array[bool] = []
	result.resize(n)
	for i in n:
		result[i] = painted[i] and _root(parent, i) == biggest
	return result


static func _root(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _join(parent: Array[int], a: int, b: int) -> void:
	parent[_root(parent, a)] = _root(parent, b)
