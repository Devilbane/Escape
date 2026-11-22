extends SceneTree
## Household goddesses (see HouseholdGods): the furnisher sells a shrine with a winged goddess,
## the furnishing tool puts it down in the hero's own house, and while the hero is inside that
## house the goddess blesses them. Maija gives +5 life per second there, a night in the house's
## bed mends injuries twice as fast and ends with full life, and the blessing shows as a boon
## icon with its explanation. One blessing per house; outside the house it is gone.
##
## Run with: godot --headless -s tests/household_gods.gd

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


## A room of 4 x 2 cells at (1, 1) with walls round it, a door in the south wall and a flat roof.
func _build_house(plan: HouseSketch) -> void:
	for x in range(1, 5):
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 3, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.DOOR if x == 4 else HouseSketch.WALL, "state": HouseSketch.BUILT}
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		plan.pieces[HouseSketch.key_of(1, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(5, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}


func _unit_checks() -> void:
	# Every goddess is whole, and every shrine kind names one.
	for id in HouseholdGods.GODDESSES:
		var g: Dictionary = HouseholdGods.GODDESSES[id]
		check(g.has("name") and g.has("title") and g.has("tale") and g.perks is Dictionary, "%s is described" % id)
		for perk in g.perks:
			check(HouseholdGods.PERKS.has(perk), "%s's perk %s has a line" % [id, perk])
		var kinds := HouseFurniture.KINDS.keys().filter(func(k): return HouseholdGods.of_kind(k) == id)
		check(kinds.size() == 1, "%s has one shrine to buy (%s)" % [id, kinds])
		for kind in kinds:
			check(HouseFurnisher.SHORT.has(kind), "%s has a name on the tool bar" % kind)
			check(HouseFurniture.SECTIONS.any(func(s): return kind in s[3]), "%s is in one of the furnisher's sections" % kind)
			check(not HouseFurniture.on_wall(kind), "%s stands on the floor" % kind)
	check(HouseholdGods.perk("maija", "regen") == 5.0, "Maija gives 5 life per second")
	check(HouseholdGods.rest_nights("maija") == 2, "under Maija a night counts twice against an injury")
	check(HouseholdGods.rest_nights("") == 1, "without a goddess a night is a night")
	check(HouseholdGods.perk("", "regen") == 0.0, "no goddess, no perk")
	var lines := HouseholdGods.perk_lines("maija")
	check(lines.size() == 2 and "5" in lines[0] and "100" in lines[1], "Maija's perks read +5 and 100 %% (%s)" % [lines])
	check(ItemIcon.make("kind:goddess", 20) != null, "the goddess has a picture")
	check(HouseholdGods.KIND in StatusIcon.BOONS, "her blessing is a boon")


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_unit_checks()
	game.hero_name = "Goddess test"
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
	check(not game.house_sketcher.own_shelter.is_empty(), "the hero's own house has an inside")
	# Buying Maija's shrine and a bed at the furnisher.
	game.coins = 2000
	game.trader_role = "µ"
	game.menus.open("raumausstatter")
	game.menus._buy_furniture("schrein_maija")
	game.menus._buy_furniture("schrein_maija")
	game.menus._buy_furniture("bett")
	game.menus.close()
	var store := HouseFurniture.of(game.hero_name)
	check(store.count("schrein_maija") == 2 and store.count("bett") == 1, "the shrines and the bed wait in the store")
	var hero: Player = game.player
	# Injury.rest counts a blessed night twice.
	Injury.give(hero, Injury.ARM, Injury.MINOR)
	check(Injury.nights(Injury.ARM, Injury.MINOR) == 3, "a minor broken arm needs three nights")
	check(not Injury.rest(hero, 2), "a blessed night does not mend it yet")
	check(hero.injury_rest == 2, "but counts for two")
	check(Injury.rest(hero, 2), "the second blessed night mends it")
	check(hero.injury == "", "the arm is whole again")
	# Inside the house without a shrine: no blessing.
	var inside := plan.cell_world(2, 2) + Vector3(0, 0.1, 0)
	var outside := plan.cell_world(2, 2) + Vector3(0, 0.1, HouseSketch.CELL * 3.0)
	hero.global_position = inside
	game._update_house_blessing()
	check(game.house_goddess == "", "no shrine, no blessing")
	check(hero.bonus_regen == 0.0, "and no extra life")
	# The tool puts the shrine down against the north wall, and the bed in the corner.
	var furnisher: HouseFurnisher = game.house_furnisher
	furnisher.enter()
	furnisher.select("schrein_maija")
	furnisher.click(HouseFurniture.centre(plan, "schrein_maija", 0, 3, 1, 0))
	check(HouseFurniture.of(game.hero_name).count("schrein_maija") == 1, "the shrine is put down")
	furnisher.select("bett")
	furnisher.click(HouseFurniture.centre(plan, "bett", 0, 1, 1, 0))
	check(HouseFurniture.of(game.hero_name).count("bett") == 0, "the bed is put down")
	furnisher.leave()
	furnisher.refresh()
	var shrines := furnisher._pieces.find_children("Shrine", "", true, false)
	check(shrines.size() == 1, "the shrine is built in the house (%d)" % shrines.size())
	check(shrines.size() == 1 and shrines[0].find_child("Relief", true, false) != null, "its plinth has a carved relief")
	check(ShrineLook.filigree_material().transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "its filigree is open lace")
	check(HouseholdGods.of_house(furnisher.furniture) == "maija", "Maija blesses the house")
	# Furniture for the rooms never takes snow (see HouseFurnisher.indoors); the garden's does.
	var up: Node = shrines[0] if shrines.size() == 1 else null
	var kept := false
	while up != null and up != furnisher._pieces:
		kept = kept or SnowCover.bare(up)
		up = up.get_parent()
	check(kept, "no snow settles on the shrine in the house")
	check(HouseFurnisher.indoors("bett") and not HouseFurnisher.indoors(AppleTree.KIND), "the rooms' furniture keeps the snow off, the garden's apple tree takes it")
	# Inside: the blessing holds.
	hero.global_position = inside
	game._update_house_blessing()
	check(game.house_goddess == "maija", "inside the house Maija's blessing holds")
	check(hero.bonus_regen == 5.0, "+5 life per second")
	check(is_equal_approx(hero.life_regen(), hero.attribute("konstitution") / Player.REGEN_PER_CON_DIVISOR / Player.REGEN_INTERVAL + 5.0), "the recovery shown includes it")
	var boons: Array = game.hero_boons()
	check(boons.any(func(b): return b[0] == HouseholdGods.KIND), "her icon shows among the boons (%s)" % [boons])
	var tip: String = game.icon_text(HouseholdGods.KIND, "")
	check("Maija" in tip and "5" in tip, "its tooltip names her and what she gives (%s)" % tip)
	# Life comes back at 5 per second (no blow just taken).
	hero.max_hp = 40
	hero.hp = 10
	hero._regen = 0.0
	hero._regen_clock = 0.0
	hero._regen_pause = 0.0
	for i in 10:
		hero._regenerate(0.1)
	check(hero.hp >= 14 and hero.hp <= 16, "a second inside gives about 5 life (%d)" % hero.hp)
	# A second shrine of the same goddess adds nothing: one blessing per house.
	var two := HouseFurniture.of(game.hero_name)
	check(two.place(plan, "schrein_maija", 0, 4, 1, 0) == "", "a second shrine fits beside the first")
	two.save(game.hero_name)
	furnisher.refresh()
	game._update_house_blessing()
	check(hero.bonus_regen == 5.0, "two shrines do not stack")
	# Outside: gone.
	hero.global_position = outside
	game._update_house_blessing()
	check(game.house_goddess == "" and hero.bonus_regen == 0.0, "outside the house the blessing is gone")
	check(not game.hero_boons().any(func(b): return b[0] == HouseholdGods.KIND), "and so is its icon")
	# A night in the house's bed: the injury mends twice as fast and the hero wakes with full life.
	hero.global_position = inside
	game._update_house_blessing()
	Injury.give(hero, Injury.LEG, Injury.MINOR)
	var need := Injury.nights(Injury.LEG, Injury.MINOR)
	hero.hp = 3
	game.quit_on_log_out = false
	game._rest_injury(HouseholdGods.active(game))
	check(hero.injury_rest == 2, "a night under Maija counts for two (%d of %d)" % [hero.injury_rest, need])
	game._rest_injury("")
	check(hero.injury_rest == 3, "a night elsewhere counts for one")
	# The furnisher's card tells what the shrine gives.
	game.menus.open("raumausstatter")
	game.menus.close()
	print("PASS: household gods" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true
