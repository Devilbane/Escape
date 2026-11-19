extends SceneTree
## Things on a flat roof: stone blocks lie on a built slab (a pile there may be
## MAX_LAYERS high) and a crate stands on it; blocks that lose their slab go back
## into the plot's stock. Run with: godot --headless -s tests/house_roof_items.gd

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


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.hero_name = "Roof test"
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
		plan.deposit("bauholz", 10)
		plan.sketch_roof(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)), HouseSketch.SLAB, 0)
		plan.ordered = true
		for i in 6:
			game.house_sketcher.work_once()
		return false
	if frames < 9:
		return false
	var level: Level = game.level
	var on_roof := plan.cell_world(3, 3) + Vector3(0.5, 0, 0.5)
	var cell := StoneBlock.grid_cell(on_roof)
	check(level.stone_column(cell) == 4, "a slab raises the stone grid by four layers (is %d)" % level.stone_column(cell))
	check(level.stone_column(StoneBlock.grid_cell(plan.cell_world(0, 0))) == 0, "ground beside the house is not raised")
	var hero: Node3D = game.player
	hero.global_position = Vector3(on_roof.x, HouseSketch.STOREY_HEIGHT, on_roof.z)
	var spot := level.stone_spot_under(hero, Vector3.BACK)
	check(not spot.is_empty() and spot.layer == 4, "a stone block can be set down on the roof")
	if not spot.is_empty():
		check(level.crate_spot(hero) != Vector3.INF, "a crate stands on the roof too")
		var stone := level.add_stone(spot.cell, spot.along_x, spot.layer)
		check(absf(stone.global_position.y - HouseSketch.STOREY_HEIGHT) < 0.05, "it lies on the roof at 3.2 m (is %f)" % stone.global_position.y)
		check(level.stone_fits(spot.cell, spot.along_x, spot.layer + 5, null, hero) == false, "a pile on the roof is limited to its five layers")
		# Take the slab away: the block goes back into the stock.
		plan.erase_above(3, 3, 0)
		plan.erase_above(4, 3, 0)
		plan.erase_above(3, 4, 0)
		plan.erase_above(4, 4, 0)
		plan.ordered = true
		for i in 6:
			game.house_sketcher.work_once()
		check(level.stones.is_empty() or not level.stones.any(func(s): return is_instance_valid(s) and s == stone and not s.is_queued_for_deletion()), "a block that lost its slab leaves the roof")
		check(plan.stock.get("steinblock", 0) >= 1, "and goes back into the stock (is %d)" % plan.stock.get("steinblock", 0))
	print("PASS: things on the roof" if failures == 0 else "FAILED: %d" % failures)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
	return true
