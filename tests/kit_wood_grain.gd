extends SceneTree
## Headless test for the wood of the KayKit buildings in the village (see
## AgedStone.grained_mesh and shaders/aged_stone.gdshader): every building
## wears the aged stone with the timber grain switched on, and its mesh
## carries the way each beam runs in its vertex colours, so the grain lies
## along the beam on every face, the sides too. grain_of picks the long edge
## of a beam's face, not the diagonal.
## Run with: godot --headless --fixed-fps 60 -s tests/kit_wood_grain.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
		if failures == 0:
			print("PASS: kit wood grain")
		else:
			print("FAILED: ", failures)
		return true
	return false


func _run() -> void:
	# A beam's face, 3 m long along x and 0.2 m high: either half of it.
	check(absf(AgedStone.grain_of(Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(3, 0.2, 0)).x) > 0.99,
			"the grain runs along the beam, not across or along the diagonal")
	check(absf(AgedStone.grain_of(Vector3(0, 0, 0), Vector3(3, 0.2, 0), Vector3(0, 0.2, 0)).x) > 0.99,
			"the other half of the face agrees")
	# An upright post: the grain runs up it.
	check(absf(AgedStone.grain_of(Vector3(0, 0, 0), Vector3(0.2, 0, 0), Vector3(0.2, 2.5, 0)).y) > 0.99,
			"the grain runs up a post")

	game.load_level(game._outdoor_index(), false)
	var lvl: Node3D = game.level
	var buildings := 0
	for node in lvl.get_children():
		if not String(node.name).begins_with("building_") or String(node.name).begins_with("building_well"):
			continue
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var mat := mi.material_override as ShaderMaterial
			if mat == null or mat.shader != AgedStone.SHADER:
				continue
			buildings += 1
			check(float(mat.get_shader_parameter("wood_grain")) > 0.5, "%s: the wood shows its grain" % node.name)
			check(mat.get_shader_parameter("wood_tex") is Texture2D, "%s: with the villagers' timber texture" % node.name)
			var arrays := mi.mesh.surface_get_arrays(0)
			var cols = arrays[Mesh.ARRAY_COLOR]
			check(cols != null and (cols as PackedColorArray).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
					"%s: every corner knows its beam's direction" % node.name)
			if cols != null and (cols as PackedColorArray).size() > 0:
				var c: Color = cols[0]
				check(absf(c.a - 0.5) < 0.05, "%s: the direction is marked as one" % node.name)
				var d := Vector3(c.r, c.g, c.b) * 2.0 - Vector3.ONE
				check(absf(d.length() - 1.0) < 0.05, "%s: the direction is a unit vector" % node.name)
	check(buildings >= 6, "the village's KayKit buildings were found (%d)" % buildings)
