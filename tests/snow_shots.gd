extends SceneTree
## Screenshots of the snow: the village under snowfall, a close view of the hero's breath and
## footprints. Run with: SHOTS=<folder> godot -s tests/snow_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
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


func _shot(name: String, from: Vector3, to: Vector3, fov := 60.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(8)
	# Everyone breathes out just before the picture, so the cold shows.
	for b: Breath in game.find_children("*", "Breath", true, false):
		b._puff.restart()
	await _wait(9)
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Snowman"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	game.set_weather(Weather.SNOW, 3.0)
	game.snow_cover = 0.0 if OS.get_environment("NOSNOW") != "" else 1.0
	var farm := lvl.cell_to_world(VillageFarm.pippi_home(lvl))
	game.player.global_position = farm + Vector3(2, 0, 3)
	await _wait(200)
	if shots != "":
		# Gorm's forge: the coals and the fire in its chimney stay clear of snow.
		for w: Vector4 in lvl.warm_spots:
			if is_equal_approx(w.w, 1.8):
				var coals := Vector3(w.x, w.y, w.z)
				await _shot("snow_forge", coals + Vector3(3.5, 3.6, 4.5), coals + Vector3(0, 1.0, 0), 55.0)
		if OS.get_environment("ONLY") == "forge":
			game.delete_save(game.save_path())
			print("PASS: snow shots")
			quit(0)
			return
		var p: Vector3 = game.player.global_position
		# A trail of prints walking towards the camera, past the hero.
		for i in 10:
			var at: Vector3 = p + Vector3(-1.2 + 0.05 * i, 0, -3.0 + 0.55 * i)
			lvl.snow_print(at + Vector3(0.09 if i % 2 == 0 else -0.09, 0, 0), 0.0)
		# Animal tracks beside it, walking the same way: paws, hooves and bird feet.
		for i in 8:
			var z := -2.6 + 0.6 * i
			lvl.snow_print(p + Vector3(1.0 + (0.05 if i % 2 == 0 else -0.05), 0, z), 0.0, 1.0, "paw")
			lvl.snow_print(p + Vector3(2.0 + (0.06 if i % 2 == 0 else -0.06), 0, z), 0.0, 1.2, "hoof")
			lvl.snow_print(p + Vector3(3.0 + (0.05 if i % 2 == 0 else -0.05), 0, z), 0.0, 1.0, "bird")
		await _shot("snow_tracks", p + Vector3(2.2, 3.2, 4.2), p + Vector3(1.8, 0, -0.5), 55.0)
		await _shot("snow_village", p + Vector3(7, 8, 9), p + Vector3(-1, 0, -2))
		await _shot("snow_hero", p + Vector3(1.4, 1.8, 3.4), p + Vector3(0, 1.3, 0), 45.0)
		await _shot("snow_prints", p + Vector3(1.0, 2.6, 3.0), p + Vector3(-1.0, 0, -0.5), 55.0)
		await _shot("snow_wide", p + Vector3(-18, 16, 18), p, 70.0)
		# Pip and Pippi at play in the snow, round their snowman.
		var pip: Villager = null
		var pippi: Villager = null
		for v: Villager in lvl.villagers:
			if v.role == "7":
				pip = v
			elif v.role == "pippi":
				pippi = v
		lvl._herald_timer = 1.0e9
		var home := VillageFarm.pippi_home(lvl)
		pippi.global_position = lvl.cell_to_world(home)
		pip.global_position = lvl.cell_to_world(home + Vector2i(-1, -1))
		pip._kid = null
		pippi._kid = null
		pip._start("play", 120.0)
		game.player.global_position = lvl.cell_to_world(home) + Vector3(9, 0, 9)
		game.player.reset_physics_interpolation()
		await _wait(150)
		var man: Snowman = lvl.snowman
		var c: Vector3 = man.global_position if man != null else lvl.cell_to_world(home)
		# Wait for a ball in the air.
		for i in 300:
			await process_frame
			if not lvl.find_children("*", "Snowball", false, false).is_empty():
				break
		await _shot("snow_play", c + Vector3(4.5, 3.2, 6.0), c + Vector3(0, 0.9, 0), 55.0)
		for i in 400:
			await process_frame
			if pip._kid != null and pip._kid.phase == "round":
				break
		await _shot("snow_round", c + Vector3(3.5, 2.6, 4.5), c + Vector3(0, 0.9, 0), 55.0)
		await _shot("snowman", c + Vector3(0.8, 1.6, 2.8), c + Vector3(0, 1.1, 0), 45.0)
	game.delete_save(game.save_path())
	print("PASS: snow shots")
	quit(0)
