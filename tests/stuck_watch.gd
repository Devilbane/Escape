extends SceneTree
## Headless test for the stuck watchdog (StuckWatch): a villager, a deer or a farm animal
## that keeps walking without getting any closer to where it is going stands still with
## idle legs for StuckWatch.REST seconds and then tries again; one that gets on is never
## stopped, and a long detour or a goal that moves is no reason to stop either.
## Run with: godot --headless --fixed-fps 60 -s tests/stuck_watch.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _rules() -> void:
	var dt := 1.0 / 60.0
	var goal := Vector3(10, 0, 0)
	# Getting closer all the time: never stuck.
	var w := StuckWatch.new()
	var stuck := false
	for i in 600:
		stuck = stuck or w.tick(goal, 10.0 - i * dt * 1.0, dt)
	check(not stuck, "a walker that gets closer is never stuck")
	# On the spot: stuck after PATIENCE seconds, not before.
	w = StuckWatch.new()
	var at := -1
	for i in 600:
		if w.tick(goal, 8.0, dt):
			at = i
			break
	check(at > 0 and absf(at * dt - StuckWatch.PATIENCE) < 0.1, "walking on the spot is stuck after %.1f s (%d ticks)" % [StuckWatch.PATIENCE, at])
	# Round and round a path point: the way ahead swings by a metre but never shrinks.
	w = StuckWatch.new()
	stuck = false
	for i in 600:
		stuck = stuck or w.tick(goal, 8.0 + 0.5 * sin(i * dt * 3.0), dt)
	check(stuck, "circling a path point is stuck")
	# A detour found (the way grows) is measured afresh: the walk along it is progress.
	w = StuckWatch.new()
	stuck = false
	var left := 4.0
	for i in 200:
		stuck = stuck or w.tick(goal, left, dt)
		left -= dt
	left += 12.0
	for i in 400:
		stuck = stuck or w.tick(goal, left, dt)
		left -= dt
	check(not stuck, "a longer way found is no reason to stop")
	# A goal that moves (the hero walking off) starts the watch again.
	w = StuckWatch.new()
	stuck = false
	for i in 600:
		stuck = stuck or w.tick(goal + Vector3(i * 0.05, 0, 0), 8.0, dt)
	check(not stuck, "a goal that keeps moving starts the watch afresh")
	# The way ahead is measured along the path, then on to a goal beyond it.
	var path: Array[Vector3] = [Vector3(3, 0, 0), Vector3(3, 0, 4)]
	check(is_equal_approx(StuckWatch.remaining(Vector3.ZERO, path), 7.0), "the way ahead runs along the path")
	check(is_equal_approx(StuckWatch.remaining(Vector3.ZERO, path, Vector3(6, 0, 4)), 10.0), "and on to a goal past its end")


func _run() -> void:
	_rules()
	game.hero_name = "Stuck walkers"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 3:
		await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false

	# One of each: a villager, a deer and a farm animal, each held on its spot while it walks.
	var walkers: Array = []
	var spots: Array[Vector3] = []
	var goals: Array[Vector3] = []
	var person: Villager = null
	for v: Villager in lvl.villagers:
		if not v.keeps_spot() and not v.at_home and v.visible:
			person = v
			break
	check(person != null, "a villager walks about")
	var deer: Animal = lvl.animals[0] if not lvl.animals.is_empty() else null
	check(deer != null, "an animal lives in the woods")
	var goat: FarmAnimal = null
	for a: FarmAnimal in lvl.farm_animals:
		if a.kind in ["goat", "sheep", "cow"]:
			goat = a
			break
	check(goat != null, "a farm animal lives in the village")
	if person == null or deer == null or goat == null:
		_finish()
		return
	walkers = [person, deer, goat]
	for body: Node3D in walkers:
		var here := lvl.world_to_cell(body.global_position)
		var goal_cell := here
		for r in range(5, 12):
			for c in [here + Vector2i(r, 0), here + Vector2i(-r, 0), here + Vector2i(0, r), here + Vector2i(0, -r)]:
				if goal_cell == here and c.x > 0 and c.y > 0 and c.x < lvl.width and c.y < lvl.height and lvl.is_open(c) and not lvl.grid_path(here, c).is_empty():
					goal_cell = c
		check(goal_cell != here, "somewhere to walk to for %s" % body.name)
		spots.append(body.global_position)
		goals.append(lvl.cell_to_world(goal_cell))
	# The hero far away, so nobody bolts, comes over for food or stops for a word.
	# (Within the farm animals' active range, on the far side from the deer.)
	var off := goat.global_position - deer.global_position
	off.y = 0.0
	game.player.global_position = goat.global_position + off.normalized() * 30.0
	person._walk_to(goals[0], Villager.WALK_SPEED, "idle")
	deer._set_path(goals[1])
	deer.state = "stroll"
	deer._speed = 1.2
	goat._set_path(goals[2])
	goat.state = "stroll"
	goat._speed = 1.0
	goat._to_roof = false
	check(person._task == "walk", "the villager sets off")

	# Held on the spot (pushed back every tick, as by something in the way) for PATIENCE + 1 s.
	for i in int((StuckWatch.PATIENCE + 1.0) * 60.0):
		await physics_frame
		for n in walkers.size():
			walkers[n].global_position = spots[n]
	check(person._task == "idle" and not person._retry.is_empty(), "a villager walking on the spot stops (%s)" % person._task)
	check(person._current_anim == "Idle", "and stands with idle legs (%s)" % person._current_anim)
	check(deer.state == "idle" and deer._hold > 0.0, "a deer walking on the spot stops (%s)" % deer.state)
	check(goat.state == "idle" and goat._hold > 0.0, "a %s walking on the spot stops (%s)" % [goat.kind, goat.state])
	# They stand still the whole rest.
	for i in int((StuckWatch.REST - 2.0) * 60.0):
		await physics_frame
		for n in walkers.size():
			check(walkers[n].global_position.distance_to(spots[n]) < 0.05, "%s stands still while it rests" % walkers[n].name)
	check(person._task == "idle", "the villager is still resting (%s)" % person._task)
	check(deer._current_anim == "Idle", "the deer rests with idle legs (%s)" % deer._current_anim)
	# Then they try again: the villager for the same place, the animals on their way.
	for i in int(3.0 * 60.0):
		await physics_frame
	check(person._task == "walk" and not person._path.is_empty() and person._path.back().distance_to(goals[0]) < 1.5, "the villager tries again for the same place (%s)" % person._task)
	check(deer._hold <= 0.0 and deer.state in ["stroll", "idle", "graze"], "the deer goes on with its day (%s)" % deer.state)
	check(goat._hold <= 0.0, "the %s goes on with its day (%s)" % [goat.kind, goat.state])

	# Free to walk, a walker is never stopped on the way.
	var free_from: Vector3 = person.global_position
	person._walk_to(goals[0], Villager.WALK_SPEED, "idle")
	var halted := false
	for i in int((StuckWatch.PATIENCE + 2.0) * 60.0):
		await physics_frame
		if person._task != "walk":
			break
		halted = halted or not person._retry.is_empty()
	check(not halted, "a villager who gets on is never stopped")
	check(person.global_position.distance_to(free_from) > 2.0, "and really walks (%.1f m)" % person.global_position.distance_to(free_from))
	_finish()


func _finish() -> void:
	if failures == 0:
		print("PASS: stuck watch")
	else:
		print("FAILED: ", failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
