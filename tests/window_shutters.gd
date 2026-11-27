extends SceneTree
## Headless test: the windows the hero builds (see HouseSketcher._solid_window)
## and their shutters (see BuiltShutters).
## - A built window has a wooden frame like a doorway's (lintel, casing, sill,
##   no glazing bars) between stone jambs, and a pair of shutters, open at first.
## - The shutters hang on the outside face of the wall, wherever that is.
## - E next to the window shuts them and opens them again; the plan keeps the
##   state over a redraw and a reload of the houses.
## - A wall turned into a door loses its shutters' state.
## - The glass is clear from both sides.
## Run with: godot --headless --fixed-fps 60 -s tests/window_shutters.gd
## With SHOTS=<folder> and a display it also saves pictures by day and night,
## open and shut.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


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
		await physics_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Shutter test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var found := Rect2i()
	for y in range(game.level.height - 5):
		for x in range(game.level.grid[y].length() - 5):
			if Plots.problem(game.level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sk: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sk.plan
	# A closed house: a window in the north wall and one in the east wall, the door south.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch([[2, 1, "x"], [4, 2, "y"]], HouseSketch.WINDOW)
	plan.sketch_roof(plan.cells_between(Vector2i(1, 1), Vector2i(3, 3)), HouseSketch.SADDLE, 0, "rx")
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(3)
	var north_key := HouseSketch.key_of(2, 1, "x")
	var east_key := HouseSketch.key_of(4, 2, "y")
	var north: BuiltShutters = sk.shutters.get("%s|%s" % [plan.plot, north_key])
	var east: BuiltShutters = sk.shutters.get("%s|%s" % [plan.plot, east_key])
	check(north != null and north.is_inside_tree() and east != null, "every built window has shutters")
	if north == null or east == null:
		_end()
		return
	check(not north.shut and north.closed == 0.0, "the shutters are open at first")
	check(north.own, "they are the hero's own")
	# The outside: north of the north wall, east of the east wall.
	var north_wall := plan.node_world(2, 1) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	var east_wall := plan.node_world(4, 2) + Vector3(0, 0, HouseSketch.CELL * 0.5)
	check(north.global_position.z < north_wall.z - 0.1, "the north window's shutters hang outside, to the north")
	check(east.global_position.x > east_wall.x + 0.1, "the east window's shutters hang outside, to the east")
	# Open, a leaf lies flat against the wall beside the window; shut, the two cover it.
	var leaf_tip := func(pair: BuiltShutters, i: int) -> Vector3:
		return pair.leaves[i].global_transform * Vector3(-float(i * 2 - 1) * pair.width * 0.5, 0, 0)
	var open_tip: Vector3 = leaf_tip.call(north, 0)
	var reach := Vector2(open_tip.x - north.global_position.x, open_tip.z - north.global_position.z).length()
	check(absf(open_tip.z - north.global_position.z) < 0.15 and reach > north.width * 0.9,
			"an open shutter lies against the wall beside the window")
	# The frame is timber, as the doorway's: lintel, casing and sill (the glass is bare, without bars).
	var wood := 0
	for m: MeshInstance3D in sk._solid.find_children("*", "MeshInstance3D", false, false):
		if m.material_override == HouseLooks.stair_wood() and absf(m.global_position.x - north_wall.x) < 1.2 \
				and absf(m.global_position.z - north_wall.z) < 0.5:
			wood += 1
	check(wood >= 4, "the window has a wooden frame: lintel, two casing boards and a sill (%d)" % wood)
	# The opening holds no glass layer at all (a see-through pane over the room flickered and read as
	# a white film): no quad of glass on either side of the wall.
	var panes := 0
	for m: MeshInstance3D in sk._solid.find_children("*", "MeshInstance3D", false, false):
		if absf(m.global_position.x - north_wall.x) < 1.2 and absf(m.global_position.z - north_wall.z) < 0.1 and m.mesh is QuadMesh:
			panes += 1
	check(panes == 0, "the window is a bare opening, with no glass layer (%d quads)" % panes)

	var hero: Player = game.player
	hero.godmode = true
	for c in game.level.find_children("*", "CharacterBody3D", true, false):
		if c != hero:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = Vector3(north.global_position.x + 0.3, north_wall.y + 0.1, north.global_position.z - 1.0)
	hero.reset_physics_interpolation()
	# (Building keeps the hero busy for a moment.)
	while not hero.can_act():
		await physics_frame
	await _wait(5)
	check(game.shutters_in_reach() == north, "next to the window its shutters are in reach")
	check(game.window_action(north) == "" and north.shut, "E shuts them")
	await _wait(40)
	check(north.closed == 1.0, "the shutters swing shut")
	var shut_tip: Vector3 = leaf_tip.call(north, 0)
	check(absf(shut_tip.x - north.global_position.x) < 0.1, "shut, the leaves meet in the middle of the window")
	check(plan.shut.has(north_key), "the plan keeps them shut")
	sk.refresh()
	await _wait(3)
	var again: BuiltShutters = sk.shutters.get("%s|%s" % [plan.plot, north_key])
	check(again != null and again.shut and again.closed == 1.0, "a redraw keeps them shut")
	HouseSketch.reload()
	check(HouseSketch.of(game.hero_name, plan.plot).shut.has(north_key), "and so does a reload")
	if shots != "":
		await _shots(sk, plan, north_key, again)
	while not hero.can_act():
		await physics_frame
	check(game.window_action(again) == "" and not again.shut and not plan.shut.has(north_key), "E opens them again")
	# A window rebuilt as a door forgets its shutters.
	plan.shut[north_key] = true
	plan.sketch([[2, 1, "x"]], HouseSketch.DOOR)
	plan.order()
	for i in 5:
		if not sk.work_once():
			break
	check(plan.piece(2, 1, "x").get("kind", "") == HouseSketch.DOOR and not plan.shut.has(north_key), "a door has no shutters")
	_end()


## Pictures of the north window from outside, open and shut, by day and by night.
func _shots(sk: HouseSketcher, plan: HouseSketch, key: String, pair: BuiltShutters) -> void:
	var at := pair.global_position + Vector3(0, 0.5, 0)
	var from := at + Vector3(2.0, 0.9, -4.2)
	game.player.global_position = at + Vector3(-3.0, -0.5, -3.0)
	game.player.reset_physics_interpolation()
	for hour: float in [12.0, 20.45]:
		game.day_hour = hour
		game.level.set_hour(hour)
		var when := "day" if hour < 18.0 else "night"
		for shut_now: bool in [false, true]:
			pair.set_shut(shut_now)
			for i in 40:
				await process_frame
			await _shot("window_%s_%s" % [when, "shut" if shut_now else "open"], from, at)
	game.day_hour = 12.0
	game.level.set_hour(12.0)
	pair.set_shut(true)


func _shot(name: String, from: Vector3, look: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(look)
	cam.make_current()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: window shutters" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
