extends SceneTree
## The ossuary under the graveyard and the trader's task of the two skulls (see Ossuary): the shelves stand on free floor, the
## names are titled and unique, the two named skulls are on their own shelves, the task needs both and pays a charged diamond,
## and handing them in tells the fourth tale of the crypt.

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Lang.language = "en"
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._title.visible = false
	game.hero_name = "Ossuary test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await process_frame

	# Items and task.
	for id in [Ossuary.MEDUSA, Ossuary.SNOOPS, "geladener_diamant"]:
		check(Items.ALL.has(id) and Lang.EN.has(Items.ALL[id].name) and Lang.EN.has(Items.ALL[id].effect), "%s is an item with English texts" % id)
		check(Rarity.tier(id) != "", "%s has a rarity" % id)
	var q: Dictionary = Quests.ALL[Quests.SKULLS]
	check(q.giver == Wanderer.ROLE and q.kind == "bring" and q.reward == "geladener_diamant", "the trader asks for the skulls and pays the diamond")
	for key in ["title", "goal", "offer", "remind", "done"]:
		check(Lang.EN.has(q[key]), "the task's %s has English" % key)
	check(not game.quests.is_available(Quests.SKULLS), "the trader has no skull task before the crypt is open")
	game.graveyard_riddles.solve(GraveyardRiddles.OWL_CLOCK)
	check(game.quests.is_available(Quests.SKULLS), "he has it once the crypt is open")

	# The crypt.
	game.treasure_maps.state[OwlClock.ID] = TreasureMaps.OPEN
	game.go_inside(OwlClock.ID)
	for i in 160:
		await process_frame
	var crypt: Level = game.level
	check(crypt.building == OwlClock.ID, "inside the crypt")
	var shelves := crypt.stations.filter(func(s): return s.kind == Ossuary.KIND)
	check(shelves.size() >= 8, "there are shelves: %d" % shelves.size())
	var keys := shelves.filter(func(s): return s.skull != "")
	check(keys.size() == 2 and keys[0].skull != keys[1].skull, "two shelves hold the two named skulls")
	var plates := {}
	for s: Dictionary in shelves:
		var c: Vector2i = s.cell
		check(crypt.cell_char(c) == ".", "a shelf stands on plain floor at %s" % c)
		check(s.names.size() == Ossuary.TIERS * Ossuary.PLACES, "a shelf holds %d skulls" % (Ossuary.TIERS * Ossuary.PLACES))
		for n: String in s.names:
			check(not plates.has(n), "name %s is on one skull only" % n)
			plates[n] = true
	check(plates.has("Madame Medusa") and plates.has("Mr. Snoops"), "the plates read Madame Medusa and Mr. Snoops")
	check(plates.size() >= 100, "many names: %d" % plates.size())
	var titled := 0
	for n: String in plates:
		if n.contains(" "):
			titled += 1
	check(titled == plates.size(), "every name has a title")
	# The skulls are taken only while the task is open, and need room in the bag.
	var medusa: Dictionary = keys.filter(func(s): return s.skull == Ossuary.MEDUSA)[0]
	var snoops: Dictionary = keys.filter(func(s): return s.skull == Ossuary.SNOOPS)[0]
	game.player.bag.clear()
	Ossuary.use(game, medusa)
	check(not game.player.bag.has(Ossuary.MEDUSA), "no skull is taken before the task")
	game.quests.state[Quests.SKULLS] = {"state": "active", "count": 0}
	Ossuary.use(game, medusa)
	check(game.player.bag.has(Ossuary.MEDUSA), "Madame Medusa's skull is taken")
	check(not Ossuary.skull_node(medusa).visible, "and is gone from the shelf")
	Ossuary.use(game, medusa)
	check(game.player.bag.count(Ossuary.MEDUSA) == 1, "it is taken once")
	check(game.quests.progress(Quests.SKULLS) == "1 / 2", "one of two: %s" % game.quests.progress(Quests.SKULLS))
	Ossuary.use(game, snoops)
	check(game.quests.missing(Quests.SKULLS) == 0, "both skulls carried")

	# Handing them in to the trader.
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	for i in 20:
		await process_frame
	var trader: Villager = game.level.villagers[0]
	trader.role = Wanderer.ROLE
	var coins: int = game.coins
	var told := [false]
	Events.bus().graveyard_riddle.connect(func(id): told[0] = told[0] or id == GraveyardRiddles.SKULLS)
	check(game.quests.talk(trader, true), "the trader takes them")
	check(game.player.bag.has("geladener_diamant") and not game.player.bag.has(Ossuary.MEDUSA) and not game.player.bag.has(Ossuary.SNOOPS), "the diamond for the skulls")
	check(game.coins == coins + 40, "and some copper")
	check(game.quests.is_done(Quests.SKULLS) and told[0], "the fourth tale of the crypt is told")
	check(game.graveyard_riddles.solved.has(GraveyardRiddles.SKULLS), "the tales count it")

	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	print("PASS: ossuary" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
