extends SceneTree
## Headless test: the epic 24-slot backpack. Its recipe scroll is epic loot, reading
## it teaches the recipe (once, and a known recipe keeps the scroll), the recipe makes
## the epic satchel from its ingredients, wearing it gives 24 slots, the merchants never
## sell either, and the inventory with 24 cells still fits a 1280 x 720 screen.
## Run with: godot --headless --fixed-fps 60 -s tests/epic_backpack.gd

const PACK := "tornister"
const SCROLL := "tornisterschnitt"

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
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _test() -> void:
	root.size = Vector2i(1280, 720)
	game.hero_name = "Epic backpack test"
	await _wait()
	var p: Player = game.player
	var crafting: Crafting = game.crafting

	# The items.
	check(Items.ALL.has(PACK) and Items.is_backpack(PACK), "the satchel is a backpack")
	check(Items.bag_size(PACK) == 24, "it holds 24 (%d)" % Items.bag_size(PACK))
	check(Level.tier_of(PACK) == "episch" and Rarity.tier(PACK) == "episch", "the satchel is epic")
	check(Items.ALL.has(SCROLL) and Items.is_recipe_scroll(SCROLL), "the scroll is a recipe scroll")
	check(Rarity.tier(SCROLL) == "episch", "the scroll is epic")
	check(Items.bag_size(PACK) > Items.bag_size("reiserucksack"), "it is bigger than every other backpack")
	for id in [PACK, SCROLL]:
		check(not Items.merchant_sells(id), "%s is not sold by merchants" % id)

	# The scroll is epic loot: part of what an epic roll can give.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := false
	for i in 6000:
		if Items.random_item(rng, Level.tier_rank("episch"), "", 14) == SCROLL:
			seen = true
			break
	check(seen, "an epic roll can give the scroll")
	check(Items.random_item(rng, 0, "", 0, {}, 0) != SCROLL, "plain loot never does")
	check(Items.random_item(rng, 0, "", 0, {}, Level.tier_rank("episch")) != PACK, "the finished satchel is not loot")

	# The recipe.
	var recipe: Dictionary = Crafting.RECIPES.get(SCROLL.replace("schnitt", ""), {})
	check(not recipe.is_empty() and recipe.result == PACK and recipe.giver == "", "a recipe makes the satchel")
	check(not crafting.knows("tornister"), "the recipe is not known at first")
	check(not recipe.has("found"), "no ingredient teaches it by itself")
	check(Crafting.RECIPES.tornister.ingredients.keys().all(func(i): return i == "eisen" or Crafting.INGREDIENTS.has(i)), "its ingredients exist")

	# Reading the scroll teaches it once and is used up.
	check(crafting.read_scroll(SCROLL) != "", "a scroll not in the bag cannot be read")
	p.bag.clear()
	p.bag.append(SCROLL)
	p.bag.append(SCROLL)
	check(crafting.read_scroll(SCROLL) == "", "reading works")
	check(crafting.knows("tornister"), "the recipe is learned")
	check(p.bag.count(SCROLL) == 1, "the read scroll is used up")
	check(crafting.read_scroll(SCROLL) != "" and p.bag.count(SCROLL) == 1, "a known recipe is not read again and keeps its scroll")

	# Making it.
	game.iron = 0
	check(crafting.why_not("tornister") != "", "it cannot be made without its ingredients")
	game.iron = 4
	crafting.add("drachenschuppe", 3, false)
	var level_needed := int(Crafting.RECIPES.tornister.craft_level)
	var why := crafting.why_not("tornister")
	check(why == "" or crafting.craft_level("feinschmieden") < level_needed, "only the craft level can hold it back: %s" % why)
	if why == "":
		p.bag.clear()
		check(crafting.make("tornister") == "" and p.bag.has(PACK), "the satchel is made into the bag")

	# Wearing it and the window.
	p.bag.clear()
	p.equipped.clear()
	p.equipped["rucksack"] = PACK
	check(p.bag_size() == 24, "wearing it, the bag has 24 slots (%d)" % p.bag_size())
	var menus: Menus = game.menus
	menus.open("inventar")
	await _wait()
	var rect: Rect2 = menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)
	check(root.get_visible_rect().encloses(rect), "the inventory with 24 slots fits the screen: %s" % rect)
	menus.close()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: epic backpack")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
