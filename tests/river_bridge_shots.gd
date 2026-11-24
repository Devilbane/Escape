extends SceneTree
## Screenshots of the valley bridge (see RiverBridge) in summer and winter, from above and from the side.
## Run with: SHOTS=<folder> godot -s tests/river_bridge_shots.gd (needs a display). It always checks the deck:
## it must run past the river's end tiles onto the banks, and no seam may show between the two halves.

var game: Node
var frames := 0
var started := false
var failures := 0
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	# The deck's extent: the bridge tiles are the ones with the letter, the planks lie in the scene.
	var tiles: Array[Vector2i] = []
	for y in lvl.height:
		for x in lvl.width:
			if RiverBridge.is_bridge(lvl, Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	if tiles.is_empty():
		failures += 1
		print("FAIL: no bridge tiles")
	else:
		# Each tile's deck is one mesh placed at its middle: its extent must reach the banks, and across the seam.
		var half := Outdoor.TILE * 0.5
		for t in tiles:
			var mid_t := lvl.cell_to_world(t)
			var box := AABB()
			var init := true
			for m: MeshInstance3D in lvl.get_children().filter(func(n): return n is MeshInstance3D):
				if m.mesh != null and m.position.is_equal_approx(mid_t):
					var bb := m.global_transform * m.get_aabb()
					box = bb if init else box.merge(bb)
					init = false
			if init:
				failures += 1
				print("FAIL: no deck for tile ", t)
				continue
			if not RiverBridge.is_bridge(lvl, t + Vector2i(0, -1)) and box.position.z > mid_t.z - half - 1.5:
				failures += 1
				print("FAIL: deck of ", t, " does not land on the north bank")
			if not RiverBridge.is_bridge(lvl, t + Vector2i(0, 1)) and box.end.z < mid_t.z + half + 1.5:
				failures += 1
				print("FAIL: deck of ", t, " does not land on the south bank")
			if RiverBridge.is_bridge(lvl, t + Vector2i(1, 0)) and box.end.x < mid_t.x + half + 0.03:
				failures += 1
				print("FAIL: a seam shows east of ", t)
	if shots != "" and not tiles.is_empty():
		var mid := lvl.cell_to_world(Vector2i(46, 70)) + Vector3(Outdoor.TILE * 0.5, 0, 0)
		for season: String in ["summer", "winter"]:
			if season == "winter":
				game.season_shift += 90
				game.set_weather(Weather.SNOW, 3.0)
				game.snow_cover = 1.0
			await _wait(60)
			if season == "winter":
				game.ice_cover = 1.0
				await _wait(10)
			var views := {"top": [Vector3(0, 30, 0.5), Vector3(0, 0, 0)], "side": [Vector3(16, 8, 14), Vector3(0, 0, 0)], "game": [Vector3(0, 16, 12), Vector3(0, 0, -6)], "close": [Vector3(0, 6, 5), Vector3(-9, 0, -1)], "under": [Vector3(-9, 4.5, 3.5), Vector3(-12, 0, 0)]}
			for name: String in views:
				var cam := Camera3D.new()
				cam.fov = 60.0
				root.add_child(cam)
				cam.global_position = mid + (views[name][0] as Vector3)
				cam.look_at(mid + (views[name][1] as Vector3))
				cam.make_current()
				await _wait(5)
				root.get_texture().get_image().save_png(shots.path_join("bridge_%s_%s.png" % [season, name]))
				cam.queue_free()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: river bridge")
	quit(1 if failures > 0 else 0)
