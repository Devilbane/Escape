extends SceneTree
## The garden of the self-built house (see GardenDecor and HouseFurniture): Ilse sells flowers,
## garden torches, a garden lamp and a grill; they stand only outdoors on the plot (no roof over
## them, ground floor level), their lights light the garden at night, the flowers follow the
## seasons, a roof built over one sends it back into the store, and the grill cooks wild meat or a
## perch from the pouch into life.

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait_until := 0


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


## A room of 2 x 2 cells at (1, 1) with walls round it, a door in the south wall and a flat roof.
func _build_house(plan: HouseSketch) -> void:
	for x in range(1, 3):
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 3, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.DOOR if x == 2 else HouseSketch.WALL, "state": HouseSketch.BUILT}
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		plan.pieces[HouseSketch.key_of(1, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(3, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}


func _meshes(kind: String, season: int) -> int:
	var model := Node3D.new()
	GardenDecor.build(model, kind, season, game.level, [])
	var n := model.find_children("*", "MeshInstance3D", true, false).size()
	model.free()
	return n


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match stage:
		0:
			_set_up()
			stage = 1
			wait_until = Time.get_ticks_msec() + int(GardenDecor.GRILL_TIME * 1000) + 600
		1:
			if Time.get_ticks_msec() < wait_until:
				return false
			_after_grill()
			print("PASS: house garden" if failures == 0 else "FAILED: house garden (%d)" % failures)
			quit(1 if failures > 0 else 0)
			return true
	return false


func _set_up() -> void:
	game.hero_name = "Garden test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	var level: Outdoor = game.level
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
	# Ilse sells the garden in its own category.
	var garden: Array = HouseFurniture.SECTIONS.filter(func(s): return s[0] == "garten")
	check(garden.size() == 1 and garden[0][3].size() == 6, "Ilse has a garden category with six pieces")
	for kind in garden[0][3]:
		check(HouseFurniture.in_garden(kind), "%s belongs in the garden" % kind)
		check(HouseFurnisher.SHORT.has(kind), "%s has a button name" % kind)
	game.coins = 2000
	game.trader_role = "µ"
	game.menus.open("raumausstatter")
	for kind in ["blumenbeet", "blumenkuebel", "gartenfackel", "gartenlaterne", "grill"]:
		game.menus._buy_furniture(kind)
	game.menus.close()
	var store := HouseFurniture.of(game.hero_name)
	check(store.count("grill") == 1 and store.count("blumenbeet") == 1, "the garden pieces wait in the store")
	# The rules: outdoors only, never under the roof, only at ground level.
	check(HouseFurniture.garden_problem(plan, 0, Vector2i(0, 0)) == "", "the open plot is garden")
	check(HouseFurniture.garden_problem(plan, 0, Vector2i(1, 1)) == "roof", "under the roof is no garden")
	check(HouseFurniture.garden_problem(plan, 1, Vector2i(0, 0)) == "garden", "the garden is only at ground level")
	check(store.problem(plan, "blumenbeet", 0, 1, 1, 0) == "roof", "no flower bed in the house")
	check(store.problem(plan, "bett", 0, 0, 0, 0) != "", "a bed still does not stand outdoors")
	check(store.problem(plan, "grill", 0, 2, 3, 0) == "door", "the way to the door stays free")
	check(HouseFurniture.reason("roof") != HouseFurniture.reason(""), "a roof has its own reason")
	# The tool: picking a garden piece shows the ground floor.
	var furnisher: HouseFurnisher = game.house_furnisher
	furnisher.storey = 1
	furnisher.enter()
	var bar_size: Vector2 = furnisher._bar.get_combined_minimum_size()
	furnisher.select("blumenbeet")
	check(furnisher.storey == 0, "a garden piece switches the tool to the ground floor")
	furnisher.storey = 1
	furnisher.select("gartenfackel")
	check(furnisher.storey == 1, "a roof light keeps the upper level, where flat roofs are")
	furnisher.storey = -1
	furnisher.select("gartenfackel")
	check(furnisher.storey == 0, "a roof light leaves the cellar for the ground floor")
	# Put them down along the west and north edge of the plot.
	var spots := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0)]
	var kinds := ["gartenfackel", "blumenbeet", "gartenlaterne", "grill", "blumenkuebel"]
	for i in kinds.size():
		furnisher.select(kinds[i])
		furnisher.click(HouseFurniture.centre(plan, kinds[i], 0, spots[i].x, spots[i].y, 0))
		check(HouseFurniture.of(game.hero_name).count(kinds[i]) == 0, "%s stands in the garden at %s" % [kinds[i], spots[i]])
	check(furnisher._bar.get_combined_minimum_size() == bar_size, "the bar keeps its size as garden pieces go down")
	furnisher.leave()
	_roof_lights(plan, level, furnisher)
	# Lights: the torch, the lamp and the grill's coals light the garden and show the hero at night.
	check(level.house_lights.size() >= 3, "three garden lights (%d)" % level.house_lights.size())
	level.night = true
	var torch_at := HouseFurniture.centre(plan, "gartenfackel", 0, 0, 0, 0)
	check(level.is_lit(torch_at + Vector3(1.5, 0, 0)), "at night the garden torch shows the hero")
	level.night = false
	# The grill is a station.
	var grills := level.stations.filter(func(s): return s.kind == GardenDecor.GRILL)
	check(grills.size() == 1, "the grill is a station")
	# The seasons: blooms in summer, fewer in winter.
	check(GardenDecor.stage(0) == GardenDecor.SPRING_SUMMER, "the year starts green")
	var winter_day := -1
	var autumn_day := -1
	for d in Weather.YEAR_DAYS:
		if winter_day < 0 and Weather.is_winter(d):
			winter_day = d
		if autumn_day < 0 and Weather.is_autumn(d):
			autumn_day = d
	check(GardenDecor.stage(winter_day) == GardenDecor.WINTER and GardenDecor.stage(autumn_day) == GardenDecor.AUTUMN, "the flowers know autumn and winter")
	check(_meshes("blumenbeet", GardenDecor.WINTER) < _meshes("blumenbeet", GardenDecor.SPRING_SUMMER), "a winter bed has fewer blooms")
	level.set_season(winter_day)
	furnisher._process(0.0)
	check(furnisher._garden_stage == GardenDecor.WINTER, "the garden is drawn again when winter comes")
	level.set_season(0)
	furnisher._process(0.0)
	# The grill: not while unhurt, nothing without food, then the meat first.
	var player: Player = game.player
	player.hp = player.max_hp
	game.crafting.add("barsch", 1)
	game.crafting.add("wildfleisch", 1)
	GardenDecor.grill(game)
	check(game.crafting.have("wildfleisch") == 1, "an unhurt hero keeps the food")
	player.hp = 1
	GardenDecor.grill(game)
	check(game.crafting.have("wildfleisch") == 0 and game.crafting.have("barsch") == 1, "the grill takes the wild meat first")
	# A roof built over a garden piece sends it back into the store.
	plan.pieces[HouseSketch.key_of(0, 1, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	game.house_sketcher.refresh()
	var after := HouseFurniture.of(game.hero_name)
	check(after.count("blumenbeet") == 1 and after.standing("blumenbeet") == 0, "a roof over the flower bed sends it back")
	check(after.standing("gartenfackel") == 1, "the torch beside it still stands")


## Garden torches and lamps also stand on a flat roof, under the open sky: on the slab over the
## ground floor (the house's roof here) and on one over the upper floor; never on a pitched roof,
## under a roof, by a ladder or on a ballista; other garden pieces and furniture stay off it.
func _roof_lights(plan: HouseSketch, level: Outdoor, furnisher: HouseFurnisher) -> void:
	var top := HouseFurniture.ROOF_STOREY
	check(HouseFurniture.roof_problem(plan, 1, Vector2i(1, 1)) == "", "the house's flat roof holds a roof light")
	check(HouseFurniture.roof_problem(plan, 1, Vector2i(0, 0)) == "no flat roof", "no roof light in the air")
	check(HouseFurniture.reason("no flat roof") != HouseFurniture.reason(""), "a missing flat roof has its own reason")
	# A room up there (a slab over (2, 1)) is indoors; a pitched roof over (2, 2) holds nothing.
	plan.pieces[HouseSketch.key_of(2, 1, HouseSketch.CELL_ORIENT, 1)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	plan.pieces[HouseSketch.key_of(2, 2, "rx", 1)] = {"kind": HouseSketch.SADDLE, "state": HouseSketch.BUILT}
	check(HouseFurniture.roof_problem(plan, 1, Vector2i(2, 1)) == "roof", "under the upper floor's roof is indoors")
	check(HouseFurniture.roof_problem(plan, top, Vector2i(2, 1)) == "", "the flat roof over the upper floor holds a roof light")
	check(HouseFurniture.roof_problem(plan, top, Vector2i(2, 2)) == "no flat roof", "nothing stands on a pitched roof")
	check(HouseFurniture.roof_problem(plan, top, Vector2i(1, 1)) == "no flat roof", "no roof light over an open roof terrace")
	# A ladder up to the top roof keeps its foot and its top free, and so does a ballista its cell.
	plan.pieces[HouseSketch.key_of(1, 1, HouseSketch.LADDER_ORIENTS["e"], 1)] = {"kind": HouseSketch.LADDER, "state": HouseSketch.BUILT}
	check(HouseFurniture.roof_problem(plan, 1, Vector2i(1, 1)) == "stairs", "a ladder's foot stays free")
	check(HouseFurniture.roof_problem(plan, top, Vector2i(2, 1)) == "stairs", "a ladder's top stays free")
	plan.pieces.erase(HouseSketch.key_of(1, 1, HouseSketch.LADDER_ORIENTS["e"], 1))
	plan.pieces[HouseSketch.key_of(1, 2, HouseSketch.BALLISTA_ORIENT, 1)] = {"kind": HouseSketch.BALLISTA, "state": HouseSketch.BUILT}
	check(HouseFurniture.roof_problem(plan, 1, Vector2i(1, 2)) == "taken", "a ballista's cell is taken")
	plan.pieces.erase(HouseSketch.key_of(1, 2, HouseSketch.BALLISTA_ORIENT, 1))
	var store := HouseFurniture.of(game.hero_name)
	check(store.problem(plan, "blumenbeet", 1, 1, 1, 0) == "garden", "flowers stay off the roof")
	check(store.problem(plan, "leuchter", 1, 1, 1, 0) == "no roof", "a candle stand stays indoors")
	check(store.problem(plan, "bett", top, 2, 1, 0) != "", "no bed on the top roof")
	# The level button reaches the top roof once a slab is built over the upper floor.
	check(HouseFurnisher.next_level(1, plan) == top and HouseFurnisher.next_level(top, plan) == -1, "the level button reaches the roof")
	plan.pieces.erase(HouseSketch.key_of(2, 1, HouseSketch.CELL_ORIENT, 1))
	check(HouseFurnisher.next_level(1, plan) == -1, "no roof level without a slab over the upper floor")
	plan.pieces[HouseSketch.key_of(2, 1, HouseSketch.CELL_ORIENT, 1)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	# Put a lamp on the house's roof and a torch on the top roof with the tool.
	var bought := HouseFurniture.of(game.hero_name)
	bought.add("gartenlaterne")
	bought.add("gartenfackel")
	bought.save(game.hero_name)
	furnisher.enter()
	furnisher.storey = 1
	furnisher.select("gartenlaterne")
	furnisher.click(HouseFurniture.centre(plan, "gartenlaterne", 1, 1, 1, 0))
	furnisher.storey = top
	furnisher.select("gartenfackel")
	check(furnisher.storey == top, "a roof light keeps the roof level")
	furnisher.click(HouseFurniture.centre(plan, "gartenfackel", top, 2, 1, 0))
	furnisher.leave()
	var after := HouseFurniture.of(game.hero_name)
	check(after.placed.any(func(p): return p.kind == "gartenlaterne" and p.storey == 1 and p.x == 1 and p.y == 1), "the lamp stands on the house's roof")
	check(after.placed.any(func(p): return p.kind == "gartenfackel" and p.storey == top and p.x == 2 and p.y == 1), "the torch stands on the top roof")
	game.house_sketcher.refresh()
	level.night = true
	check(level.is_lit(HouseFurniture.centre(plan, "gartenlaterne", 1, 1, 1, 0) + Vector3(1.0, 0, 0)), "at night the roof lamp lights the roof")
	level.night = false
	# Taking the top roof down sends its torch back into the store; the lamp below stays.
	plan.pieces.erase(HouseSketch.key_of(2, 1, HouseSketch.CELL_ORIENT, 1))
	plan.pieces.erase(HouseSketch.key_of(2, 2, "rx", 1))
	game.house_sketcher.refresh()
	var settled := HouseFurniture.of(game.hero_name)
	check(settled.count("gartenfackel") == 1 and settled.placed.any(func(p): return p.kind == "gartenlaterne" and p.storey == 1), "a roof taken down sends its light back")


func _after_grill() -> void:
	var player: Player = game.player
	check(player.hp == mini(player.max_hp, 1 + 4), "grilled wild meat gives four life (%d)" % player.hp)
	check(not game.get_meta("grilling", false), "the grill is free again")
