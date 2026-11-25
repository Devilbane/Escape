extends SceneTree
## Headless test for Miller Korbinian's quiff (see MillerQuiff).
## Run with: godot --headless --fixed-fps 60 -s tests/miller_quiff.gd
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
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(4)
	for i in 600:
		if game.level.visible:
			break
		await _wait(1)
	var miller: Villager = null
	for v: Villager in game.level.villagers:
		if v.role == "ü":
			miller = v
		else:
			check(v.find_child("Quiff", true, false) == null, "%s wears no quiff" % v.role)
	check(miller != null, "Korbinian lives in the village")
	if miller:
		var hair := miller.find_child("Quiff", true, false) as MeshInstance3D
		check(hair != null, "Korbinian wears his quiff")
		if hair:
			check(hair.get_parent() is BoneAttachment3D and (hair.get_parent() as BoneAttachment3D).bone_name == "head", "the quiff hangs from the head bone")
			var head := miller.find_child("Barbarian_Head", true, false) as MeshInstance3D
			var box := hair.mesh.get_aabb()
			var skull := head.mesh.get_aabb()
			check(box.end.y > skull.end.y, "the wave rises above the skull")
			check(hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 20000, "a full head of fine strands")
			var in_face := 0
			for p: Vector3 in hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf(p.x) < 0.3 and p.y > 1.3 and p.y < 1.8 and p.z > 0.3:
					in_face += 1
			check(in_face == 0, "no strand hangs over the face (%d points)" % in_face)
		MillerQuiff.grow(miller._model)
		check(miller.find_children("Quiff", "", true, false).size() == 1, "the quiff is grown only once")
		await _shots(miller)
	game.delete_save(game.save_path())
	print("PASS: miller_quiff" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shots(miller: Villager) -> void:
	if shots == "":
		return
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 100.0)
	game._weather_look = Weather.look(Weather.CLEAR)
	miller.visible = true
	await _wait(60)
	for look in ["before", "after"]:
		var locks := miller.find_child("Quiff", true, false) as Node3D
		if locks:
			locks.visible = look == "after"
		var at := miller.global_position + Vector3(0, 1.5, 0)
		var face := miller.global_basis.z.normalized()
		var side := miller.global_basis.x.normalized()
		await _shot("quiff_front_" + look, at, face * 2.3 + Vector3(0, 0.25, 0) + side * 0.9)
		await _shot("quiff_back_" + look, at, -face * 3.2 + Vector3(0, 0.7, 0) - side * 1.6)
		await _shot("quiff_side_" + look, at, side * 3.4 + Vector3(0, 0.4, 0))
		await _shot("quiff_game_view_" + look, miller.global_position, (game.camera.global_position - game.player.global_position) * 0.45)


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3) -> void:
	var lvl: Level = game.level
	if is_instance_valid(lvl.fog):
		lvl.fog.visible = false
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = game.camera.fov if name.ends_with("view") else 40.0
	root.add_child(cam)
	cam.global_position = at + from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	if is_instance_valid(lvl.fog):
		lvl.fog.visible = true
	for layer in hidden:
		if is_instance_valid(layer):
			layer.visible = true
