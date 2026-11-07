class_name CreatureSkin
extends RefCounted
## Gives the animals and monsters of the wild a skin of their own. The models
## come with flat colours (a yeti's whole body is one patch of its atlas), which
## makes a troll look like a plastic toy. Here the colour stays, and the shader
## of GearLook adds what the skin is made of (shaders/gear_material.gdshaderinc):
## - "hide": the thick skin of an orc or a rock troll, with deep folds, fine
##   wrinkles, pores, mottled colour and old scars,
## - "pelt": the coat of a yeti, wolf, deer, fox or spider, with hairs running
##   down, matted clumps, darker and lighter patches and bare scars.
## Every creature of a kind shares a few materials (VARIANTS of them, which
## differ in where the marks lie), so this costs no more to draw than before.

## The skin each model has, unless a kind names another ("skin").
const SKINS := {"Orc": "hide", "Yeti": "pelt", "Wolf": "pelt", "Spider": "pelt", "Deer": "pelt", "Stag": "pelt", "Fox": "pelt"}
## Surfaces that are not skin: eyes, noses, hooves and horns.
const BARE := ["eye", "nose", "hoof", "horn", "weapon"]
## How many different patterns of marks a skin comes in.
const VARIANTS := 3

static var _materials := {}
static var _white: Texture2D


## Dresses every skin surface of a creature's model: `skin` is "hide" or
## "pelt" (empty: the model's usual skin).
static func dress(model: Node, skin: String, model_name: String) -> void:
	if skin == "":
		skin = SKINS.get(model_name, "")
	if skin == "":
		return
	var variant := randi() % VARIANTS
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible or _bare(String(mesh.name)):
			continue
		var baked := GearLook.with_rest_positions(mesh.mesh)
		var changed := false
		for i in baked.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source == null or (source.emission_enabled and source.emission_energy_multiplier > 0.0) or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if _bare(source.resource_name):
				continue
			if not changed:
				mesh.mesh = baked
				changed = true
			mesh.set_surface_override_material(i, _material(source, skin, variant))


static func _bare(part: String) -> bool:
	var low := part.to_lower()
	for word: String in BARE:
		if low.contains(word):
			return true
	return false


## The shared material for a surface's colour (and texture, where it has one).
static func _material(source: StandardMaterial3D, skin: String, variant: int) -> ShaderMaterial:
	var key := [source.albedo_texture, source.albedo_color, skin, variant]
	if not _materials.has(key):
		if _white == null:
			var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
			img.fill(Color.WHITE)
			_white = ImageTexture.create_from_image(img)
		var tex: Texture2D = source.albedo_texture if source.albedo_texture != null else _white
		var mat := GearLook._look(tex, skin, Color.WHITE, false, -1.0, source.albedo_color)
		mat.set_shader_parameter("seed", Vector3(13.1, 7.7, 19.3) * float(variant))
		_materials[key] = mat
	return _materials[key]
