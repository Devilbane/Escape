extends SceneTree
## Headless test for the smith's forge in the village: Gorm stands at his
## forge, metal gear melts down into iron bars (cloth and leather do not),
## iron and gold forge new gear into the bag, worn armour is mended for gold,
## iron bars can be bought, Gorm sells his own better weapons (found nowhere
## else, shown in the hero's hand), and the iron is kept in the saved game.
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

	# Gorm's own wares: sold only by him, never loot, held in the hand.
	var wares := Forge.wares()
	check(wares.size() == 4 and wares.has("langschwert") and wares.has("streitaxt"), "Gorm sells four of his own pieces")
	check(not wares.has("kriegshammer") and not wares.has("drachenschild"), "the top tier he only forges")
	check(Forge.recipes().has("kriegshammer") and Forge.recipes().has("drachenschild"), "the hero can still have them forged")
	check(not wares.has("schwert") and not wares.has("rabenklinge"), "but not the common or unique gear")
	var rng := RandomNumberGenerator.new()
	var found := {}
	for i in 3000:
		rng.seed = i
		found[Items.random_item(rng)] = true
		found[Items.random_item(rng, 0, "waffe")] = true
	for id in wares + ["kriegshammer", "drachenschild"]:
		var item: Dictionary = Items.ALL[id]
		check(not found.has(id), "%s is never loot or merchant stock" % id)
		check(Lang.EN.has(item.name), "%s has an English name" % id)
		check(ResourceLoader.exists(item.model), "%s has its model" % id)
		check(Forge.can_melt(id) and Forge.recipes().has(id), "%s melts down and can be forged" % id)
		check(item.slot == "schild" or Training.SKILLS.has(item.uses), "%s trains a skill" % id)
		check(item.price > Items.ALL["axt"].price, "%s is better and dearer than the common axe" % id)
	p.bag.clear()
	game.coins = Items.ALL["langschwert"].price - 1
	game.menus.open("schmied")
	check(game.menus._forge_tab == "waffen", "the smith's window opens on his wares")
	game.menus._buy_ware("langschwert")
	check(p.bag.is_empty() and game.coins == Items.ALL["langschwert"].price - 1, "without enough gold nothing is bought")
	game.coins = 200
	game.menus._buy_ware("langschwert")
	check(Array(p.bag) == ["langschwert"] and game.coins == 200 - Items.ALL["langschwert"].price, "gold buys the longsword")
	check(Forge.buy(game, "schwert") != "" and p.bag.size() == 1, "Gorm does not sell the merchant's sword")
	game.menus._buy_ware("drachenschild")
	check(not p.bag.has("drachenschild"), "but not the kite shield")
	p.bag.append("drachenschild")
	game.menus.close()
	var power_before := p.power
	check(p.equip("langschwert") and p.equip("drachenschild"), "both can be worn")
	check(p.power == power_before + 2, "the longsword hits harder")
	var held_r: Node = p._model.find_child("handslot_r", true, false).get_node_or_null("Held")
	var held_l: Node = p._model.find_child("handslot_l", true, false).get_node_or_null("Held")
	check(held_r != null and held_r.find_children("*", "MeshInstance3D", true, false).size() > 0, "the longsword shows in the hero's hand")
	check(held_l != null, "the kite shield shows on the other arm")
	check(not p._model.find_child("handslot_r", true, false).get_node("Knife").visible, "the hero's own knife is put away")
	p.equipped.clear()
	p.refresh_stats()

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
