extends SceneTree
## Headless test for armour sets (see ArmourSets): every set has a helmet, an
## armour, gloves and shoes; each bonus is 1 to 4, the two together at most 7
## and only the dragon scale set reaches 7. A full set weighs 3 kg in cloth,
## 9 in leather, 25 in steel and 35 in iron; armour value rises from cloth to
## steel. Wearing all four pieces of one
## kind raises Geschick and Härtung by the set's bonus; a cloak does not
## matter, a piece of another kind breaks the set. Putting the last piece on
## or a piece off says so, and the character page shows the set worn in a
## line that keeps its size. Hydra and wyrm pieces are never sold, the dragon
## scale pieces are crafted from Embermaw's scales, and the dragon sometimes
## leaves two scales. Armour value takes a share off each hit after the
## hardening, and the character page explains both.
## Run with: godot --headless -s tests/armour_sets.gd

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
	# The table: four pieces of every set, bonuses in range.
	check(ArmourSets.PIECES == ["kopf", "ruestung", "handschuhe", "schuhe"], "a set is helmet, armour, gloves and shoes")
	check("handschuhe" in Items.SLOTS, "gloves have a slot")
	for kind in ArmourSets.SETS:
		var s: Dictionary = ArmourSets.SETS[kind]
		check(s.dex >= 1 and s.dex <= 4 and s.hardening >= 1 and s.hardening <= 4, "%s: each bonus is 1 to 4" % kind)
		check(s.dex + s.hardening <= 7, "%s: at most +7 together" % kind)
		check((s.dex + s.hardening == 7) == (kind == "drache"), "%s: only the dragon scale set reaches 7" % kind)
		check(Lang.EN.has(s.name), "%s: the set's name has English" % kind)
		for slot in ArmourSets.PIECES:
			var pieces := Items.ALL.keys().filter(func(id): return Items.ALL[id].get("set", "") == kind and Items.ALL[id].slot == slot)
			check(not pieces.is_empty(), "%s has a piece for %s" % [kind, slot])
			for id in pieces:
				check(Lang.EN.has(Items.ALL[id].name), "%s's name has English" % id)
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.has("set"):
			check(ArmourSets.SETS.has(item.set) and item.slot in ArmourSets.PIECES, "%s belongs to a known set in a set slot" % id)
	# What a full set weighs: cloth 3 kg, leather 9, steel 25, iron 35. The
	# weight is what slows the hero (Items.WEIGHT_SLOW per kg).
	var weights := {}
	for kind in ["stoff", "leder", "eisen", "stahl"]:
		var best := {}
		for id in Items.ALL:
			var item: Dictionary = Items.ALL[id]
			if item.get("set", "") == kind and id != "zauberhut" and id != "eilstiefel":
				check(not best.has(item.slot), "%s has one plain piece for %s" % [kind, item.slot])
				best[item.slot] = float(item.weight)
				if kind == "stoff":
					check(item.get("armor", 0) == 0 and item.get("speed", 0.0) >= 0.0, "cloth %s is soft and never slows by itself" % id)
				else:
					check(item.get("speed", 0.0) == 0.0, "%s slows only by its weight" % id)
		var total := 0.0
		for slot in best:
			total += best[slot]
		weights[kind] = total
	check(is_equal_approx(weights.stoff, 3.0) and is_equal_approx(weights.leder, 9.0) and is_equal_approx(weights.stahl, 25.0) and is_equal_approx(weights.eisen, 35.0),
			"a set weighs cloth 3, leather 9, steel 25, iron 35 kg (%s)" % str(weights))
	# Armour value: cloth little, leather more, iron and steel a lot; steel
	# is harder than iron.
	var guard := {}
	for kind in ["stoff", "leder", "eisen", "stahl"]:
		guard[kind] = {"armor": 0, "value": 0}
		for id in Items.ALL:
			if Items.ALL[id].get("set", "") == kind and id != "zauberhut" and id != "eilstiefel":
				guard[kind].armor += Items.ALL[id].get("armor", 0)
				guard[kind].value += Items.ALL[id].get("armour_value", 0)
	check(guard.stoff.value < guard.leder.value and guard.leder.value < guard.eisen.value and guard.eisen.value <= guard.stahl.value, "armour value rises from cloth to steel (%s)" % str(guard))
	check(guard.stahl.armor > guard.eisen.armor and guard.eisen.armor > guard.leder.armor, "steel is harder than iron, iron than leather (%s)" % str(guard))

	game.hero_name = "Armour set test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var news := []
	Events.bus().news_told.connect(func(text: String, _c: Color, _d: float) -> void: news.append(text))
	var dex := p.attribute("geschick")
	var hard := p.hardening
	# Three of four leather pieces: no bonus yet.
	for id in ["lederkappe", "lederwams", "lederhandschuhe", "lederstiefel"]:
		p.bag.append(id)
	for id in ["lederkappe", "lederwams", "lederhandschuhe"]:
		check(p.equip(id), "puts on %s" % id)
	check(ArmourSets.worn(p.equipped) == "", "three pieces are no set")
	var dex3 := p.attribute("geschick")
	var hard3 := p.hardening
	check(dex3 == dex, "no Geschick bonus without a full set")
	check(news.is_empty(), "no news before the set is complete")
	check(p.equip("lederstiefel"), "puts on the leather boots")
	check(ArmourSets.worn(p.equipped) == "leder", "four leather pieces are the leather set")
	check(p.attribute("geschick") == dex3 + 3, "the leather set adds 3 Geschick (%d -> %d)" % [dex3, p.attribute("geschick")])
	check(p.hardening == hard3 + Items.ALL.lederstiefel.get("armor", 0) + 1, "the leather set adds 1 Härtung")
	check(news.size() == 1 and Lang.t("Lederset") in news[0], "putting on the last piece says the set is complete (%s)" % str(news))
	# A cloak is free.
	p.bag.append("koenigsumhang")
	check(p.equip("koenigsumhang") and ArmourSets.worn(p.equipped) == "leder", "a cloak does not break the set")
	# The character page shows it, in a line that keeps its height.
	var menus: Menus = game.menus
	menus.open("charakter")
	await _wait()
	var line: Label = menus._character_set
	check(line != null and Lang.t("Lederset") in line.text, "the character page shows the leather set")
	var height := line.size.y if line else 0.0
	var top := line.global_position.y if line else 0.0
	menus.close()
	# A piece of another kind breaks it.
	p.bag.append("eisenhaube")
	news.clear()
	check(p.equip("eisenhaube"), "puts on the iron cap")
	check(ArmourSets.worn(p.equipped) == "", "an iron cap breaks the leather set")
	check(p.attribute("geschick") == dex3, "the Geschick bonus is gone again")
	check(news.size() == 1, "breaking the set says so (%s)" % str(news))
	menus.open("charakter")
	await _wait()
	line = menus._character_set
	check(line != null and line.size.y == height and line.global_position.y == top, "the set line keeps its place and size without a set")
	menus.close()
	# Dragon scales: the strongest set, made from the dragon's scales.
	p.equipped = {"kopf": "drachenhelm", "ruestung": "drachenpanzer", "handschuhe": "drachenhandschuhe", "schuhe": "drachenstiefel"}
	p.refresh_stats()
	check(ArmourSets.dexterity(p.equipped) == 3 and ArmourSets.hardening(p.equipped) == 4, "the dragon scale set gives +3 Geschick, +4 Härtung")
	for id in ["drachenhelm", "drachenpanzer", "drachenhandschuhe", "drachenstiefel"]:
		check(Crafting.RECIPES.has(id) and Crafting.RECIPES[id].result == id and Crafting.RECIPES[id].found == DragonLair.SCALE, "%s is crafted from dragon scales" % id)
	for id in ["hydrahelm", "hydrapanzer", "hydrahandschuhe", "hydrastiefel", "wyrmhelm", "wyrmpanzer", "wyrmhandschuhe", "wyrmstiefel"]:
		check(not Items.merchant_sells(id), "%s is never sold" % id)
		check(not Forge.recipes().has(id) and not Forge.can_melt(id), "Gorm neither forges nor melts %s" % id)
	check(Items.is_top_tier("plattenpanzer"), "trophies leave the plate armour the top of its kind")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var twice := 0
	for i in 200:
		var parts := DragonLair.parts(rng)
		check(parts.count(DragonLair.SCALE) >= 1, "the dragon always leaves a scale")
		if parts.count(DragonLair.SCALE) == 2:
			twice += 1
	check(twice > 40 and twice < 120, "now and then a second scale (%d of 200)" % twice)

	# Armour value: a share off each hit after the hardening, on average exact.
	check(Player.armour_cut(4, 25, 0.99) == 3 and Player.armour_cut(4, 0, 0.0) == 4, "25 %% off a hit of 4 leaves 3")
	var sum := 0
	for i in 1000:
		sum += Player.armour_cut(2, 30, (i + 0.5) / 1000.0)
	check(absf(sum / 1000.0 - 1.4) < 0.01, "on average 30 %% off a hit of 2 leaves 1.4 (%.3f)" % (sum / 1000.0))
	check(Player.armour_cut(1, 40, 0.9) == 0 and Player.armour_cut(1, 40, 0.1) == 1, "a light hit is now and then caught whole")
	p.equipped = {"kopf": "ritterhelm", "ruestung": "plattenpanzer", "handschuhe": "panzerhandschuhe", "schuhe": "stahlstiefel"}
	p.refresh_stats()
	check(p.armour_value == 23, "the steel pieces add up their armour value (%d)" % p.armour_value)
	var cloth := 0
	for id in ["filzkappe", "steppwams", "stoffhandschuhe", "stoffschuhe"]:
		cloth += Items.ALL[id].get("armour_value", 0)
	check(cloth < 23, "cloth protects far less than steel")
	var page := CharacterPage.new(p, game.TEXT_FONT)
	var hd: Dictionary = page.details(CharacterPage.HARDENING)
	var ad: Dictionary = page.details(CharacterPage.ARMOUR)
	check(hd.title == Lang.t("Härtung") and ad.title == Lang.t("Rüstungswert") and str(p.armour_value) in ad.lines[0], "the character page explains both")
	page.free()

	print("PASS: armour sets" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
