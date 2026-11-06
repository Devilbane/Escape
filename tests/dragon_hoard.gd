extends SceneTree
## Headless test for the old dragon's little helpers and its hoard (see
## DragonHoard and DragonHelpers): at night dragonlings fly out of the lair's
## arch and carry off all that lies on the open ground, but nothing at the
## hero's feet; the more lies about, the more of them come; gear melts into
## gold, coins of other metals into grams, books and cloth burn, task items
## and unique blades go whole to the Great Old One. What is left at daybreak
## they fetch in the morning. What lay about while the hero was elsewhere is
## gone by morning, on every map and in every building, and the event log
## says what the night brought. The hoard is kept in the saved game,
## lies in the lair beside the chest (and in no other lair), and is the hero's
## once the dragon fell. Most of what the helpers carry goes further down, to
## the Great Old One (see ElderLair), gear kept whole; that share is kept in the
## saved game too.
## Run with: godot --headless -s tests/dragon_hoard.gd

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
	if failures == 0:
		print("PASS: dragon hoard")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _floor_ids(lvl: Level) -> Array:
	return lvl.floor_items.map(func(e): return str(e[1]) if e[0] == "item" else "coin")


## Lets the helpers work for up to `seconds` of game time.
func _run_helpers(helpers: DragonHelpers, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		helpers._process(0.1)
		t += 0.1


func _test() -> void:
	# What becomes of what.
	check(DragonHoard.fate("item", "schwert") == "melt", "a sword is melted down")
	check(DragonHoard.fate("item", "fechtbuch") == "burn", "a book burns")
	check(DragonHoard.fate("item", "wollumhang") == "burn", "a wool cloak burns")
	check(DragonHoard.fate("item", "fackel") == "burn", "a torch burns")
	check(DragonHoard.fate("item", "brief") == "keep", "a task item is kept whole")
	check(DragonHoard.fate("item", "rabenklinge") == "keep", "a unique blade is kept whole")
	check(DragonHoard.fate("item", Items.KNIFE) == "melt", "a throwing knife is melted down")
	check(DragonHoard.fate("coin", "") == "coin", "coins are gathered")
	check(DragonHoard.fate("coin", "silbermuenze") == "melt", "silver coins are melted down")
	check(DragonHoard.melt_coins("silbermuenze", 3) == {"g:silber": 3 * Ore.COIN_GRAMS}, "silver coins melt into their grams")
	check(DragonHoard.melt_coins("eisenmuenze", 2) == {"g:eisen": 2 * Ore.COIN_GRAMS}, "iron coins melt into iron")
	check(DragonHoard.melt_coins("", 5).is_empty(), "the money is not melted")
	check(DragonHelpers.out_limit(0) == DragonHelpers.MIN_OUT and DragonHelpers.out_limit(100) == DragonHelpers.MAX_OUT, "more helpers come the more lies about")
	check(DragonHelpers.spawn_gap(40) < DragonHelpers.spawn_gap(0), "and they come quicker")
	check(DragonHoard.melt("schwert") == Forge.melt_into("schwert"), "a sword melts into what the smith gets from it")
	check(DragonHoard.melt("rubinring").has("g:silber"), "a ruby ring into silver")
	check(DragonHoard.melt("knochenhelm") == {"g:bronze": Forge.melt_into("knochenhelm", true)["g:bronze"]}, "the dragon's fire melts even a bone helmet")
	check(DragonHoard.melt("fechtbuch").is_empty(), "a burnt book leaves nothing")

	game.hero_name = "Hoard test"
	game.escaped = true
	game.hoard.clear()
	var outdoor: int = game._outdoor_index()
	var key: String = game.level_files[outdoor].get_file()
	game.floors.clear()
	game.day_hour = 12.0
	game.load_level(outdoor, false)
	var lvl: Outdoor = game.level
	var helpers: DragonHelpers = lvl.get_node_or_null("DragonHelpers")
	check(helpers != null, "the helpers live by the lair's arch")
	if helpers == null:
		return
	var p: Player = game.player

	# Things on the ground, the hero standing beside one of them.
	var den: Vector3 = lvl.doors.E
	var far := den + Vector3(10.0, 0, 14.0)
	lvl._drop_item("schwert", far)
	lvl._drop_item("fechtbuch", far + Vector3(2.0, 0, 0))
	lvl._drop_item("brief", far + Vector3(0, 0, 2.0))
	# Two purses spilt apart: two piles of a coin each.
	lvl._drop_coins(far + Vector3(-3.0, 0, 0), 1)
	lvl._drop_coins(far + Vector3(-3.0, 0, -4.0), 1)
	var feet := den + Vector3(-16.0, 0, 18.0)
	lvl._drop_item("axt", feet)
	p.global_position = Vector3(feet.x, p.global_position.y, feet.z)
	var on_floor: int = lvl.floor_items.size()
	check(on_floor == 6, "six things lie on the ground (%d)" % on_floor)

	# By day the helpers stay home.
	_run_helpers(helpers, 10.0)
	check(helpers.helpers.is_empty() and lvl.floor_items.size() == on_floor, "by day nothing is taken")

	# Night falls: they fly out and take what they may.
	lvl.set_hour(23.0)
	game.day_hour = 23.0
	check(lvl.night, "it is night")
	_run_helpers(helpers, 60.0)
	var left := _floor_ids(lvl)
	check(left.has("axt"), "nothing is snatched from the hero's feet")
	check(not left.has("schwert") and not left.has("fechtbuch") and not left.has("coin") and not left.has("brief"), "the rest is carried off, the letter too (%s)" % str(left))
	check(game.hoard.elder_items.has("brief"), "the letter went whole to the Great Old One")
	# Of every three things carried home, the first stays with Glutschlund and
	# the other two go down to the Great Old One, gear kept whole.
	var sword_melted: bool = game.hoard.metals == Forge.melt_into("schwert")
	check(game.hoard.gold + game.hoard.elder_gold == 2 and (sword_melted != game.hoard.elder_items.has("schwert")), "the sword went to one hoard, and two coins (%d + %d, %s, %s)" % [game.hoard.gold, game.hoard.elder_gold, str(game.hoard.metals), str(game.hoard.elder_items)])
	check(int(game.hoard.tonight.elder) == 3 and game.hoard.carried == 3, "two of the three things went to the Great Old One, and the letter (%d)" % int(game.hoard.tonight.elder))
	check(int(game.hoard.tonight.burnt) == 1, "the book burnt")
	check(game.lore.has(DragonHoard.LORE), "the compendium learns of the helpers")
	check(lvl.floor_pickups().size() == 1, "only the axe is still there for them to take")
	check(helpers.helpers.is_empty(), "the helpers all went home")

	# The hero steps away: then the axe goes too.
	p.global_position = Vector3(den.x + 40.0, p.global_position.y, den.z + 40.0)
	_run_helpers(helpers, 30.0)
	check(not _floor_ids(lvl).has("axt"), "once the hero stepped away the axe is taken")

	# Morning in sight of the helpers: the event log tells the night's tally.
	var gold_before: int = game.hoard.gold
	game._new_day()
	var said: Array = game.event_log.entries().filter(func(t): return "6" in t and Lang.t("Eisenbarren") in t and Lang.t("Verbrannt: %d.") % 1 in t)
	check(not said.is_empty(), "the event log tells what the night brought: %s" % str(game.event_log.entries()))
	check(int(game.hoard.tonight.things) == 0, "the tally starts afresh")
	check(game.hoard.gold == gold_before, "nothing more went at dawn")

	# A great heap of things: more helpers come, and what is left at daybreak
	# they fetch in the morning twilight, all of it.
	lvl.set_hour(4.0)
	game.day_hour = 4.0
	for i in 24:
		lvl._drop_item("schwert", den + Vector3(6.0 + (i % 6) * 2.0, 0, 30.0 + (i / 6) * 2.0))
	_run_helpers(helpers, 3.0)
	check(helpers.helpers.size() > DragonHelpers.MIN_OUT, "many helpers fly out for a great heap (%d)" % helpers.helpers.size())
	lvl.set_hour(7.0)
	game.day_hour = 7.0
	check(not lvl.night, "the day broke")
	game._new_day()
	check(not helpers.leftovers.is_empty(), "something was still lying about at daybreak")
	_run_helpers(helpers, 120.0)
	check(lvl.floor_pickups().is_empty(), "in the morning twilight they fetched the rest (%d left)" % lvl.floor_pickups().size())
	check(helpers.leftovers.is_empty() and helpers.helpers.is_empty(), "then they stay home for the day")
	lvl._drop_item("axt", den + Vector3(10.0, 0, 10.0))
	_run_helpers(helpers, 10.0)
	check(_floor_ids(lvl).has("axt"), "what falls by day waits for the night")
	lvl.take_from_floor(lvl.floor_pickups()[0]).queue_free()

	# While the hero was in a building: by morning the open air is swept,
	# and every other building's floor too, task items and all.
	game.floors[key] = [["item", "kettenhemd", 1.0, 1.0], ["coin", "", 2.0, 2.0], ["item", "wassereimer", 3.0, 3.0]]
	game.floors["haus.txt#2"] = [["item", "schwert", 1.0, 1.0]]
	var refuge := -1
	for i in game.level_files.size():
		if "zuflucht" in game.level_files[i]:
			refuge = i
	game.load_level(refuge, false)
	gold_before = game.hoard.gold + game.hoard.elder_gold
	var elder_before: int = game.hoard.elder_items.size()
	game._new_day()
	check(game.floors[key].is_empty(), "the open air was swept by morning, all of it: %s" % str(game.floors[key]))
	check(game.hoard.gold + game.hoard.elder_gold == gold_before + 1 and game.hoard.elder_items.size() == elder_before + 2 and game.hoard.elder_items.has("kettenhemd") and game.hoard.elder_items.has("wassereimer"), "the chain mail, the bucket and the coin went down to the Great Old One: %s" % str(game.hoard.elder_items))
	check(game.lore.has(DragonHoard.ELDER_LORE), "the compendium learns where most of the loot goes")
	check(game.floors["haus.txt#2"].is_empty(), "a building's floor is swept too")
	check(game.lore.has(DragonHoard.EVERYWHERE_LORE), "the compendium learns that they go everywhere")
	check(game.looted.get("haus.txt", {}).has("schwert"), "what they took counts as taken on its map")

	# On the map the hero is on, awake: gone by morning, all but what lies
	# right beside the hero.
	var cell: Level = game.level
	var hero_at: Vector3 = game.player.global_position
	cell._drop_item("schwert", hero_at + Vector3(0.5, 0, 0.5))
	cell._drop_item("axt", hero_at + Vector3(12.0, 0, 0))
	cell._drop_coins(hero_at + Vector3(0, 0, 12.0), 3, "silbermuenze")
	var grams_before := int(game.hoard.metals.get("g:silber", 0))
	game._new_day()
	var here := _floor_ids(cell)
	check(here == ["schwert"], "only the sword at the hero's feet is left: %s" % str(here))
	check(int(game.hoard.metals.get("g:silber", 0)) == grams_before + 3 * Ore.COIN_GRAMS, "the silver coins melted into the hoard (%s)" % str(game.hoard.metals))

	# Asleep in the open: what lies there vanishes from the ground too.
	game.floors.erase("haus.txt#2")
	for k in game.floors.keys():
		if k != key:
			game.floors[k].clear()
	game.load_level(outdoor, false)
	lvl = game.level
	lvl._drop_item("streitaxt", lvl.doors.E + Vector3(8.0, 0, 8.0))
	game._new_day(true)
	check(not _floor_ids(game.level).has("streitaxt") and game.level.floor_pickups().is_empty(), "asleep in the open, the battle axe is gone by morning")

	# Kept in the saved game; an old save has an empty hoard.
	game.hoard.metals["mondsilbererz"] = 1
	var hoard_gold: int = game.hoard.gold
	var hoard_metals: Dictionary = game.hoard.metals.duplicate()
	var elder_gold: int = game.hoard.elder_gold
	var elder_items: Array[String] = game.hoard.elder_items.duplicate()
	check(game.save_game(true), "the game saves")
	game.hoard.clear()
	var data: Dictionary = game._read_save()
	game._apply_save(data)
	check(game.hoard.gold == hoard_gold and game.hoard.metals == hoard_metals, "the hoard is kept in the saved game (%d, %s)" % [game.hoard.gold, str(game.hoard.metals)])
	check(game.hoard.elder_gold == elder_gold and game.hoard.elder_items == elder_items, "the Great Old One's share is kept in the saved game (%d, %s)" % [game.hoard.elder_gold, str(game.hoard.elder_items)])
	data.erase("hoard")
	game._apply_save(data)
	check(game.hoard.is_empty(), "a game saved before the hoard has an empty one")
	game.hoard.gold = hoard_gold
	game.hoard.metals = hoard_metals.duplicate()

	# The other lairs below the wild have chests but no dragon: no hoard there,
	# and no word of Embermaw guarding one.
	for spot in [["loch1", "the open grave"], ["loch2", "the spider hole"], ["loch3", "the pale depths"]]:
		game.load_level(game.interiors[spot[0]], false)
		var hole: Level = game.level
		check(hole.lair and not hole.guards_hoard(), "%s is a lair without the dragon" % spot[1])
		check(hole._pickups.filter(func(q): return q.kind == "hoard").is_empty(), "no hoard lies in %s" % spot[1])

	# In the lair the gold lies beside the chest, the dragon's to guard.
	game.load_level(game.interiors["E3"], false)
	var lair: Level = game.level
	check(lair.lair, "into the dragon's lair")
	var heaps: Array = lair._pickups.filter(func(q): return q.kind == "hoard")
	check(heaps.size() == 1, "the hoard lies in the lair")
	if heaps.is_empty():
		return
	var heap: Node3D = heaps[0].node
	for metal in hoard_metals.keys().filter(func(m): return Forge.METALS.has(m)):
		check(heap.get_node_or_null("Barren_" + metal) != null, "a stack of %s lies by the heap" % metal)
	var coins_before: int = game.coins
	game.iron = 0
	game.bars = {}
	game.metal_grams = {}
	game.crafting.pouch.erase("mondsilbererz")
	game.player.global_position = Vector3(heap.global_position.x, game.player.global_position.y, heap.global_position.z)
	lair._check_pickups()
	check(game.coins == coins_before and game.hoard.gold == hoard_gold, "while the dragon lives the gold stays its own")
	lair.lair_cleared = true
	lair._check_pickups()
	check(game.coins == coins_before + hoard_gold, "once it fell the coins are the hero's (+%d)" % (game.coins - coins_before))
	check(game.iron == int(hoard_metals.eisen), "the iron goes to the smith's iron bars (%d)" % game.iron)
	check(int(game.metal_grams.get("bronze", 0)) == int(hoard_metals.get("g:bronze", 0)) and hoard_metals.has("g:bronze"), "the bronze to the hero's metal in grams (%s)" % str(game.metal_grams))
	check(game.crafting.have("mondsilbererz") == 1, "the moon silver into the pouch")
	check(game.hoard.is_empty(), "the hoard is empty again")
