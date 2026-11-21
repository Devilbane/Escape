extends SceneTree
## Pictures of garden torches and lamps on flat roofs (see HouseFurniture.roof_problem): a house
## with a flat roof and railings over the ground floor, a room on top with its own flat roof up a
## ladder, lights on both roofs, by day and at night.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/house_roof_lights_shots.gd

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
	game.hero_name = "Roof light shots"
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
	# A house of 3 x 3 cells with a flat roof, a small room of two cells on it with its own flat
	# roof, a ladder up to the house's roof and one up to the room's roof.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	check(plan.sketch_roof(plan.cells_between(Vector2i(1, 1), Vector2i(3, 3)), HouseSketch.SLAB, 0) == 9, "the flat roof is planned")
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(2, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 3))
			+ plan.run_between(Vector2i(2, 1), Vector2i(2, 3)) + plan.run_between(Vector2i(1, 3), Vector2i(2, 3)), HouseSketch.WALL, 1)
	plan.sketch_roof([[1, 1], [1, 2]], HouseSketch.SLAB, 1)
	check(plan.sketch_ladder(4, 3, "w", 0), "a ladder up to the house's roof")
	check(plan.sketch_ladder(2, 1, "w", 1), "a ladder up to the room's roof")
	plan.ring_roof(2, 2)
	plan.deposit(HouseSketch.STONE, 600)
	plan.deposit(HouseSketch.TIMBER, 600)
	plan.order()
	for i in 600:
		if not sketcher.work_once():
			break
	var store := HouseFurniture.of(game.hero_name)
	var top := HouseFurniture.ROOF_STOREY
	var layout := [["gartenlaterne", 1, 3, 1], ["gartenfackel", 1, 3, 2], ["gartenfackel", 1, 1, 3], ["gartenlaterne", 1, 2, 3],
			["gartenfackel", top, 1, 2], ["gartenfackel", 0, 0, 4], ["gartenlaterne", 0, 5, 0]]
	for p in layout:
		store.add(p[0])
		var why := store.place(plan, p[0], p[1], p[2], p[3], 0)
		check(why == "", "%s on level %d at %d,%d (%s)" % [p[0], p[1], p[2], p[3], why])
	store.save(game.hero_name)
	game.house_furnisher.refresh()
	var n := plan.nodes()
	var mid := plan.node_world(n.x / 2, n.y / 2) + Vector3(0, 3, 0)
	game.player.global_position = plan.cell_world(5, 5)
	await _shot("roof_day", mid + Vector3(9, 10, 14), mid)
	await _shot("roof_close", plan.cell_world(2, 2) + Vector3(4, 7.5, 7), plan.cell_world(2, 2) + Vector3(0, 3.5, 0))
	game.day_hour = 22.5
	await _wait(30)
	await _shot("roof_night", mid + Vector3(9, 10, 14), mid)
	game.day_hour = 12.0
	await _wait(10)
	# The furnishing tool keeps the roof level for a roof light.
	store = HouseFurniture.of(game.hero_name)
	store.add("gartenlaterne")
	store.save(game.hero_name)
	game.house_furnisher.storey = 1
	game.house_furnisher.enter()
	game.house_furnisher.select("gartenlaterne")
	check(game.house_furnisher.storey == 1, "the tool stays on the roof level")
	game.house_furnisher.leave()
	print("PASS: roof light shots" if failures == 0 else "FAILED: %d" % failures)
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
