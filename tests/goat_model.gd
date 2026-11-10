extends SceneTree
## Headless test for the village goats' model (GoatModel): every goat is the sheep model dressed as a
## goat (no fleece, two horns, a beard, ears, a tail), the red-horned goat's horns are red and the others'
## are not, and the animations the herd plays (Idle, Walk, Gallop, Eating) all exist.
## With SHOTS=<folder> and a display it also saves a picture of a goat, a brown one and the red-horned one.
## Run with: godot --headless -s tests/goat_model.gd

var failures := 0
var shots := OS.get_environment("SHOTS")
var frames := 0
var herd: Array[Node3D] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var look := 0
	for spec: Array in [["", false], ["brown", false], ["black", false], ["", true]]:
		var model: Node3D = load("res://assets/animals/Sheep.glb").instantiate()
		model.scale = Vector3.ONE * 0.25
		model.position.x = look * 1.6 - 2.4
		look += 1
		root.add_child(model)
		GoatModel.dress(model, spec[0], spec[1])
		herd.append(model)
		var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var horns := 0
		var red := 0
		for part in skel.find_children("*", "MeshInstance3D", true, false):
			var mat := (part as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null and mat.albedo_color in [GoatModel.HORN, GoatModel.HORN_RED]:
				horns += 1
				red += 1 if mat.albedo_color == GoatModel.HORN_RED else 0
		check(horns == 6, "%s goat: two horns of three parts each (%d)" % [spec[0], horns])
		check(red == (6 if spec[1] else 0), "%s goat: horn colour (%d red)" % [spec[0], red])
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		for a in ["Idle", "Walk", "Gallop", "Eating"]:
			check(player.has_animation(a), "animation " + a)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			if mi.get_parent() is Skeleton3D and not mi.get_parent() is BoneAttachment3D:
				for s in (mi as MeshInstance3D).mesh.get_surface_count():
					var m := (mi as MeshInstance3D).get_surface_override_material(s) as StandardMaterial3D
					check(m != null and m.normal_texture == null, "the coat is smooth, not fleece")
	if shots != "":
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.55, 0.7, 0.85)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		root.add_child(sun)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.make_current()
		cam.look_at_from_position(Vector3(0, 0.8, 4.2), Vector3(0, 0.45, 0))


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		if shots != "":
			root.get_texture().get_image().save_png(shots.path_join("goat_model.png"))
		print("PASS: goat_model" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false
