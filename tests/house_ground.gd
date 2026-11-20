extends SceneTree
## No grass tufts, twigs or leaves lie inside a built house (see HouseGround and
## SurfaceLife.set_built), the garden outside keeps them, and they come back
## once the house is taken down. Run with: godot --headless -s tests/house_ground.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch


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


## How much litter lies on the ground of these grid cells (and is not lifted away).
func _litter_on(cells: Array) -> int:
	var life: SurfaceLife = game.level.surface_life
	var count := 0
	for c: Vector2i in cells:
		count += life.litter_near(plan.cell_world(c.x, c.y), 0.9)
	return count


func _unit_checks() -> void:
	var house := HouseSketch.new()
	house.plot = Rect2i(10, 10, 3, 3)
	# A closed 2 x 2 ring of wall with a door, one free-standing wall and a garden wall.
	for e in [[1, 1, "x"], [2, 1, "x"], [1, 3, "x"], [2, 3, "x"], [1, 1, "y"], [1, 2, "y"], [3, 1, "y"]]:
		house.pieces[HouseSketch.key_of(e[0], e[1], e[2])] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(3, 2, "y")] = {"kind": HouseSketch.DOOR, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(5, 0, "y")] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(4, 4, "x")] = {"kind": HouseSketch.STONE_FENCE, "state": HouseSketch.BUILT}
	var inside := HouseGround.inside_cells(house)
	check(inside.size() == 4, "the ring closes in four cells (is %d)" % inside.size())
	for c in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		check(inside.has(c), "cell %s lies inside the walls" % c)
	# A sketched roof does not count yet, a built one does; an open wall closes nothing in.
	house.pieces[HouseSketch.key_of(4, 0, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.SKETCH}
	check(not HouseGround.inside_cells(house).has(Vector2i(4, 0)), "a sketched slab keeps its grass")
	house.pieces[HouseSketch.key_of(4, 0, HouseSketch.CELL_ORIENT)].state = HouseSketch.BUILT
	check(HouseGround.inside_cells(house).has(Vector2i(4, 0)), "the ground under a built slab is cleared")
	house.pieces.erase(HouseSketch.key_of(1, 2, "y"))
	check(HouseGround.inside_cells(house).size() == 1, "a gap in the ring opens it again")


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_unit_checks()
	if frames == 5:
		game.hero_name = "Ground test"
		game.escaped = true
		game.load_level(game._outdoor_index(), false)
		game.state = game.State.PLAYING
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
		plan = game.house_sketcher.plan
		return false
	if frames == 30:
		check(_litter_on(_inside()) > 0, "there is litter on the plot before the house is built")
		plan.deposit("steinblock", 40)
		plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(5, 1)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(5, 1), Vector2i(5, 5)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(5, 5), Vector2i(1, 5)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(1, 5), Vector2i(1, 1)), HouseSketch.WALL)
		game.house_sketcher._redraw()
		return false
	if frames == 32:
		check(_litter_on(_inside()) > 0, "sketched walls leave the litter alone")
		plan.ordered = true
		for i in 20:
			game.house_sketcher.work_once()
		game.house_sketcher._redraw()
		return false
	if frames == 34:
		check(plan.count(HouseSketch.WALL, HouseSketch.BUILT) == 16, "the walls are built (%d)" % plan.count(HouseSketch.WALL, HouseSketch.BUILT))
		check(_litter_on(_inside()) == 0, "no litter lies inside the built house (%d pieces)" % _litter_on(_inside()))
		# The house is taken down: the litter comes back.
		for key in plan.pieces.keys():
			plan.pieces.erase(key)
		game.house_sketcher._redraw()
		return false
	if frames == 36:
		check(_litter_on(_inside()) > 0, "the litter comes back once the house is gone")
		print("PASS: house ground" if failures == 0 else "FAILED: %d" % failures)
		Plots.release(game.hero_name)
		game.delete_save(game.save_path())
		quit(1 if failures > 0 else 0)
	return false


func _inside() -> Array:
	var out := []
	for y in range(1, 5):
		for x in range(1, 5):
			out.append(Vector2i(x, y))
	return out
