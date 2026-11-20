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
	# A garden wall: dragged like a wall, on the ground even from the cellar (on
	# the upper level the same tool draws railings, see tests/house_railing.gd).
	sketcher.storey = -1
	sketcher.select_tool(HouseSketcher.TOOL_FENCE)
	check(sketcher.storey == 0, "the garden wall tool works on the ground")
	sketcher.mouse(plan.node_world(0, 5), true, MOUSE_BUTTON_LEFT)
	sketcher.hover(plan.node_world(3, 5))
	sketcher.mouse(plan.node_world(3, 5), false, MOUSE_BUTTON_LEFT)
	check(plan.count("stone_fence") == 3, "a drag draws a garden wall")
	sketcher.select_tool(HouseSketcher.TOOL_DOOR)
	sketcher.mouse(plan.node_world(1, 5) + Vector3(1.0, 0, 0.1), true, MOUSE_BUTTON_LEFT)
	check(plan.count("gate") == 1 and plan.count("stone_fence") == 2, "a door on a garden wall makes a gate")
	sketcher.cycle_fence()
	check(plan.fence_material == "wood" and sketcher._fence_button.text.contains(Lang.t("aus Holz")), "the material button switches garden walls to wood")
	sketcher.cycle_fence()
	plan.erase([[0, 5, "x"], [1, 5, "x"], [2, 5, "x"]])
	sketcher.leave()
	check(not sketcher.active, "the tool closes")
	# The plan is in the books.
	HouseSketch.reload()
	check(HouseSketch.of(game.hero_name, found).pieces.size() == plan.pieces.size(), "the plan was saved")
	# The cellar: drag a dig, put stairs, build; the ground opens and the pit has a floor.
	plan.erase([[1, 1, "x"], [2, 1, "x"]])
	plan.deposit("steinblock", 20)
	plan.deposit("bauholz", 10)
	sketcher.select_tool(HouseSketcher.TOOL_DIG)
	sketcher.storey = -1
	sketcher.mouse(plan.cell_world(3, 3), true, MOUSE_BUTTON_LEFT)
	sketcher.mouse(plan.cell_world(4, 4), false, MOUSE_BUTTON_LEFT)
	sketcher.storey = 0
	check(plan.count("dig") == 4, "dragging with the dig tool sketches a rectangle of cells, with the level on the cellar")
	check(sketcher._status.text.contains("4") or sketcher._status.text.contains(Lang.t("%d Felder vorgemerkt. Beauftrage den Bau: Dein Held baut es dann.") % 4), "the status says four squares are planned")
	check(plan.next_kind() == "" or plan.next_kind() == "dig", "the next piece to build is a dig")
	# The release of the mouse button goes through the game's input, as in play.
	sketcher.select_tool(HouseSketcher.TOOL_DIG)
	sketcher.active = true
	var dug_before := plan.count("dig")
	sketcher.mouse(plan.cell_world(6, 6), true, MOUSE_BUTTON_LEFT)
	check(sketcher.drag_from.x >= 0, "pressing starts a drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = root.get_visible_rect().size * 0.5
	game._input(release)
	check(sketcher.drag_from.x < 0, "letting go of the mouse ends the drag through the game's input")
	sketcher.active = false
	var planned_now := plan.count("dig") > dug_before
	if planned_now:
		plan.undo()
	check(planned_now or game._mouse_to_floor(release.position) == null, "and the dragged squares are planned (when the mouse is over the ground)")
	sketcher.select_tool(HouseSketcher.TOOL_STAIRS)
	sketcher.mouse(plan.cell_world(1, 3), true, MOUSE_BUTTON_LEFT)
	check(plan.count("stairs") == 1, "the stairs tool puts a ramp down to the cellar")
	plan.ordered = true
	for i in 8:
		sketcher.work_once()
	check(plan.count("dig", "built") == 4 and plan.count("stairs", "built") == 1, "the character digs the cellar and builds the stairs")
	check(game.level._floor_slabs.get_child_count() > 0, "the ground is cut open over the cellar")
	check(sketcher._body.get_child_count() >= 5, "the pit has a floor under every cell and a ramp")
	sketcher.select_tool(HouseSketcher.TOOL_ERASE)
	sketcher.storey = -1
	sketcher.mouse(plan.cell_world(1, 3), true, MOUSE_BUTTON_LEFT)
	sketcher.storey = 0
	check(plan.pieces["-1:1:3:e"].state == "demolish", "the eraser marks built stairs to be taken down")
	plan.ordered = true
	for i in 8:
		sketcher.work_once()
	plan.sketch([[1, 1, "x"]], "wall")
	plan.save(game.hero_name)
	# Away: the build block builds what the stock pays for.
	check(game.away_choices().build == [Offline.BUILD_HOUSE], "the planner offers the house while pieces are open")
	var lines: Array[String] = game._build_away(5, 10.0)
	check(not lines.is_empty() and HouseSketch.of(game.hero_name, found).open_pieces() == 0, "the hero builds the open pieces while away")
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house sketcher" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true
