extends SceneTree
## Headless test for play in the snow (see KidPlay, Snowball, Snowman): when the snow lies thick,
## Pip and Pippi build one snowman, throw snowballs at each other (and sometimes at a grown-up
## close by, who grumbles), run round their snowman, and never play in a wall. The snowman melts
## with the snow.
## Run with: godot --headless --fixed-fps 60 -s tests/snow_play.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(12)
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
	game.day_hour = 13.0
	game.set_weather(Weather.CLEAR, 8.0)
	game.snow_cover = 0.0
	game.load_level(game._outdoor_index(), false)
	await _wait()
	var lvl: Outdoor = game.level
	lvl.set_hour(13.0)
	lvl._herald_timer = 1.0e9
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
	game.player.global_position = lvl.spots.square[0] + Vector3(20, 0, 0)
	game.player.reset_physics_interpolation()

	# No snow: no snowman, the usual chase.
	check(not KidPlay.snowy(pip), "no snow play on bare ground")
	check(Snowman.ensure(lvl, pip.global_position) == null, "no snowman without snow")
	_kick_off(lvl, pip, pippi)
	await _wait(3)
	check(pip._kid.phase == "run", "on bare ground they chase each other")

	# Thick snow: a snowball fight round one snowman.
	game.snow_cover = 1.0
	await _wait(2)
	check(KidPlay.snowy(pip), "the snow is thick enough to play in")
	_kick_off(lvl, pip, pippi)
	await _wait(3)
	check(pip._task == "play" and pippi._task == "play", "both children play in the snow")
	check(pip._kid.phase == "ball" and pippi._kid.phase == "ball", "they start a snowball fight")
	check(lvl.snowman != null and is_instance_valid(lvl.snowman), "they built a snowman")
	var man: Snowman = lvl.snowman
	check(lvl.find_children("*", "Snowman", true, false).size() == 1, "there is only one snowman")
	var balls := 0
	var rounds := false
	var worst_blocked := 0
	var seen := {}
	for i in 60 * 50:
		await process_frame
		for b: Snowball in lvl.find_children("*", "Snowball", false, false):
			if not seen.has(b.get_instance_id()):
				seen[b.get_instance_id()] = true
				balls += 1
		for c: Villager in [pip, pippi]:
			if c._task == "play" and c._kid != null and c._kid.active:
				if c._kid.phase == "round":
					rounds = true
				var cell := lvl.world_to_cell(c.global_position)
				if Outdoor.BLOCK_CHARS.contains(lvl.cell_char(cell)) or c.blocked_at(c.global_position):
					worst_blocked += 1
		if pip._task != "play" and pippi._task != "play":
			_kick_off(lvl, pip, pippi)
	check(balls >= 4, "snowballs fly (%d)" % balls)
	check(rounds, "they run round their snowman")
	check(worst_blocked == 0, "nobody plays in a wall (%d ticks)" % worst_blocked)
	check(lvl.snowman == man, "the same snowman stays")
	_kick_off(lvl, pip, pippi)
	await _wait(3)
	check(lvl.find_children("*", "Snowman", true, false).size() == 1, "a new game builds no second snowman")

	# A grown-up hit by a snowball grumbles.
	var grown: Villager = null
	for v: Villager in lvl.villagers:
		if v._info.get("pal", "") == "" and v.visible and not v.at_home and v.chat_partner == null:
			grown = v
			break
	check(grown != null, "a grown-up is out")
	if grown != null:
		grown._bubble_time = 0.0
		var ball := Snowball.throw(lvl, grown.global_position + Vector3(3, 1.2, 0), grown, pip)
		for i in 90:
			await process_frame
		check(not is_instance_valid(ball), "the ball bursts where it lands")
		check(grown._bubble_time > 0.0, "the grown-up who is hit grumbles")

	# The snowman melts with the snow, and is gone with the last of it.
	game.snow_cover = 0.3
	await _wait(2)
	check(is_instance_valid(man) and man.scale.x < 1.0, "the snowman shrinks as the snow melts")
	game.snow_cover = 0.05
	await _wait(2)
	check(not is_instance_valid(man) and lvl.snowman == null, "the snowman is gone with the snow")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: snow play")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
