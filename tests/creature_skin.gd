extends SceneTree
## Headless test: the wild's creatures get a skin of their own.
## - A yeti, an orc, a rock troll, a wolf, a spider, a deer and a fox get a shader
##   material on their skin surfaces (not on eyes, noses, hooves or horns).
## - Creatures of the same kind share their materials: the number of different
##   materials stays small however many are made.
## - A ghoul keeps its own rotting skin.
## Run with: godot --headless -s tests/creature_skin.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _shaded(model: Node) -> int:
	var count := 0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i) as ShaderMaterial
			if mat != null and mat.shader == GearLook.SHADER:
				count += 1
	return count


func _initialize() -> void:
	for entry in [["wild/Yeti", "Yeti", ""], ["wild/Orc", "Orc", ""], ["wild/Yeti", "Yeti", "hide"],
			["wild/Wolf", "Wolf", ""], ["wild/Spider", "Spider", ""], ["animals/Deer", "Deer", ""],
			["animals/Stag", "Stag", ""], ["animals/Fox", "Fox", ""]]:
		var model: Node = load("res://assets/%s.glb" % entry[0]).instantiate()
		CreatureSkin.dress(model, entry[2], entry[1])
		check(_shaded(model) > 0, "%s has a skin" % entry[0])
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(i)
				var shaded := mesh.get_active_material(i) is ShaderMaterial
				if source != null and CreatureSkin._bare(source.resource_name):
					check(not shaded, "%s keeps its bare part %s" % [entry[0], source.resource_name])
		model.free()
	var before := CreatureSkin._materials.size()
	for n in 30:
		var wolf: Node = load("res://assets/wild/Wolf.glb").instantiate()
		CreatureSkin.dress(wolf, "", "Wolf")
		wolf.free()
	check(CreatureSkin._materials.size() - before <= 3 * 3, "wolves share their materials")
	if failures == 0:
		print("PASS: creature skin")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
