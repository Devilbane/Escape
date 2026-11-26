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
	check(c.pull(0.999, true, 0.0) == RockClimb.Result.FELL and is_equal_approx(c.metres, c.safe), "a fall drops only to the last safe spot")
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
	check(e.pull(0.999, true, 0.0) == RockClimb.Result.FELL and e.metres == 0.0, "without a safe spot a fall drops to the ground")
	# A slip: the hands hold and one more try follows at once; the second slip in a row needs a rest.
	var f := RockClimb.new(5.4, 8, 8)
	check(f.pull(0.999, true) == RockClimb.Result.SLIP, "the first slip holds on")
	check(f.pull(0.999, true) == RockClimb.Result.REST, "the second slip in a row needs a rest")
	check(f.pull(0.999, true) == RockClimb.Result.SLIP, "after the rest one try follows at once again")
	check(f.pull(ok_roll, true) == RockClimb.Result.UP and f.pull(0.999, true) == RockClimb.Result.SLIP, "a good pull-up gives the quick retry back")
	# Every failed try raises the chance of a fall.
	var g := RockClimb.new(5.4, 8, 8)
	var before := g.fall_chance()
	g.pull(0.999, true)
	g.pull(0.999, true)
	check(g.fall_chance() > before, "failed tries raise the chance of a fall")
	check(g.fall_chance() <= RockClimb.FALL_MAX, "the chance of a fall has a ceiling")
	# Three falls to a safe spot in one ascent: the hero gives up.
	var h := RockClimb.new(6.6, 8, 8)
	for i in 3:
		h.pull(ok_roll, true)
	h.set_nail()
	check(h.pull(0.999, true, 0.0) == RockClimb.Result.FELL and h.pull(0.999, true, 0.0) == RockClimb.Result.FELL, "two falls to the safe spot go on")
	check(h.pull(0.999, true, 0.0) == RockClimb.Result.GAVE_UP, "the third fall to the safe spot gives up")
	# Along the face: the same rules and chance, but no height and never the top.
	var t := RockClimb.new(5.4, 8, 8)
	check(t.traverse(ok_roll, true) == RockClimb.Result.UP and is_equal_approx(t.metres, 0.0), "a step along the face gains no height")
	check(t.traverse(ok_roll, true) == RockClimb.Result.UP and t.traverse(ok_roll, true) == RockClimb.Result.PITON, "steps along the face count towards a safe spot")
	check(t.traverse(0.999, true) == RockClimb.Result.SLIP and t.traverse(0.999, true) == RockClimb.Result.REST, "a step along the face slips like a pull-up")
	var u := RockClimb.new(0.9, 8, 8)
	check(u.traverse(ok_roll, true) != RockClimb.Result.TOP, "a step along the face never reaches the top")
	var w := RockClimb.new(5.4, 8, 8)
	w.pull(ok_roll, true)
	check(w.traverse(0.999, true, 0.0) == RockClimb.Result.FELL and w.metres == 0.0, "a fall on a step along the face drops like any other")
	check(RockClimb.new(5.4, 8, 20).chance() > RockClimb.new(5.4, 8, 8).chance(), "skill makes a pull-up safer")
	check(RockClimb.new(5.4, 12, 12).chance() < RockClimb.new(5.4, 8, 12).chance(), "a harder spot is less safe")
	for s: Dictionary in ClimbSpots.SPOTS["Apfeltal"]:
		check(Climbing.can_climb(float(s.height), int(s.level)), "the skill a spot asks for can climb its height")


## Walks the hero up to the rock at `cell` (from the south) and pushes north for `seconds`.
func _push(hero: Player, lvl: Level, cell: Vector2i, seconds: float) -> void:
	var mid := lvl.cell_to_world(cell)
	# Whatever roams the valley while the test waits (monsters that come with the night, stinging bees) must not
	# kill the hero between two climbs: clear the field and heal before every push.
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	if not hero.dead:
		hero.hp = Player.MAX_HP
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
	var spot: Dictionary = ClimbSpots.SPOTS["Apfeltal"][0]
	var other := Vector2i(119, 23)
	check(lvl.cell_char(spot.cell) == "=" and lvl.cell_char(spot.cell + Vector2i(0, 1)) != "=", "the spot is rock with open ground south of it")
	for s: Dictionary in ClimbSpots.SPOTS["Apfeltal"]:
		check(lvl.cell_char(s.cell) == "=" and not "#=".contains(lvl.cell_char(s.cell + Vector2i(0, 1))), "spot %s has open ground in front" % s.cell)

	# A plain rock face: the message, no climb.
	hero.companion_perks = {"skills": {"klettern": 30}}
	hero.equipped["waffe"] = "kletterhammer"
	hero.equipped["schild"] = "kletterseil"
	hero.bag.append_array(["kletterhaken", "kletterhaken", "kletterhaken", "kletterhaken"])
	told.clear()
	await _push(hero, lvl, other, 3.2)
	check(not hero.is_climbing(), "plain rock cannot be climbed")
	check(told.has(Lang.t(ClimbSpots.TOO_STEEP)), "plain rock says it is too steep (got %s)" % [told])

	# A real spot with too little skill: the same message and the same timing, no climb.
	# (The worn hammer and rope already give +2 Klettern, so they come off for this check.)
	hero.companion_perks = {"skills": {}}
	hero.equipped.erase("waffe")
	hero.equipped.erase("schild")
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	check(not hero.is_climbing(), "too little skill: no climb")
	check(told == [Lang.t(ClimbSpots.TOO_STEEP)], "too little skill says only that it is too steep (got %s)" % [told])

	# With the skill: the climb starts after the same hold, and a good roll ends on the terrace.
	hero.equipped["waffe"] = "kletterhammer"
	hero.equipped["schild"] = "kletterseil"
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
	hero.rock_fall_forced = 0.0
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	var hp_before := hero.hp
	guard = 0
	while hero.is_climbing() and guard < 3000:
		await _wait(1)
		guard += 1
	check(hero.global_position.y < 0.3, "a first slip falls to the ground (y %.2f)" % hero.global_position.y)
	check(hero.hp <= hp_before, "a fall does not heal")
	check(hero.hp >= 1, "a fall never kills")
	# With a safe spot: three falls in one ascent make the hero give up and climb down.
	hero.rock_roll_forced = 0.0
	hero.rock_fall_forced = -1.0
	told.clear()
	await _push(hero, lvl, spot.cell, 3.2)
	check(hero.is_climbing(), "the second climb begins")
	var hands := hero._model.find_child("handslot_r", true, false) as Node3D
	check(hands != null and not hands.visible, "the weapons are stowed while climbing")
	guard = 0
	while hero.is_climbing() and (hero._rock == null or hero._rock.nails.is_empty()) and guard < 3000:
		await _wait(1)
		guard += 1
	check(hero._rock != null and hero._rock.nails.size() == 1, "the first safe spot is set")
	hero.rock_roll_forced = 0.999
	hero.rock_fall_forced = 0.0
	guard = 0
	while hero.is_climbing() and guard < 6000:
		await _wait(1)
		guard += 1
	check(not hero.is_climbing(), "the climb ends after the falls")
	check(hero.global_position.y < 0.3, "after three falls the hero climbed down (y %.2f)" % hero.global_position.y)
	check(told.has(Lang.t("Du gibst auf und kletterst am Seil hinunter.")), "the hero gives up and says so")
	check(hands != null and hands.visible, "the weapons are back in the hands")
	# Along the face: a held sideways key moves the hero over, to the edge of the spot and no further.
	hero.rock_roll_forced = 0.0
	hero.rock_fall_forced = -1.0
	hero.bag.append_array(["kletterhaken", "kletterhaken"])
	await _push(hero, lvl, spot.cell, 3.2)
	check(hero.is_climbing(), "the third climb begins")
	if not hero.is_climbing():
		# Say why (the check fails on some runners only): what holds the hero back from the rock.
		print("DIAG third climb: dead=%s controllable=%s frozen=%s busy=%.2f down=%.2f falling=%.2f floor=%s y=%.2f pos=%s push=%.2f hp=%s" % [hero.dead, hero.controllable, hero.frozen, hero._busy, hero._down, hero._falling, hero.is_on_floor(), hero.global_position.y, hero.global_position, hero._rock_push, hero.hp])
	guard = 0
	while hero.is_climbing() and hero._rock_y < 1.7 and guard < 3000:
		await _wait(1)
		guard += 1
	var x_side := hero.global_position.x
	Input.action_press("ui_left")
	guard = 0
	while hero.is_climbing() and hero._rock_side == 0 and guard < 600:
		await _wait(1)
		guard += 1
	var y_side := hero._rock_y
	Input.action_release("ui_left")
	guard = 0
	while hero.is_climbing() and absf(hero._rock_dx) < Player.ROCK_SIDE_STEP - 0.02 and guard < 600:
		await _wait(1)
		guard += 1
	check(hero.is_climbing() and absf(hero._rock_y - y_side) < 0.01, "moving along the face keeps the height (%.2f to %.2f)" % [y_side, hero._rock_y])
	check(hero.global_position.x < x_side - 0.7, "a held left key moves the hero left (x %.2f to %.2f)" % [x_side, hero.global_position.x])
	# Held on, the hero stops at the edge of the spot's width and climbs on from there.
	Input.action_press("ui_left")
	await _wait(300)
	Input.action_release("ui_left")
	check(absf(hero.global_position.x - hero._rock_mid_x) <= Player.ROCK_SIDE_MAX + 0.01, "the hero stays within the spot's width")
	var x_left := hero.global_position.x
	Input.action_press("ui_right")
	await _wait(120)
	Input.action_release("ui_right")
	check(hero.global_position.x > x_left + 0.7, "a held right key moves the hero right (x %.2f to %.2f)" % [x_left, hero.global_position.x])
	guard = 0
	while hero.is_climbing() and guard < 3000:
		await _wait(1)
		guard += 1
	check(not hero.is_climbing() and absf(hero.global_position.y - float(spot.height)) < 0.2, "after the traverse the climb still reaches the terrace (y %.2f)" % hero.global_position.y)
	game.delete_save(game.save_path())
	print("PASS: rock climbing" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
