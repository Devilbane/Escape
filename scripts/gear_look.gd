class_name GearLook
extends RefCounted
## Gives worn gear a faint hint of what it is made of, so it looks less like
## plastic: cloth gets a fine weave and a matt surface, leather a pebbled grain
## and a soft sheen, metal hammered dents, and so on (the shader is
## shaders/gear_material.gdshaderinc). Items name their material in
## Items.ALL ("material"); weapons and shields are "mixed": wood, with metal
## wherever their texture is grey. The hero's own clothes are an "outfit":
## cloth, leather or metal, read from the colours of the texture.

const SHADER := preload("res://shaders/tint.gdshader")

## Material names as items use them, and the shader's number for each.
const KINDS := {"cloth": 1, "leather": 2, "metal": 3, "chain": 4, "fur": 5, "bone": 6, "wood": 7, "mixed": 7, "outfit": 8}
## How metallic metal is when an item does not say.
const DEFAULT_METAL := {"metal": 0.45, "chain": 0.4}

## Meshes that already carry their rest positions, by source mesh.
static var _baked := {}


## Puts the material look on every mesh of a node (a held weapon, a hat).
static func dress(node: Node, material: String) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		apply(mesh, material)


## Gives one mesh the look of a material; with a tint it is also recoloured
## (worn cloaks, armour and shoes). metal < 0 takes the material's default.
static func apply(mesh: MeshInstance3D, material: String, tint := Color.WHITE, recolor := false, metal := -1.0) -> void:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return
	var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null or source.albedo_texture == null:
		return
	mesh.mesh = with_rest_positions(mesh.mesh)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", source.albedo_texture)
	mat.set_shader_parameter("recolor", recolor)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("metal", metal if metal >= 0.0 else DEFAULT_METAL.get(material, 0.0))
	mat.set_shader_parameter("stuff", KINDS.get(material, 0))
	mat.set_shader_parameter("metal_where_grey", material in ["mixed", "outfit"])
	mesh.material_override = mat


## A copy of a mesh whose vertices also carry their rest position (CUSTOM0).
## The shader takes the grain from it, so the grain stays on the surface
## while a skinned part bends and moves.
static func with_rest_positions(mesh: Mesh) -> Mesh:
	if _baked.has(mesh) or mesh in _baked.values():
		return _baked.get(mesh, mesh)
	var baked := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest := PackedFloat32Array()
		rest.resize(verts.size() * 3)
		for v in verts.size():
			rest[v * 3] = verts[v].x
			rest[v * 3 + 1] = verts[v].y
			rest[v * 3 + 2] = verts[v].z
		arrays[Mesh.ARRAY_CUSTOM0] = rest
		var flags := Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		baked.surface_set_material(i, mesh.surface_get_material(i))
	_baked[mesh] = baked
	return baked
