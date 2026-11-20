extends SceneTree
## Railings round a flat roof (see HouseSketch.RAIL_STOREY and HouseSketcher):
## on the upper level the garden wall tool draws a railing beside a slab, a click
## rings the whole roof and leaves the stairs a gap, a railing is built after its
## slab and goes with it, and a built railing keeps the hero on the roof.
## Run with: godot --headless -s tests/house_railing.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch
var found := Rect2i()
var bar_width := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_plan()
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _test_plan() -> void:
	var h := HouseSketch.new()
	h.plot = Rect2i(10, 10, 4, 4)
	check(h.problem(3, 3, "x", HouseSketch.STONE_FENCE, 1) == "no roof", "no railing without a slab")
	h.sketch_roof(h.cells_between(Vector2i(3, 3), Vector2i(4, 4)), HouseSketch.SLAB, 0)
	check(h.problem(3, 3, "x", HouseSketch.STONE_FENCE, 1) == "", "a railing on the roof's edge")
	check(h.problem(3, 1, "x", HouseSketch.STONE_FENCE, 1) == "no roof", "but not away from the roof")
	check(h.sketch_upstairs(1, 3, "e"), "stairs up to the roof")
	check(h.problem(3, 3, "y", HouseSketch.WOOD_FENCE, 1) == "stairs edge", "no railing where the stairs arrive")
	check(h.ring_edges(3, 3).size() == 7, "the ring has every open edge but the stairs' (%d)" % h.ring_edges(3, 3).size())
	check(h.ring_roof(0, 0) == -1, "no ring away from a roof")
	check(h.ring_roof(4, 4) == 7, "a click rings the roof")
	check(h.ring_roof(4, 4) == 0, "a second click adds nothing")
	check(h.count(HouseSketch.STONE_FENCE) == 7, "stone is the default railing")
	h.undo()
	check(h.count(HouseSketch.STONE_FENCE) == 0, "undo takes the whole ring back at once")
	h.redo()
	# A gate where the stairs arrive is fine; a railing there stops new stairs.
	check(h.problem(3, 3, "y", HouseSketch.GATE, 1) == "needs fence", "a gate still needs a railing to sit in")
	var g := HouseSketch.new()
	g.plot = h.plot
	g.sketch_roof([[3, 3, "c"]], HouseSketch.SLAB, 0)
	g.sketch([[3, 3, "y"]], HouseSketch.STONE_FENCE, 1)
	check(g.problem_upstairs(1, 3, "e") == "railing", "stairs up do not end at a railing")
	# Building order: the slab before its railing.
	h.deposit("steinblock", 20)
	h.deposit("bauholz", 20)
	h.ordered = true
	var order := []
	for i in 20:
		var r := h.build_next()
		if r.is_empty():
			break
		order.append(r.kind)
	check(order.size() == 12 and order.rfind("slab") < order.find("stone_fence"), "slabs, then the railing: %s" % [order])
	h.save("railing_test_hero")
	HouseSketch.reload()
	var again := HouseSketch.of("railing_test_hero", h.plot)
	check(again.count(HouseSketch.STONE_FENCE) == 7, "railings are kept in the books")
	# Taking a slab down takes the railing that stood only beside it.
	h.erase_above(4, 4, 0)
	check(h.piece(4, 5, "x", 1).state == HouseSketch.DEMOLISH and h.piece(5, 4, "y", 1).state == HouseSketch.DEMOLISH, "the railing of a slab goes with it")
	check(h.piece(3, 5, "x", 1).state == HouseSketch.BUILT, "the rest of the railing stays")
	h.undo()
	check(h.piece(4, 5, "x", 1).state == HouseSketch.BUILT and h.slab_at(4, 4, 0).state == HouseSketch.BUILT, "undo brings slab and railing back together")


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.hero_name = "Railing test"
		game.escaped = true
		game.load_level(game._outdoor_index(), false)
		game.state = game.State.PLAYING
		for y in range(game.level.height - 5):
			for x in range(game.level.grid[y].length() - 5):
				var r := Rect2i(x, y, 4, 4)
				if Plots.problem(game.level, r) == "":
					found = r
					break
			if found.size != Vector2i.ZERO:
				break
		check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
		game.plot_marker.refresh()
		var sketcher: HouseSketcher = game.house_sketcher
		plan = sketcher.plan
		plan.sketch_roof(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)), HouseSketch.SLAB, 0)
		plan.sketch_upstairs(1, 3, "e")
		sketcher.enter()
		sketcher.select_tool(HouseSketcher.TOOL_FENCE)
		bar_width = sketcher._bar.size.x
		var tool_button: Button = sketcher._tool_buttons[HouseSketcher.TOOL_FENCE]
		var tool_width := tool_button.size.x
		check(tool_button.text == Lang.t("Gartenmauer"), "on the ground the tool draws garden walls")
		sketcher.cycle_level()
		check(sketcher.storey == 1 and tool_button.text == Lang.t("Geländer"), "on the upper level it draws railings")
		check(sketcher._mat_a.text.begins_with(Lang.t("Geländer: %s").get_slice("%", 0)), "the material button names the railing")
		# A click on the roof rings it.
		var on_roof := plan.cell_world(4, 4)
		sketcher.mouse(on_roof, true, MOUSE_BUTTON_LEFT)
		sketcher.hover(on_roof)
		sketcher.mouse(on_roof, false, MOUSE_BUTTON_LEFT)
		check(plan.count(HouseSketch.STONE_FENCE) == 7, "a click on the roof rings it (%d)" % plan.count(HouseSketch.STONE_FENCE))
		check(tool_button.get_combined_minimum_size().x <= tool_width + 0.5, "the tool keeps its width when renamed")
		plan.deposit("steinblock", 20)
		plan.deposit("bauholz", 20)
		plan.ordered = true
		for i in 20:
			if not sketcher.work_once():
				break
		check(plan.open_pieces() == 0, "house, stairs and railing are built")
		return false
	if frames == 10:
		check(absf(game.house_sketcher._bar.size.x - bar_width) < 0.5, "the bar keeps its width (%d -> %d)" % [bar_width, game.house_sketcher._bar.size.x])
		game.house_sketcher.leave()
		# A ray across the railing's edge, as high as a jump carries the hero, is stopped.
		var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
		var edge := plan.node_world(4, 5) + Vector3(0, HouseSketch.STOREY_HEIGHT, 0)
		for high in [0.5, 1.8]:
			var ray := PhysicsRayQueryParameters3D.create(edge + Vector3(0, high, -0.8), edge + Vector3(0, high, 0.8))
			check(not space.intersect_ray(ray).is_empty(), "the railing stops the hero %.1f m above the roof" % high)
		# Where the stairs arrive the way is open.
		var gap := plan.node_world(3, 3) + Vector3(0, HouseSketch.STOREY_HEIGHT + 1.0, 1.0)
		var through := PhysicsRayQueryParameters3D.create(gap + Vector3(-0.8, 0, 0), gap + Vector3(0.8, 0, 0))
		check(space.intersect_ray(through).is_empty(), "the stairs keep their gap")
		# The hero walks against the railing and stays on the roof.
		game.player.global_position = plan.cell_world(4, 4) + Vector3(0, HouseSketch.STOREY_HEIGHT + 0.1, 0)
		game.player.reset_physics_interpolation()
		return false
	if frames > 10 and frames < 100:
		game.player.velocity.x = 0.0
		game.player.velocity.z = 6.0
		game.player.move_and_slide()
		return false
	if frames == 100:
		var at: Vector3 = game.player.global_position
		check(at.y > HouseSketch.STOREY_HEIGHT - 0.3, "the hero is still on the roof (y %.2f)" % at.y)
		check(at.z < plan.node_world(4, 5).z, "and did not pass the railing")
		Plots.release(game.hero_name)
		game.delete_save(game.save_path())
		print("PASS: roof railings" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false
