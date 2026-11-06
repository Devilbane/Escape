extends SceneTree
## Headless test for the postmaster's peaked cap (see PostCap): Postmeister
## Anselm wears it on his head bone, it covers the top of his head without
## hiding his eyes, a bird perches on its flat top, and nobody else wears it.
## Run with: godot --headless --fixed-fps 60 -s tests/post_cap.gd
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
	var postmaster: Villager = null
	for v: Villager in game.level.villagers:
		if v.role == "M":
			postmaster = v
		else:
			check(v.find_child("PostCap", true, false) == null, "%s wears no post cap" % v.role)
	check(postmaster != null, "the postmaster lives in the village")
	if postmaster:
		var cap := postmaster.find_child("PostCap", true, false) as MeshInstance3D
		check(cap != null, "the postmaster wears his cap")
		if cap:
			check(cap.get_parent() is BoneAttachment3D and (cap.get_parent() as BoneAttachment3D).bone_name == "head", "the cap hangs from the head bone")
			check(cap.find_child("Cord", true, false) != null, "the cap has its gold cord")
			var head := postmaster.find_child("Rogue_Head", true, false) as MeshInstance3D
			var box := cap.mesh.get_aabb()
			var skull := head.mesh.get_aabb()
			check(box.end.y > skull.end.y, "the cap's top is above the top of the head")
			check(box.position.y > BodyLook.LIP_HEIGHT + 0.2, "the peak stays above the eyes")
			check(box.end.z > skull.end.z, "the peak reaches out in front of the face")
			# Out in the village (he may be indoors with a letter just now).
			postmaster.visible = true
			postmaster._head_top = -1.0
			var with_cap: float = postmaster._top_of_head()
			cap.visible = false
			postmaster._head_top = -1.0
			var bare: float = postmaster._top_of_head()
			cap.visible = true
			postmaster._head_top = -1.0
			check(with_cap > bare, "a bird perches on top of the cap")
		# The same cap is put on only once.
		PostCap.put_on(postmaster._model)
		check(postmaster.find_children("PostCap", "", true, false).size() == 1, "the cap is put on only once")
		await _shots(postmaster)
	game.delete_save(game.save_path())
	print("PASS: post cap" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shots(postmaster: Villager) -> void:
	if shots == "":
		return
	await _wait(120)
	var at := postmaster.global_position + Vector3(0, 1.4, 0)
	var face := postmaster.global_basis.z.normalized()
	await _shot("post_cap_close", at, face * 2.6 + Vector3(0, 0.9, 0) + postmaster.global_basis.x * 0.9)
	await _shot("post_cap_game_view", postmaster.global_position, game.camera.global_position - game.player.global_position)


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
