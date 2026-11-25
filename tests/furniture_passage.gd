extends SceneTree
## Furniture may not wall off part of a room (HouseFurniture.problem "cut off"): the floor is on
## a 2 m grid, so a gap beside a piece is a whole cell wide (the hero is 1.1 m) or shut, and a
## piece that would shut one off, leaving a corner nobody can get out of, is refused. A closet that
## was shut before is nobody's fault, and moving a piece (skip) leaves its old cells free.
## Run with: godot --headless -s tests/furniture_passage.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _wall(plan: HouseSketch, x: int, y: int, orient: String, kind := HouseSketch.WALL) -> void:
	plan.pieces[HouseSketch.key_of(x, y, orient)] = {"kind": kind, "state": HouseSketch.BUILT}


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	var plan := HouseSketch.new()
	plan.plot = Rect2i(0, 0, 3, 3)
	# A room of 4 x 2 cells at (1, 1): walls round it, a door in the south wall at x = 4, a roof.
	for x in range(1, 5):
		_wall(plan, x, 1, HouseSketch.ORIENT_X)
		_wall(plan, x, 3, HouseSketch.ORIENT_X, HouseSketch.DOOR if x == 4 else HouseSketch.WALL)
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		_wall(plan, 1, y, HouseSketch.ORIENT_Y)
		_wall(plan, 5, y, HouseSketch.ORIENT_Y)
	var store := HouseFurniture.new()
	check(store.problem(plan, "truhe", 0, 2, 1, 0) == "", "one chest in the room fits")
	store.placed.append({"kind": "truhe", "storey": 0, "x": 2, "y": 1, "rot": 0})
	check(store.problem(plan, "truhe", 0, 2, 2, 0) == "cut off", "a second chest closing the column shuts the corner off")
	check(store.problem(plan, "truhe", 0, 4, 1, 0) == "", "a chest elsewhere leaves the way free")
	check(store.problem(plan, "truhe", 0, 2, 2, 0, 0) == "", "moving the first chest (its cell is free again) is no wall")
	check(HouseFurniture.reason("cut off") != "Das geht hier nicht.", "the reason has its own text")
	# A closet that was shut before is not blamed: the wall already splits the room.
	_wall(plan, 3, 1, HouseSketch.ORIENT_Y)
	_wall(plan, 3, 2, HouseSketch.ORIENT_Y)
	var other := HouseFurniture.new()
	check(other.problem(plan, "truhe", 0, 4, 1, 0) == "", "a chest in a room that was split by walls before fits")
	print("PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
