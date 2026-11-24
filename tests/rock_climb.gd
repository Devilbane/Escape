extends SceneTree
## Headless test: climbing the mountain rock (see ClimbSpots, RockClimb, Player._try_climb_rock).
## The rules (three pull-ups to the first safe spot, two to each next one, a fall only to the last safe
## spot), and in the game: pushing against ANY rock gives only "too steep" until a spot is climbed with
## enough skill, so a spot cannot be told from plain rock; a climb with a good roll ends on the terrace,
## a bad roll drops the hero to the ground (no safe spot yet) or to the nail.
## Run with: godot --headless --fixed-fps 60 -s tests/rock_climb.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var told: Array[String] = []


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


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _rules() -> void:
	var c := RockClimb.new(5.4, 8, 8)
	var ok_roll := 0.0
	check(c.pull(ok_roll, true) == RockClimb.Result.UP and c.pull(ok_roll, true) == RockClimb.Result.UP, "two pull-ups are not yet a safe spot")
	check(c.pull(ok_roll, true) == RockClimb.Result.PITON, "the third pull-up in a row asks for the first safe spot")
	c.set_nail()
	check(is_equal_approx(c.safe, 3 * RockClimb.PULL), "the safe spot is where the hero hangs")
	check(c.pull(ok_roll, true) == RockClimb.Result.UP, "one pull-up after a safe spot is not another yet")
	check(c.pull(0.999, true) == RockClimb.Result.FELL and is_equal_approx(c.metres, c.safe), "a fall drops only to the last safe spot")
	check(c.streak == 0, "after a fall the pull-ups in a row start again")
	check(c.pull(ok_roll, true) == RockClimb.Result.UP and c.pull(ok_roll, true) == RockClimb.Result.PITON, "two pull-ups after the safe spot give the next one")
	var d := RockClimb.new(5.4, 8, 8)
	for i in 3:
		d.pull(ok_roll, true)
	d.set_nail()
	d.pull(ok_roll, true)
	d.pull(ok_roll, true)
	d.set_nail()
	d.pull(ok_roll, true)
	check(d.pull(ok_roll, true) == RockClimb.Result.TOP, "the top ends the climb")
	var e := RockClimb.new(5.4, 8, 8)
	e.pull(ok_roll, true)
	e.pull(0.999, true)
	check(e.metres == 0.0, "without a safe spot a fall drops to the ground")
	check(RockClimb.new(5.4, 8, 20).chance() > RockClimb.new(5.4, 8, 8).chance(), "skill makes a pull-up safer")
	check(RockClimb.new(5.4, 12, 12).chance() < RockClimb.new(5.4, 8, 12).chance(), "a harder spot is less safe")
	for s: Dictionary in ClimbSpots.SPOTS["Die Freiheit"]:
		check(Climbing.can_climb(float(s.height), int(s.level)), "the skill a spot asks for can climb its height")


## Walks the hero up to the rock at `cell` (from the south) and pushes north for `seconds`.
func _push(hero: Player, lvl: Level, cell: Vector2i, seconds: float) -> void:
	var mid := lvl.cell_to_world(cell)
	hero.global_position = Vector3(mid.x, 0.0, mid.z + Level.TILE * 0.5 + 2.0)
	hero.reset_physics_interpolation()
	await _wait(10)
	Input.action_press("ui_up")
	var left := int(seconds * 60.0)
	while left > 0 and not hero.is_climbing():
		await _wait(1)
		left -= 1
	Input.action_release("ui_up")


func _run() -> void:
	_rules()
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Climb test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	game.state = game.State.PLAYING
	var lvl: Level = game.level
	var hero: Player = game.player
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float) -> void: told.append(text))
	# Nobody in the way: the wolves of the hollow would kill the hero while he is pushing and climbing.
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	hero.global_position = Vector3(0, 0, 0)
	var spot: Dictionary = ClimbSpots.SPOTS["Die Freiheit"][0]
	var other := Vector2i(119, 23)
	check(lvl.cell_char(spot.cell) == "=" and lvl.cell_char(spot.cell + Vector2i(0, 1)) != "=", "the spot is rock with open ground south of it")
	for s: Dictionary in ClimbSpots.SPOTS["Die Freiheit"]:
		check(lvl.cell_char(s.cell) == "=" and not "#=".contains(lvl.cell_char(s.cell + Vector2i(0, 1))), "spot %s has open ground in front" % s.cell)

	# A plain rock face: the message, no climb.
	hero.companion_perks = {"skills": {"klettern": 30}}
	hero.bag.append_array(["kletterhammer", "kletterseil", "kletterhaken", "kletterhaken", "kletterhaken", "kletterhaken"])
	told.clear()
	await _push(hero, lvl, other, 3.2)
	check(not hero.is_climbing(), "plain rock cannot be climbed")
	check(told.has(Lang.t(ClimbSpots.TOO_STEEP)), "plain rock says it is too steep (got %s)" % [told])

	# A real spot with too little skill: the same message and the same timing, no climb.
	hero.companion_perks = {"skills": {}}
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	check(not hero.is_climbing(), "too little skill: no climb")
	check(told == [Lang.t(ClimbSpots.TOO_STEEP)], "too little skill says only that it is too steep (got %s)" % [told])

	# With the skill: the climb starts after the same hold, and a good roll ends on the terrace.
	hero.companion_perks = {"skills": {"klettern": 30}}
	hero.rock_roll_forced = 0.0
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	check(hero.is_climbing(), "enough skill: the climb begins")
	check(not told.has(Lang.t(ClimbSpots.TOO_STEEP)), "a climb begins without the too-steep message")
	var guard := 0
	while hero.is_climbing() and guard < 3000:
		await _wait(1)
		guard += 1
	check(not hero.is_climbing(), "the climb ends")
	check(absf(hero.global_position.y - float(spot.height)) < 0.2, "the hero stands on the terrace (y %.2f)" % hero.global_position.y)
	check(hero.bag.count("kletterhaken") == 3, "one safe spot took one nail (%d left)" % hero.bag.count("kletterhaken"))
	await _wait(20)
	check(absf(hero.global_position.y - float(spot.height)) < 0.2, "the hero stays up on the terrace (y %.2f)" % hero.global_position.y)
	# Stepping off the terrace comes down to the ground.
	Input.action_press("ui_down")
	await _wait(120)
	Input.action_release("ui_down")
	await _wait(30)
	check(hero.global_position.y < 0.3, "stepping off comes down to the ground (y %.2f)" % hero.global_position.y)

	# A slip with no safe spot yet: back on the ground with a few life points less.
	hero.rock_roll_forced = 0.999
	var hp_before := hero.hp
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	guard = 0
	while hero.is_climbing() and guard < 3000:
		await _wait(1)
		guard += 1
	check(hero.global_position.y < 0.3, "a first slip falls to the ground (y %.2f)" % hero.global_position.y)
	check(hero.hp <= hp_before, "a fall does not heal")
	check(hero.hp >= 1, "a fall never kills")
	game.delete_save(game.save_path())
	print("PASS: rock climbing" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
