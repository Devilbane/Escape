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
		# The snow's body: thick caps over the eaves, icicles, and a bush under snow.
		var houses: Array = lvl.find_children("*", "Node3D", true, false).filter(
				func(n: Node): return n.has_meta("village_house") or n.has_meta("town_house"))
		if not houses.is_empty():
			var house: Node3D = houses[0]
			var front: Vector3 = house.global_transform.basis.z.normalized()
			var mid: Vector3 = house.global_position
			var top := 6.0
			for cap in SnowCaps.in_world(lvl):
				var cb: AABB = cap.global_transform * cap.get_aabb()
				if cb.has_point(mid + Vector3(0, 3, 0)):
					top = cb.end.y
			var side := front.cross(Vector3.UP)
			await _shot("snow_roof_house", mid + front * 11.0 + side * 4.0 + Vector3(0, top + 1.5, 0), mid + Vector3(0, top * 0.6, 0), 55.0)
			await _shot("snow_eaves", mid + front * 6.0 + side * 2.0 + Vector3(0, top * 0.45, 0), mid + front * 1.0 + Vector3(0, top * 0.6, 0), 50.0)
		# The highest icicle in the village, seen from close by.
		var hi := Vector3(0, -100, 0)
		var hi_cap: MeshInstance3D = null
		for cap in SnowCaps.in_world(lvl):
			for i in cap.mesh.get_surface_count():
				if cap.mesh.surface_get_material(i) != SnowCaps.ice_material():
					continue
				for v: Vector3 in cap.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
					var w: Vector3 = cap.global_transform * v
					if w.y > hi.y and w.y < 7.0:
						hi = w
						hi_cap = cap
		if hi_cap:
			var cb: AABB = hi_cap.global_transform * hi_cap.get_aabb()
			var away := Vector3(hi.x - cb.get_center().x, 0, hi.z - cb.get_center().z).normalized()
			await _shot("snow_icicles", hi + away * 3.5 + Vector3(0, -1.0, 0) + away.cross(Vector3.UP) * 1.5, hi + Vector3(0, -0.4, 0), 50.0)
		var biggest: MeshInstance3D = null
		for cap: MeshInstance3D in SnowCaps.in_world(lvl):
			if biggest == null or cap.get_aabb().size.length() > biggest.get_aabb().size.length():
				biggest = cap
		if biggest:
			var box: AABB = biggest.global_transform * biggest.get_aabb()
			var c: Vector3 = box.get_center()
			await _shot("snow_roof_kit", c + Vector3(box.size.x * 0.9, box.size.y * 0.6, box.size.z * 0.9), c, 55.0)
		for leaves: Node3D in lvl.find_children("Leaves_*", "MultiMeshInstance3D", true, false):
			var lbox: AABB = (leaves as GeometryInstance3D).global_transform * (leaves as GeometryInstance3D).get_aabb()
			if lbox.size.y < 2.5:
				var lc := lbox.get_center()
				await _shot("snow_bush", lc + Vector3(3.0, 2.5, 3.0), lc, 50.0)
				break
		if OS.get_environment("ONLY") in ["forge", "roofs"]:
			game.delete_save(game.save_path())
			print("PASS: snow shots")
			quit(0)
			return
		var p: Vector3 = game.player.global_position
		# A trail of prints walking towards the camera, past the hero.
		for i in 10:
			var at: Vector3 = p + Vector3(-1.2 + 0.05 * i, 0, -3.0 + 0.55 * i)
			lvl.snow_print(at + Vector3(0.09 if i % 2 == 0 else -0.09, 0, 0), 0.0)
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
