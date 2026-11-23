extends SceneTree
## Builds assets/animals/Rabbit.glb from the "Rabbit" by CDmir (CC0, opengameart.org/content/rabbit-0,
## rabbit-FBX.7z): the fur shell mesh is dropped, the 1024 px skin is shrunk to 512 px and only the
## animations the game plays are kept, named like the other animals' (see Animal): a hop for the Walk,
## the run for the Gallop, the alert pose on its hind legs for Idle and the sitting one for Eating.
## Copy rabbit.fbx and skin.png (rabbit-skinn.png at 512 px) into assets/animals/rabbit_src/, then:
##   godot --headless --import
##   godot --headless -s tools/build_rabbit.gd
## (the rabbit_src folder itself is not committed).

const SOURCE := "res://assets/animals/rabbit_src/rabbit.fbx"
const SKIN := "res://assets/animals/rabbit_src/skin.png"
const OUT := "res://assets/animals/Rabbit.glb"
const KEEP := {"Idle": "Armature|Guarding", "Walk": "Armature|Jump", "Gallop": "Armature|Running", "Eating": "Armature|Sitting_000"}


func _initialize() -> void:
	var model: Node3D = load(SOURCE).instantiate()
	root.add_child(model)
	var fur := model.find_child("Fur", true, false)
	if fur:
		fur.get_parent().remove_child(fur)
		fur.free()
	# The FBX is in centimetres (its armature is scaled by 100). Here it is made as big as the other
	# animals' models (a fox is 5.9 long), so the same Animal scale of about 0.4 fits all of them.
	model.get_node("Armature").scale = Vector3.ONE * 17.0
	var mesh: MeshInstance3D = model.find_child("Rabbit", true, false)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Rabbit"
	mat.albedo_texture = load(SKIN)
	mat.roughness = 1.0
	for s in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(s, mat)
		mesh.mesh.surface_set_material(s, mat)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var lib := player.get_animation_library(player.get_animation_library_list()[0])
	var made := {}
	for n in KEEP:
		made[n] = lib.get_animation(KEEP[n]).duplicate()
	for n in lib.get_animation_list():
		lib.remove_animation(n)
	for n in made:
		lib.add_animation(n, made[n])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(model, state)
	if err == OK:
		err = doc.write_to_filesystem(state, OUT)
	print("wrote ", OUT, " ", error_string(err))
	quit(0 if err == OK else 1)
