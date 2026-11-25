extends SceneTree
## Headless test: the secret garden on the mountain (see SummitGarden). The hidden climb (level 16, no
## easier way to tell it from plain rock), the ledge with its silver edelweiss (picked by walking into
## them, back after REGROW_DAYS), the tablet to read and the spring to drink from.
## Run with: godot --headless --fixed-fps 60 -s tests/summit_garden.gd

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
	var spot := {}
	for s: Dictionary in ClimbSpots.SPOTS["Apfeltal"]:
		if s.cell == SummitGarden.CELL:
			spot = s
	check(not spot.is_empty(), "the garden's rock is a climbing spot")
	check(int(spot.get("level", 0)) == SummitGarden.LEVEL and is_equal_approx(float(spot.get("height", 0.0)), SummitGarden.HEIGHT), "the spot has the garden's level and height")
	check(SummitGarden.LEVEL >= 16, "the climb asks for level 16 or more")
	check(not Climbing.can_climb(SummitGarden.HEIGHT, SummitGarden.LEVEL - 1), "one level less cannot reach the ledge")
	check(Climbing.can_climb(SummitGarden.HEIGHT, SummitGarden.LEVEL), "the level asked for can reach the ledge")
	check(Crafting.INGREDIENTS.has(SummitGarden.INGREDIENT) and Crafting.INGREDIENTS[SummitGarden.INGREDIENT].get("rare", false), "the silver edelweiss is a rare ingredient")
	check(SummitGarden.plant_key(0, 0) != SummitGarden.plant_key(0, SummitGarden.REGROW_DAYS), "a plant has a new key every period")
	check(SummitGarden.plant_key(1, 3) == SummitGarden.plant_key(1, 4), "the key stays the same within a period")
	for at: Vector2 in SummitGarden.PLANTS:
		check(absf(at.x) <= 1.9 and at.y >= -1.9 and at.y <= 0.9, "plant %s is on the flat part of the ledge" % at)
		check(at.distance_to(SummitGarden.TABLET_AT) > 0.9 and at.distance_to(SummitGarden.SPRING_AT) > 0.9, "plant %s does not stand in the tablet or the spring" % at)


func _run() -> void:
	_rules()
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Garden test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	game.state = game.State.PLAYING
	var lvl: Level = game.level
	var hero: Player = game.player
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float) -> void: told.append(text))
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	var cell := SummitGarden.CELL
	check(lvl.cell_char(cell) == "=" and not "#=".contains(lvl.cell_char(cell + Vector2i(0, 1))), "the foot of the climb is rock with open ground in front")
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
		check(lvl.cell_char(cell + d) == "=", "the rock round the ledge at %s stays rock" % [cell + d])

	# The garden is built: the plants, the tablet, the spring.
	check(lvl.get_node_or_null("SummitGarden") != null, "the garden is built")
	check(SummitGarden.blooming(lvl) == SummitGarden.PLANTS.size(), "all the silver edelweiss bloom (%d)" % SummitGarden.blooming(lvl))
	var tablet := {}
	var spring := {}
	for s in lvl.stations:
		if s.kind == SummitGarden.TABLET_KIND and s.text == SummitGarden.TABLET:
			tablet = s
		elif s.kind == SummitGarden.SPRING_KIND:
			spring = s
	check(not tablet.is_empty() and not spring.is_empty(), "the tablet and the spring are stations")
	check(absf(float(tablet.pos.y) - SummitGarden.HEIGHT) < 0.1, "the tablet stands on the ledge")
	check(lvl.station_at(tablet.pos + Vector3(0.4, 0.3, 0.2)) == tablet, "running into the tablet uses it")
	check(lvl.station_at(spring.pos + Vector3(-0.4, 0.3, 0.2)) == spring, "running into the spring uses it")
	check(lvl.get_node("SummitGarden").find_child("Bract1_0", true, false) == null, "the plants are not part of the ledge's decoration")
	check(lvl.find_child("Bract1_0", true, false) != null, "a plant has its bracts")
	check(lvl.get_node("SummitGarden").find_child("Water", true, false) != null, "the spring has water")

	# Nothing below shows the way up: level 15 gets only the too-steep message, level 16 starts the climb.
	hero.equipped.erase("waffe")
	hero.equipped.erase("schild")
	hero.companion_perks = {"skills": {"klettern": SummitGarden.LEVEL - 1}}
	var mid := lvl.cell_to_world(cell)
	hero.global_position = Vector3(mid.x, 0.0, mid.z + Level.TILE * 0.5 + 2.0)
	hero.reset_physics_interpolation()
	await _wait(10)
	told.clear()
	Input.action_press("ui_up")
	await _wait(200)
	Input.action_release("ui_up")
	check(not hero.is_climbing(), "level 15 does not climb the garden's face")
	check(told.has(Lang.t(ClimbSpots.TOO_STEEP)), "level 15 is told it is too steep (got %s)" % [told])
	hero.companion_perks = {"skills": {"klettern": SummitGarden.LEVEL}}
	hero.equipped["waffe"] = "kletterhammer"
	hero.equipped["schild"] = "kletterseil"
	hero.bag.append_array(["kletterhaken", "kletterhaken", "kletterhaken", "kletterhaken"])
	hero.global_position = Vector3(mid.x, 0.0, mid.z + Level.TILE * 0.5 + 2.0)
	hero.reset_physics_interpolation()
	await _wait(10)
	Input.action_press("ui_up")
	var left := 300
	while left > 0 and not hero.is_climbing():
		await _wait(1)
		left -= 1
	Input.action_release("ui_up")
	check(hero.is_climbing(), "level 16 starts the climb")
	# The viper in the face bites once on the way up: life points and poison, never the last life point.
	hero.hp = hero.max_hp
	hero.cure()
	hero.rock_roll_forced = 0.0
	var guard := 0
	while hero.is_climbing() and not hero.ailments.has("gift") and guard < 3000:
		await _wait(1)
		guard += 1
	check(hero.ailments.has("gift"), "the viper poisons the climbing hero")
	check(hero.hp == hero.max_hp - SummitGarden.BITE, "the bite takes %d life points (%d/%d)" % [SummitGarden.BITE, hero.hp, hero.max_hp])
	check(told.has(Lang.t(SummitGarden.BITTEN)) and game.lore.has(SummitGarden.BITTEN_LEARN), "the bite is told and the compendium learns of it")
	hero._end_rock(true)
	check(hero._rock_bitten, "one bite per climb")

	# Up on the ledge: the hero stands, the plants are picked by walking into them, the rest is used.
	var top := SummitGarden.middle(lvl) + Vector3(0, 0.05, 0)
	hero.global_position = top
	hero.reset_physics_interpolation()
	await _wait(30)
	check(absf(hero.global_position.y - SummitGarden.HEIGHT) < 0.2, "the hero stands on the ledge (y %.2f)" % hero.global_position.y)
	var before: int = game.crafting.have(SummitGarden.INGREDIENT)
	hero.global_position = SummitGarden.spot(lvl, SummitGarden.PLANTS[0]) + Vector3(0, 0.05, 0)
	hero.reset_physics_interpolation()
	await _wait(30)
	check(game.crafting.have(SummitGarden.INGREDIENT) == before + 1, "walking into a plant picks the silver edelweiss")
	check(SummitGarden.blooming(lvl) == SummitGarden.PLANTS.size() - 1, "a picked plant is gone (%d bloom)" % SummitGarden.blooming(lvl))
	check(game.lore.has(SummitGarden.PICKED_LEARN), "the compendium learns of the silver edelweiss")
	# It comes back after REGROW_DAYS days, not before (the hero stepped away: a plant that blooms
	# under their feet would be picked at once).
	hero.global_position = top
	hero.reset_physics_interpolation()
	await _wait(5)
	SummitGarden.refresh(lvl, game.day + SummitGarden.REGROW_DAYS - 1 - (game.day % SummitGarden.REGROW_DAYS))
	check(SummitGarden.blooming(lvl) == SummitGarden.PLANTS.size() - 1, "within the period it stays gone")
	SummitGarden.refresh(lvl, game.day + SummitGarden.REGROW_DAYS, true)
	await _wait(5)
	check(SummitGarden.blooming(lvl) == SummitGarden.PLANTS.size(), "after the period it blooms again (%d)" % SummitGarden.blooming(lvl))
	# A picked plant is not made twice in the same period.
	SummitGarden.refresh(lvl, game.day + SummitGarden.REGROW_DAYS)
	check(SummitGarden.blooming(lvl) == SummitGarden.PLANTS.size(), "a refresh does not double the plants")

	# The tablet: its words go into the compendium.
	hero.global_position = top
	game._use_station(tablet)
	check(game.lore.has(SummitGarden.TABLET), "reading the tablet teaches its words")
	# The spring: all the life back and the poison gone.
	hero.hp = maxi(1, hero.max_hp - 5)
	hero.afflict("gift")
	game._use_station(spring)
	check(not hero.ailments.has("gift"), "the spring cures the viper's poison")
	check(hero.hp == hero.max_hp, "the spring heals fully (%d/%d)" % [hero.hp, hero.max_hp])
	check(game.lore.has(SummitGarden.SPRING_LEARN), "the first sip teaches about the spring")
	for text in [SummitGarden.TABLET, SummitGarden.SPRING_LEARN, SummitGarden.PICKED, SummitGarden.PICKED_LEARN, SummitGarden.SPRING_FULL,
			SummitGarden.SPRING_HEALED, SummitGarden.SPRING_CURED, SummitGarden.BITTEN, SummitGarden.BITTEN_LEARN]:
		check(Lang.EN.has(text), "English text: %s" % text.left(30))
	game.delete_save(game.save_path())
	print("PASS: summit garden" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
