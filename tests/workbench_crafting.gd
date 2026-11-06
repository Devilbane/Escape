extends SceneTree
## Headless test for making things at the workbenches on the crafting
## square: a bench lists the known recipes of its craft, says what is still
## missing, makes the piece from the pouch's ingredients (and the smith's
## iron) into the bag, or into the chest when the bag is full, and trains
## the craft. Recipes that are not complete yet cannot be made.
## Run with: godot --headless -s tests/workbench_crafting.gd

var failures := 0
var game: Node
var frames := 0
## Set at the very end of _test: a script error stops the test early.
var finished := false
const HERO := "Workbench test"


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
	check(finished, "the whole test ran through")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: workbench crafting")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	game.hero_name = HERO
	game.crafting.clear()
	game.storage.clear()
	game.iron = 0
	game.player.xp.clear()
	game.player.bag.clear()
	game.player.equipped.clear()
	game.load_level(game._outdoor_index(), false)
	var c: Crafting = game.crafting

	# Every recipe that makes something makes a crafted item with English texts.
	for id in Crafting.RECIPES:
		var r: Dictionary = Crafting.RECIPES[id]
		if r.has("result"):
			check(Items.ALL.has(r.result) and Items.ALL[r.result].get("crafted", false), "%s makes a crafted item" % id)
			check(Lang.EN.has(Items.ALL[r.result].name), "%s: the item has an English name" % id)
			check(not CraftingSquare.bench_of(r.craft).is_empty(), "%s can be made at a bench on the square" % id)
	check(Lang.EN.has(Menus.MADE_LEARN), "the how-to has an English text")

	# Nothing known yet.
	check(c.recipes_for("feinschmieden").is_empty(), "a new hero has nothing to make")
	check(c.make("klingenring") != "", "an unknown recipe cannot be made")

	# A known recipe says what is missing.
	c.learn_recipe("klingenring")
	c.learn_recipe("mondsilberring")
	check(c.recipes_for("feinschmieden") == ["mondsilberring", "klingenring"], "the bench lists the known recipes of its craft")
	check(c.recipes_for("alchemie").is_empty(), "another craft's bench lists none of them")
	var why: String = c.why_not("klingenring")
	check(why.contains("Mondsilbererz") and why.contains("2 Eisenbarren"), "the bench says what is missing")
	check(c.why_not("mondsilberring") == "Das Rezept ist noch nicht vollständig.", "a recipe without a result cannot be made yet")

	# The window at the bench.
	game.menus.bench = "feinschmieden"
	game.menus.open("werkbank")
	check(game.menus.current == "werkbank", "the bench window opens")
	game.menus._make_recipe("klingenring")
	check(game.menus._note == why, "trying without the ingredients says what is missing")
	check(game.player.bag.is_empty(), "nothing is made without the ingredients")

	# Everything there: the piece is made.
	c.add("mondsilbererz", 2, false)
	c.add("glimmermoos", 1, false)
	game.iron = 3
	check(c.why_not("klingenring") == "", "with every ingredient the recipe can be made")
	game.menus._make_recipe("klingenring")
	check(game.player.bag == ["klingenring"], "the ring goes into the bag")
	check(game.menus._note.contains("Klingenring"), "the bench says what was made")
	check(c.have("mondsilbererz") == 1 and c.have("glimmermoos") == 0 and game.iron == 1, "the ingredients and iron are used up")
	check(not c.pouch.has("glimmermoos"), "a used-up ingredient leaves the pouch")
	check(game.player.xp.get("feinschmieden", 0.0) > 0.0, "making it trains the craft")
	check(game.lore.has(Menus.MADE_LEARN), "the compendium explains making things")
	game.menus.close()

	# The ring does what its recipe says.
	game.player.equipped["ring"] = "klingenring"
	game.player.refresh_stats()
	check(game.player.skill("klingen") >= 1, "the Blade Ring adds a level of Blades")
	game.player.equipped.erase("ring")

	# A full bag: the piece waits in the chest.
	while game.player.bag.size() < game.player.bag_size():
		game.player.bag.append("kupferring")
	c.learn_recipe("axtreif")
	c.add("hoehlenpilz", 2, false)
	game.iron = 3
	check(c.make("axtreif") == "", "the bracelet is made with a full bag")
	check(game.storage.has("axtreif") and not game.player.bag.has("axtreif"), "with a full bag it goes into the chest")

	# Practice makes the craft grow, and the level shows at the bench.
	var before: int = c.craft_level("feinschmieden")
	for i in 4:
		c.add("hoehlenpilz", 2, false)
		game.iron = 3
		c.make("axtreif")
	check(c.craft_level("feinschmieden") > before, "making things raises the craft's level")
	game.menus.open("werkbank")
	check(game.menus.current == "werkbank", "the bench window opens again")
	game.menus.close()
	finished = true
