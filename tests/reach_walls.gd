extends SceneTree
## Headless test: nothing is picked up or used through a wall that is solid
## from the floor to above the hero's head (see Level.can_reach).
## - A built house wall and a shut door stop a reaching hand; an open door,
##   a window and a garden wall two blocks high do not.
## - An item lying just inside a house wall is not picked up from outside,
##   only once the hero stands inside.
## - The blocks of the village's buildings stop it too; open ground does not.
## Run with: godot --headless --fixed-fps 60 -s tests/reach_walls.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Lang.language = "en"
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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Reach test"
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
	var n := plan.nodes()
	# A house from node (1, 1) to (4, 4): a door in the south wall, a window in
	# the east wall, and a garden wall along the plot's north edge.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch([[4, 2, "y"]], HouseSketch.WINDOW)
	plan.sketch(plan.run_between(Vector2i(0, 0), Vector2i(n.x, 0)), HouseSketch.STONE_FENCE)
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(3)
	var hero: Player = game.player
	hero.godmode = true
	for c in level.find_children("*", "CharacterBody3D", true, false):
		if c != hero:
			c.process_mode = Node.PROCESS_MODE_DISABLED

	# Half a cell either side of the middle of a wall piece.
	var wall_mid := plan.node_world(3, 4) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	var inside := wall_mid + Vector3(0, 0.1, -0.9)
	var outside := wall_mid + Vector3(0, 0.1, 0.9)
	check(not level.can_reach(outside, inside), "a house wall stops a reaching hand")
	check(level.can_reach(inside + Vector3(0, 0, -0.5), inside), "inside the house everything is in reach")
	var door_mid := plan.node_world(2, 4) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	var door: BuiltDoor = sk.doors.get("%s|%s" % [plan.plot, HouseSketch.key_of(2, 4, "x")])
	check(door != null and not door.is_open(), "the door is shut")
	check(not level.can_reach(door_mid + Vector3(0, 0.1, 0.9), door_mid + Vector3(0, 0.1, -0.9)), "a shut door stops it")
	if door != null:
		door.use(door_mid + Vector3(0, 0, 2.0))
		for i in 120:
			await _wait(1)
			if door.openness() >= 0.99:
				break
		check(door.is_open(), "the door swings open")
		check(level.can_reach(door_mid + Vector3(0, 0.1, 0.9), door_mid + Vector3(0, 0.1, -0.9)), "an open doorway lets the hand through")
	var window_mid := plan.node_world(4, 2) + Vector3(0, 0, HouseSketch.CELL * 0.5)
	check(level.can_reach(window_mid + Vector3(0.9, 0.1, 0), window_mid + Vector3(-0.9, 0.1, 0)), "one reaches in through a window")
	var fence_mid := plan.node_world(2, 0) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	check(level.can_reach(fence_mid + Vector3(0, 0.1, -0.9), fence_mid + Vector3(0, 0.1, 0.9)), "one reaches over a garden wall two blocks high")

	# An item just inside the wall stays there while the hero stands outside.
	var id := ""
	for k in Items.ALL:
		if k != Items.KNIFE and hero.bag_fits(k):
			id = k
			break
	level._drop_item(id, wall_mid + Vector3(0, 0, -0.4))
	var pickup: Dictionary = level._pickups.back()
	hero.global_position = outside
	hero.reset_physics_interpolation()
	level._check_pickups()
	check(level._pickups.has(pickup), "an item behind a house wall is not picked up from outside")
	hero.global_position = inside
	hero.reset_physics_interpolation()
	level._check_pickups()
	check(not level._pickups.has(pickup), "inside, the same item is picked up")

	# A village building: a block letter with open ground either side along x.
	var blocked := false
	var open := false
	for y in level.height:
		for x in range(2, level.grid[y].length() - 2):
			var ch: String = level.grid[y][x]
			var left: String = level.grid[y][x - 1]
			var right: String = level.grid[y][x + 1]
			if not blocked and ".,:".contains(level.grid[y][x - 2]) and Outdoor.BLOCK_CHARS.contains(left) \
					and Outdoor.BLOCK_CHARS.contains(ch) and Outdoor.BLOCK_CHARS.contains(right) and ".,:".contains(level.grid[y][x + 2]):
				blocked = true
				check(not level.can_reach(level.cell_to_world(Vector2i(x - 2, y)), level.cell_to_world(Vector2i(x + 2, y))),
						"a village building stops a reaching hand")
			if not open and ".,:".contains(left) and ".,:".contains(ch) and ".,:".contains(right):
				open = true
				check(level.can_reach(level.cell_to_world(Vector2i(x - 1, y)), level.cell_to_world(Vector2i(x + 1, y))),
						"open ground does not")
	check(blocked and open, "the village has buildings and open ground to try")
	_end()


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: reach walls" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
