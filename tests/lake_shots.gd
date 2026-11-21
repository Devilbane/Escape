extends SceneTree
## The pond in the wolf hollow, north of the robbers' pass: its shore follows the pond tiles (what
## looks like water blocks the way, the bank can be walked all round it), the hero can still fish
## it and the ice still leaves its one hole open. With SHOTS=<folder> (and a display) it also saves
## pictures of the pond in summer, from low on the bank, and frozen in winter.
## Run with: godot --headless -s tests/lake_shots.gd

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


func _shot(name: String, from: Vector3, to: Vector3, fov := 50.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Lake test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	var cells: Array[Vector2i] = []
	var middle := Vector3.ZERO
	for w: Dictionary in lvl._pond_waters:
		if w.water == "senke":
			cells.append(w.cell)
			middle += w.pos
	check(cells.size() >= 12, "the hollow's pond is a lake of a dozen tiles or more")
	middle /= maxf(1.0, cells.size())
	# Every pond tile blocks the way, every tile round it that is grass can be walked.
	var bank: Array[Vector2i] = []
	for c in cells:
		check(lvl.astar.is_point_solid(c), "the pond blocks the way at %s" % c)
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := c + dir
			if not cells.has(next) and lvl.cell_char(next) == "." and not bank.has(next):
				bank.append(next)
	var open_bank := bank.filter(func(b: Vector2i) -> bool: return not lvl.astar.is_point_solid(b))
	check(open_bank.size() >= 8, "the hero reaches the water from all round the bank (%d of %d)" % [open_bank.size(), bank.size()])
	# The bank is one walk: every open bank tile can be reached from every other.
	var from: Vector2i = open_bank[0]
	for b: Vector2i in open_bank:
		check(lvl.astar.get_id_path(from, b).size() > 0, "the bank at %s can be reached" % b)
	# The grate out of the sewers and the way down to the pass stay open.
	for y in lvl.height:
		for x in lvl.width:
			if lvl.cell_char(Vector2i(x, y)) == "`":
				var out := false
				for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					out = out or (lvl.is_open(Vector2i(x, y) + dir) and not cells.has(Vector2i(x, y) + dir))
				check(out, "the sewer grate opens onto dry ground")
	# The shore the shader draws matches the tiles: water in the middle of a pond tile, none in
	# the middle of a bank tile.
	for c in cells:
		check(lvl.pond_shore_at(lvl.cell_to_world(c)) > 0.5, "water shows on pond tile %s" % c)
	for b in bank:
		check(lvl.pond_shore_at(lvl.cell_to_world(b)) < -0.5, "dry ground shows on bank tile %s" % b)
	# Fishing from the bank, and the ice keeps one hole open in the middle.
	var edge := lvl.cell_to_world(open_bank[0])
	check(not lvl.nearest_water(edge, 3.0).is_empty(), "the line reaches the water from the bank")
	var hole: Dictionary = {}
	for h: Dictionary in lvl.ice_cover.holes:
		if h.water == "senke":
			hole = h
	check(not hole.is_empty(), "the frozen lake keeps a fishing hole")
	if not hole.is_empty():
		var at: Vector2i = lvl.world_to_cell(hole.pos)
		var inner := true
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			inner = inner and cells.has(at + dir)
		check(inner, "the hole lies out on the ice, not at the bank")

	if shots != "":
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		for e in lvl.enemies:
			if is_instance_valid(e):
				e.queue_free()
		lvl.enemies.clear()
		game.day_hour = 12.0
		lvl.set_hour(12.0)
		game.set_weather(Weather.CLEAR, 100.0)
		game._weather_look = Weather.look(Weather.CLEAR)
		game.snow_cover = 0.0
		game.ice_cover = 0.0
		game.player.global_position = lvl.cell_to_world(open_bank[open_bank.size() - 1]) + Vector3(0, 0.3, 0)
		game.player.reset_physics_interpolation()
		await _wait(60)
		await _shot("lake_top", middle + Vector3(0, 26, 10), middle + Vector3(0, 0, 0.5), 50.0)
		await _shot("lake_bank", middle + Vector3(-3, 4.5, 15), middle + Vector3(0, 0, 0), 60.0)
		await _shot("lake_wide", middle + Vector3(6, 34, 40), middle + Vector3(4, 0, 10), 55.0)
		# The village pond shares the new shore.
		var village := Vector3.ZERO
		var tiles := 0
		for w: Dictionary in lvl._pond_waters:
			if w.water == "teich":
				village += w.pos
				tiles += 1
		village /= maxf(1.0, tiles)
		await _shot("village_pond", village + Vector3(0, 26, 10), village + Vector3(0, 0, 0.5), 50.0)
		game.snow_cover = 1.0
		game.ice_cover = 1.0
		await _wait(120)
		await _shot("lake_winter", middle + Vector3(0, 26, 10), middle + Vector3(0, 0, 0.5), 50.0)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: lake shots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
