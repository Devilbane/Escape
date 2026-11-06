class_name GearLook
extends RefCounted
## Shows what worn gear and whole characters are made of, so they look less
## like plastic: cloth gets a fine weave and a matt surface, leather a pebbled grain
## and a soft sheen, metal hammered dents, and so on (the shader is
## shaders/gear_material.gdshaderinc). Items name their material in
## Items.ALL ("material"); weapons and shields are "mixed": wood, with metal
## wherever their texture is grey. The hero's own clothes are an "outfit":
## cloth, leather or metal, read from the colours of the texture.

const SHADER := preload("res://shaders/tint.gdshader")

## Material names as items use them, and the shader's number for each.
## "scale" (the beast scale armour of ArmourSets) has the grain of chain.
## "remains" is a skeleton's whole model: like an outfit, but pale parts are bone.
const KINDS := {"cloth": 1, "leather": 2, "metal": 3, "chain": 4, "scale": 4, "fur": 5, "bone": 6, "wood": 7, "mixed": 7, "outfit": 8, "remains": 9}
## How metallic metal is when an item does not say.
const DEFAULT_METAL := {"metal": 0.45, "chain": 0.4, "scale": 0.35}

## Meshes that already carry their rest positions, by source mesh.
static var _baked := {}
## The shared materials of dress_body, by texture, material and dye.
static var _body_looks := {}
## Hats with a narrowed brim, by source mesh and how much brim is kept.
static var _narrowed := {}
## How wide a hat's crown is where the brim begins, and how high the brim
## reaches (in the hat's own units, as the models of assets/characters have them).
const CROWN_RADIUS := 0.55
const BRIM_TOP := 0.2


## Puts the material look on every mesh of a node (a held weapon, a hat).
## A tint other than white recolours it too (the hoods and helmets of the
## armour sets, see ArmourSets).
static func dress(node: Node, material: String, tint := Color.WHITE, metal := -1.0) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		apply(mesh, material, tint, tint != Color.WHITE, metal)


## Pulls a hat's brim in towards the crown, so it no longer hides the face:
## `keep` is how much of the brim's width is left (0.4 keeps 40 %). The crown
## and the tip stay as they are. Used on the hero's wizard hat ("brim" in
## Items.ALL); villagers wearing the same hat keep the wide brim.
static func narrow_brim(node: Node, keep: float) -> void:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var key := [mesh.mesh, keep]
		if not _narrowed.has(key):
			_narrowed[key] = _narrowed_mesh(mesh.mesh, keep)
		mesh.mesh = _narrowed[key]


static func _narrowed_mesh(mesh: Mesh, keep: float) -> Mesh:
	var narrow := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts.size():
			var p := verts[v]
			var flat := Vector2(p.x, p.z)
			var r := flat.length()
			if p.y < BRIM_TOP and r > CROWN_RADIUS:
				flat *= (CROWN_RADIUS + (r - CROWN_RADIUS) * keep) / r
				verts[v] = Vector3(flat.x, p.y, flat.y)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var flags := 0
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		narrow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		narrow.surface_set_material(i, mesh.surface_get_material(i))
	return narrow


## Gives one mesh the look of a material; with a tint it is also recoloured
## (worn cloaks, armour and shoes). metal < 0 takes the material's default.
static func apply(mesh: MeshInstance3D, material: String, tint := Color.WHITE, recolor := false, metal := -1.0) -> void:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return
	var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null or source.albedo_texture == null:
		return
	mesh.mesh = with_rest_positions(mesh.mesh)
	mesh.material_override = _look(source.albedo_texture, material, tint, recolor, metal)


static func _look(texture: Texture2D, material: String, tint := Color.WHITE, recolor := false, metal := -1.0, dye := Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", texture)
	mat.set_shader_parameter("recolor", recolor)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("metal", metal if metal >= 0.0 else DEFAULT_METAL.get(material, 0.0))
	mat.set_shader_parameter("stuff", KINDS.get(material, 0))
	mat.set_shader_parameter("metal_where_grey", material in ["mixed", "outfit", "remains"])
	mat.set_shader_parameter("dye", dye)
	return mat


## Gives a whole character model (a villager, a bandit, a skeleton) the look
## of what it is made of: material "outfit" for people, "remains" for the
## dead. A part still drawn with the model's own plain material keeps the
## colour it was dyed; a part already recoloured by the tint shader (brutes,
## worn cloaks) gets the grain on top. Parts with a look of their own
## (glowing eyes, hair, ghosts, props) are left as they are.
static func dress_body(model: Node, material: String) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
			continue
		var own := mesh.get_active_material(0)
		if own is ShaderMaterial and (own as ShaderMaterial).shader == SHADER:
			var tinted := own as ShaderMaterial
			var stuff = tinted.get_shader_parameter("stuff")
			if stuff == null or int(stuff) == 0:
				mesh.mesh = with_rest_positions(mesh.mesh)
				tinted.set_shader_parameter("stuff", KINDS[material])
				tinted.set_shader_parameter("metal_where_grey", true)
			continue
		if _in_prop(mesh, model):
			continue
		var plain := own as StandardMaterial3D
		var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if plain == null or source == null or plain.albedo_texture == null or plain.albedo_texture != source.albedo_texture:
			continue
		if plain.emission_enabled or plain.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or plain.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			continue
		# A person's own body has no metal on it: grey there is hair, a beard
		# or a glove (helmets, weapons and buckles are parts of their own).
		var grey_is_metal := material != "outfit" or not _is_body(mesh)
		var key := [plain.albedo_texture, material, plain.albedo_color, grey_is_metal]
		if not _body_looks.has(key):
			_body_looks[key] = _look(plain.albedo_texture, material, Color.WHITE, false, -1.0, plain.albedo_color)
			_body_looks[key].set_shader_parameter("metal_where_grey", grey_is_metal)
		mesh.mesh = with_rest_positions(mesh.mesh)
		mesh.material_override = _body_looks[key]


## Whether a mesh belongs to a village prop someone carries (a bucket, a
## sack): those weather like the props around them (see WeatheredProps).
static func _in_prop(mesh: Node, model: Node) -> bool:
	var node := mesh
	while node != null and node != model:
		if node.scene_file_path != "" and WeatheredProps.MODELS.has(node.scene_file_path.get_file().get_basename()):
			return true
		node = node.get_parent()
	return false


## The parts every character model has: head, body, arms and legs.
const BODY_PARTS := ["Head", "Body", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]


static func _is_body(mesh: MeshInstance3D) -> bool:
	return String(mesh.name).get_slice("_", String(mesh.name).get_slice_count("_") - 1) in BODY_PARTS


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
