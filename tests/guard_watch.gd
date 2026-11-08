extends SceneTree
## Headless test for the town guard's watch on the west gate (see GuardWatch):
## - the west gate is the western one of the two gates;
## - the guard goes to it far more often at night, in rain and storm and on wet
##   ground than on a calm, dry day;
## - at the gate he calls out a slime in sight once, and the gate shuts;
## - the guard's rounds really lead to the west gate at night.
## Run with: godot --headless --fixed-fps 60 -s tests/guard_watch.gd

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


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: guard watch" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game.hero_name = "Guard test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	for v in lvl.villagers:
		v._fire_cool = 1.0e9
	var guard: Villager = null
	for v in lvl.villagers:
		if v.role == "4":
			guard = v
	check(guard != null, "the village has a guard")

	var west := GuardWatch.west_gate(lvl)
	check(west != null and west == wall.brick_at(Vector2i(37, 27)), "the west gate is the western one")
	for g in wall.gates:
		check(g.global_position.x >= west.global_position.x, "no gate lies west of the west gate")

	# How often he goes: calm and dry, then night, rain, storm and wet ground.
	lvl.night = false
	lvl.weather = Weather.CLEAR
	lvl.puddles.water = 0.0
	var calm := GuardWatch.chance(lvl)
	check(calm == GuardWatch.CHANCE_CALM and not GuardWatch.watchful(lvl), "a dry, calm day is not watchful")
	lvl.night = true
	check(GuardWatch.chance(lvl) > calm * 3.0, "he goes to the gate much more often at night")
	lvl.night = false
	lvl.weather = Weather.RAIN
	check(GuardWatch.watchful(lvl), "he is watchful in rain")
	lvl.weather = Weather.STORM
	check(GuardWatch.watchful(lvl), "he is watchful in a storm")
	lvl.weather = Weather.CLEAR
	lvl.puddles.water = 0.5
	check(GuardWatch.watchful(lvl), "he is watchful while the puddles lie after the rain")
	lvl.puddles.water = 0.0
	check(GuardWatch.goes_to_gate(lvl, 0.5) == false, "a calm day rarely sends him to the gate")
	lvl.night = true
	check(GuardWatch.goes_to_gate(lvl, 0.5), "a night sends him to the gate")

	# His round leads there at night: every leg of it he picks (rolls are random).
	for v in lvl.villagers:
		if v != guard:
			v.global_position = lvl.spots.square[0]
			v._start("idle", 600.0)
	var visits := 0
	for i in 20:
		guard.global_position = lvl.spots.square[0]
		guard._start("idle", 0.0)
		guard._next_task()
		if guard._task == "walk" and guard.get_meta("then", "") == "watch":
			visits += 1
	check(visits >= 10, "at night most legs of his round lead to the west gate, got %d of 20" % visits)

	# At the gate, in sight of a slime: he calls out once and the gate shuts.
	var spot := GuardWatch.post(lvl)
	guard.global_position = spot
	guard._start("watch", 30.0)
	guard.say("")
	var slime := lvl.spawn_slime("schleim", west.global_position + Vector3(-12, 0, 0), {})
	slime.set_physics_process(false)
	var news := []
	var on_news := func(text, _colour, _time): news.append(text)
	Events.bus().news_told.connect(on_news)
	await _wait(5)
	check(GuardWatch.slime_in_sight(lvl) == slime, "he sees the slime outside the west gate")
	check(guard._watch_pause > 0.0, "he called out the slime")
	check(news.count(Lang.t(GuardWatch.NEWS)) == 1, "he calls it out once")
	await _wait(120)
	check(news.size() >= 1 and news.count(Lang.t(GuardWatch.NEWS)) == 1, "no second call within the pause")
	check(wall.shut_wanted, "the villagers shut the gate")
	Events.bus().news_told.disconnect(on_news)
	_finish()
