extends SceneTree
## Headless test: a hero inside a built house is hidden from monsters while no
## line of sight leads in (see Level.built_between).
## - The house's walls and its shut door hide them; a window and an open door
##   do not. The roof hides them from above.
## - No blow, shot or spell goes through a wall, a pane or a shut door; a hero
##   standing in the open doorway can be struck.
## - A monster outside neither sees nor hears a hero walking about indoors,
##   but does once the hero steps out.
## Run with: godot --headless --fixed-fps 60 -s tests/house_hiding.gd

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
	game.hero_name = "Hiding test"
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
	# A house from node (1, 1) to (4, 4): a door in the south wall, a window in
	# the east wall, and a flat roof over it all.
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch([[4, 2, "y"]], HouseSketch.WINDOW)
	var roof := []
	for y in range(1, 4):
		for x in range(1, 4):
			roof.append(Vector2i(x, y))
	plan.sketch_roof(roof, HouseSketch.SLAB, 0)
	plan.deposit(HouseSketch.STONE, 600)
	plan.deposit(HouseSketch.TIMBER, 600)
	plan.order()
	for i in 400:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(3)
	var hero: Player = game.player
	hero.godmode = true
	for c in level.find_children("*", "CharacterBody3D", true, false):
		if c != hero:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	check(not level.built_floors.is_empty(), "the roof is known to the map")

	var middle := plan.node_world(2, 2) + Vector3(HouseSketch.CELL, 0, HouseSketch.CELL)
	middle.y = plan.node_world(2, 2).y + 0.1
	var wall_mid := plan.node_world(3, 4) + Vector3(HouseSketch.CELL * 0.5, 0.1, 0)
	var south := wall_mid + Vector3(0, 0, 8.0)
	check(not level.has_line_of_sight(south, middle), "a house wall hides the hero inside")
	check(level.has_line_of_sight(south, south + Vector3(3.0, 0, 0)), "out in the open, sight is clear")
	var window_mid := plan.node_world(4, 2) + Vector3(0, 0.1, HouseSketch.CELL * 0.5)
	var east := window_mid + Vector3(8.0, 0, 0)
	var by_window := window_mid + Vector3(-0.8, 0, 0)
	check(level.has_line_of_sight(east, by_window), "a monster looks in through a window")
	check(level.blow_blocked(window_mid + Vector3(0.8, 0, 0), by_window), "but strikes not through the pane")
	check(level.shot_blocked(east + Vector3(0, 1.2, 0), by_window + Vector3(0, 1.2, 0)), "nor shoots through it")
	var above := middle + Vector3(0, 12.0, 6.0)
	check(not level.has_line_of_sight(above, middle), "the roof hides the hero from above")

	var door_mid := plan.node_world(2, 4) + Vector3(HouseSketch.CELL * 0.5, 0.1, 0)
	var door: BuiltDoor = sk.doors.get("%s|%s" % [plan.plot, HouseSketch.key_of(2, 4, "x")])
	check(door != null and not door.is_open(), "the door is shut")
	var front := door_mid + Vector3(0, 0, 1.2)
	var behind := door_mid + Vector3(0, 0, -1.0)
	check(not level.has_line_of_sight(front + Vector3(0, 0, 5.0), behind), "a shut door hides the hero")
	check(level.blow_blocked(front, behind), "no blow lands through a shut door")
	check(level.blow_blocked(wall_mid + Vector3(0, 0, 1.0), wall_mid + Vector3(0, 0, -0.8)), "nor through a wall")
	check(level.shot_blocked(south + Vector3(0, 1.2, 0), middle + Vector3(0, 1.2, 0)), "nor a shot")

	# A skeleton outside the south wall.
	var cell := level.world_to_cell(south)
	var e: Enemy = level._spawn_enemy("krieger", cell)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.global_position = wall_mid + Vector3(0, 0, 4.0)
	e.reset_physics_interpolation()
	hero.global_position = middle
	hero.reset_physics_interpolation()
	hero.sneaking = false
	hero.velocity = Vector3(3.0, 0, 0)
	await _wait(1)
	hero.velocity = Vector3(3.0, 0, 0)
	var to := hero.global_position - e.global_position
	to.y = 0.0
	var sees := level.has_line_of_sight(e.global_position, hero.global_position)
	check(hero.is_noisy(), "the hero walks about noisily")
	check(not sees and not e._notices(hero, to, to.length(), sees), "a monster outside neither sees nor hears the hero indoors")
	hero.global_position = wall_mid + Vector3(0, 0.1, 1.2)
	hero.reset_physics_interpolation()
	to = hero.global_position - e.global_position
	to.y = 0.0
	sees = level.has_line_of_sight(e.global_position, hero.global_position)
	check(e._notices(hero, to, to.length(), sees), "out of the house it hears the hero again")

	if door != null:
		door.use(door_mid + Vector3(0, 0, 2.0))
		for i in 120:
			await _wait(1)
			if door.openness() >= 0.99:
				break
		check(door.is_open(), "the door swings open")
		check(level.has_line_of_sight(front + Vector3(0, 0, 5.0), behind), "through the open door the hero is seen")
		check(not level.blow_blocked(front, door_mid), "and in the open doorway can be struck")
	_end()


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: house hiding" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
