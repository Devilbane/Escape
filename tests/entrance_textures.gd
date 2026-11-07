extends SceneTree
## Headless test: every dungeon entrance on the open-air map is built from the
## aged, textured materials (AgedStone), not from plain colours: the lair's
## arch, the mines' timber, the Great Old One's cave and the Ashen Spire's gate.
## Run with: godot --headless -s tests/entrance_textures.gd

var failures := 0
var checks := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _plain_boxes_near(out: Node3D, at: Vector3, radius: float) -> int:
	var n := 0
	for mi: MeshInstance3D in out.find_children("*", "MeshInstance3D", false, false):
		if not mi.mesh is BoxMesh or mi.material_override == null:
			continue
		var d := Vector2(mi.position.x - at.x, mi.position.z - at.z).length()
		if d < radius and mi.material_override is StandardMaterial3D:
			var m := mi.material_override as StandardMaterial3D
			# The dark openings are meant to be unlit black; everything else is stone or timber.
			if m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and not m.emission_enabled:
				n += 1
	return n


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	var out: Outdoor = game.level
	var ids: Array = []
	for id: String in out.doors:
		if id.begins_with("mine") or id in [Outdoor.ELDER_CAVE, Outdoor.SPIRE_GATE]:
			ids.append(id)
	check(ids.size() >= 4, "the map has mines, the cave and the spire gate (%d)" % ids.size())
	for id in ids:
		var near := _plain_boxes_near(out, out.doors[id], 8.0)
		check(near == 0, "%s has no plain-coloured stone or timber (%d)" % [id, near])
	check(AgedStone.timber_material(Color(0.34, 0.23, 0.14)) is ShaderMaterial, "mine timber is the aged, grained shader")
	game.delete_save(game.save_path())
	print("PASS: entrance textures (%d checks)" % checks if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
