extends SceneTree
## Headless test for the day and night above ground: the clock runs in the
## open and stands still in the dungeon, the sky follows the hour with the
## old daylight as the daytime look, lanterns and windows glow at night,
## most villagers go home to sleep, the dead rise on the graveyard and sink
## back at dawn, bandits are tougher at night, a night in the bed skips to
## the morning, and the hour is kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/day_night.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var risen: Array = []
const HERO := "Day night test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: day and night")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _lamp_energy() -> float:
	return game.level._lamps[0].light_energy if not game.level._lamps.is_empty() else -1.0


func _window_glow() -> float:
	for mat in game.level._window_mats.values():
		return mat.emission_energy_multiplier
	return -1.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if frames > 60 * 60:
		check(false, "the test finished in time (stage %d)" % stage)
		_finish()
		return true
	if wait > 0:
		wait -= 1
		return false
	match stage:
		0:
			_by_day()
			stage = 1
		1:
			_load_at_night()
			wait = 30
			stage = 2
		2:
			_at_night()
			stage = 3
		3:
			# Dawn: the dead go back, the village wakes up.
			game.day_hour = 7.0
			for s in game.level._risen:
				if s.enemy != null:
					risen.append(s.enemy)
			# Far from the graveyard, so any skeleton on the hunt gives up.
			game.player.global_position = _villager("0").global_position + Vector3(2, 0, 2)
			wait = 2
			stage = 4
		4:
			_at_dawn()
			wait = 480
			stage = 5
		5:
			for e in risen:
				check(not is_instance_valid(e) or e.dead, "a risen skeleton has sunk into its grave by day")
			for v in game.level.villagers:
				check(v.visible and not v.at_home, "%s is out and about in the morning" % v.display_name)
			_clock_and_saving()
			_finish()
			return true
	return false


func _by_day() -> void:
	game.hero_name = HERO
	game.day_hour = 12.0
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the open air is an outdoor level")
	check(not game.level.night, "noon is not night")
	# The toned-down open-air look stays the daylight.
	check(is_equal_approx(game._env.ambient_light_energy, 0.52), "daylight keeps the ambient light of the old look")
	check(is_equal_approx(game._moon.light_energy, 0.88), "daylight keeps the sun of the old look")
	check(game._env.background_color.is_equal_approx(Color(0.5, 0.46, 0.57)), "daylight keeps the sky colour of the old look")
	check(not game.level._lamps.is_empty(), "the village has lanterns")
	check(not game.level._window_mats.is_empty(), "the houses have windows that can glow")
	check(is_equal_approx(_window_glow(), 0.0), "windows are dark by day")
	check(_lamp_energy() < 1.0, "lanterns are dim by day")
	for v in game.level.villagers:
		check(v.visible and not v.at_home, "%s is about by day" % v.display_name)
	check(game.level.risen_alive() == 0 and game.level._risen.is_empty(), "no dead walk by day")
	check(game.level.is_lit(Vector3(-500, 0, -500)), "by day everything is lit")
	check(game._level_label.text.contains("12:00"), "the HUD shows the time of day")


func _load_at_night() -> void:
	game.day_hour = 23.0
	game.load_level(game._outdoor_index(), false)
	check(game.level.night, "23:00 is night")
	check(game._env.ambient_light_energy < 0.4, "the night is darker than the day")
	check(game._env.background_color.v < 0.2, "the night sky is dark")
	check(_lamp_energy() > 2.5, "lanterns burn bright at night")
	check(_window_glow() > 1.0, "windows glow at night")
	# Only the panes may shine: a textured window mask must multiply the
	# glow colour, never add to it, or the whole building turns white.
	for mat: StandardMaterial3D in game.level._window_mats.values():
		if mat.emission_texture:
			check(mat.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "only the window panes glow, not the whole building")
	for v in game.level.villagers:
		if v.goes_to_bed():
			check(v.at_home and not v.visible, "%s is asleep at home in a game loaded at night" % v.display_name)
			check(v.station.used, "nobody trades with %s at night" % v.display_name)
		else:
			check(v.visible and not v.at_home, "%s stays up at night" % v.display_name)
	check(_villager("4") != null and _villager("4").visible, "the guard keeps watch at night")
	check(not game.level._risen.is_empty(), "the dead get their spots at nightfall")
	check(not game.level.is_lit(Vector3(-500, 0, -500)), "away from the lanterns the night is dark")
	check(game.level.is_lit(game.level._lamps[0].global_position), "a lantern lights its spot at night")
	var bandits := 0
	for e in game.level.enemies:
		if is_instance_valid(e) and e.is_human():
			bandits += 1
			check(e.night, "a bandit out at night is a night bandit")
			check(e.hp == e._stats.hp and e.hp >= Enemy.KINDS[e.kind].hp + 2, "a night bandit has more life")
	check(bandits > 0, "bandits roam the pass at night")


func _at_night() -> void:
	risen.clear()
	for s in game.level._risen:
		if s.enemy != null:
			risen.append(s.enemy)
	check(risen.size() > 0, "the dead have risen on the graveyard")
	for e in risen:
		check(not e.is_human() and e.night and e._stats.get("roam", false), "a risen skeleton roams the graveyard")
	for s in game.level._risen:
		var start: Vector3 = game.level.cell_to_world(game.level.start_cell)
		check(game.level._flat_distance(game.level.cell_to_world(s.cell), start) > Outdoor.NIGHT_DEAD_FAR, "the dead never rise right next to the hero")
	# Nightfall on the street: a villager walks home instead of vanishing.
	game.day_hour = 12.0
	game.level.set_hour(12.0)
	var mira := _villager("6")
	check(mira != null and mira.visible and not mira.at_home, "the shopkeeper is back by day")
	# Back at her stall first: she woke up at the door she went in by.
	mira.global_position = game.level.cell_to_world(mira.home)
	game.level.set_hour(22.0)
	check(mira.visible and mira._task == "walk", "at nightfall the shopkeeper walks home")
	game.level.set_hour(23.0)
	game.day_hour = 23.0


func _at_dawn() -> void:
	check(not game.level.night, "07:00 is day")
	check(game.level._risen.is_empty(), "the dead lose their spots at dawn")
	for e in risen:
		check(not is_instance_valid(e) or e.dead or e._dawn, "a risen skeleton heads back to its grave at dawn")


func _clock_and_saving() -> void:
	# The clock runs above ground while playing: 20 real minutes a day.
	var before_state = game.state
	game.state = game.State.PLAYING
	game.day_hour = 10.0
	game._tick_clock(60.0)
	check(is_equal_approx(game.day_hour, 10.0 + 24.0 / 20.0), "one real minute is 1.2 hours of the day")
	game.day_hour = 23.9
	game._tick_clock(30.0)
	check(game.day_hour < 1.0, "the clock goes round past midnight")
	# Down in the dungeon time stands still.
	game.load_level(0, false)
	game.day_hour = 15.0
	game._tick_clock(120.0)
	check(is_equal_approx(game.day_hour, 15.0), "time stands still in the dungeon")
	game.state = before_state

	# The hour goes into the saved game and comes back from it.
	game.day_hour = 22.5
	check(game.save_game(), "the game is saved")
	var data: Dictionary = game._read_save(game.save_path())
	check(is_equal_approx(float(data.get("hour", -1.0)), 22.5), "the saved game holds the hour")
	game.day_hour = 3.0
	game._apply_save(data)
	check(is_equal_approx(game.day_hour, 22.5), "loading brings the hour back")
	data.erase("hour")
	game._apply_save(data)
	check(is_equal_approx(game.day_hour, DayNight.START_HOUR), "an older saved game starts in the morning")

	# A night in the bed skips to the morning.
	game.load_level(game._outdoor_index(), false)
	game.day_hour = 23.5
	game.sleep()
	check(is_equal_approx(game.day_hour, DayNight.WAKE_HOUR), "sleeping in the bed skips to the morning")
	data = game._read_save(game.save_path())
	check(is_equal_approx(float(data.get("hour", -1.0)), DayNight.WAKE_HOUR), "the hero wakes up in the morning after loading")

	# The sky blends smoothly and the parts of the day have names.
	check(DayNight.is_night(0.0) and DayNight.is_night(22.0) and not DayNight.is_night(12.0) and not DayNight.is_night(6.0), "night is from 21:00 to 05:00")
	check(DayNight.clock_text(13.6) == "13:30", "the clock shows quarter hours")
	var dusk: Dictionary = DayNight.sky_at(19.0)
	check(dusk.amb_e < 0.52 and dusk.amb_e > 0.3, "dusk is between day and night")
