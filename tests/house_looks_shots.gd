extends SceneTree
## Headless test: the finished stone and wood of a house built on a plot (see
## HouseLooks): stone walls and garden walls in the temple's blocks, a stone
## cellar floor of flagstones, wooden floors of the pen's boards and wooden
## cellar walls of the stairs' boards.
## Run with: godot --headless --fixed-fps 60 -s tests/house_looks_shots.gd
## With SHOTS=<folder> and a display it also saves pictures of the house.

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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Looks test"
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
	var n := plan.nodes()
	# A house with a door and a window, half of it under a flat roof.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch([[4, 2, "y"]], HouseSketch.WINDOW)
	plan.sketch_roof(plan.cells_between(Vector2i(1, 1), Vector2i(3, 1)), HouseSketch.SLAB, 0)
	# Two cellar pits beside it: one of stone, one of wood.
	plan.floor_surface = "stone"
	plan.wall_surface = "stone"
	plan.sketch_dig(plan.cells_between(Vector2i(5, 1), Vector2i(6, 2)))
	plan.floor_surface = "wood"
	plan.wall_surface = "wood"
	plan.sketch_dig(plan.cells_between(Vector2i(5, 4), Vector2i(6, 5)))
	# A stone garden wall along two sides.
	plan.sketch(plan.run_between(Vector2i(0, 0), Vector2i(n.x, 0)) + plan.run_between(Vector2i(n.x, 0), Vector2i(n.x, n.y)), HouseSketch.STONE_FENCE)
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sketcher.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	# (The pieces of earlier drawings are freed at the end of the frame.)
	await _wait(2)
	var stone := 0
	var flags := 0
	var stair_boards := 0
	var planks := 0
	for m: MeshInstance3D in sketcher._solid.find_children("*", "MeshInstance3D", false, false):
		if m.material_override == HouseLooks.temple_stone():
			stone += 1
		elif m.material_override == HouseLooks.flagstones():
			flags += 1
		elif m.material_override == HouseLooks.stair_wood():
			stair_boards += 1
		elif m.material_override == WeatheredProps.vertex_material():
			planks += 1
	check(stone > 20, "walls, garden walls and stone cellar walls are the temple's blocks (%d)" % stone)
	check(flags == 4, "the stone cellar floor is four squares of flagstones (%d)" % flags)
	check(stair_boards > 0, "the wooden cellar walls are the stairs' boards (%d)" % stair_boards)
	check(planks == 4 + 3, "the wooden cellar floor and the flat roof are the pen's boards (%d)" % planks)
	var mid := plan.node_world(n.x / 2, n.y / 2)
	game.player.global_position = mid + Vector3(0, 0, Level.TILE * 4)
	await _shot("house_front", mid + Vector3(4, 7, 15), mid + Vector3(0, 1, 0))
	await _shot("house_side", mid + Vector3(16, 6, 3), mid + Vector3(0, 1, 0))
	await _shot("walls_close", plan.node_world(4, 4) + Vector3(3.5, 2.0, 5.0), plan.node_world(3, 3) + Vector3(0, 1.3, 0))
	await _shot("cellar_stone", plan.cell_world(5, 1) + Vector3(1, 4.5, 4.5), plan.cell_world(5, 1) + Vector3(1, -2.4, 0.5))
	await _shot("cellar_wood", plan.cell_world(5, 4) + Vector3(1, 4.5, 4.5), plan.cell_world(5, 4) + Vector3(1, -2.4, 0.5))
	await _shot("roof_boards", plan.cell_world(2, 1) + Vector3(3, 7, 5), plan.cell_world(2, 1) + Vector3(0, 3.2, 0))
	# The cattle pen's fence beside it, for comparison.
	var pen: Vector3 = game.level.cell_to_world(Corral.PEN.position + Vector2i(2, -1))
	await _shot("pen_fence", pen + Vector3(2.5, 2.0, -3.5), pen + Vector3(0, 0.7, 0))
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house looks shots" if failures == 0 else "FAILED: %d" % failures)
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
