extends SceneTree
## Headless test: villagers never cross a wall brick or a shut gate (see Villager.blocked_at):
## - every way of moving (steps, pushes, a walk along an old path) stops at a shut gate or a wall;
## - an open gate lets them through;
## - a villager whose path leads through a gate that has been shut waits and finds another way.
## Run with: godot --headless --fixed-fps 60 -s tests/villager_walls.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
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
	game.hero_name = "Wall walkers"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	lvl.night = false
	var v: Villager = lvl.villagers[0]
	v._start("idle", 600.0)
	var gate: WallBrick = wall.brick_at(Vector2i(37, 27))
	var brick: WallBrick = wall.brick_at(Vector2i(37, 26))
	var at_gate := gate.global_position
	var outside := at_gate + Vector3(-3, 0, 0)

	# A standing brick and a shut gate stop every kind of step.
	v.global_position = outside
	check(not v._move_to(brick.global_position), "nobody steps into a wall brick")
	check(v.blocked_at(brick.global_position), "a brick blocks")
	check(not v.blocked_at(at_gate), "an open gate does not block")
	check(v._move_to(at_gate), "an open gate lets a villager through")
	v.global_position = outside
	gate.shut = true
	wall.changed(gate)
	check(v.blocked_at(at_gate), "a shut gate blocks")
	check(not v._move_to(at_gate), "nobody steps into a shut gate")
	check(v.global_position.distance_to(outside) < 0.01, "the villager stayed where they were")

	# A walk along a path that leads through a gate that was shut meanwhile.
	v._path.clear()
	v._path.append(at_gate)
	v._path.append(at_gate + Vector3(3, 0, 0))
	v._speed = Villager.WALK_SPEED
	v._task = "walk"
	v.set_meta("then", "idle")
	for i in 240:
		await physics_frame
		check(not v.blocked_at(v.global_position) or v._task != "walk", "the walker never stands in the shut gate")
		if v.blocked_at(v.global_position):
			break
	check(not v.blocked_at(v.global_position), "a shut gate was never crossed (%s)" % v.global_position)
	check(v.global_position.x < at_gate.x - 0.2, "the villager is still on the outer side of the shut gate")

	# Someone caught inside a block can still step out of it.
	v.global_position = at_gate
	check(v._move_to(outside), "one standing in a shut gate can step out")

	if failures == 0:
		print("PASS: villager walls")
	else:
		print("FAILED: ", failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
