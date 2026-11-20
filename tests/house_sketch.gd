extends SceneTree
## The house plan (see HouseSketch): grid, snapping, sketching, undo and the books.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	HouseSketch.reload()
	var s := HouseSketch.new()
	s.plot = Rect2i(10, 20, 3, 2)
	check(s.nodes() == Vector2i(6, 4), "two grid cells to a tile")
	check(s.node_at(s.node_world(2, 3)) == Vector2i(2, 3), "a node snaps to itself")
	check(s.node_at(s.node_world(2, 3) + Vector3(0.4, 0, -0.3)) == Vector2i(2, 3), "a point snaps to the nearest node")
	check(s.node_at(Vector3(-500, 0, 500)) == Vector2i(0, 4), "snapping stays inside the plot")
	check(s.in_plot(5, 4, "x") and not s.in_plot(6, 4, "x"), "the last cell edge is inside")
	check(not s.in_plot(7, 0, "y"), "an edge beyond the plot is outside")
	var run := s.run_between(Vector2i(1, 1), Vector2i(4, 2))
	check(run.size() == 3 and run[0] == [1, 1, "x"], "a drag runs straight along the longer way")
	check(s.run_between(Vector2i(2, 2), Vector2i(2, 2)).is_empty(), "no drag, no wall")
	check(s.sketch(run, "wall") == 3, "three wall pieces sketched")
	check(s.piece(2, 1, "x").get("state") == "sketch", "pieces start as sketches")
	check(s.stage() == "plan", "a sketch is the plan stage")
	check(s.problem(2, 1, "x", "door") == "", "a door fits in a wall")
	check(s.problem(2, 3, "x", "door") == "needs wall", "a door needs a wall")
	check(s.problem(9, 3, "x", "wall") == "outside", "no wall outside the plot")
	check(s.sketch([[2, 1, "x"]], "door") == 1, "a wall becomes a door")
	check(s.count("door") == 1 and s.count("wall") == 2, "counts by kind")
	check(s.sketch([[2, 1, "x"]], "door") == 0, "the same door again changes nothing")
	var near := s.edge_near(s.node_world(2, 1) + Vector3(1.0, 0, 0.2))
	check(near == [2, 1, "x"], "the edge nearest to a point")
	check(s.edge_near(s.node_world(3, 3) + Vector3(1.0, 0, 1.0), 0.3).is_empty(), "no edge within a short reach")
	check(s.undo(), "undo")
	check(s.count("door") == 0 and s.count("wall") == 3, "undo takes the door back")
	check(s.redo() and s.count("door") == 1, "redo puts the door back")
	check(s.erase([[1, 1, "x"], [5, 3, "y"]]) == 1, "erasing takes sketched pieces only")
	check(s.undo() and s.has_piece(1, 1, "x"), "undo takes the erased wall back")
	# Built pieces stay.
	s.pieces[HouseSketch.key_of(3, 1, "x")].state = "built"
	check(s.problem(3, 1, "x", "window") == "built", "a built piece is not sketched over")
	check(s.erase([[3, 1, "x"]]) == 1 and s.piece(3, 1, "x").state == "demolish", "a built piece is marked for demolition")
	check(s.erase([[3, 1, "x"]]) == 1 and s.piece(3, 1, "x").state == "built", "erasing again keeps it")
	# The character builds: materials, order, and what is done first.
	var b := HouseSketch.new()
	b.plot = s.plot
	b.sketch([[0, 0, "x"], [1, 0, "x"]], "wall")
	b.sketch([[1, 0, "x"]], "door")
	check(b.needs() == {"steinblock": 3, "bauholz": 2}, "the sketch says what it needs")
	check(b.missing() == {"steinblock": 3, "bauholz": 2}, "nothing in stock, all missing")
	check(b.build_next().is_empty(), "nothing is built before the order")
	check(b.order() and b.stage() == "build", "the order starts the build")
	check(b.build_next().get("why", "") == "materials", "no material, no work")
	b.deposit("steinblock", 2)
	b.deposit("bauholz", 5)
	b.deposit("gold", 9)
	check(not b.stock.has("gold"), "only building material is taken in")
	var first := b.build_next()
	check(first.get("did") == "built" and first.kind == "wall", "walls are built first")
	check(b.stock.steinblock == 0, "a wall uses two stone blocks")
	check(b.build_next().get("why", "") == "materials", "the door waits for stone")
	b.deposit("steinblock", 1)
	var second := b.build_next()
	check(second.kind == "door" and b.stock.bauholz == 3, "the door uses stone and timber")
	check(b.stage() == "done" and not b.ordered, "the last piece ends the order")
	check(b.build_next().is_empty(), "nothing left to do")
	check(b.erase([[1, 0, "x"]]) == 1 and b.stage() == "plan", "tearing down is a new plan")
	b.order()
	var down := b.build_next()
	check(down.get("did") == "demolished" and b.stock.steinblock == 1 and b.stock.bauholz == 5, "the material comes back")
	check(not b.has_piece(1, 0, "x"), "the piece is gone")
	check(not b.can_undo(), "what was built cannot be undone")
	# The books.
	s.save("Tester")
	HouseSketch.reload()
	var again := HouseSketch.of("Tester", s.plot)
	check(again.pieces.size() == s.pieces.size(), "the plan survives a reload")
	check(again.piece(3, 1, "x").get("state") == "built", "a built piece stays built")
	b.save("Builder")
	HouseSketch.reload()
	check(HouseSketch.of("Builder", s.plot).stock.get("bauholz", 0) == 5, "the stock survives a reload")
	check(HouseSketch.of("Somebody else", s.plot).is_empty(), "another hero has an empty plan")
	for i in 60:
		s.sketch([[0, 0, "x"]], "wall" if i % 2 == 0 else "window")
	var undone := 0
	while s.undo():
		undone += 1
	check(undone <= HouseSketch.UNDO_LIMIT, "undo remembers a limited number of steps")
	_garden()
	if failures == 0:
		print("PASS: house sketch")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Garden walls: free of the house, on the ground only, a door in one is a gate.
func _garden() -> void:
	var g := HouseSketch.new()
	g.plot = Rect2i(0, 0, 3, 3)
	check(g.fence_kind() == "stone_fence", "garden walls are of stone at first")
	check(g.sketch([[0, 0, "x"], [1, 0, "x"], [2, 0, "x"]], g.fence_kind()) == 3, "a stone garden wall is sketched")
	g.fence_material = "wood"
	check(g.sketch([[0, 0, "y"]], g.fence_kind()) == 1 and g.count("wood_fence") == 1, "and a wooden one")
	check(g.problem(4, 4, "x", "stone_fence", 1) == "garden storey", "no garden wall on the upper floor")
	check(g.door_kind(1, 0, "x") == "gate" and g.door_kind(3, 3, "x") == "door", "a door on a garden wall is a gate")
	check(g.problem(1, 0, "x", "door") == "needs wall", "no house door in a garden wall")
	check(g.problem(1, 0, "x", "window") == "needs wall", "no window in a garden wall")
	check(g.problem(3, 3, "x", "gate") == "needs fence", "a gate needs a garden wall")
	check(g.sketch([[1, 0, "x"]], "gate") == 1 and g.count("stone_fence") == 2, "a gate opens the wall")
	check(g.needs() == {"steinblock": 2, "bauholz": 3}, "garden walls cost a block or a timber each, a gate two timber")
	g.deposit("steinblock", 2)
	g.deposit("bauholz", 3)
	g.order()
	for i in 6:
		g.build_next()
	check(g.count("gate", "built") == 1 and g.open_pieces() == 0, "the hero builds the garden")
	g.save("Garden test")
	HouseSketch.reload()
	var back := HouseSketch.of("Garden test", g.plot)
	check(back.count("stone_fence") == 2 and back.count("gate") == 1 and back.fence_material == "wood", "the garden and its material are saved")
