class_name WornLook
extends RefCounted
## Makes dungeon furniture look old and used, to match the dusty floor:
## chests, trunks, barrels, crates, tables, beds, doors and the wall
## decorations get grime, dust on top, scratches, chipped spots, rust on iron
## fittings and dull brass, and flags and banners fade and get moth holes
## (the shader is shaders/worn.gdshader). One material is shared by every
## part with the same texture, so the props still draw in few batches.

const SHADER := preload("res://shaders/worn.gdshader")
## How worn things look in the dungeon, and in the hero's own home (lived in
## and looked after, but not new).
const DUNGEON := 1.0
const HOME := 0.35

static var _materials := {}


## The worn material for a texture (with its normal map, if it has one).
## tint darkens or colours the texture; cloth: flags and banners.
## flat: the texture is flat cartoon colour (KayKit), not painted wood and metal.
static func material(albedo: Texture2D, normal: Texture2D = null, strength := DUNGEON, cloth := false, tint := Color.WHITE, flat := false) -> ShaderMaterial:
	var key := [albedo, normal, strength, cloth, tint, flat]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_tex", albedo)
		m.set_shader_parameter("use_normal_map", normal != null)
		if normal != null:
			m.set_shader_parameter("normal_tex", normal)
		m.set_shader_parameter("albedo_color", tint)
		m.set_shader_parameter("strength", strength)
		m.set_shader_parameter("cloth", cloth)
		m.set_shader_parameter("flat_texture", flat)
		_materials[key] = m
	return _materials[key]


## Wears every textured mesh of a KayKit model (a chest, bed or banner):
## each keeps its own texture and colour.
static func wear(node: Node, strength := DUNGEON, cloth := false) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		wear_mesh(mi, strength, cloth)


static func wear_mesh(mi: MeshInstance3D, strength := DUNGEON, cloth := false, tint := Color.WHITE) -> void:
	var source := mi.get_active_material(0) as StandardMaterial3D
	if source == null or source.albedo_texture == null:
		return
	var colour := source.albedo_color * tint
	mi.material_override = material(source.albedo_texture, source.normal_texture if source.normal_enabled else null, strength, cloth, colour, true)
