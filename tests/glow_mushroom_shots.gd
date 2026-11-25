extends SceneTree
## Pictures of the glow mushrooms (see GlowMushrooms): one patch of every kind by day, at dusk and at night,
## a big patch close up, and a village lantern with its mushroom.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/glow_mushroom_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
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


func _hour(h: float) -> void:
	game.day_hour = h
	game.level.set_hour(h)
	await _wait(20)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Glow shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	# A clear stretch of grass for a row of patches.
	var spot := Vector3.INF
	for y in range(8, level.height - 8):
		for x in range(8, level.width - 8):
			var ok := true
			for dx in range(0, 9):
				ok = ok and level.cell_char(Vector2i(x + dx, y)) == "." and level.cell_char(Vector2i(x + dx, y + 1)) == "."
			if ok and Vector2(x, y).distance_to(level.village_middle()) > 25.0:
				spot = level.cell_to_world(Vector2i(x, y))
				break
		if spot != Vector3.INF:
			break
	game.player.global_position = spot + Vector3(0, 0, 3)
	var sizes := [5, 3, 7, 6]
	for k in 4:
		GlowMushrooms._grow(level, {"cell": Vector2i.ZERO, "pos": spot + Vector3(2.0 * k + 1.0, 0, 0), "kind": k, "count": sizes[k], "variant": k % 3}, "gp:x:%d" % k, false)
	for t in [["day", 12.0], ["dusk", 19.5], ["night", 23.0]]:
		await _hour(t[1])
		await _shot("row_" + t[0], spot + Vector3(4.0, 1.6, 4.5), spot + Vector3(4.0, 0.1, 0))
	await _shot("close_night", spot + Vector3(7.0, 0.6, 1.4), spot + Vector3(7.0, 0.1, 0))
	await _shot("close_night_first", spot + Vector3(1.0, 0.6, 1.4), spot + Vector3(1.0, 0.1, 0))
	await _hour(12.0)
	await _shot("close_day", spot + Vector3(7.0, 0.6, 1.4), spot + Vector3(7.0, 0.1, 0))
	if not level._candles.is_empty():
		var lamp: Vector3 = level._candles[0].global_position
		for t in [["day", 12.0], ["night", 23.0]]:
			await _hour(t[1])
			await _shot("lantern_" + t[0], lamp + Vector3(0.9, 0.2, 1.6), lamp)
	print("PASS: glow mushroom shots")
	quit(0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
