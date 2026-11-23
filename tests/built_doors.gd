extends SceneTree
## Headless test: the doors and gates the hero builds (see BuiltDoor).
## - A built door is a doorway the hero fits through upright, with a board leaf
##   that is shut at first and stops everyone while shut.
## - The hero walks into it: it swings open away from them, lets them through and
##   shuts behind them by itself.
## - E keeps it open and shuts it again; a redraw of the houses keeps its state.
## - Shift+E locks the hero's own door (a padlock shows; saved with the house):
##   a creature cannot push a locked door open and is stopped by it, an unlocked
##   one opens for it; the hero still gets through their own locked door.
## - Monsters other than people (a slime, say) do not open even an unlocked door.
## - A gate in a garden wall gets a leaf of its own.
## - Under a pitched roof the eave over a door does not catch the hero's head: the hero walks in
##   and out of the old hut over the silver mine (see LostMine.HUT).
## Run with: godot --headless --fixed-fps 60 -s tests/built_doors.gd
## With SHOTS=<folder> and a display it also saves pictures of the door.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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
	game.hero_name = "Door test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var found := Rect2i()
	for y in range(game.level.height - 5):
		for x in range(game.level.grid[y].length() - 5):
			if Plots.problem(game.level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sk: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sk.plan
	var n := plan.nodes()
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(4, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 4))
			+ plan.run_between(Vector2i(4, 1), Vector2i(4, 4)) + plan.run_between(Vector2i(1, 4), Vector2i(4, 4)), HouseSketch.WALL)
	plan.sketch([[2, 4, "x"]], HouseSketch.DOOR)
	plan.sketch(plan.run_between(Vector2i(0, 0), Vector2i(n.x, 0)), HouseSketch.STONE_FENCE)
	plan.sketch([[2, 0, "x"]], plan.door_kind(2, 0, "x"))
	plan.deposit(HouseSketch.STONE, 400)
	plan.deposit(HouseSketch.TIMBER, 400)
	plan.order()
	for i in 300:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	await _wait(3)
	var door_key := HouseSketch.key_of(2, 4, "x")
	var gate_key := HouseSketch.key_of(2, 0, "x")
	check(plan.pieces.get(gate_key, {}).get("kind", "") == HouseSketch.GATE, "the garden wall has a gate")
	var door: BuiltDoor = sk.doors.get("%s|%s" % [plan.plot, door_key])
	var gate: BuiltDoor = sk.doors.get("%s|%s" % [plan.plot, gate_key])
	check(door != null and door.is_inside_tree(), "the built door has a leaf")
	check(gate != null and gate.gate, "the gate has a leaf of its own")
	if door == null:
		_end()
		return
	var hero: Player = game.player
	hero.godmode = true # a wolf or a bat must not interrupt the test
	# A companion following the hero would hold the door open.
	# Nor may a wolf, a bat or a villager passing by (each of them would push it
	# open, as they should).
	for c in game.level.find_children("*", "CharacterBody3D", true, false):
		if c != hero:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	check(HouseSketcher.DOOR_HEIGHT >= hero.tall, "the doorway (%.2f m) is as high as the hero's reach (%.2f m)" % [HouseSketcher.DOOR_HEIGHT, hero.tall])
	check(door.height > 2.3 and door.width > 1.1, "the leaf fills a tall doorway (%.2f x %.2f m)" % [door.width, door.height])
	check(door.openness() == 0.0 and not door._blocker.disabled, "the door is shut at first and stops whoever walks into it")
	check(not door._locks[0].visible, "an unlocked door shows no padlock")

	var at := door.global_position
	hero.global_position = at + Vector3(3.0, 0.1, 4.0)
	hero.reset_physics_interpolation()
	await _shot("door_shut", at + Vector3(1.6, 1.7, 4.2), at + Vector3(0, 1.2, 0))
	await _shot("gate", gate.global_position + Vector3(1.5, 1.6, -4.0), gate.global_position + Vector3(0, 0.8, 0))
	# The hero walks into it from the street (south) and comes out inside.
	hero.global_position = at + Vector3(0, 0.1, 2.0)
	hero.reset_physics_interpolation()
	await _wait(10)
	var widest := 0.0
	Input.action_press("ui_up")
	var snapped := false
	for i in 400:
		await _wait(1)
		widest = maxf(widest, door.openness())
		if not snapped and hero.global_position.z < at.z + 0.3 and shots != "":
			snapped = true
			Input.action_release("ui_up")
			await _shot("hero_in_doorway", at + Vector3(2.2, 1.6, 4.0), at + Vector3(0, 1.2, 0))
			Input.action_press("ui_up")
		if hero.global_position.z < at.z - 1.6:
			break
	Input.action_release("ui_up")
	check(widest > 0.9, "walking into the door swings it open (%.2f)" % widest)
	var tip := door.leaf.global_transform * Vector3(door.width, 1.0, 0)
	check(tip.z < at.z - 0.5, "it swings away from the hero, into the house (tip %.2f)" % (tip.z - at.z))
	check(hero.global_position.z < at.z - 1.0, "the hero walks through the doorway upright (z %.2f, door %.2f)" % [hero.global_position.z, at.z])
	hero.global_position = at + Vector3(0, 0.1, -3.5)
	hero.reset_physics_interpolation()
	await _wait(int((BuiltDoor.HOLD + BuiltDoor.OPEN_TIME + 0.4) * 60))
	check(door.openness() == 0.0 and not door._blocker.disabled, "the door falls shut behind the hero")

	# E: open and keep open, then shut.
	hero.global_position = at + Vector3(0, 0.1, 1.6)
	hero.reset_physics_interpolation()
	await _wait(5)
	check(game.door_in_reach() == door, "the door is in reach of E")
	check(game.door_action(door, false) == "", "E opens the door")
	await _wait(int((BuiltDoor.HOLD + BuiltDoor.OPEN_TIME + 0.5) * 60))
	check(door.is_open() and door.held_open, "and keeps it open")
	sk._redraw()
	await _wait(3)
	var again: BuiltDoor = sk.doors.get("%s|%s" % [plan.plot, door_key])
	check(again != door and again.is_open() and again.held_open, "the houses drawn again keep the door open")
	door = again
	var said: String = game.door_action(door, false)
	await _wait(int((BuiltDoor.OPEN_TIME + 0.2) * 60))
	check(said == "", "E is not refused (%s)" % said)
	check(door.openness() == 0.0 and not door._blocker.disabled, "E shuts it again, with the hero standing at it")

	# A creature in front of the door.
	var beast := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.7
	beast.add_child(shape)
	game.level.add_child(beast)
	hero.global_position = at + Vector3(4.0, 0.1, 4.0)
	hero.reset_physics_interpolation()
	await _wait(5)

	# Locked: Shift+E.
	hero.global_position = at + Vector3(0, 0.1, 1.6)
	hero.reset_physics_interpolation()
	await _wait(3)
	var said_lock: String = game.door_action(door, true)
	check(said_lock == "" and door.locked, "Shift+E locks the hero's own door (%s)" % said_lock)
	check(door._locks[0].visible and door._locks[1].visible, "a padlock shows on both faces")
	check(plan.locked.has(door_key), "the lock is kept in the plan")
	# Double click on the door unlocks and locks it again (and is not a sneak toggle).
	check(game._lock_door_by_double_click(at) and not door.locked and not plan.locked.has(door_key), "a double click on the door unlocks it")
	check(game._lock_door_by_double_click(at) and door.locked and plan.locked.has(door_key), "a double click locks it again")
	check(not game._lock_door_by_double_click(at + Vector3(6, 0, 6)), "a double click away from the door is left to sneaking")
	hero.global_position = at + Vector3(3.0, 0.1, 4.0)
	hero.reset_physics_interpolation()
	await _shot("door_locked", at + Vector3(0.9, 1.5, 2.0), at + Vector3(0.4, 1.2, 0))
	HouseSketch._loaded = false
	check(HouseSketch.of(game.hero_name, plan.plot).locked.has(door_key), "and saved with the house")
	hero.global_position = at + Vector3(4.0, 0.1, 4.0)
	hero.reset_physics_interpolation()
	beast.global_position = at + Vector3(0, 0.05, 1.5)
	await _wait(3)
	var stopped := true
	for i in 90:
		beast.velocity = Vector3(0, -1, -3.0)
		beast.move_and_slide()
		await _wait(1)
		if door.openness() > 0.0:
			stopped = false
	check(stopped and beast.global_position.z > at.z, "a creature cannot push a locked door open and stays out (z %.2f)" % (beast.global_position.z - at.z))

	# The hero gets through their own locked door.
	beast.global_position = at + Vector3(5.0, 0.05, 5.0)
	hero.global_position = at + Vector3(0, 0.1, 2.0)
	hero.reset_physics_interpolation()
	await _wait(5)
	widest = 0.0
	Input.action_press("ui_up")
	for i in 400:
		await _wait(1)
		widest = maxf(widest, door.openness())
		if hero.global_position.z < at.z - 1.6:
			break
	Input.action_release("ui_up")
	check(widest > 0.9 and hero.global_position.z < at.z - 1.0, "the owner walks through their locked door (%.2f, z %.2f)" % [widest, hero.global_position.z - at.z])
	hero.global_position = at + Vector3(4.0, 0.1, -4.0)
	hero.reset_physics_interpolation()
	await _wait(int((BuiltDoor.HOLD + BuiltDoor.OPEN_TIME + 0.4) * 60))

	# Unlocked again: the creature pushes it open.
	door.set_locked(false)
	check(not plan.locked.has(door_key) and not door._locks[0].visible, "Shift+E again unlocks it")
	beast.global_position = at + Vector3(0, 0.05, 1.5)
	await _wait(3)
	var pushed := false
	for i in 90:
		beast.velocity = Vector3(0, -1, -3.0)
		beast.move_and_slide()
		await _wait(1)
		pushed = pushed or door.is_open()
	check(pushed and beast.global_position.z < at.z, "an unlocked door opens for a creature too (z %.2f)" % (beast.global_position.z - at.z))
	beast.queue_free()
	await _wait(int((BuiltDoor.HOLD + BuiltDoor.OPEN_TIME + 0.4) * 60))
	check(door.openness() == 0.0 and not door.locked, "the unlocked door is shut again")

	# A slime is no door opener: an unlocked, shut door stops it like a wall.
	var slime: Enemy = game.level._spawn_enemy("schleim", game.level.world_to_cell(at + Vector3(0, 0, 3.0)))
	# Its own mind stays off: the test moves it.
	slime.set_physics_process(false)
	slime.set_process(false)
	slime.global_position = at + Vector3(0, 0.05, 1.5)
	slime.reset_physics_interpolation()
	check(not door.may_pass(slime) and not BuiltDoor.opens_doors(slime), "a slime may not open a door")
	await _wait(3)
	var slime_stopped := true
	for i in 90:
		slime.velocity = Vector3(0, -1, -3.0)
		slime.move_and_slide()
		await _wait(1)
		if door.openness() > 0.0:
			slime_stopped = false
	check(slime_stopped and slime.global_position.z > at.z, "a slime cannot push an unlocked door open and stays out (z %.2f)" % (slime.global_position.z - at.z))
	slime.queue_free()
	# People can: a bandit opens an unlocked door, but not a locked one.
	var bandit: Enemy = game.level._spawn_enemy("schlaeger", game.level.world_to_cell(at + Vector3(0, 0, 3.0)))
	bandit.process_mode = Node.PROCESS_MODE_DISABLED
	check(BuiltDoor.opens_doors(bandit) and door.may_pass(bandit), "a bandit opens an unlocked door")
	door.locked = true
	check(not door.may_pass(bandit), "but not a locked one")
	door.locked = false
	bandit.queue_free()
	await _through_roofed_door()
	_end()


## In and out through the door of the old mine hut, whose pitched roof's eave hangs over the door.
func _through_roofed_door() -> void:
	var hero: Player = game.player
	var s := LostMine.sketch()
	var x := LostMine.HUT.position.x + LostMine.HUT.size.x / 2
	var outside := s.cell_world(x, LostMine.HUT.position.y - 1)
	var inside := s.cell_world(x, LostMine.HUT.position.y)
	for way: Array in [[outside, "ui_down", inside.z, "walks into the roofed hut through its door"], [inside, "ui_up", outside.z, "walks out again"]]:
		hero.global_position = (way[0] as Vector3) + Vector3(0, 0.1, 0)
		hero.reset_physics_interpolation()
		await _wait(5)
		Input.action_press(way[1])
		var goal: float = way[2]
		var start_z := hero.global_position.z
		for i in 240:
			await _wait(1)
			if absf(hero.global_position.z - start_z) >= absf(goal - start_z) - 0.2:
				break
		Input.action_release(way[1])
		check(absf(hero.global_position.z - start_z) >= absf(goal - start_z) - 0.2, "the hero %s (z %.2f, aiming for %.2f)" % [way[3], hero.global_position.z, goal])


func _shot(name: String, from: Vector3, look: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(look)
	cam.make_current()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: built doors" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
