extends SceneTree
## Headless test for the children's play (see KidPlay): Pip and Pippi chase each other and show off
## cartwheels and somersaults, only by day, never during an alarm, never into walls, the hero or
## closed ground, and the game ends at once when anybody speaks to a child.
## Run with: godot --headless --fixed-fps 60 -s tests/kid_play.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _upright(v: Villager) -> bool:
	var s := v._model.scale.x
	return v._model.position.length() < 0.001 and v._model.basis.y.normalized().y > 0.999 and absf(v._model.basis.get_scale().x - s) < 0.001


func _hero_to(at: Vector3) -> void:
	game.player.global_position = at
	game.player.reset_physics_interpolation()


## Puts both children idle side by side, far from the hero, and starts the game with Pip chasing.
func _kick_off(lvl: Outdoor, pip: Villager, pippi: Villager) -> void:
	var at := lvl.cell_to_world(VillageFarm.pippi_home(lvl))
	pippi.global_position = at
	pip.global_position = lvl.cell_to_world(VillageFarm.pippi_home(lvl) + Vector2i(-1, -1))
	pippi.reset_physics_interpolation()
	pip.reset_physics_interpolation()
	pip._kid = null
	pippi._kid = null
	pip._start("idle", 30.0)
	pippi._start("idle", 30.0)
	pip._start("play", 60.0)


func _run() -> void:
	# The pose: upright at both ends, upside down half-way, for both tricks and both ways round.
	for kind in KidPlay.TRICKS:
		for yaw in [0.0, 1.0, 3.0, -2.0]:
			var forward := Vector3(sin(yaw), 0, cos(yaw))
			var side := Vector3(forward.z, 0, -forward.x)
			var along := side if kind == "cartwheel" else forward
			var ways: Array[Vector3] = [along, -along]
			for dir: Vector3 in ways:
				var s := 0.7
				var a := KidPlay.pose(kind, 0.0, dir, yaw, s)
				var z := KidPlay.pose(kind, 1.0, dir, yaw, s)
				check((a.position as Vector3).length() < 0.001 and (z.position as Vector3).length() < 0.001, "%s starts and ends at the feet" % kind)
				check((a.basis as Basis).y.normalized().y > 0.999 and (z.basis as Basis).y.normalized().y > 0.99, "%s starts and ends upright" % kind)
				var mid := KidPlay.pose(kind, 0.5, dir, yaw, s)
				check((mid.basis as Basis).y.normalized().y < -0.9, "%s turns the child head over heels half-way" % kind)
				# Nobody sinks into the ground: the head, at the top of a 1.9 m child, stays above it.
				for i in 21:
					var p := KidPlay.pose(kind, i / 20.0, dir, yaw, s)
					var head: Vector3 = (p.position as Vector3) + (p.basis as Basis) * Vector3(0, 1.9, 0)
					var feet: Vector3 = p.position
					check(head.y > -0.12 * s and feet.y > -0.12 * s, "%s keeps head and feet off the ground (t=%.2f)" % [kind, i / 20.0])
	# A cartwheel turns about the way the child faces, a somersault about its shoulders.
	var cw := KidPlay.pose("cartwheel", 0.25, Vector3(1, 0, 0), 0.0, 1.0)
	check(absf((cw.basis as Basis).y.z) < 0.01 and absf((cw.basis as Basis).y.x) > 0.5, "a cartwheel tips the child sideways")
	var sm := KidPlay.pose("somersault", 0.5 * 0.5, Vector3(0, 0, 1), 0.0, 1.0)
	check(absf((sm.basis as Basis).y.x) < 0.01 and (sm.basis as Basis).y.z > 0.1, "a somersault tips the child head forwards")

	game.load_level(game._outdoor_index(), false)
	await _wait()
	var lvl: Outdoor = game.level
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	var pip: Villager = null
	var pippi: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "7":
			pip = v
		elif v.role == "pippi":
			pippi = v
	check(pip != null and pippi != null, "Pip and Pippi are in the village")
	if pip == null or pippi == null:
		_finish()
		return
	check(KidPlay.pal_of(pip) == pippi and KidPlay.pal_of(pippi) == pip, "they are each other's pal")
	_hero_to(lvl.spots.square[0] + Vector3(20, 0, 0))
	# The herald's call (a random time) would gather the children on the square mid-test.
	lvl._herald_timer = 1.0e9

	# A game: the chase, the tricks, the rules of the ground.
	_kick_off(lvl, pip, pippi)
	await _wait(3)
	check(pip._task == "play" and pippi._task == "play", "both children play")
	check(pip._kid.chaser != pippi._kid.chaser, "one chases, one is chased")
	var tricks := {}
	var tipped := false
	var swapped := false
	var first_chaser := pip._kid.chaser
	var worst_blocked := 0
	var worst_far := 0.0
	var closest := 99.0
	for i in 60 * 70:
		await process_frame
		for c: Villager in [pip, pippi]:
			if c._task != "play" or not c._kid.active:
				continue
			if c._kid.phase == "trick":
				tricks[c._kid.trick] = true
				if c._model.basis.y.normalized().y < 0.2:
					tipped = true
			var cell := lvl.world_to_cell(c.global_position)
			if Outdoor.BLOCK_CHARS.contains(lvl.cell_char(cell)) or lvl.cell_char(cell) == "\\" or c.blocked_at(c.global_position):
				worst_blocked += 1
			worst_far = maxf(worst_far, _flat(c.global_position, c._kid.centre))
		if pip._kid.chaser != first_chaser:
			swapped = true
		if pip._task == "play" and pippi._task == "play":
			closest = minf(closest, _flat(pip.global_position, pippi.global_position))
		if pip._task != "play" and pippi._task != "play":
			# The game ran its time: start another one.
			_kick_off(lvl, pip, pippi)
	check(tricks.size() >= 1, "they do tricks (%s)" % str(tricks.keys()))
	check(tricks.has("cartwheel") and tricks.has("somersault"), "they do both cartwheels and somersaults (%s)" % str(tricks.keys()))
	check(tipped, "a trick turns the child over")
	check(swapped, "the chase changes hands when someone is caught")
	check(worst_blocked == 0, "nobody plays in a wall, a gate or a doorway (%d ticks)" % worst_blocked)
	check(worst_far <= KidPlay.ARENA + 1.0, "they stay on their ground (%.1f m from where they began)" % worst_far)
	check(closest > 0.3, "the two never stand inside each other (%.2f m)" % closest)

	# The hero stands close by: nobody runs into them.
	_kick_off(lvl, pip, pippi)
	await _wait(3)
	var hero_near := 99.0
	for i in 60 * 20:
		_hero_to(pip.global_position + Vector3(1.4, 0, 0))
		await process_frame
		for c: Villager in [pip, pippi]:
			hero_near = minf(hero_near, _flat(c.global_position, game.player.global_position))
			check(c._kid == null or c._kid.phase != "trick" or not c._kid.active or _flat(c.global_position, game.player.global_position) > 0.9, "no trick right into the hero")
	check(hero_near > 0.5, "nobody runs into the hero (%.2f m)" % hero_near)
	_hero_to(lvl.spots.square[0] + Vector3(20, 0, 0))

	# Words with the hero end the game and leave the child upright.
	_kick_off(lvl, pip, pippi)
	await _wait(60 * 5)
	check(pip._kid.active and pippi._kid.active, "the game is on again")
	pippi.talk(game.player)
	await _wait(4)
	check(not pippi._kid.active and _upright(pippi), "a word with Pippi ends her game and stands her upright")
	await _wait(4)
	check(not pip._kid.active or pip._task != "play", "Pip stops too when his friend does")
	await _wait(2)
	check(_upright(pip) and _upright(pippi), "both stand upright")

	# An alarm ends it at once, mid-trick or not, and none begins during it.
	pippi._bubble_time = 0.0
	pip._bubble_time = 0.0
	_kick_off(lvl, pip, pippi)
	var in_trick := false
	for i in 60 * 40:
		await process_frame
		if pip._kid.tricking():
			in_trick = true
			break
	check(in_trick, "Pip does a trick in time")
	lvl.village_alarm.raised = true
	await _wait(3)
	check(pip._task != "play" and pippi._task != "play", "an alarm ends the game")
	check(_upright(pip) and _upright(pippi), "nobody is left upside down")
	for i in 60 * 6:
		await process_frame
		check(not pip._kid.active and not pippi._kid.active, "no play during an alarm")
	lvl.village_alarm.raised = false

	# Night: nobody plays, they go home.
	pip._start("idle", 5.0)
	pippi._start("idle", 5.0)
	pip._kid = null
	pippi._kid = null
	lvl.set_hour(23.0)
	game.day_hour = 23.0
	await _wait(60 * 40)
	check(pip.at_home and pippi.at_home, "the children go to bed at night")
	check(not KidPlay.can_join(pip) and not KidPlay.can_join(pippi), "nobody joins a game at night")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: kid_play" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
