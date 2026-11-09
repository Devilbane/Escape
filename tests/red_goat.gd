extends SceneTree
## Headless test for the village's red-horned goat (see FarmAnimal, kind "billy"):
## there is exactly one, it shows a wind-up and shouts before it charges, a bump
## shoves the hero without harm, the third bump sends it off to sulk for ten
## minutes, and it cannot be hurt.
## Run with: godot --headless --fixed-fps 60 -s tests/red_goat.gd

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


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


## Waits up to `limit` frames until `done` holds.
func _until(done: Callable, limit := 600) -> bool:
	for i in limit:
		if done.call():
			return true
		await process_frame
	return done.call()


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: red_goat" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The hero stands `gap` metres from the goat, on a side with a clear way between them.
func _hero_near(lvl: Outdoor, goat: FarmAnimal, gap: float) -> void:
	for ang in range(0, 360, 45):
		var p := goat.global_position + Vector3(gap, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
		var clear := true
		for k in range(1, 13):
			clear = clear and lvl.is_open(lvl.world_to_cell(goat.global_position.lerp(p, k / 12.0)))
		if clear:
			game.player.global_position = p
			game.player.velocity = Vector3.ZERO
			return


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait()
	var lvl: Outdoor = game.level
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	var billies := lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind == "billy")
	check(billies.size() == 1, "one red-horned goat (%d)" % billies.size())
	if billies.is_empty():
		_finish()
		return
	var goat: FarmAnimal = billies[0]
	check(not goat.has_method("take_hit") and not goat.has_method("take_damage"), "it cannot be hurt")
	check(FarmAnimal.BUMPS == 3 and FarmAnimal.COOLDOWN == 600.0, "three bumps, ten minutes")
	check(Lang.EN.has(FarmAnimal.CRY) and Lang.EN.has("Rothorn-Ziege"), "its texts have English entries")
	var hp: int = game.player.hp
	var team := lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind == "goat")
	check(team.size() == 4, "the four ordinary goats are still there (%d)" % team.size())

	for round in 3:
		goat._begin("idle", 30.0)
		goat._charge_wait = 0.01
		goat.global_position = goat.global_position
		_hero_near(lvl, goat, 6.0)
		var wound_up: bool = await _until(func(): return goat.state == "windup", 120)
		check(wound_up, "round %d: it winds up first" % round)
		check(goat._bubble.is_shown(), "round %d: it shouts" % round)
		var before: Vector3 = game.player.global_position
		var bumped: bool = await _until(func(): return goat.bumps > round or goat.cooldown > 0.0, 400)
		check(bumped, "round %d: it bumps the hero" % round)
		check(game.player.hp == hp, "round %d: the bump does no harm" % round)
		await _wait(10)
		check(game.player.global_position.distance_to(before) > 0.5, "round %d: the hero is shoved" % round)
	check(goat.cooldown > 590.0, "after three bumps it sulks (%.0f s)" % goat.cooldown)
	check(goat.bumps == 0, "the bump count starts over")

	# While it sulks, it leaves the hero alone, however close.
	_hero_near(lvl, goat, 4.0)
	await _wait(60 * 15)
	check(goat.state not in ["windup", "charge"], "no charge on cooldown (%s)" % goat.state)
	check(goat.cooldown < 590.0 and goat.cooldown > 0.0, "the cooldown runs (%.0f s)" % goat.cooldown)

	# When it is over, it may charge again.
	goat.cooldown = 0.05
	goat._begin("idle", 30.0)
	_hero_near(lvl, goat, 6.0)
	var again: bool = await _until(func(): return goat.state == "windup", 900)
	check(again, "it charges again after the cooldown")
	check(game.player.hp == hp, "the hero never lost life")
	_finish()
