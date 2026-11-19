extends SceneTree
## Headless test for the cellar of a player house (HouseSketch): digging, stairs,
## surfaces, their costs, the building order and the books.
## Run with: godot --headless -s tests/house_cellar.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var h := HouseSketch.new()
	h.plot = Rect2i(10, 10, 4, 4)
	check(h.cell_in_plot(0, 0) and h.cell_in_plot(7, 7) and not h.cell_in_plot(8, 0), "cells lie inside the plot")
	check(h.problem_dig(8, 0) == "outside", "no digging outside the plot")
	# A cellar of 2 x 2 cells with a stone floor and bare walls.
	h.floor_surface = "stone"
	check(h.sketch_dig(h.cells_between(Vector2i(4, 4), Vector2i(5, 5))) == 4, "a drag digs a rectangle of four cells")
	check(h.sketch_dig([[4, 4, "c"]]) == 0, "a dug cell cannot be dug twice")
	check(HouseSketch.cost_of(h.pieces["-1:4:4:c"]) == {"steinblock": 1}, "a stone floor costs a block a cell")
	check(h.is_dug(4, 4) and not h.is_dug(4, 4, true), "a sketched cell is not yet built")
	# Stairs: two free cells and a dug cell after them.
	check(h.stairs_dir(2, 4) == "e", "stairs find the way down towards the cellar")
	check(h.problem_stairs(5, 5, "e") == "taken", "stairs cannot lie on a dug cell")
	check(h.problem_stairs(1, 1, "e") == "no cellar", "stairs need a dug cell below")
	check(h.sketch_stairs(2, 4, "e") and h.hole_key(3, 4) == "-1:2:4:e" and h.hole_key(2, 4) == "-1:2:4:e", "stairs hold two cells open")
	check(h.sketch_dig([[3, 4, "c"]]) == 0, "no digging under the stairs")
	check(h.erase_cell(4, 4) == "needed", "a cell the stairs lead to stays")
	# Build: dig first, the stairs after.
	h.deposit("steinblock", 20)
	h.deposit("bauholz", 4)
	h.ordered = true
	var order := []
	for i in 6:
		var r := h.build_next()
		if r.is_empty():
			break
		order.append(r.kind)
	check(order.size() == 5 and order[0] == "dig" and order[4] == "stairs", "the cellar is dug before the stairs are built")
	check(h.stock.get("steinblock", 0) == 16 and h.stock.get("bauholz", 0) == 2, "the floor and the stairs were paid")
	check(h.stage() == "done", "the cellar is done")
	# Changing it later: stairs first, then the cell.
	check(h.erase_cell(2, 4) == "" and h.pieces["-1:2:4:e"].state == "demolish", "built stairs are marked for demolition")
	h.ordered = true
	var back := h.build_next()
	check(back.get("did", "") == "demolished" and h.stock.get("bauholz", 0) == 4, "the timber of the stairs comes back")
	check(h.erase_cell(4, 4) == "" and h.pieces["-1:4:4:c"].state == "demolish", "a dug cell is marked to be filled in")
	h.ordered = true
	h.build_next()
	check(h.stock.get("steinblock", 0) == 17, "the surface material comes back")
	# The books keep surfaces and cells.
	h.save("cellar_test_hero")
	HouseSketch.reload()
	var again := HouseSketch.of("cellar_test_hero", Rect2i(10, 10, 4, 4))
	check(again.pieces.size() == h.pieces.size() and again.floor_surface == "stone", "the cellar is kept in the books")
	var cell: Dictionary = again.pieces.get("-1:5:5:c", {})
	check(cell.get("floor", "x") == "stone" and cell.get("wall", "x") == "", "a cell remembers its surfaces")
	print("PASS: house cellar" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
