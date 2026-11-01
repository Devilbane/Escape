extends SceneTree
## Headless test for the smith's forge in the village: Gorm stands at his
## forge, metal gear melts down into iron bars (cloth and leather do not),
## iron and gold forge new gear into the bag, worn armour is mended for gold,
## iron bars can be bought, and the iron is kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/forge.gd

const HERO := "Forge test"

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	game.delete_save(game.save_path(HERO))
	if failures == 0:
		print("PASS: forge")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO

	# The rules.
	check(Forge.can_melt("plattenpanzer") and Forge.can_melt("schwert") and Forge.can_melt("kupferring"), "metal gear and jewellery melt")
	check(not Forge.can_melt("lederwams") and not Forge.can_melt("wollumhang") and not Forge.can_melt("fechtbuch") and not Forge.can_melt("steinblock"), "leather, cloth, books and stone do not")
	check(Forge.melt_yield("plattenpanzer") == 6 and Forge.melt_yield("schwert") == 2, "pricier pieces give more iron")
	var recipes := Forge.recipes()
	check(recipes.has("schwert") and recipes.has("plattenpanzer") and recipes.has("ritterhelm") and not recipes.has("lederwams") and not recipes.has("vampirzahn"), "the smith forges metal gear only")
	for id in recipes:
		var cost := Forge.forge_cost(id)
		check(cost.iron * Forge.IRON_PRICE + cost.gold <= Items.ALL[id].price + Forge.IRON_PRICE, "forging %s from bought iron costs about the merchant's price" % id)
		check(Forge.melt_yield(id) <= cost.iron, "melting %s down gives back no more iron than it takes" % id)

	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	var smith: Dictionary = {}
	for s in lvl.stations:
		if s.kind == "schmied":
			smith = s
	check(not smith.is_empty() and smith.has("npc"), "the smith stands at his forge in the village")
	check(lvl.astar.is_point_solid(smith.cell + Vector2i(-1, 0)), "the forge takes the tile beside him")

	# Melting down.
	p.bag.clear()
	p.bag.append_array(["plattenpanzer", "lederwams", "kupferring"])
	game.iron = 0
	game.coins = 100
	game.menus.open("schmied")
	check(game.menus.current == "schmied", "the smith's window opens")
	check(game.lore.has(Forge.LEARN), "the compendium tells about the forge")
	game.menus._show_forge_tab("einschmelzen")
	game.menus._melt(1)
	check(p.bag.size() == 3 and game.iron == 0, "leather does not melt")
	game.menus._melt(0)
	check(Array(p.bag) == ["lederwams", "kupferring"] and game.iron == 6, "the plate armour melts into 6 iron bars")
	game.menus._melt(1)
	check(Array(p.bag) == ["lederwams"] and game.iron == 8, "the copper ring into 2 more")

	# Forging.
	game.menus._show_forge_tab("schmieden")
	var cost := Forge.forge_cost("ritterhelm")
	game.menus._forge("ritterhelm")
	check(p.bag.has("ritterhelm") and game.iron == 8 - cost.iron and game.coins == 100 - cost.gold, "iron and gold become a knight's helmet")
	game.iron = 0
	game.menus._forge("schwert")
	check(not p.bag.has("schwert") and game.coins == 100 - cost.gold, "without iron nothing is forged")
	game.menus._buy_iron(5)
	check(game.iron == 5 and game.coins == 100 - cost.gold - 5 * Forge.IRON_PRICE, "iron bars can be bought")
	while p.bag.size() < p.bag_size():
		p.bag.append("lederwams")
	game.menus._forge("schwert")
	check(game.iron == 5 and not p.bag.has("schwert"), "nothing is forged into a full bag")
	p.bag.assign(["ritterhelm"])

	# Mending.
	check(p.equip("ritterhelm"), "the helmet can be worn")
	p.wear["ritterhelm"] = 3
	check(Forge.worn_down(p) == ["ritterhelm"], "the worn helmet is up for mending")
	game.coins = Forge.mend_price("ritterhelm") * 2
	game.menus._show_forge_tab("ausbessern")
	game.menus._mend("ritterhelm")
	check(int(p.wear.get("ritterhelm", 0)) == 1 and game.coins == 0, "the gold mends two of three points")
	game.coins = 50
	game.menus._mend("ritterhelm")
	check(not p.wear.has("ritterhelm") and game.coins == 50 - Forge.mend_price("ritterhelm"), "then the helmet is as good as new")
	check(Forge.worn_down(p).is_empty(), "nothing left to mend")
	game.menus.close()

	# The iron stays in the saved game.
	game.iron = 7
	await _wait(5)
	check(game.save_game(), "the game saves")
	var data: Dictionary = game._read_save(game.save_path(HERO))
	check(int(data.get("iron", -1)) == 7, "the saved game holds the iron")
	game.iron = 0
	game._apply_save(data)
	await _wait(5)
	check(game.iron == 7, "after loading the iron is back")
	_finish()
