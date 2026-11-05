extends SceneTree
## Headless test for the loot of fallen monsters (see Loot and
## Level.drop_kill_loot): the drop odds per rarity tier, who counts as
## intelligent, the coins they carry, the food, ingredients and parts the
## beasts leave, slimes holding their victims' things, god-born pieces not
## being loot, and a hundred coins melting into one bar at the forge.
## Run with: godot --headless -s tests/loot.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_odds()
	_test_minds()
	_test_creatures()
	_test_coins()
	_test_no_godborn()
	_test_ore()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test_game()
	return false


## Odds per kill: common 1 in 20 to 40, uncommon 1 in 80 to 160, rare 1 in
## 320 to 640, epic 1 in 1000 to 2500; tough foes get the short odds.
func _test_odds() -> void:
	var ranges := {"normal": [20, 40], "ungewoehnlich": [80, 160], "selten": [320, 640], "episch": [1000, 2500]}
	for tier in ranges:
		var best: float = 1.0 / ranges[tier][0]
		var worst: float = 1.0 / ranges[tier][1]
		check(is_equal_approx(Loot.chance(tier, 1.0), best), "%s: 1 in %d for the toughest" % [tier, ranges[tier][0]])
		check(is_equal_approx(Loot.chance(tier, 0.0), worst), "%s: 1 in %d for the weakest" % [tier, ranges[tier][1]])
		var mid := Loot.chance(tier, 0.5)
		check(mid > worst and mid < best, "%s: in between for a middling foe" % tier)
	check(Loot.chance("gottgeboren", 1.0) == 0.0, "god-born pieces are never loot")
	check(Loot.toughness(1) == 0.0 and Loot.toughness(Loot.TOUGH_HP) == 1.0, "toughness runs from 1 life to TOUGH_HP")
	check(Loot.toughness(2, true) == 1.0 and Loot.toughness(2, false, true) == 1.0, "elites and bosses get the best odds")
	# A roll lands on the finest tier first, then the plainer ones, then nothing.
	check(Loot.roll_tier(0.0, Loot.TOP_TIER, 0.0) == "episch", "the luckiest roll is epic")
	check(Loot.roll_tier(0.0, Loot.TOP_TIER, 0.99) == "", "most rolls find nothing")
	check(Loot.roll_tier(0.0, "normal", 0.0) == "normal", "a roll capped at common is common")
	# Over many kills the shares match the odds.
	var counts := {}
	var n := 400000
	for i in n:
		var t := Loot.roll_tier(0.0)
		counts[t] = int(counts.get(t, 0)) + 1
	for tier in ranges:
		var share := float(counts.get(tier, 0)) / n
		var want := Loot.chance(tier, 0.0)
		check(absf(share - want) < want * 0.25, "%s turns up about 1 in %d (%.5f vs %.5f)" % [tier, ranges[tier][1], share, want])


## Skeletons, people, orcs, trolls and dragons are intelligent; wolves,
## spiders, bats, yetis and slimes are not, but slimes carry valuables.
func _test_minds() -> void:
	for kind in ["krieger", "schuetze", "magier", "wicht", "koloss", "waechter", "fog_wraith", "halsabschneider", "hauptmann",
			"klippenschuetze", "ork", "bergork", "felstroll", "bergkoenig", "drache"]:
		check(Loot.is_intelligent(kind), "%s is intelligent" % kind)
		check(Loot.carries_valuables(kind), "%s carries coins and gear" % kind)
	for kind in ["wolf", "eiswolf", "spinne", "fledermaus", "yeti", "schleim", "glutschleim"]:
		check(not Loot.is_intelligent(kind), "%s is not intelligent" % kind)
	for kind in Loot.SWALLOWS:
		check(Loot.carries_valuables(kind), "%s holds what its victims carried" % kind)
	check(not Loot.carries_valuables("wolf"), "a wolf carries no coins")


## Every beast without a mind has a table: food (common), an ingredient of
## where it lives (uncommon), a part (rare), each a real ingredient of that tier.
func _test_creatures() -> void:
	var want := {"food": "normal", "biome": "ungewoehnlich", "part": "selten"}
	for kind in Enemy.KINDS:
		if Loot.is_intelligent(kind):
			continue
		check(Loot.CREATURES.has(kind), "%s has a loot table" % kind)
		if not Loot.CREATURES.has(kind):
			continue
		for key in want:
			var what = Loot.CREATURES[kind][key]
			for id in (what if what is Array else [what]):
				check(Crafting.INGREDIENTS.has(id), "%s's %s %s is an ingredient" % [kind, key, id])
				check(Rarity.tier(id) == want[key], "%s's %s %s is %s, not %s" % [kind, key, id, want[key], Rarity.tier(id)])
				check(Lang.EN.has(Crafting.INGREDIENTS.get(id, {}).get("name", "?")), "%s has an English name" % id)
	check(Loot.creature_find("wolf", "normal") == "wildfleisch", "a wolf may leave meat")
	check(Loot.creature_find("wolf", "selten") == "wolfsfell", "a wolf may leave its pelt")
	check(Loot.creature_find("wolf", "episch") == "", "a beast has no epic find")
	check(Loot.creature_find("krieger", "normal") == "", "an intelligent foe has no beast table")


## Intelligent foes always carry iron coins, tough ones copper and silver
## more often; beasts carry none; slimes now and then.
func _test_coins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var copper_weak := 0
	var copper_tough := 0
	var slime_iron := 0
	for i in 400:
		var weak := Loot.coins("wicht", 0.0, rng)
		check(int(weak.get("eisenmuenze", 0)) >= 2, "a fallen skeleton leaves iron coins")
		copper_weak += 1 if weak.has("kupfermuenze") else 0
		copper_tough += 1 if Loot.coins("bergkoenig", 1.0, rng).has("kupfermuenze") else 0
		check(Loot.coins("wolf", 1.0, rng).is_empty(), "a wolf leaves no coins")
		slime_iron += 1 if Loot.coins("schleim", 0.1, rng).has("eisenmuenze") else 0
	check(copper_tough > copper_weak, "tough foes carry copper more often (%d vs %d)" % [copper_tough, copper_weak])
	check(slime_iron > 100 and slime_iron < 300, "a slime holds coins about half the time (%d of 400)" % slime_iron)
	for coin in Loot.COINS:
		check(Crafting.INGREDIENTS.has(coin) != (coin == Loot.MONEY), "%s goes into the pouch, or is the money" % coin)
		check(Forge.METALS.has(Loot.COINS[coin]), "%s melts into a real metal" % coin)
		check(ItemIcon.kind_of(coin) == "coin", "%s looks like a coin" % coin)
	check(Lang.EN.get("Kupferbarren", "") == "Copper bar" and Forge.FINE.has("kupfer"), "copper bars are kept with the fine bars")


## No chest, kill or hoard holds a god-born piece, even when asked for one.
func _test_no_godborn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 300:
		var id := Items.random_item(rng, Level.tier_rank("gottgeboren"), "", 0, {}, Level.tier_rank("gottgeboren"))
		check(Level.tier_of(id) != "gottgeboren", "%s is god-born loot" % id)
	var lvl := Level.new()
	lvl.depth = 9
	for i in 4:
		var id := lvl.loot_item(rng, Level.tier_rank("gottgeboren"), 12)
		check(Level.tier_of(id) != "gottgeboren", "a god-born chest holds no god-born piece (%s)" % id)
	lvl.free()


## Ore: trolls and mountain creatures carry it; its weight sets its tier;
## its make-up is rolled in order, slag 25-60 %, iron 10-40 %, copper 5-40 %,
## silver 1-15 %, gold 1-5 %, the rest an unknown metal; melted, it gives
## the grams of each metal in it.
func _test_ore() -> void:
	for kind in ["felstroll", "bergkoenig", "eiswolf", "bergork", "kristallschleim", "klippenschuetze"]:
		check(Loot.drops_ore(kind), "%s carries ore" % kind)
	for kind in ["wolf", "krieger", "schleim"]:
		check(not Loot.drops_ore(kind), "%s carries no ore" % kind)
	check(Loot.ore_find("felstroll", 1.0, 0.0) == "erzbrocken_episch", "the luckiest troll roll is noble ore")
	check(Loot.ore_find("felstroll", 1.0, Loot.chance("episch", 1.0) + 0.0001) == "erzbrocken_gross", "the next luckiest is a large lump")
	check(Loot.ore_find("felstroll", 1.0, 0.99) == "", "most trolls carry none")
	check(Loot.ore_find("wolf", 1.0, 0.0) == "", "a wolf never carries ore")
	var weights := {"erzbrocken_klein": [500, 999, "normal"], "erzbrocken": [1000, 2000, "ungewoehnlich"], "erzbrocken_gross": [2500, 5000, "selten"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var unknown := 0
	for id in weights:
		check(Rarity.tier(id) == weights[id][2], "%s is %s" % [id, weights[id][2]])
		check(Ore.lump_of_tier(weights[id][2]) == id, "a %s find is a %s" % [weights[id][2], id])
		for i in 300:
			var lump := Ore.roll(id, rng)
			check(int(lump.grams) >= weights[id][0] and int(lump.grams) <= weights[id][1], "%s weighs %d g" % [id, lump.grams])
			var share: Dictionary = lump.share
			var total := 0
			for part in share:
				total += int(share[part])
			check(total == 100, "the shares make 100 %")
			check(share.schlacke >= 25 and share.schlacke <= 60, "slag 25-60 %")
			check(share.eisen >= 10 and share.eisen <= 40, "iron 10-40 %")
			check(share.kupfer <= 40 and share.silber <= 15 and share.gold <= 5, "copper, silver and gold within their shares")
			unknown += 1 if int(share.unbekannt) > 0 else 0
			var grams := Ore.metal_grams(lump)
			check(not grams.has(Ore.SLAG), "slag is thrown away")
			check(int(grams.get("eisen", 0)) == floori(int(lump.grams) * int(share.eisen) / 100.0), "the iron is its share of the weight")
	check(unknown > 0, "some lumps hold the unknown metal (%d)" % unknown)
	# Noble ore: little slag, much silver and gold, one to five uncut gems.
	check(Rarity.tier("erzbrocken_episch") == "episch", "noble ore is epic")
	for i in 300:
		var lump := Ore.roll("erzbrocken_episch", rng)
		var share: Dictionary = lump.share
		check(share.schlacke >= 10 and share.schlacke <= 20 and share.eisen >= 5 and share.eisen <= 15 and share.kupfer >= 5 and share.kupfer <= 15
				and share.silber >= 10 and share.silber <= 20 and share.gold >= 20 and share.gold <= 30, "noble ore's shares: %s" % str(share))
		check(lump.gems.size() >= 1 and lump.gems.size() <= 5, "one to five gems (%d)" % lump.gems.size())
	# Gems: their weight in carat sets their rarity; cutting takes 15-50 %.
	var tiers := {2: "normal", 4: "normal", 5: "ungewoehnlich", 11: "ungewoehnlich", 12: "selten", 18: "selten", 19: "episch", 22: "episch", 23: "gottgeboren", 24: "gottgeboren"}
	for carat in tiers:
		check(Ore.gem_tier(carat) == tiers[carat], "%d ct is %s" % [carat, tiers[carat]])
	var seen := {}
	for i in 3000:
		var carat := Ore.roll_carat(rng)
		check(carat >= 2 and carat <= 24, "a gem weighs 2 to 24 ct (%d)" % carat)
		seen[Ore.gem_tier(carat)] = int(seen.get(Ore.gem_tier(carat), 0)) + 1
	check(int(seen.get("normal", 0)) > int(seen.get("ungewoehnlich", 0)) and int(seen.get("ungewoehnlich", 0)) > int(seen.get("selten", 0)), "small gems are the most common: %s" % str(seen))
	for i in 300:
		var cut := Ore.cut_weight(20, rng)
		check(cut >= 10 and cut <= 17, "a 20 ct gem cuts to 10-17 ct (%d)" % cut)
	check(Ore.GRAMS_PER_BAR == Loot.COINS_PER_BAR * Ore.COIN_GRAMS, "a bar weighs as much as a hundred coins")


func _test_game() -> void:
	game.hero_name = "Loot test"
	game.crafting.clear()
	game.bars = {}
	game.iron = 0
	game.load_level(game._outdoor_index(), false)
	var lvl: Level = game.level
	# An intelligent foe: gold, pouch coins, and on a lucky roll an epic piece.
	var bandit := Enemy.new()
	bandit.kind = "halsabschneider"
	bandit.level = lvl
	lvl.add_child(bandit)
	bandit.global_position = game.player.global_position + Vector3(30, 0, 0)
	var before: int = lvl._pickups.size()
	var found := lvl.drop_kill_loot(bandit, 2, 0.0)
	check(Level.tier_of(found) == "episch", "a lucky bandit kill drops an epic piece (%s)" % found)
	var added: Array = lvl._pickups.slice(before)
	check(added.filter(func(p): return p.kind == "coin").size() == 2, "two gold coins from the purse")
	check(added.any(func(p): return p.kind == "ingredient" and p.ingredient == "eisenmuenze" and int(p.count) >= 2), "a heap of iron coins")
	check(added.any(func(p): return p.kind == "item" and p.id == found), "the epic piece lies on the floor")
	# A plain roll leaves coins only.
	before = lvl._pickups.size()
	check(lvl.drop_kill_loot(bandit, 0, 0.99) == "", "an unlucky roll drops no gear")
	check(lvl._pickups.slice(before).all(func(p): return p.kind == "ingredient" and Loot.is_coin(p.ingredient)), "only coins")
	bandit.queue_free()
	# A beast: no coins, but its rare part on a rare roll.
	var wolf := Enemy.new()
	wolf.kind = "wolf"
	wolf.level = lvl
	lvl.add_child(wolf)
	wolf.global_position = game.player.global_position + Vector3(-30, 0, 0)
	before = lvl._pickups.size()
	var rare_roll := Loot.chance("episch", 0.0) + Loot.chance("selten", 0.0) * 0.5
	check(lvl.drop_kill_loot(wolf, 5, rare_roll) == "wolfsfell", "a wolf leaves its pelt on a rare roll")
	added = lvl._pickups.slice(before)
	check(added.size() == 1 and added[0].kind == "ingredient" and added[0].loot, "only the pelt, and no gold")
	check(lvl.drop_kill_loot(wolf, 5, 0.99) == "", "most wolves leave nothing")
	wolf.queue_free()
	# Picked up: the coins go into the pouch, with no mark on the map.
	game._on_ingredient_collected("eisenmuenze", 250, true)
	check(game.crafting.have("eisenmuenze") == 250, "250 iron coins in the pouch")
	# A hundred coins melt into one bar.
	check(Forge.melt_coins(game, "eisenmuenze") == "" and game.iron == 1, "100 iron coins become an iron bar")
	check(Forge.melt_coins(game, "eisenmuenze") == "" and game.iron == 2, "and another")
	check(Forge.melt_coins(game, "eisenmuenze") != "" and game.iron == 2, "50 are not enough")
	check(game.crafting.have("eisenmuenze") == 50, "50 iron coins are left")
	# Copper coins are the money: picked up, they go into the purse.
	game.coins = 30
	game._on_ingredient_collected(Loot.MONEY, 100, true)
	check(game.coins == 130 and game.crafting.have(Loot.MONEY) == 130, "copper coins go into the purse")
	check(Forge.melt_coins(game, Loot.MONEY) == "" and int(game.bars.get("kupfer", 0)) == 1 and game.coins == 30, "100 copper coins become a copper bar")
	check(Forge.melt_coins(game, Loot.MONEY) != "" and game.coins == 30, "30 are not enough")
	check(Forge.sell_bars(game, "kupfer", 1) != "", "a copper bar is not sold back for the coins it was")

	# A troll may leave a lump of ore; melted, it gives grams, and full
	# kilos become bars.
	var troll := Enemy.new()
	troll.kind = "felstroll"
	troll.level = lvl
	lvl.add_child(troll)
	troll.global_position = game.player.global_position + Vector3(0, 0, 30)
	before = lvl._pickups.size()
	lvl.drop_kill_loot(troll, 0, 0.99, 0.0)
	check(lvl._pickups.slice(before).any(func(p): return p.kind == "ingredient" and p.ingredient == "erzbrocken_episch"), "a lucky troll drops noble ore")
	troll.queue_free()
	game._on_ingredient_collected("erzbrocken_gross", 1, true)
	game._on_ingredient_collected("erzbrocken", 1, true)
	check(game.crafting.have("erzbrocken_gross") == 1 and game.crafting.ores["erzbrocken_gross"].size() == 1, "the lump is in the pouch with its make-up")
	game.crafting.ores["erzbrocken_gross"][0] = {"grams": 4000, "share": {"schlacke": 30, "eisen": 40, "kupfer": 20, "silber": 6, "gold": 3, "unbekannt": 1}}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.crafting.for_save()))
	game.crafting.load_from(saved)
	check(int(game.crafting.ores["erzbrocken_gross"][0].grams) == 4000, "the lump keeps its make-up in the saved game")
	game.metal_grams = {}
	var iron_before: int = game.iron
	var out := Forge.melt_ore(game, "erzbrocken_gross")
	check(out.why == "", "Gorm melts the lump")
	check(out.grams == {"eisen": 1600, "kupfer": 800, "silber": 240, "gold": 120, "unbekannt": 40}, "it gives the grams of each metal: %s" % str(out.grams))
	check(game.iron == iron_before + 1 and int(game.metal_grams.eisen) == 600, "1600 g of iron: one bar and 600 g left")
	check(int(game.metal_grams.kupfer) == 800 and int(game.metal_grams.unbekannt) == 40, "the rest waits in grams")
	check(game.crafting.have("erzbrocken_gross") == 0 and not game.crafting.ores.has("erzbrocken_gross"), "the lump is gone")
	check(Forge.melt_ore(game, "erzbrocken_gross").why != "", "no lump, no melting")
	# Noble ore gives its gems; Gorm cuts them and buys the cut ones.
	game.crafting.add("erzbrocken_episch", 1, false)
	game.crafting.ores["erzbrocken_episch"][0].gems = [20, 3]
	var noble := Forge.melt_ore(game, "erzbrocken_episch")
	check(noble.why == "" and game.crafting.have(Ore.UNCUT) == 2 and game.crafting.gems[Ore.UNCUT] == [20, 3], "two uncut gems from the noble ore")
	var cut := Forge.cut_gem(game)
	check(cut.why == "" and cut.from == 20 and cut.to >= 10 and cut.to <= 17, "the 20 ct gem is cut down to %d ct" % cut.to)
	check(game.crafting.have(Ore.UNCUT) == 1 and game.crafting.gems[Ore.CUT] == [cut.to], "one cut gem, one still uncut")
	var gold_before: int = game.coins
	check(Forge.sell_gem(game) == "" and game.coins == gold_before + Ore.gem_worth(cut.to), "Gorm buys the cut gem")
	check(game.crafting.have(Ore.CUT) == 0 and Forge.sell_gem(game) != "", "no cut gem left to sell")
	saved = JSON.parse_string(JSON.stringify(game.crafting.for_save()))
	game.crafting.load_from(saved)
	check(game.crafting.gems.get(Ore.UNCUT, []) == [3], "the uncut gem keeps its weight in the saved game")
	# Metal armour is priced by its iron: a bar per kilo.
	check(Forge.armour_iron("plattenpanzer") == 8 and Forge.melt_yield("plattenpanzer") == 8, "plate armour holds 8 iron bars")
	check(Forge.forge_cost("plattenpanzer").iron == 8, "forging plate armour takes 8 bars")
	check(int(Items.ALL["plattenpanzer"].price) >= 8 * Forge.IRON_PRICE, "plate armour is worth at least its iron")
	check(Forge.armour_iron("schwert") == 0 and Forge.armour_iron("lederwams") == 0, "weapons and leather go by the old rule")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: loot")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
