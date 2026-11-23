extends SceneTree
## Headless test for Smith Gorm's bandana (see Bandana): he wears it on his head bone,
## it sits above his eyes and over the crown, a winter hat hides it, and nobody else wears one.
## Run with: godot --headless --fixed-fps 60 -s tests/bandana.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(4)
	# With a display the village is shown only once it has warmed up.
	for i in 600:
		if game.level.visible:
			break
		await _wait(1)
	var smith: Villager = null
	for v: Villager in game.level.villagers:
		if v.role == "1":
			smith = v
		else:
			check(v.find_child(Bandana.TAG, true, false) == null, "%s wears no bandana" % v.role)
	check(smith != null, "the smith lives in the village")
	if smith:
		var cloth := smith.find_child(Bandana.TAG, true, false) as MeshInstance3D
		check(cloth != null, "Gorm wears his bandana")
		if cloth:
			check(cloth.get_parent() is BoneAttachment3D and (cloth.get_parent() as BoneAttachment3D).bone_name == "head", "the bandana hangs from the head bone")
			var box := WinterWear._head_box(smith._model)
			var m := cloth.mesh.get_aabb()
			check(m.end.y > box.end.y, "the cloth covers the crown")
			check(m.position.y > TownsfolkLook.EYE_Y + 0.05, "the cloth stays above the eyes (%f)" % m.position.y)
			check(m.position.x < box.position.x and m.end.x > box.end.x, "the band is wider than the head")
			check(m.position.z < box.position.z, "the knot sits behind the head")
			check(cloth.material_override is ShaderMaterial, "the cloth has the woven look, not a plain material")
		Bandana.put_on(smith._model)
		check(smith.find_children(Bandana.TAG, "", true, false).size() == 1, "the bandana is tied only once")
		Bandana.show_on(smith._model, false)
		check(not (smith.find_child(Bandana.TAG, true, false) as Node3D).visible, "a winter hat hides the bandana")
		Bandana.show_on(smith._model, true)
		await _shots(smith)
	game.delete_save(game.save_path())
	print("PASS: bandana" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shots(smith: Villager) -> void:
	if shots == "":
		return
	await _wait(120)
	var at := smith.global_position + Vector3(0, 1.4, 0)
	var face := smith.global_basis.z.normalized()
	await _shot("bandana_close", at, face * 2.6 + Vector3(0, 0.9, 0) + smith.global_basis.x * 0.9)
	await _shot("bandana_game_view", smith.global_position, game.camera.global_position - game.player.global_position)


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3) -> void:
	var lvl: Level = game.level
	if lvl.fog:
		lvl.fog.visible = false
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = 45.0 if name.ends_with("close") else game.camera.fov
	root.add_child(cam)
	cam.global_position = at + from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	if lvl.fog:
		lvl.fog.visible = true
	for layer in hidden:
		layer.visible = true
