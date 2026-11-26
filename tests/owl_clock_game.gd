extends SceneTree
## Headless test of the Deathringer in the game (see OwlClock): rung at the right grave in the right
## pattern it opens the crypt (once, for good, and the counter stone counts it); rung three times in a row
## anywhere else it wakes Death, stronger at a fuller moon, and then rests until the next night; after
## CALLS_REWARDED calls Death pays nothing. The pattern and the grave are asked from OwlClock, never
## written here.
## Run with: godot --headless -s tests/owl_clock_game.gd

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
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: owl clock game" if failures == 0 else "FAILED: " + str(failures))
	quit(1 if failures > 0 else 0)
	return true


## Rings the bell in groups of the given sizes: quick rings within a group, a pause between groups.
func _ring_groups(groups: Array, start: float) -> float:
	var t := start
	for g: int in groups:
		for i in g:
			game.owl_clock.ring(t)
			t += 0.9
		t += OwlClock.SPLIT + 0.5
	return t


func _enemies(kind: String) -> Array:
	return game.level.enemies.filter(func(e): return is_instance_valid(e) and e.kind == kind and not e.dead)


func _test() -> void:
	game.hero_name = "Owl clock test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	check(lvl is Outdoor and lvl.owlav_pos != Vector3.INF, "the graveyard has Owlav's grave")
	check(lvl.owls.clock_owl >= 0, "the dead tree has its clock owl")
	var readers := lvl.stations.filter(func(s): return s.kind == GraveLore.KIND)
	check(readers.size() == 22, "every grave can be read (%d)" % readers.size())
	check(readers.filter(func(s): return s.get("counter", false)).size() == 1, "one counter stone")
	check(lvl.stations.filter(func(s): return s.get("building", "") == OwlClock.ID).is_empty(), "no way down before the riddle")
	game.player.bag.append(OwlClock.BELL)
	# Wrong places and wrong patterns first.
	game.player.global_position = lvl.owlav_pos + Vector3(0, 0, 3.0)
	var t := _ring_groups(Array(OwlClock.pattern()).slice(1), 100.0)
	game.owl_clock._end_attempt(game.owl_clock._attempt)
	check(game.treasure_maps.state.get(OwlClock.ID, "") == "", "a wrong pattern opens nothing")
	check(_enemies(OwlClock.DEATH_KIND).is_empty(), "the grave never calls Death")
	t = _ring_groups(Array(OwlClock.pattern()), t + 10.0)
	game.owl_clock._end_attempt(game.owl_clock._attempt)
	check(game.treasure_maps.state.get(OwlClock.ID, "") == TreasureMaps.OPEN, "the right pattern opens the crypt")
	check(game.riddles.count() == 1 and game.riddles.solved.has(RiddleCount.OWL_CLOCK), "the counter counts it")
	check(not lvl.stations.filter(func(s): return s.get("building", "") == OwlClock.ID).is_empty() or not game.interiors.has(OwlClock.ID), "the way down stands (when the map is loaded)")
	check(game.interiors.has(OwlClock.ID), "the crypt's map is found by its building id")
	# Away from the grave: two rings are nothing, three wake Death.
	game.player.global_position = lvl.cell_to_world(lvl.start_cell)
	game.day = 3
	t += 20.0
	game.owl_clock.ring(t)
	game.owl_clock.ring(t + 0.9)
	check(_enemies(OwlClock.DEATH_KIND).is_empty(), "two rings wake nobody")
	game.owl_clock.ring(t + 1.8)
	var death := _enemies(OwlClock.DEATH_KIND)
	check(death.size() == 1 and game.owl_clock.calls == 1, "three in a row wake Death")
	check(not death.is_empty() and not death[0].no_reward, "the first call pays")
	var strong_life: int = death[0].max_hp() if not death.is_empty() else 0
	# Rest: the same night, nothing more.
	for e in death:
		e.queue_free()
	t += 10.0
	for i in 3:
		game.owl_clock.ring(t + i * 0.9)
	check(game.owl_clock.calls == 1 and _enemies(OwlClock.DEATH_KIND).filter(func(e): return not e.is_queued_for_deletion()).is_empty(), "the bell rests until the next night")
	# The fuller the moon, the stronger Death.
	var lives := {}
	for day in Moon.CYCLE:
		game.day = 10 + day
		game.owl_clock.rest_until = 0
		game.owl_clock.calls = 0
		t += 10.0
		for i in 3:
			game.owl_clock.ring(t + i * 0.9)
		var d := _enemies(OwlClock.DEATH_KIND)
		lives[Moon.phase(game.day)] = d[d.size() - 1].max_hp() if not d.is_empty() else 0
	check(int(lives[Moon.FULL]) > int(lives[Moon.NEW]), "Death is stronger at the full moon (%s)" % [lives])
	# After the third call Death pays nothing.
	game.owl_clock.calls = OwlClock.CALLS_REWARDED
	game.owl_clock.rest_until = 0
	game.day = 40
	t += 10.0
	for i in 3:
		game.owl_clock.ring(t + i * 0.9)
	var last := _enemies(OwlClock.DEATH_KIND)
	check(not last.is_empty() and last[last.size() - 1].no_reward, "later calls pay nothing")
	# Save and load.
	game.owl_clock.calls = 5
	var saved: Dictionary = game.owl_clock.for_save()
	game.owl_clock.clear()
	game.owl_clock.load_from(saved)
	check(game.owl_clock.calls == 5, "the bell's calls are saved")
