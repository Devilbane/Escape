extends SceneTree
## Headless test: garden walls on a plot (see HouseSketch.FENCE_KINDS): a stone
## wall with a gate and a wooden fence get built, and the blueprint bar still fits
## the screen with the garden wall tool and its material button.
## Run with: godot --headless --fixed-fps 60 -s tests/garden_wall_shots.gd
## With SHOTS=<folder> and a display it also saves pictures of the garden and the bar.

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
	if shots != "":
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
	if shots != "":
		game._title.visible = false
	game.hero_name = "Garden test"
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
	# A small house in one corner, a walled garden around the rest.
	var n := plan.nodes()
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch(plan.run_between(Vector2i(0, 0), Vector2i(n.x, 0)) + plan.run_between(Vector2i(n.x, 0), Vector2i(n.x, n.y)), HouseSketch.STONE_FENCE)
	plan.sketch(plan.run_between(Vector2i(0, n.y), Vector2i(n.x, n.y)) + plan.run_between(Vector2i(0, 0), Vector2i(0, n.y)), HouseSketch.WOOD_FENCE)
	plan.sketch([[n.x, 3, "y"]], HouseSketch.GATE)
	plan.sketch([[3, n.y, "x"]], HouseSketch.GATE)
	plan.deposit(HouseSketch.STONE, 200)
	plan.deposit(HouseSketch.TIMBER, 200)
	plan.order()
	for i in 200:
		if not sketcher.work_once():
			break
	check(plan.open_pieces() == 0, "the house and the garden are built")
	check(plan.count(HouseSketch.GATE, HouseSketch.BUILT) == 2, "both gates stand")
	# The stone garden wall's pieces meet end to end and at the corner without
	# overlapping: two faces in one place flicker (z-fighting).
	await _wait(2)
	var stones: Array[AABB] = []
	for m: MeshInstance3D in sketcher._solid.find_children("*", "MeshInstance3D", false, false):
		var box := m.global_transform * m.mesh.get_aabb()
		if not m.is_queued_for_deletion() and m.material_override == HouseLooks.temple_stone() and absf(box.size.y - HouseSketch.FENCE_HEIGHT) < 0.01:
			stones.append(box)
	check(stones.size() >= n.x + n.y - 1, "the stone garden wall is built (%d pieces)" % stones.size())
	var overlaps := 0
	for i in stones.size():
		for j in range(i + 1, stones.size()):
			var cut := stones[i].intersection(stones[j])
			if cut.size.x > 0.005 and cut.size.z > 0.005 and cut.size.y > 0.005:
				overlaps += 1
	check(overlaps == 0, "no two stone garden wall pieces overlap (%d do)" % overlaps)
	var mid := plan.node_world(n.x / 2, n.y / 2)
	game.player.global_position = mid + Vector3(0, 0, Level.TILE * 3)
	await _shot("garden_built", mid + Vector3(9, 11, 14), mid)
	# The blueprint bar with the garden wall tool.
	sketcher.enter()
	sketcher.select_tool(HouseSketcher.TOOL_FENCE)
	await _wait(5)
	var width: float = sketcher._bar.size.x
	check(width <= 1280.0 - 16.0, "the blueprint bar fits the screen (%d px)" % int(width))
	if shots != "":
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = true
		await _wait(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("garden_bar.png"))
	sketcher.leave()
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: garden wall shots" if failures == 0 else "FAILED: %d" % failures)
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
