extends SceneTree
## Screenshots of a rainy day in a self-built house: a big puddle lies across the plot, and the floor
## inside stays dry (see IndoorMask and puddle.gdshader).
## Run with: SHOTS=<folder> godot -s tests/house_puddle_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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
	game._title.visible = false
	game.hero_name = "Puddle test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(30)
	var found := Rect2i()
	for y in range(game.level.height - 4):
		for x in range(game.level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(game.level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	Plots.register(game.level, game.hero_name, found)
	game.plot_marker.refresh()
	var plan: HouseSketch = game.house_sketcher.plan
	plan.deposit("steinblock", 40)
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(5, 1)), HouseSketch.WALL)
	plan.sketch(plan.run_between(Vector2i(5, 1), Vector2i(5, 5)), HouseSketch.WALL)
	plan.sketch(plan.run_between(Vector2i(5, 5), Vector2i(1, 5)), HouseSketch.WALL)
	plan.sketch(plan.run_between(Vector2i(1, 5), Vector2i(1, 1)), HouseSketch.WALL)
	plan.ordered = true
	for i in 20:
		game.house_sketcher.work_once()
	for cell: Array in plan.cells_between(Vector2i(1, 1), Vector2i(4, 4)):
		plan.pieces[HouseSketch.key_of(cell[0], cell[1], cell[2])] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	game.house_sketcher._redraw()
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.day_hour = 12.0
	game.set_weather(Weather.CLEAR, 5.0)
	game.puddle_water = 1.0
	var mid: Vector3 = plan.node_world(3, 3)
	var pu: Puddles = (game.level as Outdoor).puddles
	# One big sheet of water across the house and the ground round it.
	var mi := MeshInstance3D.new()
	var spot := {"node": null, "at": mid, "radius": 9.0, "needs": 0.0, "fill": 1.0, "span": 9.0, "long": false, "id": 9999}
	mi.mesh = Puddles._round[0]
	mi.material_override = pu._material
	mi.scale = Vector3(9.0, 1.0, 9.0)
	mi.position = Vector3(mid.x, Puddles.LIFT, mid.z)
	pu.add_child(mi)
	spot.node = mi
	pu.spots.append(spot)
	pu._register(spot)
	game.player.global_position = mid + Vector3(0, 0, 3)
	game.player.reset_physics_interpolation()
	await _wait(120)
	var cam := Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	for view: Array in [["inside", mid + Vector3(1.6, 1.7, 1.6), mid + Vector3(-1.5, 0.0, -1.0)], ["outside", mid + Vector3(-11.0, 7.0, 11.0), mid]]:
		cam.global_position = view[1]
		cam.look_at(view[2])
		cam.make_current()
		await _wait(20)
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, view[0]])
	quit(0)
