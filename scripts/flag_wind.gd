class_name FlagWind
extends Node
## Flags and banners flutter gently in the wind: the village's flags on their
## poles, the dungeon's wall flags, the tattered banners of the dragon's lair
## and the banners behind the shields in the hero's home. A wave runs through
## the cloth from the edge it hangs by to its free end (the vertex shader is
## shaders/flutter.gdshaderinc, part of worn.gdshader and
## weathered_prop.gdshader). Outside it goes by the weather, like the
## windmill's sails (see Windmill): a breeze under clear skies, brisker in the
## rain, hardly a stir in the still air of fog and wild in a thunderstorm.
## Down in the dungeon a soft draught stirs them. When the weather changes the
## wind picks up or dies down gently instead of jumping.
##
## The models' cloth is a few large faces, too few to bend, so each cloth
## mesh is cut into narrow strips across the way the wave runs (once per
## model, shared by every copy). The flutter materials are shared too: one per
## material and model.

## Each model whose cloth moves: which mesh and which of its surfaces are
## cloth, and in that mesh's own space a point on the edge it hangs by, the
## way from there to the free end and the way it swings; and how far the free
## end swings, as a share of the cloth's length (in a breeze).
const SHAPES := {
	# A pennant on a pole, flying out sideways from it.
	"flag_red": {"mesh": "flag_red", "surfaces": [0], "root": Vector3(0, 0, -0.02),
			"reach": Vector3(0, 0, -0.222), "push": Vector3(1, 0, 0), "flutter": 0.16},
	"flag_blue": {"mesh": "flag_blue", "surfaces": [0], "root": Vector3(0, 0, -0.02),
			"reach": Vector3(0, 0, -0.222), "push": Vector3(1, 0, 0), "flutter": 0.16},
	# Wall flags hanging from a rod (Level.WALL_DECOR).
	"SM_RedFlag": {"mesh": "SM_RedFlag", "surfaces": [0], "root": Vector3(0, 0.05, 0),
			"reach": Vector3(0, -1.21, 0), "push": Vector3(0, 0, 1), "flutter": 0.12},
	"SM_BlueFlag": {"mesh": "SM_BlueFlag", "surfaces": [0], "root": Vector3(0, 0.05, 0),
			"reach": Vector3(0, -1.21, 0), "push": Vector3(0, 0, 1), "flutter": 0.12},
	# The lair's banner on its stand: only the cloth (the model stands on its
	# z axis); the pole and the iron stay still.
	"Banner": {"mesh": "Banner", "surfaces": [2], "root": Vector3(0, 0, 0.031),
			"reach": Vector3(0, 0, -0.029), "push": Vector3(0, 1, 0), "flutter": 0.12},
	# The banners behind the shields in the hero's home: the shield and its
	# swords are fixed to the cloth, so only the hem below them stirs.
	"banner_shield_brown": {"mesh": "banner_shield_brown", "surfaces": [0], "root": Vector3(0, 1.3, 0),
			"reach": Vector3(0, -0.77, 0), "push": Vector3(0, 0, 1), "flutter": 0.22},
}
## The wind in each weather: how hard it blows (1 is a breeze) and how fast
## its waves run through the cloth (radians per second).
const WINDS := {
	Weather.CLEAR: Vector2(1.0, 4.5),
	Weather.RAIN: Vector2(1.6, 6.2),
	Weather.FOG: Vector2(0.4, 2.5),
	Weather.STORM: Vector2(2.6, 8.5),
}
## The shader for cloth that had a plain material.
const CLOTH := preload("res://shaders/flutter_cloth.gdshader")
## The soft draught down in the dungeon.
const DRAUGHT := Vector2(0.6, 3.0)
## How long the wind takes to come most of the way to a new weather's (seconds).
const EASE := 6.0
## The cloth is cut until a strip spans at most this share of its length.
const STEP := 0.08

## The flutter materials (to be told the wind each frame) and cut meshes.
static var _materials := {}
static var _meshes := {}

## The wind now: strength and speed (see WINDS), and how far its waves have run.
var wind := WINDS[Weather.CLEAR] as Vector2
var phase := 0.0
var _level: Node


## Makes the cloth of a model placed by `level` flutter. Does nothing for a
## model that has no cloth (see SHAPES).
static func attach(node: Node, model: String, level: Node) -> void:
	if not SHAPES.has(model):
		return
	var shape: Dictionary = SHAPES[model]
	var meshes := node.find_children(shape.mesh, "MeshInstance3D", true, false)
	if node is MeshInstance3D and node.name == shape.mesh:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		_dress(mi, model, shape)
	if meshes.size() > 0 and level and not level.has_node("FlagWind"):
		var driver := FlagWind.new()
		driver.name = "FlagWind"
		driver._level = level
		driver.wind = wind_for(level.get("weather") if "weather" in level else "")
		level.add_child(driver)


## The wind in a weather; "" (no weather: down in the dungeon) is the draught.
static func wind_for(weather: String) -> Vector2:
	if weather == "":
		return DRAUGHT
	return WINDS.get(weather, WINDS[Weather.CLEAR])


func _process(delta: float) -> void:
	var target := wind_for(_level.get("weather") if _level and "weather" in _level else "")
	wind = wind.lerp(target, 1.0 - exp(-delta * 3.0 / EASE))
	phase = fmod(phase + wind.y * delta, TAU * 1000.0)
	for mat: ShaderMaterial in _materials.values():
		mat.set_shader_parameter("wind_strength", wind.x)
		mat.set_shader_parameter("wind_phase", phase)


## Gives one mesh its cut cloth and flutter materials.
static func _dress(mi: MeshInstance3D, model: String, shape: Dictionary) -> void:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null:
		return
	var count := mesh.get_surface_count()
	# Each surface's material as it looks now, kept per surface.
	var mats: Array[Material] = []
	for s in count:
		mats.append(mi.get_active_material(s))
	mi.material_override = null
	var key := [mesh, model]
	if not _meshes.has(key):
		_meshes[key] = _cut(mesh, shape)
	mi.mesh = _meshes[key]
	for s in count:
		var mat := mats[s]
		if s in shape.surfaces:
			mat = _flutter_material(mat, shape)
		mi.set_surface_override_material(s, mat)


## The flutter copy of a material. A plain material (the lair's banner) gets
## the plain cloth shader in its own colours instead.
static func _flutter_material(source: Material, shape: Dictionary) -> ShaderMaterial:
	var key := [source, shape]
	if _materials.has(key):
		return _materials[key]
	var base := source as ShaderMaterial
	if base == null:
		var plain := source as StandardMaterial3D
		base = ShaderMaterial.new()
		base.shader = CLOTH
		if plain:
			if plain.albedo_texture:
				base.set_shader_parameter("albedo_tex", plain.albedo_texture)
			base.set_shader_parameter("albedo_color", plain.albedo_color)
			base.set_shader_parameter("roughness", plain.roughness)
			base.set_shader_parameter("metallic", plain.metallic)
	var mat := base.duplicate() as ShaderMaterial
	mat.set_shader_parameter("flutter", shape.flutter)
	mat.set_shader_parameter("flutter_root", shape.root)
	mat.set_shader_parameter("flutter_reach", shape.reach)
	mat.set_shader_parameter("flutter_push", shape.push)
	mat.set_shader_parameter("wind_strength", DRAUGHT.x)
	_materials[key] = mat
	return mat


## A copy of the mesh whose cloth surfaces are cut into narrow strips across
## the way the wave runs, so they can bend. An edge is cut in half while its
## ends lie further apart along the cloth than STEP; the cut only depends on
## the edge's own ends, so two faces sharing an edge always cut it alike and
## the cloth never tears open.
static func _cut(mesh: ArrayMesh, shape: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if s in shape.surfaces and mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			arrays = _cut_arrays(arrays, shape.root, shape.reach)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	return out


static func _cut_arrays(arrays: Array, root: Vector3, reach: Vector3) -> Array:
	var cutter := _Cutter.new(arrays, root, reach)
	cutter.run()
	return cutter.result()


## Cuts one surface (see _cut). Kept in an object so that the vertex lists
## grow in place as edges are halved.
class _Cutter:
	var verts: PackedVector3Array
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var index := PackedInt32Array()
	var root: Vector3
	var reach: Vector3
	var halves := {}

	func _init(arrays: Array, from: Vector3, to_end: Vector3) -> void:
		root = from
		reach = to_end
		verts = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		if arrays[Mesh.ARRAY_TANGENT] != null:
			tangents = arrays[Mesh.ARRAY_TANGENT]
		if arrays[Mesh.ARRAY_COLOR] != null:
			colours = arrays[Mesh.ARRAY_COLOR]
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV]
		if arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2s = arrays[Mesh.ARRAY_TEX_UV2]
		if arrays[Mesh.ARRAY_INDEX] != null:
			index = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			for i in verts.size():
				index.append(i)

	## How far along the cloth a point lies: 0 at the fixed edge, 1 at the free end.
	func along(p: Vector3) -> float:
		return clampf((p - root).dot(reach) / reach.length_squared(), 0.0, 1.0)

	func long(a: int, b: int) -> bool:
		return absf(along(verts[a]) - along(verts[b])) > STEP

	## The middle of edge a-b as a vertex (made once per edge).
	func half(a: int, b: int) -> int:
		var k := Vector2i(mini(a, b), maxi(a, b))
		if halves.has(k):
			return halves[k]
		verts.append((verts[a] + verts[b]) * 0.5)
		if not normals.is_empty():
			normals.append((normals[a] + normals[b]).normalized())
		if not tangents.is_empty():
			var t := (Vector3(tangents[a * 4], tangents[a * 4 + 1], tangents[a * 4 + 2]) \
					+ Vector3(tangents[b * 4], tangents[b * 4 + 1], tangents[b * 4 + 2])).normalized()
			tangents.append_array([t.x, t.y, t.z, tangents[a * 4 + 3]])
		if not colours.is_empty():
			colours.append(colours[a].lerp(colours[b], 0.5))
		if not uvs.is_empty():
			uvs.append((uvs[a] + uvs[b]) * 0.5)
		if not uv2s.is_empty():
			uv2s.append((uv2s[a] + uv2s[b]) * 0.5)
		halves[k] = verts.size() - 1
		return halves[k]

	func run() -> void:
		for _pass in 12:
			var next := PackedInt32Array()
			var cut_any := false
			for f in range(0, index.size(), 3):
				var tri := [index[f], index[f + 1], index[f + 2]]
				var cut := [long(tri[0], tri[1]), long(tri[1], tri[2]), long(tri[2], tri[0])]
				var n := cut.count(true)
				if n == 0:
					next.append_array(tri)
					continue
				cut_any = true
				# Turn the face so that the cut edges come first: a-b, then b-c.
				var turn := 0
				if n == 1:
					turn = cut.find(true)
				elif n == 2:
					turn = (cut.find(false) + 1) % 3
				var a: int = tri[turn]
				var b: int = tri[(turn + 1) % 3]
				var c: int = tri[(turn + 2) % 3]
				var ab := half(a, b)
				if n == 1:
					next.append_array([a, ab, c, ab, b, c])
				elif n == 2:
					var bc := half(b, c)
					next.append_array([ab, b, bc, a, ab, bc, a, bc, c])
				else:
					var bc := half(b, c)
					var ca := half(c, a)
					next.append_array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca])
			index = next
			if not cut_any:
				break

	func result() -> Array:
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_INDEX] = index
		if not normals.is_empty():
			out[Mesh.ARRAY_NORMAL] = normals
		if not tangents.is_empty():
			out[Mesh.ARRAY_TANGENT] = tangents
		if not colours.is_empty():
			out[Mesh.ARRAY_COLOR] = colours
		if not uvs.is_empty():
			out[Mesh.ARRAY_TEX_UV] = uvs
		if not uv2s.is_empty():
			out[Mesh.ARRAY_TEX_UV2] = uv2s
		return out
