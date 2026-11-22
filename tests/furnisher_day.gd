extends SceneTree
## Headless test: the working day of Ilse the furnisher (see FurnisherDay). Her stall is open
## from 8 to 11 and from half past one to 6; outside those hours she strolls about, eats with
## the village and may rest on a bench, and through her hours she keeps to her stall.
## Run with: godot --headless --fixed-fps 60 -s tests/furnisher_day.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	# The hours: open in the morning and the afternoon, shut for the meals, the evening and the night.
	check(not FurnisherDay.is_open(7.0), "shut at 7, before she opens")
	check(FurnisherDay.is_open(9.0) and FurnisherDay.is_open(15.0), "open at 9 and at 15")
	check(not FurnisherDay.is_open(12.0) and not FurnisherDay.is_open(19.0), "shut at lunch and at dinner")
	check(not FurnisherDay.is_open(22.0), "shut at night")
	# The meals gather only while she is shut, so she can come to the table.
	for m: float in TownMeals.MEALS:
		var first := m - TownMeals.WALK_AHEAD - TownMeals.ARRIVE_EARLY
		check(not FurnisherDay.is_open(first) and TownMeals.meal_at(first) >= 0, "shut when the meal at %d gathers" % int(m))

	game.hero_name = "Furnisher day test"
	game.escaped = true
	Villager.morning_spread = 0.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await physics_frame
	var ilse: Villager = null
	for v: Villager in game.level.villagers:
		if v.role == FurnisherDay.ROLE:
			ilse = v
	check(ilse != null, "Ilse is in the village")
	if ilse == null:
		_finish()
		return
	# Off duty she lives like the strollers: she eats with the village and rests on the benches.
	game.day_hour = 7.0
	await physics_frame
	check(ilse.day_plan() == "stroll" and not ilse.keeps_spot(), "at 7 she strolls about and keeps no spot")
	check(TownMeals.goes(ilse) and BenchRest.rests_here(ilse), "off duty she may eat at the tables and rest on a bench")
	check(ilse.comes_to_listen(), "off duty she comes to hear the herald")
	# On duty she keeps her stall like a shopkeeper.
	game.day_hour = 9.0
	await physics_frame
	check(ilse.day_plan() == "stay" and ilse.keeps_spot(), "at 9 she keeps her stall")
	check(not TownMeals.goes(ilse) and not BenchRest.rests_here(ilse), "on duty she neither eats nor rests")
	# Over the morning she walks back to her stall and stays there.
	var home := false
	for i in 2400:
		game.day_hour = 9.0
		await physics_frame
		if game.level.world_to_cell(ilse.global_position) == ilse.home:
			home = true
			break
	check(home, "at 9 she is at her stall")
	var strayed := false
	for i in 1200:
		game.day_hour = 9.5
		await physics_frame
		if game.level.world_to_cell(ilse.global_position) != ilse.home and not game.level.village_alarm.raised:
			strayed = true
	check(not strayed, "through her opening hours she keeps to her stall")
	# Once the stall shuts she leaves it: within a while she is somewhere else.
	var left := false
	for i in 3600:
		game.day_hour = 20.0
		await physics_frame
		if game.level.world_to_cell(ilse.global_position) != ilse.home:
			left = true
			break
	check(left, "in the evening she walks away from her stall")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: furnisher day" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
