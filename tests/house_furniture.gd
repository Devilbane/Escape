extends SceneTree
## Furniture for the self-built house (see HouseFurniture and HouseFurnisher): the furnisher in
## the village sells it, the furnishing tool puts it down inside the built house (on a floor under
## a roof, not across walls, in front of doors or on other pieces; torches and paintings on a
## wall), and placed pieces work like their counterparts in the old town house.

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## Builds a small house on the plan at once: a room of 3 x 2 cells at (1, 1) with walls round
## it, a door in the south wall, a flat roof over it, and a cellar cell with a ceiling.
func _build_house(plan: HouseSketch) -> void:
	for x in range(1, 4):
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 3, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.DOOR if x == 3 else HouseSketch.WALL, "state": HouseSketch.BUILT}
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		plan.pieces[HouseSketch.key_of(1, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(4, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	game.hero_name = "Furniture test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var level: Outdoor = game.level
	# The furnisher stands in the village and opens a merchant's window.
	var ilse: Array = level.villagers.filter(func(v): return v.role == "µ")
	check(ilse.size() == 1, "the village has one furnisher")
	check(level.stations.any(func(s): return s.kind == "raumausstatter"), "she is a station")
	check(Menus.TRADE_WINDOWS.has("raumausstatter"), "her window is a merchant's window")
	var furnisher: HouseFurnisher = game.house_furnisher
	check(furnisher != null, "the open map has the furnishing tool")
	# A plot and a built house.
	var found := Rect2i()
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(level, r) == "":
				found = r
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var plan: HouseSketch = game.house_sketcher.plan
	_build_house(plan)
	plan.save(game.hero_name)
	game.house_sketcher.refresh()
	# Buying at the furnisher: the piece goes into the store, the money out of the purse.
	game.coins = 1000
	game.trader_role = "µ"
	game.menus.open("raumausstatter")
	check(Menus.fixed_size("raumausstatter") == Menus.fixed_size("haendler"), "her window has every merchant's size")
	game.menus._buy_furniture("bett")
	game.menus._buy_furniture("truhe")
	game.menus._buy_furniture("fackel")
	game.menus._buy_furniture("trophaeen")
	game.menus.close()
	var store := HouseFurniture.of(game.hero_name)
	check(store.count("bett") == 1 and store.count("truhe") == 1 and store.count("fackel") == 1, "bought pieces wait in the store")
	var paid: int = game.trader_price(100) + game.trader_price(50) + game.trader_price(25) + game.trader_price(150)
	check(game.coins == 1000 - paid, "the purse paid for them (%d left)" % game.coins)
	# The rules.
	check(HouseFurniture.floor_problem(plan, 0, Vector2i(0, 0)) == "no roof", "no furniture outdoors")
	check(HouseFurniture.floor_problem(plan, 0, Vector2i(1, 1)) == "", "inside under the roof is floor")
	check(HouseFurniture.floor_problem(plan, -1, Vector2i(1, 1)) == "no floor", "no cellar dug, no cellar floor")
	check(store.problem(plan, "bett", 0, 2, 2, 0) == "no roof", "a bed reaching out of the house does not fit")
	check(store.problem(plan, "truhe", 0, 3, 2, 0) == "door", "the cell in front of the door stays free")
	check(store.problem(plan, "fackel", 0, 2, 2, 0) == "needs wall", "a torch needs a wall behind it")
	check(store.problem(plan, "fackel", 0, 2, 1, 0) == "", "a torch hangs on the north wall")
	# A wall through the middle stops a big piece.
	plan.pieces[HouseSketch.key_of(2, 1, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	check(store.problem(plan, "bett", 0, 1, 1, 0) == "wall", "no piece across a wall")
	plan.pieces.erase(HouseSketch.key_of(2, 1, HouseSketch.ORIENT_Y))
	# The tool puts them down.
	furnisher.enter()
	check(furnisher.active, "the tool opens")
	check(furnisher._bar.visible, "its bar shows")
	var bar_size: Vector2 = furnisher._bar.get_combined_minimum_size()
	furnisher.select("bett")
	furnisher.click(HouseFurniture.centre(plan, "bett", 0, 1, 1, 0))
	check(HouseFurniture.of(game.hero_name).count("bett") == 0, "the bed is put down")
	furnisher.select("truhe")
	furnisher.click(HouseFurniture.centre(plan, "truhe", 0, 1, 1, 0))
	check(HouseFurniture.of(game.hero_name).count("truhe") == 1, "not on top of the bed")
	furnisher.click(HouseFurniture.centre(plan, "truhe", 0, 3, 1, 0))
	check(HouseFurniture.of(game.hero_name).count("truhe") == 0, "the chest goes beside it")
	furnisher.select("fackel")
	furnisher.hover(plan.cell_world(2, 1) + Vector3(0, 0, -0.8))
	check(furnisher.rot == 0, "a torch near the north wall turns its back to it")
	furnisher.click(plan.cell_world(2, 1) + Vector3(0, 0, -0.8))
	check(HouseFurniture.of(game.hero_name).count("fackel") == 0, "the torch hangs on the wall above the bed")
	furnisher.turn()
	check(furnisher._bar.get_combined_minimum_size() == bar_size, "the bar keeps its size as pieces are put down")
	# Dragging a placed piece: hold the left button on it, let go somewhere else.
	var chest_at := func() -> Vector2i:
		var p: Array = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "truhe")
		return Vector2i(p[0].x, p[0].y) if p.size() == 1 else Vector2i(-1, -1)
	furnisher.furniture = HouseFurniture.of(game.hero_name)
	check(furnisher.grab(plan.cell_world(3, 1), Vector2(100, 100)), "pressing on the chest takes hold of it")
	check(furnisher.dragging() and furnisher.tool == "truhe", "the chest is held")
	furnisher.drop(plan.cell_world(3, 2), Vector2(100, 100))
	check(chest_at.call() == Vector2i(3, 1), "a click without moving leaves it where it stood")
	furnisher.grab(plan.cell_world(3, 1), Vector2(100, 100))
	furnisher.drop(plan.cell_world(3, 2), Vector2(100, 180))
	check(chest_at.call() == Vector2i(3, 1), "dragged in front of the door it goes back (%s)" % [chest_at.call()])
	check(not furnisher.dragging(), "and is let go")
	furnisher.grab(plan.cell_world(3, 1), Vector2(100, 100))
	furnisher.drop(plan.cell_world(1, 1), Vector2(40, 100))
	check(chest_at.call() == Vector2i(3, 1), "not onto the bed")
	# Make room: the bed goes back into the store for a moment.
	var bed_store := HouseFurniture.of(game.hero_name)
	bed_store.pick_up(bed_store.piece_at(0, Vector2i(1, 1)))
	bed_store.save(game.hero_name)
	furnisher.furniture = bed_store
	furnisher.grab(plan.cell_world(3, 1), Vector2(100, 100))
	furnisher.drop(plan.cell_world(2, 2) + Vector3(0.1, 0, 0.1), Vector2(60, 160))
	check(chest_at.call() == Vector2i(2, 2), "dragged to a free square it stands there (%s)" % [chest_at.call()])
	check(HouseFurniture.of(game.hero_name).count("truhe") == 0, "moving does not put it into the store")
	furnisher.grab(plan.cell_world(2, 2), Vector2(60, 160))
	furnisher.drop(plan.cell_world(3, 1), Vector2(100, 100))
	check(chest_at.call() == Vector2i(3, 1), "and back again")
	var back_bed := HouseFurniture.of(game.hero_name)
	check(back_bed.place(plan, "bett", 0, 1, 1, 0) == "", "the bed goes back")
	back_bed.save(game.hero_name)
	furnisher.furniture = back_bed
	# A torch dragged from the north wall onto the west wall turns to it.
	var torch: Array = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "fackel")
	check(torch.size() == 1 and torch[0].rot == 0, "the torch hangs on the north wall")
	furnisher.furniture = HouseFurniture.of(game.hero_name)
	furnisher.storey = 0
	check(furnisher.grab(plan.cell_world(2, 1) + Vector3(0, 0, -0.8), Vector2(0, 0)), "the torch can be taken off the wall")
	furnisher.drop(plan.cell_world(1, 2) + Vector3(-0.8, 0, 0), Vector2(0, 90))
	torch = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "fackel")
	check(torch.size() == 1 and torch[0].x == 1 and torch[0].y == 2 and torch[0].rot == 1 and HouseFurniture.wall_behind(plan, 0, Vector2i(1, 2), torch[0].rot), "it hangs on the west wall (%s)" % [torch])
	# R over a placed piece turns it where it stands, to the next way it fits.
	var shelf_store := HouseFurniture.of(game.hero_name)
	var chest_i := shelf_store.piece_at(0, Vector2i(3, 1))
	furnisher.furniture = shelf_store
	check(furnisher.turn_placed(chest_i), "a placed chest turns")
	var turned: Array = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "truhe")
	check(turned.size() == 1 and turned[0].rot == 1 and turned[0].x == 3 and turned[0].y == 1, "a quarter, in place (%s)" % [turned])
	furnisher.hover(plan.cell_world(3, 1))
	furnisher.turn()
	turned = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "truhe")
	check(turned.size() == 1 and turned[0].rot == 2, "R with the mouse over it turns it again (%s)" % [turned])
	var bed_i := HouseFurniture.of(game.hero_name).piece_at(0, Vector2i(1, 1))
	furnisher.furniture = HouseFurniture.of(game.hero_name)
	furnisher.turn_placed(bed_i)
	var beds: Array = HouseFurniture.of(game.hero_name).placed.filter(func(q): return q.kind == "bett")
	check(beds.size() == 1 and beds[0].x == 1 and beds[0].y == 1, "the square bed turns in its corner (%s)" % [beds])
	# Closing the tool while holding a piece puts it back.
	furnisher.grab(plan.cell_world(3, 1), Vector2(100, 100))
	furnisher.leave()
	check(chest_at.call() == Vector2i(3, 1) and not furnisher.dragging(), "closing the tool puts a held piece back")
	furnisher.enter()
	furnisher.leave()
	check(not furnisher.active, "the tool closes")
	# Placed pieces are stations like the old house's.
	var kinds := level.stations.filter(func(s): return s.has("furniture")).map(func(s): return s.kind)
	check(kinds.has("bett") and kinds.has("lager"), "the bed and the chest are stations (%s)" % [kinds])
	var bed: Dictionary = level.stations.filter(func(s): return s.kind == "bett" and s.has("furniture"))[0]
	check(level.station_at(bed.pos + Vector3(0.5, 0.5, 0.5)) == bed, "running into the bed finds it")
	check(bed.has("side"), "the bed has a side to get up at")
	check(level.house_lights.size() >= 1, "the torch lights the house")
	level.night = true
	check(level.is_lit(level.house_lights[0] + Vector3(1, 0, 0)), "at night the torch shows the hero")
	level.night = false
	# Trophy stand: counts as the trophy wall.
	check(not HouseFurniture.upgrades_with_stand({}, game.hero_name).has("trophaeen"), "no stand, no trophy life")
	store = HouseFurniture.of(game.hero_name)
	furnisher.furniture = store
	check(store.place(plan, "trophaeen", 0, 2, 2, 0) != "", "the trophy stand does not fit in front of the bed")
	# Pick up the chest and put the stand there.
	var at := store.piece_at(0, Vector2i(3, 1))
	check(store.pick_up(at) == "truhe", "a piece is picked up again")
	check(store.place(plan, "trophaeen", 0, 3, 1, 0) == "", "the stand goes where the chest stood")
	store.save(game.hero_name)
	check(HouseFurniture.upgrades_with_stand({}, game.hero_name).get("trophaeen", false), "a stand counts as the trophy wall")
	# Taking the roof down sends the pieces under it back into the store.
	for x in range(1, 4):
		for y in range(1, 3):
			plan.pieces.erase(HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT))
	game.house_sketcher.refresh()
	var after := HouseFurniture.of(game.hero_name)
	check(after.placed.is_empty(), "without a roof nothing stands (%d left)" % after.placed.size())
	check(after.count("bett") == 1 and after.count("truhe") == 1, "they wait in the store again")
	check(not level.stations.any(func(s): return s.has("furniture")), "and are stations no more")
	print("PASS: house furniture" if failures == 0 else "FAILED: house furniture (%d)" % failures)
	quit(1 if failures > 0 else 0)
	return true
