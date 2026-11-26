extends SceneTree
## Headless test for the beekeeper and his honey (see Beekeeper, Apiary):
## - Ambrosius lives in the farming valley and trades honey in a window of his own;
## - the honey is an ingredient of the pouch, bought for copper, and the first jar teaches the honey draught,
##   which brews a healing potion from two jars;
## - the apiary stands beside him with its hives, flowers and bees, on free ground, solid where the hives stand;
## - every text the feature shows has English.
## Run with: godot --headless --fixed-fps 60 -s tests/beekeeper.gd

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
	if frames >= 5 and not started and "state" in game:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Beekeeper test"
	game.coins = 100
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level

	# --- The man ---------------------------------------------------------------------------
	var keeper: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == Beekeeper.ROLE:
			keeper = v
	check(keeper != null, "Ambrosius the beekeeper stands in the valley")
	check(Villager.ROLES.has(Beekeeper.ROLE) and Villager.ROLES[Beekeeper.ROLE].plan == "farm", "he keeps the farm day plan")
	check(keeper != null and keeper.station.kind == Beekeeper.KIND, "he trades honey (station kind)")
	check(keeper != null and keeper.find_child("BeeVeil", true, false) != null, "he wears the straw hat and veil")
	check(lvl.world_to_cell(keeper.global_position).y >= Outdoor.VALLEY_FROM, "he lives in the farming valley, not in the village")

	# --- The apiary -------------------------------------------------------------------------
	var api: Apiary = lvl.apiary
	check(api != null, "the level has an apiary")
	if api == null:
		_end()
		return
	check(api.hive_count() == 8, "four hive tiles make eight hives (%d)" % api.hive_count())
	check(api.flower_count() > 40, "the meadow round the hives has flowers (%d)" % api.flower_count())
	check(api.bee_count() == api.hive_count() * Apiary.BEES_PER_HIVE, "every hive has its bees")
	check(api.distance_to(keeper.global_position) < 10.0, "the beekeeper's place is among his hives")
	for h: Dictionary in api.hives:
		var node: Node3D = h.node
		check(node.get_child_count() > 8, "a hive is built of many parts (%s)" % node.name)
	var jobs := ValleyFolk.hive_spots(lvl)
	check(jobs.size() >= 4, "there are places in front of the hives to work at (%d)" % jobs.size())
	var picked := ValleyFolk.pick(keeper)
	check(not picked.is_empty() and ValleyFolk.hive_spots(lvl).any(func(s: Dictionary) -> bool: return s.spot.is_equal_approx(picked.spot)),
			"his day's job is at a hive")
	# The hero cannot walk through a hive.
	var first: Dictionary = api.hives[0]
	var c := lvl.world_to_cell(first.pos)
	check(not lvl.is_open(c) or lvl.cell_char(c) == Apiary.HIVE, "the hive's tile is a hive tile")

	# --- Honey ------------------------------------------------------------------------------
	check(Crafting.INGREDIENTS.has(Beekeeper.HONEY) and Crafting.RECIPES.has(Beekeeper.RECIPE), "honey is an ingredient and has its recipe")
	check(not game.crafting.knows(Beekeeper.RECIPE), "the hero does not know the honey draught yet")
	game.crafting.set_count(Beekeeper.HONEY, 0)
	game.trader_role = Beekeeper.ROLE
	game.menus.open(Beekeeper.KIND)
	await _wait(2)
	check(game.menus.current == Beekeeper.KIND, "the window opens")
	var had: int = game.coins
	game.menus._buy_honey(3)
	check(game.crafting.have(Beekeeper.HONEY) == 3, "the hero buys three jars into the pouch")
	check(game.coins == had - 3 * Beekeeper.price(game), "and pays for them")
	check(game.crafting.knows(Beekeeper.RECIPE), "the first jar teaches the honey draught")
	game.coins = 3
	game.menus._buy_honey(5)
	check(game.crafting.have(Beekeeper.HONEY) == 3, "without the copper no honey is sold")
	game.menus.close()
	game.state = game.State.PLAYING
	check(game.crafting.has_ingredients(Beekeeper.RECIPE), "two jars are enough for a brew")
	check(Crafting.RECIPES[Beekeeper.RECIPE].result == "heiltrank" and Crafting.RECIPES[Beekeeper.RECIPE].get("potency", false), "the draught is a healing potion by the brewer's skill")

	# --- English ----------------------------------------------------------------------------
	for key in [Villager.ROLES[Beekeeper.ROLE].name, "Imker", Beekeeper.NOTE, Beekeeper.LEARN, Apiary.LEARN, Apiary.VEXED, Apiary.STUNG,
			Crafting.INGREDIENTS[Beekeeper.HONEY].where, Crafting.RECIPES[Beekeeper.RECIPE].name, Crafting.INGREDIENTS[Beekeeper.HONEY].region]:
		check(Lang.EN.has(key), "English for: " + String(key).substr(0, 40))
	for line: String in Villager.ROLES[Beekeeper.ROLE].lines:
		check(Lang.EN.has(line), "English for his line: " + line.substr(0, 40))
	for job: Dictionary in ValleyFolk.JOBS:
		if String(job.who).contains(Beekeeper.ROLE):
			check(Lang.EN.has(job.say), "English for his job: " + String(job.say).substr(0, 40))
	_end()


func _end() -> void:
	if failures == 0:
		print("PASS: beekeeper")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
