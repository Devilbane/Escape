extends SceneTree
## Headless test for upgrading the hero's town house on Weavers' Lane: the upgrade
## window opens from the bed at home and from the stonemason, upgrades cost
## stone blocks (bag first, then the chest) and gold, each is built once, its
## furniture stands on the chalked furniture spots of the house without
## blocking the ways between the door, the stairs, the bed and the chest, the second chest doubles the
## storage, the workbench makes knives from iron and mends gear (and speeds up
## crafting while away), the trophy wall gives +1 life per trophy won, and
## everything is kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/home_upgrades.gd

const HERO := "Home upgrades test"

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


func _finish() -> void:
	game.delete_save(game.save_path(HERO))
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	if failures == 0:
		print("PASS: home upgrades")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _station(lvl: Level, kind: String) -> Array:
	return lvl.stations.filter(func(s): return s.kind == kind)


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
	game.home_upgrades.clear()
	game.trophies.clear()
	game.storage.clear()
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(HERO, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	var lvl: Level = game.level
	check(lvl.is_home, "the hero is in their town house")
	check(_station(lvl, "hauswerkbank").is_empty() and _station(lvl, "trophaeen").is_empty() and _station(lvl, "lager").size() == 1,
			"a fresh house has only its bed and chest")
	check(lvl.chalk_marks.size() == lvl.furniture_slots.size(), "every free furniture spot is chalked on the floor")

	# Every text has its English.
	for id in HomeUpgrades.ALL:
		check(Lang.EN.has(HomeUpgrades.ALL[id].name) and Lang.EN.has(HomeUpgrades.ALL[id].text), "%s has English texts" % id)
	for kind in HomeUpgrades.TROPHIES:
		check(Enemy.KINDS.has(kind), "the trophy %s comes from a real foe" % kind)
		check(Lang.EN.has(HomeUpgrades.TROPHIES[kind]) and Lang.EN.has(HomeUpgrades.TROPHY_HINTS[kind]), "the trophy %s has English texts" % kind)
	check(Lang.EN.has(HomeUpgrades.LEARN), "the compendium entry has its English")

	# The window opens from the bed at home and from the stonemason.
	game.menus.open("bett")
	check(_has_button(game.menus._box, Lang.t("Haus ausbauen")), "the bed at home offers to upgrade the house")
	game.menus.open("steinmetz")
	check(_has_button(game.menus._box, Lang.t("Haus ausbauen")), "so does the stonemason")
	game.menus.open("ausbau")
	check(game.menus.current == "ausbau" and game.lore.has(HomeUpgrades.LEARN), "the upgrade window opens and the compendium learns about it")

	# Not enough stones or gold: nothing is built.
	p.bag.clear()
	game.coins = 100
	game.menus._build_upgrade("truhe")
	check(not game.home_upgrades.has("truhe") and game.coins == 100, "without stone blocks nothing is built")
	for i in 2:
		p.bag.append("steinblock")
	for i in 3:
		game.storage.append("steinblock")
	game.coins = 5
	game.menus._build_upgrade("truhe")
	check(not game.home_upgrades.has("truhe") and p.bag.count("steinblock") == 2, "without the gold nothing is built")

	# The second chest: stones from the bag first, then from the chest.
	game.coins = 100
	game.menus._build_upgrade("truhe")
	check(game.home_upgrades.has("truhe"), "the second chest is built")
	check(p.bag.count("steinblock") == 0 and game.storage.count("steinblock") == 1, "the bag's stones went first, then the chest's")
	check(game.coins == 100 - HomeUpgrades.ALL.truhe.gold, "the gold is paid")
	game.menus._build_upgrade("truhe")
	check(game.coins == 100 - HomeUpgrades.ALL.truhe.gold, "an upgrade is built only once")
	var chests := _station(lvl, "lager")
	check(chests.size() == 2, "a second chest stands in the house")
	check(HomeUpgrades.storage_size(game.home_upgrades) == 32, "the chests hold twice as much")
	game.storage.clear()
	for i in 20:
		game.storage.append("lederwams")
	p.bag.assign(["kupferring"])
	game.menus.open("lager")
	game.menus._store(0)
	check(game.storage.size() == 21 and p.bag.is_empty(), "more than 16 things fit into the chests now")
	game.storage.clear()

	# The workshop and the trophy wall.
	for i in 11:
		p.bag.append("steinblock")
	game.coins = 100
	game.menus._build_upgrade("werkstatt")
	game.menus._build_upgrade("trophaeen")
	check(game.home_upgrades.has("werkstatt") and game.home_upgrades.has("trophaeen") and p.bag.is_empty(), "the workshop and the trophy wall are built")
	check(_station(lvl, "hauswerkbank").size() == 1 and _station(lvl, "trophaeen").size() == 1, "a workbench and a trophy wall stand in the house")

	# All of it on the chalked furniture spots, each on its own, and the ways
	# on every storey stay open: door, stairs, bed, chests and workbench.
	var cells := {}
	var spots := lvl.furniture_slots.map(func(slot): return slot.cell)
	for id in lvl._upgrade_cells:
		var c: Vector2i = lvl._upgrade_cells[id]
		check(spots.has(c), "%s stands on a furniture spot" % id)
		check(not cells.has(c), "%s has a spot of its own" % id)
		cells[c] = true
	var old_chest := lvl._home_chest_cell()
	check(lvl.storey_of(lvl._upgrade_cells.truhe) == lvl.storey_of(old_chest) and Vector2(lvl._upgrade_cells.truhe - old_chest).length() < 2.0,
			"the second chest stands next to the first")
	check(lvl.storey_of(lvl._upgrade_cells.werkstatt) == 2 and lvl.storey_of(lvl._upgrade_cells.trophaeen) == 2, "the workbench and the trophy wall are in the attic")
	check(lvl._against_back_wall(lvl._upgrade_cells.trophaeen), "the trophy wall hangs on a wall")
	for storey in lvl.storey_count():
		# Where the hero arrives on this storey: the front door or the stairs.
		var start := lvl.exit_cell
		for st in lvl.stairs:
			if st.storey == storey - 1 and st.up:
				start = lvl.stair_target(st.cell)
		var goals: Array = lvl.stairs.filter(func(st): return st.storey == storey).map(func(st): return st.cell)
		for s in lvl.stations:
			if lvl.storey_of(s.cell) == storey and s.kind != "trophaeen":
				goals.append(s.cell)
		for goal: Vector2i in goals:
			var reached := false
			for d: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var n := goal + d
				if lvl.storey_of(n) == storey and lvl._walkable(n) and not lvl.astar.is_point_solid(n) and _path_ok(lvl, start, n):
					reached = true
			check(reached, "on storey %d the hero still gets to %s" % [storey, goal])
	check(not lvl.astar.is_point_solid(lvl._upgrade_cells.trophaeen), "the trophy wall leaves its spot free to walk")

	# The workbench.
	game.iron = 2
	var knives: int = p.knives
	game.menus.open("hauswerkbank")
	check(game.menus.current == "hauswerkbank", "the workbench window opens")
	game.menus._make_knives()
	check(game.iron == 1 and p.knives == knives + HomeUpgrades.KNIVES_PER_IRON, "an iron bar becomes throwing knives")
	p.bag.assign(["ritterhelm"])
	p.wear["ritterhelm"] = 4
	game.menus._mend_at_home("ritterhelm")
	check(game.iron == 0 and not p.wear.has("ritterhelm"), "an iron bar mends a worn piece")
	game.menus._make_knives()
	check(p.knives == knives + HomeUpgrades.KNIVES_PER_IRON, "without iron no knives")
	game.menus.close()
	var plan := Offline.empty_plan()
	plan.craft = "messer"
	plan.craft_hours = 6
	check(Offline.simulate(plan, 24.0).knives == 2 and Offline.simulate(plan, 24.0, true).knives == 3, "the workshop makes crafting while away faster")

	# Trophies: the first foe of a mighty kind gives one, more do not.
	var base_hp: int = p.max_hp
	game._win_trophy("wolf")
	game._win_trophy("wolf")
	game._win_trophy("krieger")
	check(game.trophies.keys() == ["wolf"], "a wolf gives a trophy, a common skeleton does not")
	check(p.max_hp == base_hp + 1, "the trophy on the wall gives +1 life")
	game._win_trophy("drache")
	check(p.max_hp == base_hp + 2, "every trophy gives +1 life")
	check(lvl._trophy_shelf != null, "the trophy wall has its shelf")
	check(lvl._trophy_shelf.get_child_count() == 2, "both trophies stand on the shelf")
	game.menus.open("trophaeen")
	check(game.menus.current == "trophaeen", "the trophy wall's window opens")
	var struck := _struck_texts(game.menus._box)
	check(struck.size() == 2, "the two trophies won are struck through (%d)" % struck.size())
	check(struck.any(func(t): return t.contains(Lang.t("Wolfspelz"))) and struck.all(func(t): return t.contains(Lang.t("erbeutet"))),
			"each says which trophy it is and that it is won")
	game.menus.close()
	check(Lang.EN.has("Trophäenwand: Dagegenlaufen, um zu sehen, welche Trophäen du hast und welche noch fehlen (je +1 Leben)"), "the trophy wall's hint says what it is for")

	# Kept in the saved game: loaded again, everything is still there.
	check(game.save_game(), "the game saves")
	game.home_upgrades.clear()
	game.trophies.clear()
	game._apply_save(game._read_save())
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	lvl = game.level
	check(game.home_upgrades.size() == 3 and game.trophies.size() == 2, "the upgrades and trophies are loaded again")
	check(_station(lvl, "hauswerkbank").size() == 1 and _station(lvl, "trophaeen").size() == 1 and _station(lvl, "lager").size() == 2,
			"a loaded game rebuilds the furniture")
	check(p.max_hp == base_hp + 2, "the trophies' life is back after loading")
	for id in lvl._upgrade_cells:
		check(not lvl.chalk_marks.has(lvl._upgrade_cells[id]), "no chalk square is left under the %s" % id)
	check(lvl.chalk_marks.size() == lvl.furniture_slots.size() - 3, "the free spots keep their chalk squares")

	# A trophy won before the wall stands gives no life until it is built.
	game.home_upgrades.erase("trophaeen")
	game.apply_home_bonus()
	check(p.max_hp == base_hp, "without the wall the trophies give no life")
	_finish()


## The texts of the struck-through (finished) lines in a window.
func _struck_texts(node: Node) -> Array:
	var out := []
	for l in node.find_children("*", "RichTextLabel", true, false):
		if (l as RichTextLabel).text.contains("[s]"):
			out.append((l as RichTextLabel).get_parsed_text())
	return out


func _has_button(node: Node, text: String) -> bool:
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return true
	return false


func _path_ok(lvl: Level, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	var path: Array[Vector2i] = lvl.astar.get_id_path(from, to)
	return not path.is_empty() and path[-1] == to
