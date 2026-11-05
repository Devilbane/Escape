extends SceneTree
## Headless test: the purse (Crafting.purse). Every coin (copper as the
## money in game.coins, iron, silver and gold in the purse) and the cut and
## uncut gems are carried in the purse: they never take a place in the bag
## or the ingredient pouch, come back from the saved game, older games move
## them out of the pouch, and Gorm still melts coins and cuts gems from it.
## Run with: godot --headless -s tests/purse.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Purse test"
	await _wait(10)
	var c: Crafting = game.crafting
	var p: Player = game.player
	c.clear()
	p.bag.clear()
	var bag_used := p.bag_used()

	# What goes in the purse, and what does not.
	for id in ["eisenmuenze", "silbermuenze", "goldmuenze", "kupfermuenze", Ore.UNCUT, Ore.CUT]:
		check(Crafting.in_purse(id), "%s is carried in the purse" % id)
	for id in ["baerlauch", "mondstein", "erzbrocken"]:
		check(not Crafting.in_purse(id), "%s stays in the pouch" % id)

	# Coins and gems found go into the purse, not the pouch or the bag.
	c.add("eisenmuenze", 150, false)
	c.add("silbermuenze", 4, false)
	c.add("goldmuenze", 2, false)
	c.add_gem(Ore.UNCUT, 13)
	c.add_gem(Ore.UNCUT, 6)
	c.add_gem(Ore.CUT, 9)
	c.add("baerlauch", 3, false)
	check(c.purse == {"eisenmuenze": 150, "silbermuenze": 4, "goldmuenze": 2, Ore.UNCUT: 2, Ore.CUT: 1}, "coins and gems are in the purse (%s)" % c.purse)
	check(c.pouch == {"baerlauch": 3}, "the pouch holds only the herbs (%s)" % c.pouch)
	check(p.bag_used() == bag_used, "nothing of it takes a bag slot")
	check(c.have("eisenmuenze") == 150 and c.have(Ore.UNCUT) == 2, "the counts are read from the purse")
	check(game.coins_held("silbermuenze") == 4, "the coin tab counts the purse")

	# The inventory's pouch tab leaves them out; the purse tab shows them.
	var menus: Menus = game.menus
	menus.open("inventar")
	await _wait()
	check(menus._pouch_ids() == ["baerlauch"], "the pouch tab lists no coins or gems (%s)" % str(menus._pouch_ids()))
	menus._show_inventory_tab("tasche")
	await _wait()
	var size: Vector2 = menus._panel.size
	menus._show_inventory_tab("muenzen")
	await _wait()
	check(menus._panel.size == size, "the purse tab keeps the window's size (%s, was %s)" % [menus._panel.size, size])
	var texts := menus._box.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check(texts.any(func(t): return Crafting.ingredient_name(Ore.UNCUT) in t), "the purse tab shows the uncut gems")
	check(texts.any(func(t): return "13 ct" in t and "6 ct" in t), "with each gem's weight")
	menus.close()

	# Taking out of the purse: putting coins down, recipes, the home chest.
	check(game.put_coins_down("goldmuenze", 1) == 1 and c.have("goldmuenze") == 1, "a gold coin goes down from the purse")
	c.take("silbermuenze", 4)
	check(not c.purse.has("silbermuenze"), "an empty kind leaves the purse")
	HomeStores.put(game, Ore.UNCUT, 1)
	check(c.have(Ore.UNCUT) == 1 and HomeStores.stored(game, Ore.UNCUT) == 1, "a gem goes from the purse into the chest")
	HomeStores.take(game, Ore.UNCUT, 1)
	check(c.purse.get(Ore.UNCUT, 0) == 2 and not c.pouch.has(Ore.UNCUT), "and comes back into the purse")

	# Gorm melts a hundred coins of one metal into a bar from the purse.
	var iron_before: int = game.iron
	check(Forge.melt_coins(game, "eisenmuenze") == "", "Gorm melts iron coins from the purse")
	check(c.have("eisenmuenze") == 50 and game.iron == iron_before + 1, "a hundred coins make one iron bar")
	check(Forge.melt_coins(game, "eisenmuenze") != "", "fifty are not enough")
	# And cuts a gem from the purse.
	var cut := Forge.cut_gem(game)
	check(cut.why == "" and c.have(Ore.CUT) == 2 and c.have(Ore.UNCUT) == 1, "Gorm cuts an uncut gem from the purse")

	# Kept in the saved game.
	var saved: Dictionary = c.for_save()
	c.clear()
	c.load_from(saved)
	check(c.purse == saved.purse and c.gems == saved.gems, "the purse comes back from the saved game")

	# An older game kept coins and gems in the pouch: they move to the purse.
	c.load_from({"pouch": {"eisenmuenze": 30, "goldmuenze": 1, "rohedelstein": 1, "baerlauch": 2}, "gems": {"rohedelstein": [7]}})
	check(c.pouch == {"baerlauch": 2}, "the old pouch keeps only the herbs (%s)" % c.pouch)
	check(c.purse == {"eisenmuenze": 30, "goldmuenze": 1, "rohedelstein": 1}, "its coins and gem are in the purse (%s)" % c.purse)
	check(c.gems.get("rohedelstein", []) == [7], "the gem keeps its weight")

	# Every text has its English.
	for text in ["Geldbeutel", "Infos", "%s kommt in deinen Geldbeutel. Du findest ihn im Inventar (I) als eigenen Reiter."]:
		check(Lang.EN.has(text), "English for: %s" % text)

	game.delete_save(game.save_path())
	print("PASS: purse" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
