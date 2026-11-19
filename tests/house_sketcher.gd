extends SceneTree
## The blueprint tool on the open map (see HouseSketcher): the sign, entering,
## drawing a wall by dragging, a door, the eraser and undo.

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	game.hero_name = "Sketch test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var sketcher: HouseSketcher = game.house_sketcher
	check(sketcher != null, "the open map has a blueprint tool")
	check(sketcher.plan == null, "no plot, no plan")
	sketcher.enter()
	check(not sketcher.active, "the tool does not open without a plot")
	# Register a plot somewhere free.
	var found := Rect2i()
	for y in range(game.level.height - 4):
		for x in range(game.level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(game.level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	check(sketcher.plan != null, "a plot brings a plan")
	check(game.level.stations.any(func(s): return s.kind == HouseSketcher.KIND), "the plot has a blueprint sign")
	sketcher.enter()
	check(sketcher.active, "the tool opens at the sign")
	var plan: HouseSketch = sketcher.plan
	# Drag a wall: two cells east.
	sketcher.select_tool(HouseSketcher.TOOL_WALL)
	var a := plan.node_world(1, 1)
	var b := plan.node_world(3, 1)
	sketcher.mouse(a, true, MOUSE_BUTTON_LEFT)
	sketcher.hover(b)
	sketcher.mouse(b, false, MOUSE_BUTTON_LEFT)
	check(plan.count("wall") == 2, "a drag draws a wall of two pieces")
	# A door in the first piece.
	sketcher.select_tool(HouseSketcher.TOOL_DOOR)
	sketcher.mouse(plan.node_world(1, 1) + Vector3(1.0, 0, 0.1), true, MOUSE_BUTTON_LEFT)
	check(plan.count("door") == 1 and plan.count("wall") == 1, "a click turns a wall into a door")
	sketcher.select_tool(HouseSketcher.TOOL_WINDOW)
	sketcher.mouse(plan.node_world(1, 3) + Vector3(1.0, 0, 0.0), true, MOUSE_BUTTON_LEFT)
	check(plan.count("window") == 0, "a window needs a wall")
	sketcher.select_tool(HouseSketcher.TOOL_ERASE)
	sketcher.mouse(plan.node_world(2, 1) + Vector3(1.0, 0, 0.0), true, MOUSE_BUTTON_LEFT)
	check(plan.count("wall") == 0, "the eraser takes a piece back")
	sketcher.undo()
	check(plan.count("wall") == 1, "undo brings it back")
	# The character builds: with material the sketch turns solid.
	plan.deposit("steinblock", 10)
	plan.deposit("bauholz", 10)
	check(plan.order(), "the build is ordered")
	var before := sketcher._body.get_child_count()
	check(sketcher.work_once(), "the character builds a piece")
	check(sketcher._body.get_child_count() > before, "a built piece blocks the way")
	sketcher.select_tool(HouseSketcher.TOOL_ERASE)
	var built_key := ""
	for key in plan.pieces:
		if plan.pieces[key].state == "built":
			built_key = key
	var bp := HouseSketch.parts_of(built_key)
	sketcher.mouse(plan.node_world(bp[1], bp[2]) + (Vector3(1.0, 0, 0) if bp[3] == "x" else Vector3(0, 0, 1.0)), true, MOUSE_BUTTON_LEFT)
	check(plan.piece(bp[1], bp[2], bp[3]).state == "demolish", "the eraser marks a built piece for demolition")
	sketcher.leave()
	check(not sketcher.active, "the tool closes")
	# The plan is in the books.
	HouseSketch.reload()
	check(HouseSketch.of(game.hero_name, found).pieces.size() == plan.pieces.size(), "the plan was saved")
	# Away: the build block builds what the stock pays for.
	check(game.away_choices().build == [Offline.BUILD_HOUSE], "the planner offers the house while pieces are open")
	var lines: Array[String] = game._build_away(5, 10.0)
	check(not lines.is_empty() and HouseSketch.of(game.hero_name, found).open_pieces() == 0, "the hero builds the open pieces while away")
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house sketcher" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true
