extends SceneTree
## Headless test for the bees of the valley (see Apiary): they fly by day in spring and summer when it is dry, never at
## night, in winter or in the wet; they come out of the hives, land on flowers and go home; the meadow blooms and
## fades with the seasons; a hero who stands at a hive vexes it once, is stung once and is then left alone.
## Run with: godot --headless --fixed-fps 60 -s tests/bees.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _day_of(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


## Runs the apiary's tick for `seconds` of game time, the hero at `hero`.
func _tick(api: Apiary, seconds: float, hero: Vector3, hour: float, day: int, weather := "clear") -> void:
	var t := 0.0
	while t < seconds:
		api.tick(1.0 / 30.0, hero, hour, false, day, weather)
		t += 1.0 / 30.0


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Bee test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for _i in 20:
		await process_frame
	var lvl: Outdoor = game.level
	var api: Apiary = lvl.apiary
	check(api != null, "the apiary stands")
	if api == null:
		quit(1)
		return
	# When bees fly.
	check(Apiary.flying_now(11.0, "summer", "clear") and Apiary.flying_now(9.0, "spring", "fog"), "bees fly on a dry day of spring and summer")
	check(not Apiary.flying_now(22.0, "summer", "clear") and not Apiary.flying_now(5.0, "spring", "clear"), "not at night")
	check(not Apiary.flying_now(11.0, "winter", "clear") and not Apiary.flying_now(11.0, "autumn", "clear"), "not in autumn or winter")
	check(not Apiary.flying_now(11.0, "summer", "rain") and not Apiary.flying_now(11.0, "summer", "storm"), "not in the rain")
	# The hum loops.
	var buzz := Apiary.buzz_stream()
	check(buzz.loop_mode == AudioStreamWAV.LOOP_FORWARD and buzz.get_length() > 0.5, "the buzz is a loop")
	check(buzz.data.size() == buzz.loop_end * 2, "and covers the whole sample")
	var hero := lvl.cell_to_world(lvl.world_to_cell(api.hives[0].pos) + Vector2i(0, 5))
	var summer := _day_of("summer")
	# A summer morning near the hives: bees come out.
	_tick(api, 40.0, hero, 10.0, summer)
	check(api.bees_out() > 0, "bees are out on a summer morning (%d)" % api.bees_out())
	check(api.bees_in("go") + api.bees_in("feed") + api.bees_in("orbit") + api.bees_in("back") == api.bees_out(), "out means circling, flying or feeding")
	check(api.season() == "summer", "the meadow is dressed for summer")
	var fed := 0
	for _i in 6:
		_tick(api, 10.0, hero, 10.0, summer)
		fed += api.bees_in("feed")
	check(fed > 0, "bees sit on flowers now and then")
	# Far away the apiary sleeps.
	_tick(api, 1.0, hero + Vector3(300, 0, 0), 10.0, summer)
	check(not api._bees_root.visible, "far from the hero no bees are drawn")
	# Night, rain and winter: hidden.
	_tick(api, 1.0, hero, 23.0, summer)
	check(not api._bees_root.visible, "at night they are in their hives")
	_tick(api, 1.0, hero, 10.0, summer, "rain")
	check(not api._bees_root.visible, "in the rain too")
	_tick(api, 1.0, hero, 10.0, _day_of("winter"))
	check(not api._bees_root.visible and api.season() == "winter", "and in winter, when the meadow is bare")
	for bed in api._beds:
		check(not (bed.node as Node3D).visible, "the flowers are gone in winter")
		break
	_tick(api, 1.0, hero, 10.0, _day_of("spring"))
	check(api._bees_root.visible and api.season() == "spring", "in spring they are back")
	check((api._beds[0].node as Node3D).visible, "and the flowers bloom")

	# A hero at a hive: vexed once, stung once, left alone.
	_tick(api, 1.0, hero, 10.0, summer)
	var h: Dictionary = api.hives[0]
	var near: Vector3 = h.pos + h.front * 1.3
	game.player.global_position = near
	game.player.hp = game.player.max_hp
	game.player._invulnerable = 0.0
	game.player._down = 0.0
	var hp: int = game.player.hp
	_tick(api, Apiary.VEXED_AFTER + 0.5, near, 10.0, summer)
	check(api.vexed(), "standing at a hive vexes it")
	check(api.bees_in("swarm") >= Apiary.BEES_PER_HIVE, "the bees swarm round the hero")
	_tick(api, Apiary.STING_AFTER + 1.0, near, 10.0, summer)
	check(game.player.hp == hp - Apiary.STING, "one bee stings once (%d -> %d)" % [hp, game.player.hp])
	_tick(api, 5.0, near, 10.0, summer)
	check(game.player.hp == hp - Apiary.STING, "and only once")
	_tick(api, Apiary.ANGRY_TIME, near, 10.0, summer)
	check(not api.vexed(), "the bees calm down")
	_tick(api, Apiary.VEXED_AFTER + 1.0, near, 10.0, summer)
	check(not api.vexed(), "the hive then lets the hero be for a while")
	for _i in 5:
		await process_frame
	print("PASS: bees" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
