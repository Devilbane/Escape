extends SceneTree
## Pictures of a garden on a plot (see GardenDecor): a small built house with flower beds, a
## flower tub, garden torches, a garden lamp and a grill around it, by day, at night and in winter,
## and the furnishing tool's bar with the garden row.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/house_garden_shots.gd

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
	HouseFurniture.reload()
	Lang.language = OS.get_environment("SHOT_LANG") if OS.get_environment("SHOT_LANG") != "" else "en"
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
	game.hero_name = "Garden shots"
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
	var sketcher: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sketcher.plan
	# A small house in the north-east, the garden round it.
	plan.sketch(plan.run_between(Vector2i(3, 0), Vector2i(5, 0)) + plan.run_between(Vector2i(3, 0), Vector2i(3, 2))
			+ plan.run_between(Vector2i(5, 0), Vector2i(5, 2)) + plan.run_between(Vector2i(3, 2), Vector2i(5, 2)), HouseSketch.WALL)
	plan.sketch([[3, 2, "x"]], HouseSketch.DOOR)
	plan.sketch(plan.cells_between(Vector2i(3, 0), Vector2i(4, 1)), HouseSketch.SLAB)
	plan.deposit(HouseSketch.STONE, 300)
	plan.deposit(HouseSketch.TIMBER, 300)
	plan.order()
	for i in 300:
		if not sketcher.work_once():
			break
	var store := HouseFurniture.of(game.hero_name)
	var layout := [["blumenbeet", 0, 0], ["blumenbeet", 1, 0], ["gartenfackel", 2, 0], ["blumenkuebel", 0, 1],
			["grill", 1, 2], ["gartenlaterne", 0, 3], ["gartenfackel", 2, 3], ["blumenbeet", 1, 4], ["blumenkuebel", 4, 3]]
	for p in layout:
		store.add(p[0])
		var why := store.place(plan, p[0], 0, p[1], p[2], 0)
		check(why == "", "%s at %d,%d (%s)" % [p[0], p[1], p[2], why])
	store.save(game.hero_name)
	game.house_furnisher.refresh()
	var n := plan.nodes()
	var mid := plan.node_world(n.x / 2, n.y / 2)
	game.player.global_position = plan.cell_world(2, 2)
	await _shot("garden_day", mid + Vector3(8, 9, 13), mid)
	await _shot("garden_close", plan.cell_world(1, 1) + Vector3(3, 3.2, 5), plan.cell_world(1, 1))
	game.day_hour = 22.5
	await _wait(30)
	await _shot("garden_night", mid + Vector3(8, 9, 13), mid)
	var winter := 0
	while not Weather.is_winter(winter):
		winter += 1
	game.day = winter
	game.day_hour = 12.0
	await _wait(30)
	await _shot("garden_winter", plan.cell_world(1, 1) + Vector3(3, 3.2, 5), plan.cell_world(1, 1))
	game.day = 0
	await _wait(10)
	# The furnishing tool with the garden row.
	game.house_furnisher.enter()
	game.house_furnisher.select("grill")
	await _wait(20)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	game.house_furnisher.hover(plan.cell_world(3, 4))
	await _wait(20)
	await RenderingServer.frame_post_draw
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("garden_tool.png"))
	check(game.house_furnisher._bar.size.x <= 1280.0 - 16.0, "the bar fits the screen (%d px)" % int(game.house_furnisher._bar.size.x))
	game.house_furnisher.leave()
	print("PASS: garden shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


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
