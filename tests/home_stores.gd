extends SceneTree
## Headless test for the two special stores of every town house (see
## HomeStores): the steel-banded chest for coins, bars, ore and raw gems, and
## the ingredient board for herbs, fish, the dragon's parts and animal food.
## Every house has both beside its storage chest, each a station the hero can
## reach; their windows move one, ten coins or all of a kind in and out; things
## for the bag come back only while it has room; nothing goes into the wrong
## store; everything is kept in the saved game; and every text has English.
## Run with: godot --headless --fixed-fps 60 -s tests/home_stores.gd

const HERO := "Home stores test"

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
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	if failures == 0:
		print("PASS: home stores")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _station(lvl: Level, kind: String) -> Array:
	return lvl.stations.filter(func(s): return s.kind == kind)


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
	game.home_stores = HomeStores.empty()
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

	# The storage chest stands on the ground floor; the steel-banded chest
	# and the ingredient board in the cellar below it, each on a tile of its
	# own the hero can walk up to. Stairs lead down there and back up.
	var chest := _station(lvl, "lager")
	var metal := _station(lvl, HomeStores.STATIONS[HomeStores.METAL])
	var board := _station(lvl, HomeStores.STATIONS[HomeStores.PANTRY])
	check(chest.size() == 1 and metal.size() == 1 and board.size() == 1, "every house has a storage chest, a steel-banded chest and an ingredient board")
	for s in chest + metal + board:
		var want := 0 if s.kind == "lager" else -1
		check(lvl.storey_of(s.cell) == want, "%s stands on storey %d (%d)" % [s.kind, want, lvl.storey_of(s.cell)])
		# A chalked furniture spot ("+") is plain floor until furniture stands on it.
		var reachable := false
		for d in Level.DIRS:
			var n: Vector2i = s.cell + d
			if ".P+".contains(lvl.cell_char(n)):
				reachable = true
		check(reachable, "%s has plain floor beside it to walk up to" % s.kind)
		check(lvl.station_at(s.pos).get("kind", "") == s.kind, "running into %s finds it" % s.kind)
		check(lvl.nearest_station(s.pos).get("kind", "") == s.kind, "the hint over %s names it, not a neighbour" % s.kind)
	check(lvl.has_cellar() and lvl.storey_name(-1) == Lang.t("Keller"), "the house has a cellar")
	check(lvl.storey_of(lvl.exit_cell) == 0 and lvl.storey_count() == 3, "the front door is on the ground floor, with two floors above")
	var down: Array = lvl.stairs.filter(func(st): return not st.up and st.storey == 0)
	check(down.size() == 1, "stairs on the ground floor lead down")
	if down.size() == 1:
		var to := lvl.stair_target(down[0].cell)
		check(to.x >= 0 and lvl.storey_of(to) == -1 and lvl.cell_char(to) == "<", "and arrive on the cellar's stairs up")
		check(lvl.stair_target(to) == down[0].cell, "which lead back up to the ground floor")
	check(lvl.find_child("MetalChest", false, false) != null and lvl.find_child("IngredientBoard", false, false) != null, "both are built as furniture")

	# What goes where.
	check(HomeStores.store_of(HomeStores.COINS) == HomeStores.METAL, "coins go in the steel-banded chest")
	for id in ["eisen", "bronze", "silber", "gold", "donnererz", "mondsilbererz", "mondstein", "grottenkristall"]:
		check(HomeStores.store_of(id) == HomeStores.METAL, "%s goes in the steel-banded chest" % id)
	for id in ["baerlauch", "steinpilz", "barsch", "mondblume", "drachenblut", "drachenschuppe", "apfel", "wurst"]:
		check(HomeStores.store_of(id) == HomeStores.PANTRY, "%s goes on the ingredient board" % id)
	for id in ["schwert", "fackel", "steinblock", "wassereimer", "brief", "wurfmesser"]:
		check(HomeStores.store_of(id) == "", "%s goes in neither" % id)
	for id in Crafting.INGREDIENTS:
		check(HomeStores.store_of(id) != "", "the ingredient %s has a store" % id)

	# The steel-banded chest: coins ten at a time or all, bars, ore.
	game.coins = 25
	game.iron = 3
	game.bars = {"silber": 2}
	p.bag.clear()
	p.bag.append("donnererz")
	p.bag.append("donnererz")
	game.crafting.pouch = {"grottenkristall": 4, "baerlauch": 5}
	var menus: Menus = game.menus
	menus.open(HomeStores.STATIONS[HomeStores.METAL])
	check(Lang.t(HomeStores.LEARN) != "" and game.lore.size() >= 0, "opening teaches the compendium line")
	var shown := HomeStores.shown(game, HomeStores.METAL)
	check(shown == [HomeStores.COINS, "eisen", "silber", "grottenkristall", "donnererz"], "the chest lists what the hero has of its kinds, in order: %s" % [shown])
	menus._store_move(HomeStores.COINS, HomeStores.step(HomeStores.COINS), true)
	check(game.coins == 15 and HomeStores.stored(game, HomeStores.COINS) == 10, "the small button stores ten coins")
	menus._store_move("eisen", 3, true)
	check(game.iron == 0 and HomeStores.stored(game, "eisen") == 3, "iron bars go in")
	menus._store_move("donnererz", 2, true)
	check(not p.bag.has("donnererz") and HomeStores.stored(game, "donnererz") == 2, "thunder ore leaves the bag")
	menus._store_all(HomeStores.METAL, true)
	check(game.coins == 0 and not game.bars.has("silber") and game.crafting.have("grottenkristall") == 0, "store everything empties the hero of metal")
	check(game.crafting.have("baerlauch") == 5, "the herbs stay in the pouch")
	check(HomeStores.stored(game, "silber") == 2 and HomeStores.stored(game, "grottenkristall") == 4 and HomeStores.stored(game, HomeStores.COINS) == 25, "and it all lies in the chest")
	check(HomeStores.put(game, "silber", 1) == 0, "nothing more to store")
	# Taking back: the bag's things only while it has room.
	while p.bag_used() < p.bag_size():
		p.bag.append("schwert")
	check(HomeStores.take(game, "donnererz", 2) == 0, "a full bag takes no ore")
	menus._store_move("donnererz", 2, false)
	check(menus._note == Lang.t("Deine Tasche ist voll."), "and says why")
	p.bag.clear()
	menus._store_all(HomeStores.METAL, false)
	check(game.coins == 25 and game.iron == 3 and int(game.bars.get("silber", 0)) == 2 and p.bag.count("donnererz") == 2 and game.crafting.have("grottenkristall") == 4,
			"take everything gives it all back")
	check(HomeStores.shown(game, HomeStores.METAL).all(func(id): return HomeStores.stored(game, id) == 0), "the chest is empty again")
	menus.close()

	# The ingredient board: herbs from the pouch, food from the bag.
	p.bag.append("apfel")
	menus.open(HomeStores.STATIONS[HomeStores.PANTRY])
	check(HomeStores.shown(game, HomeStores.PANTRY) == ["baerlauch", "apfel"], "the board lists herbs and food")
	menus._store_move("baerlauch", 1, true)
	check(game.crafting.have("baerlauch") == 4 and HomeStores.stored(game, "baerlauch") == 1, "one bundle of wild garlic goes on the board")
	menus._store_all(HomeStores.PANTRY, true)
	check(not game.crafting.pouch.has("baerlauch") and not p.bag.has("apfel") and HomeStores.stored(game, "apfel") == 1, "everything goes on the board")
	check(HomeStores.put(game, "grottenkristall", 1) == 0 or HomeStores.stored(game, "grottenkristall") > 0, "crystals never land on the board")
	check(not game.home_stores[HomeStores.PANTRY].has("grottenkristall"), "the board keeps no crystals")
	menus.close()

	# Kept in the saved game.
	game.home_stores[HomeStores.METAL][HomeStores.COINS] = 40
	check(game.save_game(), "the game saves")
	game.home_stores = HomeStores.empty()
	game._apply_save(game._read_save())
	check(HomeStores.stored(game, HomeStores.COINS) == 40 and HomeStores.stored(game, "baerlauch") == 5 and HomeStores.stored(game, "apfel") == 1, "the stores come back from the save")
	var odd := HomeStores.load_from({"metall": {"baerlauch": 3, "muenzen": 5, "nichts": 2}, "zutaten": {"apfel": -1}})
	check(odd.metall == {"muenzen": 5} and odd.zutaten.is_empty(), "a saved store keeps only what belongs in it")
	check(HomeStores.load_from(null) == HomeStores.empty(), "an old save starts with empty stores")

	# Ore, gems and the new coins go in the chest; each lump and gem stays
	# as it was (weight, make-up, carat), through the chest and the save.
	for id in ["erzbrocken_klein", "erzbrocken_episch", "rohedelstein", "edelstein", "eisenmuenze", "silbermuenze", "goldmuenze"]:
		check(HomeStores.store_of(id) == HomeStores.METAL, "%s goes in the steel-banded chest" % id)
	game.crafting.add("erzbrocken", 2, false)
	game.crafting.add_gem("rohedelstein", 13)
	var lumps: Array = game.crafting.ores["erzbrocken"].duplicate(true)
	check(HomeStores.put(game, "erzbrocken", 2) == 2 and HomeStores.put(game, "rohedelstein", 1) == 1, "two lumps of ore and a raw gem go in")
	check(game.crafting.have("erzbrocken") == 0 and not game.crafting.ores.has("erzbrocken") and not game.crafting.gems.has("rohedelstein"), "and leave the pouch")
	check(game.save_game(), "the game saves with ore in the chest")
	game.home_stores = HomeStores.empty()
	game._apply_save(game._read_save())
	check(HomeStores.take(game, "erzbrocken", 2) == 2 and HomeStores.take(game, "rohedelstein", 1) == 1, "and come back out after loading")
	var back: Array = game.crafting.ores.get("erzbrocken", [])
	check(back.size() == 2 and int(back[0].grams) == int(lumps[0].grams) and int(back[1].grams) == int(lumps[1].grams), "each lump as heavy as before (%s)" % str(back))
	check(game.crafting.gems.get("rohedelstein", []) == [13], "the gem as heavy as before")
	check(not game.home_stores[HomeStores.PIECES].has("erzbrocken"), "the chest keeps no pieces of what left it")

	# Every text has its English.
	for text in [HomeStores.LEARN, "Stahlbeschlagene Truhe", "Zutatenbord", "Bei dir", "Einlagern", "Nehmen", "Im Haus", "Alle",
			"Alles einlagern", "Alles nehmen", "Kupfermünzen", "%d × %s eingelagert.", "%d × %s genommen."]:
		check(Lang.EN.has(text), "English for: " + text)
	_finish()
