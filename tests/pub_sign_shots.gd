extends SceneTree
## Headless test and pictures: the Apples & Ivy! pub sign (see PubSign). The tavern hangs it by its
## door and a second one stands on a post on the village square, south of and between the two dining
## tents; both hang high enough to walk under, and the post is solid.
## Run with: godot --headless --fixed-fps 60 -s tests/pub_sign_shots.gd
## With SHOTS=<folder> and a display it also saves pictures.

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
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _low(node: Node3D) -> float:
	var low := INF
	for mi: MeshInstance3D in (node.get_node("Board") if node.has_node("Board") else node).find_children("*", "MeshInstance3D", true, false):
		low = minf(low, (mi.global_transform * mi.get_aabb()).position.y)
	return low


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Mason"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(20)
	var lvl: Outdoor = game.level
	lvl.set_hour(10.5)
	var halls: Array = lvl.find_children("HallSign", "Node3D", true, false).filter(func(n: Node) -> bool: return n.name == "HallSign" and n.has_meta("name_text"))
	check(not halls.is_empty(), "the tavern hangs the pub sign by its door")
	var square := lvl.find_child("PubSignSquare", true, false) as Node3D
	check(square != null, "the pub sign stands on the square")
	check(lvl.meals.tables.size() >= 2, "the square has two dining tables")
	if square != null and lvl.meals.tables.size() >= 2:
		var a: Vector3 = lvl.meals.tables[0]
		var b: Vector3 = lvl.meals.tables[1]
		var board := square.get_node("Board") as Node3D
		var mid := (a.x + b.x) * 0.5
		check(absf(board.global_position.x - mid) < 0.2, "the sign hangs midway between the tents")
		check(board.global_position.z > maxf(a.z, b.z) + 2.0, "the sign hangs south of both tents")
		check(_low(square) >= PubSign.CLEAR, "the post sign's board is high enough to walk under (%.2f)" % _low(square))
	for sign_node: Node3D in halls:
		check(_low(sign_node) >= PubSign.CLEAR - 0.2, "the tavern's sign is high enough to walk under (%.2f)" % _low(sign_node))
	if shots != "":
		var front: Vector3 = lvl.doors["n"]
		game.player.global_position = front
		var pitch := deg_to_rad(52.0)
		var tents: Vector3 = lvl.meals.tables[0].lerp(lvl.meals.tables[1], 0.5)
		await _shot("tavern_front", front + Vector3(0, sin(pitch), cos(pitch)) * 15.0, front + Vector3(0, 1.0, -2.0))
		if not halls.is_empty():
			var s: Node3D = halls[0]
			var board := s.get_node("Board") as Node3D
			var c := board.global_position + Vector3(0, -PubSign.TALL * 0.5, 0)
			await _shot("tavern_sign_close", c + board.global_basis.z.normalized() * 4.5 + Vector3(0, 0.5, 0), c)
			await _shot("tavern_sign_wide", c + board.global_basis.z.normalized() * 9.0 + Vector3(0, 3.0, 0), c)
		game.player.global_position = tents + Vector3(0, 0, 6)
		await _shot("square_game_view", tents + Vector3(0, 8.5, 12.5) + Vector3(0, 0, 2.5), tents + Vector3(0, 0.5, 4.0))
		if square != null:
			var board := square.get_node("Board") as Node3D
			var c := board.global_position + Vector3(0, -PubSign.TALL * 0.5, 0)
			await _shot("square_sign_close", c + Vector3(0, 0.3, 3.2), c)
			await _shot("square_sign_wide", c + Vector3(1.0, -0.6, 8.0), c + Vector3(0, -0.8, 0))
			await _shot("square_sign_back", c + Vector3(-1.6, -0.2, -3.2), c)
			await _shot("square_post", square.global_position + Vector3(2.5, 3.0, 6.5), square.global_position + Vector3(0.8, 2.2, 0))
	game.delete_save(game.save_path())
	print("PASS: pub sign" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
