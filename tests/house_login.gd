extends SceneTree
## Headless test: a game saved inside the hero's own self-built house (on the ground floor, the
## upper storey, the roof or down in the cellar) logs back in at that very spot, with the
## house built round the hero (see Game._built_house_spot and HouseSketcher.holds). Out in
## the open the save keeps no such spot, and a spot whose floor is gone falls back to the
## usual place. Out of a built bed the hero gets up beside its own foot.
## Run with: godot --headless --fixed-fps 60 -s tests/house_login.gd

var failures := 0
var game: Node
var frames := 0
var started := false


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
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _cells(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			out.append(Vector2i(x, y))
	return out


## Saves where the hero stands now, loads that save again (the open air built anew) and
## returns how far from the spot the hero ends up, once they had time to fall.
func _relog(at: Vector3, what: String) -> float:
	game.player.global_position = at
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	await _wait(3)
	at = game.player.global_position
	var record: Dictionary = game.hero_record()
	check(record.has("built_house"), "%s: the save keeps the spot in the house" % what)
	record = JSON.parse_string(JSON.stringify(record))
	game._go_to_wake_place(game._wake_place(record))
	check(game.level is Outdoor, "%s: the load wakes up in the open air" % what)
	await _wait(30)
	return game.player.global_position.distance_to(at)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "House login test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Level = game.level
	var found := Rect2i()
	for y in range(level.height - 5):
		for x in range(level.grid[y].length() - 5):
			if Plots.problem(level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sk: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sk.plan
	# Walls from node (1, 1) to (5, 5) with a door, a floor over the ground floor (the upper
	# storey stands on it) and a flat roof over the upper storey; a cellar dug under the house.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(5, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 5))
			+ plan.run_between(Vector2i(5, 1), Vector2i(5, 5)) + plan.run_between(Vector2i(1, 5), Vector2i(5, 5)), HouseSketch.WALL)
	plan.sketch([[2, 5, "x"]], HouseSketch.DOOR)
	plan.sketch_roof(_cells(Vector2i(1, 1), Vector2i(4, 4)), HouseSketch.SLAB, 0)
	plan.sketch_roof(_cells(Vector2i(1, 1), Vector2i(4, 4)), HouseSketch.SLAB, 1)
	plan.sketch_dig(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)))
	plan.deposit(HouseSketch.STONE, 800)
	plan.deposit(HouseSketch.TIMBER, 800)
	plan.order()
	for i in 600:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(5)
	var hero: Player = game.player
	hero.godmode = true
	var ground: Vector3 = plan.cell_world(1, 2) + Vector3(0, 0.1, 0)
	var upper: Vector3 = plan.cell_world(2, 2) + Vector3(0, HouseSketch.STOREY_HEIGHT + 0.3, 0)
	var roof: Vector3 = plan.cell_world(2, 2) + Vector3(0, HouseSketch.STOREY_HEIGHT * 2.0 + 0.3, 0)
	var cellar: Vector3 = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	check(sk.holds(ground, true), "the ground floor under the roof is in the house")
	check(sk.holds(upper, true) and sk.holds(roof, true), "the upper storey and the roof are in the house")
	check(sk.holds(cellar, true), "the cellar is in the house")
	# The ground floor, the upper storey, the roof and the cellar each log back in there.
	var off: float = await _relog(ground, "ground floor")
	check(off < 0.6, "ground floor: the hero logs back in at the spot (%.2f m off)" % off)
	off = await _relog(upper, "upper storey")
	check(off < 0.6, "upper storey: the hero logs back in at the spot (%.2f m off)" % off)
	check(game.player.global_position.y > HouseSketch.STOREY_HEIGHT - 0.3, "upper storey: the hero stands up there, not on the ground")
	off = await _relog(roof, "roof")
	check(off < 0.6, "roof: the hero logs back in at the spot (%.2f m off)" % off)
	check(game.player.global_position.y > HouseSketch.STOREY_HEIGHT * 2.0 - 0.3, "roof: the hero stands on the roof")
	off = await _relog(cellar, "cellar")
	check(off < 0.6, "cellar: the hero logs back in at the spot (%.2f m off)" % off)
	await _wait(10)
	check(game.house_sketcher.cellar_view.active, "cellar: the cellar view is on after the load")
	# Out in the open, away from the plot, the save keeps no spot in the house.
	game.player.global_position = plan.node_world(0, 0) + Vector3(-12, 0, -12)
	game.player.reset_physics_interpolation()
	await _wait(3)
	check(not game.hero_record().has("built_house"), "out in the open the save keeps no spot in the house")
	# A spot whose floor is gone (no cellar dug there): the hero wakes up as before.
	var gone: Vector3 = plan.cell_world(6, 6) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	check(not game.house_sketcher.holds(gone, true), "under undug ground is no floor")
	var broken: Dictionary = game.hero_record()
	broken.built_house = {"pos": [gone.x, gone.y, gone.z], "facing": 0.0}
	game._go_to_wake_place(game._wake_place(broken))
	await _wait(3)
	check(game.player.global_position.distance_to(gone) > 1.0, "a spot without a floor is not used")
	# Out of a built bed the hero gets up beside its own foot, on its own storey.
	var side := upper + Vector3(1, 0, 1)
	check(game._bedside({"side": side, "pos": upper}, Vector3.BACK) == side, "out of a built bed beside its foot")
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house login" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
