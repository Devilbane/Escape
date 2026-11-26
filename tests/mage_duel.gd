extends SceneTree
## Headless test for the mages' practice duel (see MageDuel): Odo walks over to Aldo
## and the two trade a whole show of harmless spells and lines, near the hero and by
## day only; every line has an English text; the hero talking to one of them, an alarm
## or the night ends it and sends both back to their day; nobody is hurt.
## Run with: godot --headless -s tests/mage_duel.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	print("PASS: mage duel" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _mages() -> Array:
	return [MageDuel.mage(game.level, MageDuel.ALDO), MageDuel.mage(game.level, MageDuel.ODO)]


func _load_village() -> void:
	game.hero_name = "Testheld Duell"
	game.village_talk.clear()
	game.load_level(game._outdoor_index(), false)
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	game.mage_duel._timer = 1e9


func _calm() -> void:
	for v in game.level.villagers:
		v._start("idle", 600.0)
		v.hush()
	game.level.set_weather(Weather.CLEAR)
	game.level.set_hour(11.0)


func _run(seconds: float, step := 0.1) -> void:
	var t := 0.0
	while t < seconds and game.mage_duel.is_dueling():
		game.mage_duel.update(step, game.level)
		for v in game.level.villagers:
			v._physics_process(step)
			v._update_bubble(step)
		t += step


func _test() -> void:
	# Every line has an English text; the spells have names and colours.
	var pools := [MageDuel.EXCUSES, MageDuel.MISS_EXCUSES, MageDuel.TEACH, MageDuel.PROMISES, MageDuel.PRAISE,
		MageDuel.TRIUMPH, MageDuel.DODGED, MageDuel.DODGE_CHEER, MageDuel.OUCH]
	for pair in MageDuel.OPENERS + MageDuel.CLOSERS:
		pools.append(pair)
	for pool in WEATHER_KEYS():
		pools.append(MageDuel.WEATHER_EXCUSES[pool])
	for pool in pools:
		for line in pool:
			check(Lang.EN.has(line), "English text for: " + line)
	for kind in DuelSpells.KINDS:
		check(DuelSpells.NAMES.has(kind) and Lang.EN.has(DuelSpells.NAMES[kind]) and DuelSpells.COLOURS.has(kind), "spell " + kind)
	_load_village()
	check(game.level is Outdoor, "the village is loaded")
	if not game.level is Outdoor:
		return
	var aldo: Villager = _mages()[0]
	var odo: Villager = _mages()[1]
	check(aldo != null and odo != null, "Aldo and Odo live in the village")
	if aldo == null or odo == null:
		return
	_calm()
	var duel: MageDuel = game.mage_duel
	# Far from the hero nothing starts; by night nothing starts.
	game.player.global_position = aldo.global_position + Vector3(80, 0, 0)
	check(not duel.start(game.level), "no duel with the hero far away")
	var square: Array = MageDuel.duel_ground(game.level)
	game.player.global_position = (square[0] + square[1]) * 0.5 + Vector3(6, 0, -10)
	game.level.set_hour(23.0)
	check(not duel.start(game.level), "no duel by night")
	game.level.set_hour(11.0)
	# By day near the hero it starts, and plays to the end.
	check(duel.start(game.level), "the duel starts by day near the hero")
	check(aldo.chat_partner == odo and odo.chat_partner == aldo, "they are partners")
	# They hold it on the square between the crafting benches and the apple trees by the fountain.
	var ground := MageDuel.duel_ground(game.level)
	check(ground.size() == 2, "the village has a duel ground")
	if ground.size() == 2:
		var bench_x := -INF
		for st in game.level.stations:
			if st.kind == MageDuel.BENCH_KIND:
				bench_x = maxf(bench_x, st.pos.x)
		var tree_x := INF
		for tr in game.level.square_trees:
			if not tr.has("garden") and not tr.has("pocket"):
				tree_x = minf(tree_x, (tr.node as Node3D).global_position.x)
		for spot in ground:
			check(spot.x > bench_x + 3.0 and spot.x < tree_x - 3.0, "a duellist's place lies between the benches and the trees (x %.1f, benches %.1f, trees %.1f)" % [spot.x, bench_x, tree_x])
		check(VillageTalk._flat(ground[0], ground[1]) >= MageDuel.MIN_APART, "and they stand apart")
	var hp: int = game.player.hp
	var lines := {}
	var casts := 0
	var t := 0.0
	while duel.is_dueling() and t < 400.0:
		duel.update(0.1, game.level)
		for v in game.level.villagers:
			v._physics_process(0.1)
			v._update_bubble(0.1)
		for v in [aldo, odo]:
			if v.is_talking():
				lines[v.display_name + v._bubble.text] = true
		t += 0.1
		if t > 16 and t < 25:
			print("t=%.0f odo task=%s retry=%s path=%d dist=%.1f in_place=%s/%s partner=%s broke=%s/%s" % [t, odo._task, odo._retry, odo._path.size(), aldo.global_position.distance_to(odo.global_position), aldo.in_chat_place(), odo.in_chat_place(), aldo.chat_partner != null, aldo.chat_broken, odo.chat_broken])
	check(not duel.is_dueling(), "the duel ends by itself (%.0f s)" % t)
	print("duel took %.0f s, %d lines" % [t, lines.size()])
	check(lines.size() >= 8, "a good many different lines were said (%d)" % lines.size())
	check(aldo.chat_partner == null and odo.chat_partner == null, "both are back to their day")
	check(game.player.hp == hp, "nobody is hurt")
	# The hero talking to Odo breaks it off.
	_calm()
	check(duel.start(game.level), "a second duel starts")
	_run(15.0)
	odo.say("Hallo!")
	duel.update(0.1, game.level)
	check(not duel.is_dueling(), "talking to a mage ends the duel")
	# An alarm ends it too.
	_calm()
	check(duel.start(game.level), "a third duel starts")
	_run(10.0)
	game.level.village_alarm.raised = true
	duel.update(0.1, game.level)
	check(not duel.is_dueling(), "an alarm ends the duel")
	game.level.village_alarm.raised = false


func WEATHER_KEYS() -> Array:
	return MageDuel.WEATHER_EXCUSES.keys()
