extends SceneTree
## Headless test for the smith's forge in the village: Gorm stands at his
## forge, metal gear melts down into iron bars (cloth and leather do not),
## iron and gold forge new gear into the bag, worn armour is mended for gold,
## iron bars can be bought, fine pieces and jewellery melt into bronze,
## silver and gold by one table with the dragon's hoard, Gorm buys the fine
## bars back, Gorm sells his own better weapons (found nowhere
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
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: forge")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	Forge.rigged_roll = 1  # the forging is a d100 roll; these tests want it to succeed
	var p: Player = game.player
	game.hero_name = HERO

	# The rules.
	check(Forge.can_melt("plattenpanzer") and Forge.can_melt("schwert") and Forge.can_melt("kupferring"), "metal gear and jewellery melt")
	check(not Forge.can_melt("lederwams") and not Forge.can_melt("wollumhang") and not Forge.can_melt("fechtbuch") and not Forge.can_melt("steinblock"), "leather, cloth, books and stone do not")
	check(Forge.melt_yield("kettenhemd") == 18 and Forge.melt_yield("eisenhaube") == 6 and Forge.melt_yield("schwert") == 3, "heavier gear gives more iron, a bar per kilo")
	check(Forge.melt_yield("plattenpanzer") == 0 and Forge.melt_into("plattenpanzer").get("stahl", 0) == 14, "steel plate armour melts into 14 steel bars, no iron")
	# One table by kind and rarity: plain gear iron, fine gear fittings of a
	# finer metal, jewellery the metal of its rarity, magic moon silver.
	check(Forge.melt_into("schwert") == {"eisen": 3}, "a plain 3 kg sword is 3 iron bars: %s" % str(Forge.melt_into("schwert")))
	check(Forge.melt_into("kettenhemd") == {"eisen": 18}, "uncommon chain mail is iron: %s" % str(Forge.melt_into("kettenhemd")))
	# Fine metal comes in grams, worth a quarter of a weapon's or armour's
	# price for fittings and half a piece of jewellery's (see Forge.GRAM_VALUE).
	check(Forge.melt_into("streitaxt").get("g:bronze", 0) == Forge.grams_worth("bronze", Items.ALL["streitaxt"].price / 4.0), "a rare battle axe has bronze fittings")
	check(Forge.melt_into("plattenpanzer").get("g:silber", 0) == Forge.grams_worth("silber", Items.ALL["plattenpanzer"].price / 4.0), "epic plate armour has silver fittings")
	check(Forge.melt_into("bronzearmreif") == {"g:bronze": Forge.grams_worth("bronze", Items.ALL["bronzearmreif"].price / 2.0)}, "a bronze bracelet is bronze: %s" % str(Forge.melt_into("bronzearmreif")))
	check(Forge.melt_into("rubinring").keys() == ["g:silber"], "a ruby ring is silver: %s" % str(Forge.melt_into("rubinring")))
	check(Forge.melt_into("klingenring").has("g:gold") and Forge.melt_into("klingenring").get("mondsilbererz", 0) == 1, "a magic epic ring is gold and moon silver: %s" % str(Forge.melt_into("klingenring")))
	check(Forge.melt_into("lederwams").is_empty() and Forge.melt_into("knochenhelm").is_empty(), "leather and bone do not melt at the forge")
	check(DragonHoard.melt("kettenhemd") == Forge.melt_into("kettenhemd"), "the dragon melts by the same table")
	var recipes := Forge.recipes()
	check(recipes.has("schwert") and recipes.has("plattenpanzer") and recipes.has("ritterhelm") and not recipes.has("lederwams") and not recipes.has("vampirzahn"), "the smith forges metal gear only")
	for id in recipes:
		var cost := Forge.forge_cost(id)
		check((cost.iron + cost.steel) * Forge.IRON_PRICE + cost.gold <= Items.buy_price(id) + Forge.IRON_PRICE, "forging %s from bought iron costs about the merchant's price" % id)
		check(Forge.melt_yield(id) <= cost.iron, "melting %s down gives back no more iron than it takes" % id)
		check(int(Forge.melt_into(id).get("stahl", 0)) <= cost.steel, "melting %s down gives back no more steel than it takes" % id)

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
	game.bars = {}
	game.metal_grams = {}
	game.coins = 300
	game.menus.open("schmied")
	check(game.menus.current == "schmied", "the smith's window opens")
	check(game.lore.has(Forge.LEARN), "the compendium tells about the forge")
	game.menus._show_forge_tab("einschmelzen")
	game.menus._melt(1)
	check(p.bag.size() == 3 and game.iron == 0, "leather does not melt")
	game.menus._melt(0)
	check(Array(p.bag) == ["lederwams", "kupferring"] and game.iron == 0 and int(game.bars.get("stahl", 0)) == 14, "the 14 kg steel plate armour melts into 14 steel bars")
	check(int(game.metal_grams.get("silber", 0)) == Forge.melt_into("plattenpanzer")["g:silber"], "and its fine fittings into grams of silver (%s)" % str(game.metal_grams))
	game.menus._melt(1)
	check(Array(p.bag) == ["lederwams"] and game.iron == 0 and int(game.metal_grams.get("bronze", 0)) == Forge.melt_into("kupferring")["g:bronze"], "the copper ring into grams of bronze (%s)" % str(game.metal_grams))
	game.bars["bronze"] = 3


	# Forging.
	game.menus._show_forge_tab("schmieden")
	var cost := Forge.forge_cost("eisenhaube")
	check(cost.iron == 6, "a 6 kg iron cap takes 6 iron bars, one per kilo")
	game.iron = cost.iron + 2
	game.menus._forge("eisenhaube")
	check(p.bag.has("eisenhaube") and game.iron == 2 and game.coins == 300 - cost.gold, "iron and gold become an iron cap (%d iron, %d gold)" % [game.iron, game.coins])
	game.iron = 0
	game.menus._forge("schwert")
	check(not p.bag.has("schwert") and game.coins == 300 - cost.gold, "without iron nothing is forged")
	game.menus._buy_iron(5)
	check(game.iron == 5 and game.coins == 300 - cost.gold - 5 * Forge.IRON_PRICE, "iron bars can be bought")
	while p.bag.size() < p.bag_size():
		p.bag.append("lederwams")
	game.menus._forge("schwert")
	check(game.iron == 5 and not p.bag.has("schwert"), "nothing is forged into a full bag")
	p.bag.assign(["ritterhelm"])

	# The roll: chance = (Stärke + Intelligenz + Intuition + Geschick) / 15 x skill, % on a d100.
	var sum := 0
	for a in Forge.CHANCE_ATTRIBUTES:
		sum += p.attribute(a)
	check(Forge.chance(game) == clampi(roundi(sum / 15.0 * Forge.skill(game)), Forge.MIN_CHANCE, Forge.MAX_CHANCE), "the chance follows the four attributes and the skill (%d%%)" % Forge.chance(game))
	p.xp[Forge.FORGING] = 1.0e9
	for a in Forge.CHANCE_ATTRIBUTES:
		p.xp[a] = 1.0e9
	check(Forge.chance(game) == 80 and Forge.chance(game) <= Forge.MAX_CHANCE, "at the highest skill and attributes the chance is 120 / 15 x 10 = 80%%, within the %d%% cap (%d%%)" % [Forge.MAX_CHANCE, Forge.chance(game)])
	for a in Forge.CHANCE_ATTRIBUTES:
		p.xp.erase(a)
	p.xp[Forge.FORGING] = 0.0
	check(Forge.chance(game) >= Forge.MIN_CHANCE and Forge.skill(game) == 1, "a beginner counts as skill 1")
	game.iron = 6
	game.coins = 300
	p.bag.clear()
	var xp0 := float(p.xp.get(Forge.FORGING, 0.0))
	Forge.rigged_roll = 100
	Forge.last = {}
	Forge.forge(game, "eisenhaube")  # the hero's own hand: Gorm's menu never fails
	check(not p.bag.has("eisenhaube") and not Forge.last.success and Forge.last.roll == 100, "a roll above the chance fails")
	check(game.iron == 3 and game.coins == 300 - Forge.forge_cost("eisenhaube").gold, "a failure spoils half the iron and the gold is spent")
	check(float(p.xp.get(Forge.FORGING, 0.0)) - xp0 == Forge.FAIL_XP, "a failure still trains the skill")
	Forge.rigged_roll = 1
	game.iron = 6
	game.menus._forge("eisenhaube")
	check(p.bag.has("eisenhaube") and Forge.last.success, "a roll within the chance succeeds")
	p.bag.clear()
	game.iron = 6
	Forge.rigged_roll = 100  # even a hopeless roll: at Gorm's menu forging always succeeds
	game.menus._forge("eisenhaube")
	check(p.bag.has("eisenhaube") and Forge.last.success and game.iron == 6 - Forge.forge_cost("eisenhaube").iron, "Gorm's forging never fails and costs the full price")
	Forge.rigged_roll = 1
	game.coins = 300
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
	game.coins = Items.buy_price("langschwert") - 1
	game.menus.open("schmied")
	check(game.menus._forge_tab == "waffen", "the smith's window opens on his wares")
	game.menus._buy_ware("langschwert")
	check(p.bag.is_empty() and game.coins == Items.buy_price("langschwert") - 1, "without enough gold nothing is bought")
	game.coins = 400
	game.menus._buy_ware("langschwert")
	check(Array(p.bag) == ["langschwert"] and game.coins == 400 - Items.buy_price("langschwert"), "copper buys the longsword")
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

	# Gorm buys the fine bars back, one at a time.
	game.menus.open("schmied")
	game.menus._show_forge_tab("einschmelzen")
	var coins_now: int = game.coins
	game.menus._sell_bar("bronze")
	check(int(game.bars.get("bronze", 0)) == 2 and game.coins == coins_now + Forge.METALS.bronze.worth, "a bronze bar sold to Gorm")
	game.menus._sell_bar("gold")
	check(game.coins == coins_now + Forge.METALS.bronze.worth and game.menus._note != "", "no gold bar, nothing sold")

	# The iron stays in the saved game.
	game.iron = 7
	await _wait(5)
	check(game.save_game(), "the game saves")
	var data: Dictionary = game._read_save(game.save_path())
	check(int(data.get("iron", -1)) == 7, "the saved game holds the iron")
	game.iron = 0
	var bars_had: Dictionary = game.bars.duplicate()
	game.bars = {}
	game._apply_save(data)
	await _wait(5)
	check(game.iron == 7, "after loading the iron is back")
	check(game.bars == bars_had and not bars_had.is_empty(), "and the fine bars too (%s)" % str(game.bars))
	data.erase("bars")
	game._apply_save(data)
	await _wait(5)
	check(game.bars.is_empty(), "a game saved before the fine bars has none")
	_finish()
