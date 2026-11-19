extends SceneTree
## Floors, roofs and stairs up on the open map (see HouseSketch and
## HouseSketcher): the plan rules, building order, the ground you can stand on at
## every level, and the roof fading while the hero stands under it.
## Run with: godot --headless -s tests/house_upper.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch


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
	check(h.sketch_roof(h.cells_between(Vector2i(4, 2), Vector2i(5, 3)), HouseSketch.SLAB, 0) == 4, "a drag sketches slabs")
	check(h.problem_roof(4, 2, 0) == "taken" and h.problem_roof(4, 2, 1) == "", "a cell has one slab or roof per storey")
	check(h.problem_roof(4, 2, 2) == "storey", "no storey above the upper floor")
	check(h.upstairs_dir(2, 2) == "e", "stairs up find the way to the slab")
	check(h.problem_upstairs(0, 2, "w") == "outside", "stairs up cannot leave the plot")
	check(h.sketch_upstairs(2, 2, "e"), "stairs up are sketched")
	check(h.problem_roof(3, 2, 0) == "taken", "no slab over the stairs")
	check(h.erase_above(4, 2, 0) == "needed", "the slab the stairs lead to stays")
	# Walls on the upper floor are legal; a roof comes over them.
	check(h.sketch([[4, 2, "x"]], HouseSketch.WALL, 1) == 1 and h.has_piece(4, 2, "x", 1), "a wall on the upper floor")
	check(h.problem(4, 2, "x", HouseSketch.WALL, 2) == "storey", "no wall on a third storey")
	check(h.sketch_roof([[4, 2, "c"]], HouseSketch.SADDLE, 1, "rx") == 1 and h.roof_key(4, 2, 1) == "1:4:2:rx", "a saddle roof over the upper floor")
	# Building order: the floor before the upper wall before the roof; stairs after the slab.
	h.deposit("steinblock", 20)
	h.deposit("bauholz", 30)
	h.ordered = true
	var order := []
	for i in 12:
		var r := h.build_next()
		if r.is_empty():
			break
		order.append(r.kind)
	check(order.size() == 7, "everything is built (%d)" % order.size())
	check(order.find("slab") < order.find("upstairs") and order.find("wall") > order.find("slab") and order[-1] == "saddle", "slab, stairs, upper wall, roof in that order: %s" % [order])
	h.save("upper_test_hero")
	HouseSketch.reload()
	var again := HouseSketch.of("upper_test_hero", Rect2i(10, 10, 4, 4))
	check(again.pieces.size() == h.pieces.size(), "floors and roofs are kept in the books")


func _height_at(point: Vector3, from := 12.0) -> float:
	var space: PhysicsDirectSpaceState3D = game.level.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3(0, from, 0), point + Vector3(0, -20, 0)))
	return hit.position.y if not hit.is_empty() else -999.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.hero_name = "Upper test"
		game.escaped = true
		game.load_level(game._outdoor_index(), false)
		game.state = game.State.PLAYING
		var found := Rect2i()
		for y in range(game.level.height - 5):
			for x in range(game.level.grid[y].length() - 5):
				var r := Rect2i(x, y, 4, 4)
				if Plots.problem(game.level, r) == "":
					found = r
					break
			if found.size != Vector2i.ZERO:
				break
		Plots.register(game.level, game.hero_name, found)
		game.plot_marker.refresh()
		plan = game.house_sketcher.plan
		plan.deposit("steinblock", 20)
		plan.deposit("bauholz", 30)
		plan.sketch_roof(plan.cells_between(Vector2i(4, 2), Vector2i(5, 3)), HouseSketch.SLAB, 0)
		plan.sketch_upstairs(2, 2, "e")
		plan.sketch_roof(plan.cells_between(Vector2i(4, 2), Vector2i(5, 3)), HouseSketch.SADDLE, 1, "rx")
		plan.ordered = true
		for i in 12:
			game.house_sketcher.work_once()
		return false
	if frames < 9:
		return false
	var slab := plan.cell_world(5, 3)
	check(absf(_height_at(slab, 4.0) - HouseSketch.STOREY_HEIGHT) < 0.05, "the slab carries you at 3 m (is %f)" % _height_at(slab, 4.0))
	var h := _height_at(plan.node_world(2, 2) + Vector3(0.05, 0, 1.0))
	check(h > -0.01 and h < 0.5, "the stairs up start low (is %f)" % h)
	check(_height_at(plan.cell_world(0, 0)) < 0.05, "open ground beside the house stays at 0")
	# Roof fading: under the roof, in the doorway-free yard.
	var sketcher: HouseSketcher = game.house_sketcher
	var roof_nodes := sketcher._solid.get_children().filter(func(n): return n.has_meta("ymin") and float(n.get_meta("ymin")) >= 2.5)
	check(roof_nodes.size() > 0, "roof pieces are tagged for fading")
	game.player.global_position = plan.cell_world(0, 0) + Vector3(0, 0.1, 0)
	sketcher._update_fade()
	check(roof_nodes.all(func(n): return n.visible), "far from the house the roof is drawn")
	game.player.global_position = plan.cell_world(4, 2) + Vector3(0, 0.1, 0)
	sketcher._update_fade()
	check(roof_nodes.all(func(n): return not n.visible), "under the roof the roof fades away")
	game.player.global_position = plan.cell_world(4, 2) + Vector3(0, HouseSketch.STOREY_HEIGHT + 0.1, 0)
	sketcher._update_fade()
	check(roof_nodes.any(func(n): return n.visible), "up on the slab the slab is drawn again")
	print("PASS: house upper floors" if failures == 0 else "FAILED: %d" % failures)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
	return true
