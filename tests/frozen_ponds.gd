extends SceneTree
## Headless test for the frozen ponds: they freeze while snow lies and thaw slowly after, and once
## frozen over the hero can walk on them while one hole per pond stays open for fishing: a click
## on the hole walks the hero out over the ice and casts into it.
## Run with: godot --headless -s tests/frozen_ponds.gd
## With SHOTS=<folder> (and a display) it also saves pictures of the ice.

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


func _shot(name: String, from: Vector3, to: Vector3, fov := 55.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(12)
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


## The nearest walkable tile beside the pond of `hole` (the bank), in the world.
func _shore_near(lvl: Outdoor, hole: Dictionary) -> Vector3:
	var at: Vector2i = lvl.world_to_cell(hole.pos)
	var best := Vector2i(-1, -1)
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := at + Vector2i(dx, dy)
				if best.x < 0 and lvl.astar.is_in_boundsv(c) and not "~;".contains(lvl.cell_char(c)) \
						and not lvl.astar.is_point_solid(c):
					best = c
		if best.x >= 0:
			break
	return lvl.cell_to_world(best)


func _run() -> void:
	# The ice builds with snow and melts slowly (Weather.ice).
	var hours := DayNight.DAY_LENGTH / 24.0
	check(Weather.ice(0.0, 0.5, Weather.SNOW, hours) > 0.3, "ice forms while snow lies")
	check(Weather.ice(1.0, 0.0, Weather.CLEAR, hours) > 0.9, "ice thaws slowly")
	check(Weather.ice(1.0, 0.0, Weather.RAIN, hours * 12.0) < 0.1, "rain thaws ice faster")
	check(Weather.ice(0.0, 0.0, Weather.CLEAR, hours) == 0.0, "no ice without snow")

	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Ice test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	var open_waters := lvl.fishing_waters.size()
	var ponds := lvl._pond_waters.size()
	check(ponds == 55, "fifty-five pond tiles")
	check(lvl.ice_cover.holes.size() == 2, "one hole in each of the two ponds")

	game.ice_cover = 0.5
	lvl.set_ice(0.5)
	check(lvl.fishing_waters.size() == open_waters, "half-frozen ponds still hold open water")
	game.ice_cover = 1.0
	lvl.set_ice(1.0)
	check(lvl.fishing_waters.size() == open_waters - ponds + 2, "frozen: only the two holes can be fished")
	await _wait(3)
	var blocking := 0
	for w: Dictionary in lvl._pond_waters:
		if not (w.shape as CollisionShape3D).disabled:
			blocking += 1
	check(blocking == 2, "the hole tiles stay shut, the rest of the ice can be walked on")
	var hole: Dictionary = lvl.ice_cover.holes[0]
	check(lvl.nearest_water(hole.pos + Vector3(2.5, 0, 0), 2.4).get("water", "") == hole.water, "the hole can be fished from its edge")
	var far: Vector3 = hole.pos + Vector3(0, 0, 4.0)
	check(lvl.nearest_water(far, 1.0).is_empty(), "the ice between is not water")
	# A click on the hole is a click on water (the fountain basin still is not), and the
	# way-finding leads over the ice to it while the hole's own tile stays shut.
	check(Fishing.water_in(lvl.fishing_waters, hole.pos) == hole, "a click on the hole is on water")
	for w: Dictionary in lvl.fishing_waters:
		if w.water == "brunnen":
			check(Fishing.water_in(lvl.fishing_waters, w.pos).is_empty(), "a click on the fountain is not")
	var open_ice := 0
	for w: Dictionary in lvl._pond_waters:
		if lvl.astar.is_point_solid(w.cell) == w.get("hole", false):
			open_ice += 1
	check(open_ice == ponds, "the paths lead over the ice, not into the holes")
	# Clicked from the shore, the hero walks out over the ice and casts into the hole.
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	var shore: Vector3 = _shore_near(lvl, hole)
	game.player.global_position = shore + Vector3(0, 0.3, 0)
	game.player.reset_physics_interpolation()
	await _wait(5)
	check(game.fishing.click_water(hole.pos), "the click on the hole is taken")
	for i in 900:
		await physics_frame
		game.player.hp = game.player.max_hp
		if game.fishing.is_fishing():
			break
	check(game.fishing.is_fishing() and game.fishing.water == hole, "walked to the hole and cast into it")
	check(Level.water_distance(hole, game.fishing._float_rest) <= 0.0, "the float lies in the hole")
	game.fishing.stop()

	game.ice_cover = 0.2
	lvl.set_ice(0.2)
	check(lvl.fishing_waters.size() == open_waters, "thawed: all pond tiles are water again")
	await _wait(3)
	blocking = 0
	for w: Dictionary in lvl._pond_waters:
		if not (w.shape as CollisionShape3D).disabled:
			blocking += 1
	check(blocking == ponds, "thawed: the pond blocks the way again")
	var shut := 0
	for w: Dictionary in lvl._pond_waters:
		if lvl.astar.is_point_solid(w.cell):
			shut += 1
	check(shut == ponds, "thawed: the paths go round the pond again")

	if shots != "":
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		lvl.set_hour(12.0)
		game.set_weather(Weather.CLEAR, 5.0)
		game.snow_cover = 1.0
		game.ice_cover = 1.0
		var spot: Vector3 = lvl.ice_cover.holes[0].pos
		game.player.global_position = spot + Vector3(4, 0, 0)
		await _wait(120)
		await _shot("ice_pond", spot + Vector3(-2, 15, 6), spot + Vector3(0, 0, -0.5), 50.0)
		game.ice_cover = 0.55
		await _wait(5)
		await _shot("ice_forming", spot + Vector3(-2, 15, 6), spot + Vector3(0, 0, -0.5), 50.0)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: frozen ponds")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
