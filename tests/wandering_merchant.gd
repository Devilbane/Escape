extends SceneTree
## Headless test for Zarek, the wandering merchant: he comes every third
## night only, sets up with his cart on his pitch by the market and is gone at
## dawn; he sells tonight's ingredients and plain, basic gear (nothing
## magic, special or top of its kind), buys nothing, and his wares, the day
## count and what was bought are kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/wandering_merchant.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Wandering merchant test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: wandering merchant")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_rules()
	_items()
	_in_the_village()
	_trading()
	_saving()
	_counting_days()
	_finish()
	return true


## Which nights he comes, worked out from the day and the hour.
func _rules() -> void:
	check(not Wanderer.visits(0), "he does not come on the very first night")
	check(Wanderer.visits(1) and Wanderer.visits(4) and Wanderer.visits(7), "he comes every third night")
	check(not Wanderer.visits(2) and not Wanderer.visits(3), "he stays away in between")
	check(Wanderer.is_here(1, 22.0) and Wanderer.is_here(1, 4.5), "on his night he is there from nightfall to dawn (the day turns at dawn)")
	check(not Wanderer.is_here(2, 6.0) and not Wanderer.is_here(1, 12.0), "by day he is not there")
	check(Wanderer.nights_until(2) == 2 and Wanderer.nights_until(4) == 0, "the nights until his next visit")
	check(Wanderer.price("schwert") == 15 and Wanderer.price("rundschild") == 12, "gear costs a fifth more, rounded up")
	check(Wanderer.price("mondstein") == Wanderer.INGREDIENT_PRICES.mondstein, "an ingredient costs its own price")


## His wares: ingredients from far away and plain, basic gear only.
func _items() -> void:
	for id in Wanderer.INGREDIENT_PRICES:
		check(Crafting.INGREDIENTS.has(id), "%s is a known ingredient" % id)
		check(not Crafting.INGREDIENTS[id].get("rare", false) and id != "trueffel", "%s is not one of the rarest finds" % id)
	# Merchants sell nothing magic, special or top of its kind.
	for id in ["vampirzahn", "phoenixfeder", "gluecksklee", "dornenrune", "amulett_kraft", "zauberhut", "fechtbuch",
			"plattenpanzer", "axt", "eilstiefel", "rubinring", "grosser_rucksack", "langschwert", "rabenklinge", "schattenumhang"]:
		check(not Items.is_basic(id), "%s is not basic, so no merchant sells it" % id)
	for id in ["schwert", "rundschild", "lederwams", "lederstiefel", "wollumhang", "kupferring", "leinenrucksack"]:
		check(Items.is_basic(id), "%s is basic gear" % id)
	for night in [1, 4, 7, 10]:
		var wares := Wanderer.stock_for(night, HERO)
		var ingredients := wares.filter(Wanderer.is_ingredient)
		var gear := wares.filter(func(id): return not Wanderer.is_ingredient(id))
		var kinds := {}
		for id in ingredients:
			kinds[id] = true
		check(kinds.size() == Wanderer.INGREDIENT_KINDS, "three kinds of ingredient on night %d" % night)
		check(ingredients.size() <= Wanderer.INGREDIENT_KINDS * Wanderer.MAX_EACH, "a few pieces of each on night %d" % night)
		check(gear.size() == Wanderer.GEAR_COUNT, "two pieces of gear on night %d" % night)
		for id in gear:
			check(Items.is_basic(id), "%s on night %d is basic gear" % [id, night])
		check(wares == Wanderer.stock_for(night, HERO), "the same night brings the same wares")
	check(Wanderer.stock_for(1, HERO) != Wanderer.stock_for(4, HERO) or Wanderer.stock_for(4, HERO) != Wanderer.stock_for(7, HERO), "another visit brings other wares")


func _station() -> Dictionary:
	for s in game.level.stations:
		if s.kind == "wanderhaendler":
			return s
	return {}


func _cart_cell() -> Vector2i:
	return game.level._wanderer_cell + Outdoor.CART_OFFSET


## He arrives on his night, sets up on his pitch and leaves at dawn.
func _in_the_village() -> void:
	game.hero_name = HERO
	game.day = 1
	game.day_hour = 12.0
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	check(level._wanderer_cell.x >= 0, "the village has a pitch for the wandering merchant")
	check(level.wanderer == null and _station().is_empty(), "by day he is not in the village")
	check(not level.astar.is_point_solid(_cart_cell()), "by day his cart's spot is free")
	# Nightfall on his night.
	game.day_hour = 21.5
	level.day = game.day
	level.set_hour(game.day_hour)
	check(level.wanderer != null and level.wanderer.visible, "at nightfall he is in the village")
	check(level.wanderer != null and level.wanderer.role == Wanderer.ROLE, "he is the wandering merchant")
	check(level.world_to_cell(level.wanderer.global_position) == level._wanderer_cell, "he stands on his pitch")
	check(not _station().is_empty(), "he can be traded with")
	check(level._cart != null and level.astar.is_point_solid(_cart_cell()), "his cart stands behind him")
	var square: Vector2i = level.world_to_cell(level.spots.square[0])
	check(level.grid_path(square, level._wanderer_cell).size() > 1, "the way from the square to him is open")
	check(not level.wanderer.goes_to_bed(), "he does not go to bed")
	# Past midnight he is still there: the day only turns at dawn.
	level.set_hour(2.0)
	check(level.wanderer != null, "after midnight he is still there")
	# Dawn: he packs up.
	level.set_hour(5.5)
	check(level.wanderer == null and _station().is_empty(), "at dawn he is gone")
	check(level._cart == null and not level.astar.is_point_solid(_cart_cell()), "at dawn his cart is gone")
	# The next night is not his.
	level.day = 2
	level.set_hour(22.0)
	check(level.wanderer == null, "on the following night he stays away")
	# A game loaded on his night finds him there at once.
	game.day = 4
	game.day_hour = 23.0
	game.load_level(game._outdoor_index(), false)
	check(game.level.wanderer != null, "a game loaded on his night finds him there")


## He sells tonight's wares and buys nothing.
func _trading() -> void:
	game.coins = 1000
	game.player.bag.clear()
	var wares: Array[String] = game.wanderer_wares()
	check(game.wanderer_night == 4 and wares == Wanderer.stock_for(4, HERO), "tonight's wares")
	game.menus.open("wanderhaendler")
	check(game.menus.current == "wanderhaendler", "the trading window opens")
	check(game.lore.has(Menus.WANDERER_LEARN), "the compendium learns about him")
	# An ingredient goes into the pouch.
	var size := wares.size()
	var herb: String = wares.filter(Wanderer.is_ingredient)[0]
	var had: int = game.crafting.have(herb)
	game.menus._buy_from_wanderer(wares.find(herb))
	check(game.crafting.have(herb) == had + 1, "a bought ingredient is in the pouch")
	check(game.player.bag.is_empty(), "an ingredient does not take room in the bag")
	check(game.coins == 1000 - Wanderer.price(herb), "it cost his price")
	# Gear goes into the bag.
	var gear: String = game.wanderer_wares().filter(func(w): return not Wanderer.is_ingredient(w))[0]
	game.menus._buy_from_wanderer(game.wanderer_wares().find(gear))
	check(game.player.bag.has(gear), "bought gear is in the bag")
	check(game.coins == 1000 - Wanderer.price(herb) - Wanderer.price(gear), "the gear cost his price")
	check(game.wanderer_wares().size() == size - 2 and not game.wanderer_wares().has(gear), "what was bought is gone from his wares")
	game.coins = 0
	var left: int = game.wanderer_wares().size()
	game.menus._buy_from_wanderer(0)
	check(game.wanderer_wares().size() == left and game.coins == 0, "without gold nothing is bought")
	game.menus.close()


## The day, his wares and what was bought are kept in the saved game.
func _saving() -> void:
	var wares: Array = game.wanderer_wares().duplicate()
	check(game.save_game(), "the game is saved")
	var data: Dictionary = game._read_save(game.save_path(HERO))
	check(int(data.get("day", -1)) == 4, "the saved game holds the day")
	game.day = 0
	game.wanderer_stock.clear()
	game.wanderer_night = -1
	game._apply_save(data)
	check(game.day == 4, "loading brings the day back")
	check(game.wanderer_night == 4 and game.wanderer_stock == wares, "loading brings his wares back, without the one bought")
	data.erase("day")
	data.erase("wanderer")
	data.erase("wanderer_night")
	game._apply_save(data)
	check(game.day == 0 and game.wanderer_night == -1, "an older saved game starts on day 0")


## The clock counts the days: at dawn and through a night in the bed.
func _counting_days() -> void:
	game.day = 3
	game.load_level(game._outdoor_index(), false)
	var before_state = game.state
	game.state = game.State.PLAYING
	game.day_hour = 23.9
	game._tick_clock(30.0)
	check(game.day == 3, "midnight does not start a new day")
	game.day_hour = 4.8
	game._tick_clock(30.0)
	check(game.day == 4, "dawn starts a new day")
	game._tick_clock(30.0)
	check(game.day == 4, "only dawn starts a new day")
	game.state = before_state
	game.day_hour = 23.0
	game.sleep()
	check(game.day == 5, "a night in the bed ends on the next day")
	var data: Dictionary = game._read_save(game.save_path(HERO))
	check(int(data.get("day", -1)) == 5, "the next day is saved")
	# On his night the next morning's wares are new ones.
	game.day = 7
	game.day_hour = 22.0
	check(game.wanderer_wares() == Wanderer.stock_for(7, HERO) and game.wanderer_night == 7, "a new visit brings new wares")
