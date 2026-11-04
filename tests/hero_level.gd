extends SceneTree
## Headless test for the hero's level and experience (see HeroLevel): the
## level curve, what a level-up gives, monster levels by area, how much the
## dungeon is worth (the hero leaves the crypt at about level 5), the deep mine
## at 16 to 20, experience from tasks, bounties and riddles on the event bus,
## loot that suits a place, keeping the level with the hero's name, and the
## level on the HUD and the character page.
## Run with: godot --headless --fixed-fps 60 -s tests/hero_level.gd
## With REPORT=1 it prints every monster's level by place.

var failures := 0
var game: Node
var frames := 0
const HERO := "Hero level test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	game.hero_name = HERO
	game.player.hero_xp = 0
	game.player.level_points = {}
	_curve()
	_rewards()
	_attribute_effects()
	await _dungeon()
	await _areas()
	await _sources()
	_loot()
	_keeping()
	await _shown()
	game.delete_save(game.save_path())
	Training.save_hero(HERO, {}, {})
	print("PASS: hero level" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _curve() -> void:
	check(HeroLevel.level_for(0) == 1, "a new hero is level 1")
	check(HeroLevel.level_for(99) == 1 and HeroLevel.level_for(100) == 2, "level 2 takes 100 XP")
	check(HeroLevel.total_for(5) == 1000, "level 5 takes 1000 XP in all: %d" % HeroLevel.total_for(5))
	check(HeroLevel.level_for(10 ** 7) == HeroLevel.MAX, "level %d is the top" % HeroLevel.MAX)
	check(HeroLevel.progress(150) == Vector2i(50, 200), "progress within level 2: %s" % HeroLevel.progress(150))
	# The owner's seasoned character is the yardstick at level 18.
	check(HeroLevel.expected_power(18) == Mines.BENCHMARK.power, "power at level 18 is the benchmark's")
	check(HeroLevel.expected_hardening(18) == Mines.BENCHMARK.hardening, "hardening at level 18 is the benchmark's")
	for level in range(2, HeroLevel.MAX + 1):
		check(HeroLevel.expected_life(level) > HeroLevel.expected_life(level - 1), "the expected hero gets tougher at %d" % level)
	# The equipment reference matches the expected hero.
	for level in HeroLevel.GEAR_REFERENCE:
		var gear: Array = HeroLevel.GEAR_REFERENCE[level]
		var power := 1 + HeroLevel.points_earned(level) / 2
		var hardening := 0
		for id in gear:
			check(Items.ALL.has(id), "the reference names a real item: %s" % id)
			power += int(Items.ALL.get(id, {}).get("power", 0))
			hardening += int(Items.ALL.get(id, {}).get("armor", 0))
			check(Items.item_level(id) <= level, "%s suits level %d (it is %d)" % [id, level, Items.item_level(id)])
		check(absi(power - HeroLevel.expected_power(level)) <= 2, "the level %d gear gives about the expected power: %d vs %d" % [level, power, HeroLevel.expected_power(level)])
		check(absi(hardening - HeroLevel.expected_hardening(level)) <= 1, "the level %d gear gives about the expected hardening: %d vs %d" % [level, hardening, HeroLevel.expected_hardening(level)])


func _rewards() -> void:
	var p: Player = game.player
	p.hero_xp = 0
	p.level_points = {}
	p.refresh_stats()
	var life := p.max_hp
	var con := p.attribute("konstitution")
	var speed := p.base_speed
	var strength := p.attribute("staerke")
	var power := p.power
	var reached := []
	p.leveled_up.connect(func(l: int): reached.append(l))
	check(p.gain_xp(HeroLevel.total_for(6)) == 5, "1500 XP is five levels")
	check(reached == [2, 3, 4, 5, 6], "every level is told: %s" % [reached])
	check(p.hero_level() == 6, "the hero is level 6")
	# Five levels, and the Konstitution of level 5 is one more.
	check(p.max_hp == life + 5 + 1, "+1 life per level: %d -> %d" % [life, p.max_hp])
	check(p.attribute("konstitution") == con + 1, "+1 Konstitution at level 5")
	check(is_equal_approx(p.base_speed, speed * 1.03 / 1.0) or p.base_speed > speed, "+1 %% speed every 2 levels")
	check(p.free_points() == 2, "a point at levels 3 and 6: %d" % p.free_points())
	check(not p.spend_point("weisheit"), "a point goes only to Stärke, Geschick or Intelligenz")
	check(p.spend_point("staerke"), "a point goes to Stärke")
	check(p.attribute("staerke") == strength + 1 and p.power == power + 1, "Stärke and power grew")
	check(p.spend_point("intelligenz") and p.free_points() == 0, "the second point is spent")
	check(not p.spend_point("geschick"), "no third point")
	p.hero_xp = 0
	p.level_points = {}
	p.refresh_stats()


## What a level point in each main attribute gives (see Player): Stärke
## melee damage, Geschick knife damage and dodging, Intelligenz quicker
## skills and more experience. The character page shows these numbers.
func _attribute_effects() -> void:
	var p: Player = game.player
	var keep_xp: Dictionary = p.xp.duplicate()
	p.xp = {}
	p.hero_xp = 0
	p.level_points = {}
	p.refresh_stats()
	var power := p.power
	check(p.throw_power() == power and p.dodge_chance() == 0.0, "a fresh hero throws as hard as they strike and does not dodge")
	check(p.clever_xp(100) == 100, "a fresh hero gets plain experience")
	p.level_points = {"staerke": 2}
	p.refresh_stats()
	check(p.power == power + 2 and p.throw_power() == power, "Stärke adds to blows, not to knives: %d, %d" % [p.power, p.throw_power()])
	p.level_points = {"geschick": 3}
	p.refresh_stats()
	check(p.power == power and p.throw_power() == power + 3, "Geschick adds to knives, not to blows: %d, %d" % [p.power, p.throw_power()])
	check(is_equal_approx(p.dodge_chance(), 0.12), "Geschick 13 dodges 12 %%: %s" % p.dodge_chance())
	p.level_points = {"geschick": 20}
	check(is_equal_approx(p.dodge_chance(), Player.DODGE_MAX), "dodging stops at %s" % Player.DODGE_MAX)
	p.level_points = {"intelligenz": 2}
	p.refresh_stats()
	check(p.clever_xp(100) == 106, "Intelligenz 12 earns 6 %% more experience: %d" % p.clever_xp(100))
	p.equipped["waffe"] = "schwert"
	p.train("klingen", 1.0)
	check(is_equal_approx(p.xp.get("klingen", 0.0), 1.2), "Intelligenz 12 trains skills 20 %% quicker: %s" % p.xp.get("klingen", 0.0))
	p.train("staerke", 1.0)
	check(is_equal_approx(p.xp.get("staerke", 0.0), 1.0), "but not attributes: %s" % p.xp.get("staerke", 0.0))
	p.equipped.erase("waffe")
	p.xp = keep_xp
	p.level_points = {}
	p.refresh_stats()


## All the monsters on a floor and the XP each is worth to a hero of `hero`.
func _floor_xp(hero: int) -> int:
	var total := 0
	for e in game.level.enemies:
		if is_instance_valid(e) and not e.kind in Enemy.HORRORS:
			total += HeroLevel.kill_xp(e.rated_level, hero, e.is_level_boss())
	return total


func _dungeon() -> void:
	var report := OS.get_environment("REPORT") != ""
	var xp := 0
	for i in 10:
		game.load_level(i, false)
		await _wait()
		var hero := HeroLevel.level_for(xp)
		xp += _floor_xp(hero)
		# A wall writing on every floor, and the secret room.
		var place := HeroLevel.place_level(game.level)
		xp += HeroLevel.time_xp(HeroLevel.RIDDLES.writing, place, hero) + HeroLevel.time_xp(HeroLevel.RIDDLES.secret, place, hero)
		for e in game.level.enemies:
			# A horror may lurk on any deep floor by chance (Level._spawn_horror):
			# it is meant to be far above the hero and is left out, as in _floor_xp.
			if e.kind in Enemy.HORRORS:
				continue
			check(e.rated_level <= 7, "dungeon monsters stay low: %s on floor %d is %d" % [e.kind, i + 1, e.rated_level])
			if report:
				print("floor %d  %s  %d" % [i + 1, e.kind, e.rated_level])
		if report:
			print("after floor %d: %d XP, level %d" % [i + 1, xp, HeroLevel.level_for(xp)])
	var leaving := HeroLevel.level_for(xp)
	check(leaving >= 4 and leaving <= 6, "the hero leaves the crypt at about level 5: %d (%d XP)" % [leaving, xp])


func _areas() -> void:
	var report := OS.get_environment("REPORT") != ""
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	for e in game.level.enemies:
		var area := HeroLevel.area_of(game.level, e.kind)
		if report:
			print("%s  %s  %d" % [area, e.kind, e.rated_level])
		if HeroLevel.AREAS.has(area) and not HeroLevel.FIXED.has(e.kind):
			check(e.rated_level >= HeroLevel.AREAS[area].min and e.rated_level <= HeroLevel.AREAS[area].max, "%s in %s fits levels %d to %d: %d" % [e.kind, area, HeroLevel.AREAS[area].min, HeroLevel.AREAS[area].max, e.rated_level])
	for building in ["loch1", "loch2", "loch2b", "E", "E2", "E3", "mine1", "mine2", "mine3", "mine3b", "mine3c", "uralt1", "uralt2", "uralt3"]:
		game.load_level(game.interiors[building], false)
		await _wait()
		var area: String = HeroLevel.BUILDING_AREAS[building]
		for e in game.level.enemies:
			if report:
				print("%s  %s  %d" % [building, e.kind, e.rated_level])
			if HeroLevel.FIXED.has(e.kind) or e.kind in Enemy.HORRORS:
				continue
			check(e.rated_level >= HeroLevel.AREAS[area].min and e.rated_level <= HeroLevel.AREAS[area].max, "%s in %s fits levels %d to %d: %d" % [e.kind, building, HeroLevel.AREAS[area].min, HeroLevel.AREAS[area].max, e.rated_level])
		game.load_level(game._outdoor_index(), false)
		await _wait()
	check(HeroLevel.FIXED.bergkoenig == 20, "the Mountain King is the top")
	check(HeroLevel.AREAS.mine3.min == 16, "the deep mine starts at 16")
	check(HeroLevel.AREAS.mine2.max == 15, "the areas before it lead up to 15")
	var bergork := HeroLevel.rate("bergork", 17 + 3, 3 + 2, 2, 1.4)
	check(HeroLevel.area_target("mine3", bergork) >= 16, "a mountain orc in the deep mine is lifted: %d" % HeroLevel.area_target("mine3", bergork))
	check(HeroLevel.area_target("mine3", 30) == HeroLevel.AREAS.mine3.max, "a monster above the area is toned down to its top")


func _sources() -> void:
	var p: Player = game.player
	var bus := Events.bus()
	p.hero_xp = 0
	bus.enemy_felled.emit(3, false)
	check(p.hero_xp == HeroLevel.KILL_XP * 4, "a level 3 monster is worth 20 XP: %d" % p.hero_xp)
	p.hero_xp = 0
	bus.enemy_felled.emit(3, true)
	check(p.hero_xp == HeroLevel.KILL_XP * 4 * HeroLevel.BOSS_FACTOR, "a boss is worth five times as much")
	p.hero_xp = HeroLevel.total_for(15)
	var before := p.hero_xp
	bus.enemy_felled.emit(3, false)
	check(p.hero_xp - before == 2, "a monster far below the hero gives a tenth: %d" % (p.hero_xp - before))
	p.hero_xp = 0
	game.quests.clear()
	bus.quest_done.emit("hauptmann")
	check(p.hero_xp == HeroLevel.task_xp("hauptmann", 1), "the chief's task pays its minutes: %d" % p.hero_xp)
	check(HeroLevel.task_xp("hauptmann", 1) > HeroLevel.task_xp("brief", 1), "a long task pays more than a quick errand")
	for id in Quests.ALL:
		check(HeroLevel.TASKS.has(id), "every task has its minutes: %s" % id)
	for id in Bounties.POOL:
		check(HeroLevel.TASKS.has("bounty:" + id), "every bounty has its minutes: %s" % id)
	p.hero_xp = 0
	game.bounties.clear()
	game.bounties.refresh(game.day)
	var hunt: String = game.bounties.posted[0]
	game.bounties.take(hunt)
	for i in Bounties.POOL[hunt].count:
		game.bounties.on_kill(Bounties.POOL[hunt].targets[0])
	game.bounties.claim(hunt)
	check(p.hero_xp >= HeroLevel.task_xp("bounty:" + hunt, 1), "a paid bounty is worth XP: %d" % p.hero_xp)
	p.hero_xp = 0
	game.writing_found(Mines.RUNE_ORE)
	check(p.hero_xp >= HeroLevel.time_xp(HeroLevel.RIDDLES.rune, HeroLevel.rune_level("kupfer"), 1), "a rune tablet is a riddle worth XP: %d" % p.hero_xp)
	var after_rune := p.hero_xp
	game.writing_found(Mines.RUNE_ORE)
	check(p.hero_xp == after_rune, "a riddle pays only once")
	p.hero_xp = 0
	p.refresh_stats()
	await _wait()


func _loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var deep_best := 0
	for i in 200:
		var low := Items.random_item(rng, 0, "", 1)
		check(Items.item_level(low) <= 1 + Items.LOOT_ABOVE, "the first floors hold simple gear: %s" % low)
		var high := Items.random_item(rng, 0, "", 16)
		check(Items.item_level(high) >= 6, "the deep mine holds strong gear: %s" % high)
		deep_best = maxi(deep_best, Items.item_level(high))
	check(deep_best >= 10, "the best loot turns up deep down: %d" % deep_best)
	for id in Items.LEVELS:
		check(Items.ALL.has(id), "item levels name real items: %s" % id)


func _keeping() -> void:
	var p: Player = game.player
	Training.save_hero(HERO, {"staerke": 10.0}, {"xp": 1234, "points": {"geschick": 1}})
	Training.save_hero(HERO, {"staerke": 20.0})
	var kept := Training.load_level(HERO)
	check(int(kept.get("xp", 0)) == 1234, "the level stays with the name when only training is saved")
	check(Training.load_hero(HERO).get("staerke", 0.0) == 20.0, "the training is saved beside it")
	p.set_level_data(kept)
	check(p.hero_xp == 1234 and int(p.level_points.get("geschick", 0)) == 1, "the level comes back")
	p.hero_xp = 0
	p.level_points = {}
	p.refresh_stats()


func _shown() -> void:
	var p: Player = game.player
	var menus: Menus = game.menus
	root.size = Vector2i(1280, 720)
	game.state = game.State.PLAYING
	p.hero_xp = HeroLevel.total_for(3) + 50
	p.level_points = {}
	p.refresh_stats()
	game._update_hud()
	check(game._xp_label.text.contains(Lang.t("Heldenstufe %d") % 3), "the HUD shows the level: %s" % game._xp_label.text)
	check(game._xp_bar.value == 50 and game._xp_bar.max_value == 300, "the HUD bar shows the way to the next level")
	check(game._xp_label.text.contains(Lang.t("Punkt frei (P)")), "the HUD tells of a free point")
	menus.open("charakter")
	await _wait()
	check(menus._character_level.text.contains("50 / 300"), "the character page shows the XP: %s" % menus._character_level.text)
	check(is_equal_approx(menus._panel.scale.x, 1.0), "the character page still fits 1280 × 720 unshrunk")
	var spend: Button = menus._character_spend
	check(spend.disabled, "without an attribute picked, the point button waits")
	var size_before: Vector2 = menus._panel.size
	var wheel: CharacterPage = _find_wheel(menus._box)
	wheel.pick("staerke")
	check(not spend.disabled, "with Stärke picked, the point can be spent")
	var strength := p.attribute("staerke")
	spend.pressed.emit()
	await _wait()
	check(p.attribute("staerke") == strength + 1, "pressing it raises Stärke")
	check(menus._panel.size == size_before, "spending a point does not reshape the window")
	check(menus._character_spend.disabled, "no point left: the button is off")
	check(_find_wheel(menus._box).picked == "staerke", "the picked attribute stays picked")
	menus.close()
	p.hero_xp = 0
	p.level_points = {}
	p.refresh_stats()


func _find_wheel(node: Node) -> CharacterPage:
	if node is CharacterPage:
		return node
	for c in node.get_children():
		var found := _find_wheel(c)
		if found:
			return found
	return null
