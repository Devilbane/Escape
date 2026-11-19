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
	check(s.erase([[3, 1, "x"]]) == 0, "a built piece is not erased")
	# The books.
	s.save("Tester")
	HouseSketch.reload()
	var again := HouseSketch.of("Tester", s.plot)
	check(again.pieces.size() == s.pieces.size(), "the plan survives a reload")
	check(again.piece(3, 1, "x").get("state") == "built", "a built piece stays built")
	check(HouseSketch.of("Somebody else", s.plot).is_empty(), "another hero has an empty plan")
	for i in 60:
		s.sketch([[0, 0, "x"]], "wall" if i % 2 == 0 else "window")
	var undone := 0
	while s.undo():
		undone += 1
	check(undone <= HouseSketch.UNDO_LIMIT, "undo remembers a limited number of steps")
	if failures == 0:
		print("PASS: house sketch")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
