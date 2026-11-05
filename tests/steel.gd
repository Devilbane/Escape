extends SceneTree
## Headless test for steel at Gorm's forge: an iron bar, charcoal and
## limestone make a steel bar, but only from Stahlkochen level
## Forge.STEEL_MAKING_LEVEL; steel gear is forged from steel bars only, and
## only from Schmiedekunst level Forge.STEEL_FORGING_LEVEL; both crafts grow
## by working at the forge; Gorm sells the charcoal, the creatures of the
## mountains carry the limestone; steel gear is always rare or finer; steel
## gear melts back into steel; the steel bars are kept in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/steel.gd

const HERO := "Steel test"

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
		print("PASS: steel")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## Gives the hero just enough training for `level` in a craft.
func _set_level(craft: String, level: int) -> void:
	var p: Player = game.player
	p.xp[craft] = 0.0
	while Training.skill_level(float(p.xp[craft]), craft) < level:
		p.xp[craft] = float(p.xp[craft]) + 0.5


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO

	# The rules.
	var steel_gear := Items.ALL.keys().filter(func(id): return Forge.is_steel(id))
	check(steel_gear.size() >= 4 and steel_gear.has("plattenpanzer") and steel_gear.has("ritterhelm"), "the steel set is steel gear (%s)" % str(steel_gear))
	for id in steel_gear:
		check(Level.rank_of(id) >= Level.tier_rank("selten"), "%s is rare or finer" % id)
		check(Forge.recipes().has(id), "Gorm forges %s" % id)
		var cost := Forge.forge_cost(id)
		check(cost.iron == 0 and cost.steel > 0, "%s takes steel bars, no iron (%s)" % [id, str(cost)])
		check(Forge.forge_level(id) == Forge.STEEL_FORGING_LEVEL, "%s needs Schmiedekunst %d" % [id, Forge.STEEL_FORGING_LEVEL])
		check(Forge.melt_into(id).get(Forge.STEEL, 0) == cost.steel and not Forge.melt_into(id).has("eisen"), "%s melts back into its steel" % id)
	check(not Forge.is_steel("kettenhemd") and Forge.forge_cost("kettenhemd").steel == 0 and Forge.forge_level("kettenhemd") == 0, "iron gear stays iron, with no level")
	check(Training.CRAFTS.has(Forge.FORGING) and Training.CRAFTS.has(Forge.STEEL_MAKING), "forging and steel making are crafts")
	for craft in [Forge.FORGING, Forge.STEEL_MAKING]:
		check(Lang.EN.has(Training.CRAFTS[craft].name), "%s has an English name" % craft)
	for ingredient in [Forge.CHARCOAL, Forge.LIMESTONE]:
		check(Crafting.INGREDIENTS.has(ingredient) and Lang.EN.has(Crafting.INGREDIENTS[ingredient].name), "%s is an ingredient with an English name" % ingredient)
		check(ItemIcon.kind_of(ingredient) != "bag", "%s has a picture of its own" % ingredient)
	check(Forge.STEEL_RECIPE.keys() == ["eisen", Forge.CHARCOAL, Forge.LIMESTONE], "a steel bar is iron, charcoal and limestone")
	check(Forge.STEEL_LEARN.contains("Stahlkochen Stufe %d" % Forge.STEEL_MAKING_LEVEL) and Forge.STEEL_LEARN.contains("Schmiedekunst Stufe %d" % Forge.STEEL_FORGING_LEVEL), "the compendium names both levels")
	check(Lang.EN.has(Forge.STEEL_LEARN), "the steel lore has its English")

	# Limestone from the mountains.
	check(Loot.limestone_find("felstroll", 0.0) >= Loot.TROLL_LIMESTONE[0], "a troll carries limestone on a lucky roll")
	check(Loot.limestone_find("felstroll", 0.99) == 0, "but not always")
	check(Loot.limestone_find("halsabschneider", 0.0) == 0 and Loot.limestone_find("wolf", 0.0) == 0, "foes of the lowlands carry none")
	game.load_level(game._outdoor_index(), false)
	var lvl: Level = game.level
	var troll := Enemy.new()
	troll.kind = "felstroll"
	troll.level = lvl
	lvl.add_child(troll)
	troll.global_position = p.global_position + Vector3(30, 0, 0)
	var limestone := 0
	for i in 40:
		var before: int = lvl._pickups.size()
		lvl.drop_kill_loot(troll, 0, 0.99, 0.99)
		for q in lvl._pickups.slice(before):
			if q.kind == "ingredient" and q.ingredient == Forge.LIMESTONE:
				limestone += int(q.count)
	check(limestone > 0, "fallen trolls leave limestone (%d in 40)" % limestone)
	troll.queue_free()

	# The forge window: no steel without the level.
	game.crafting.clear()
	game.bars = {}
	game.iron = 3
	game.coins = 100
	p.bag.clear()
	p.xp.erase(Forge.FORGING)
	p.xp.erase(Forge.STEEL_MAKING)
	game.menus.open("schmied")
	check(game.lore.has(Forge.STEEL_LEARN), "the compendium tells about steel")
	game.menus._show_forge_tab("schmieden")
	game.menus._buy_charcoal(5)
	check(game.crafting.have(Forge.CHARCOAL) == 5 and game.coins == 100 - 5 * Forge.CHARCOAL_PRICE, "Gorm sells charcoal (%d)" % game.coins)
	game.crafting.add(Forge.LIMESTONE, 3, false)
	game.menus._make_steel()
	check(int(game.bars.get(Forge.STEEL, 0)) == 0 and game.iron == 3, "without Stahlkochen %d no steel is made" % Forge.STEEL_MAKING_LEVEL)
	check(game.menus._note.contains(str(Forge.STEEL_MAKING_LEVEL)), "and the note names the level: %s" % game.menus._note)

	# Melting trains steel making.
	var melts := 0
	while Forge.craft_level(game, Forge.STEEL_MAKING) < Forge.STEEL_MAKING_LEVEL and melts < 100:
		p.bag.assign(["schwert"])
		check(Forge.melt(game, 0) == "", "a sword melts")
		melts += 1
	check(Forge.craft_level(game, Forge.STEEL_MAKING) >= Forge.STEEL_MAKING_LEVEL, "melting teaches steel making (%d melts)" % melts)
	check(melts >= 3, "but it takes a few melts (%d)" % melts)
	game.iron = 3
	game.menus._make_steel()
	check(int(game.bars.get(Forge.STEEL, 0)) == 1 and game.iron == 2 and game.crafting.have(Forge.CHARCOAL) == 4 and game.crafting.have(Forge.LIMESTONE) == 2,
			"an iron bar, a charcoal and a limestone become a steel bar")
	game.crafting.take(Forge.LIMESTONE, 2)
	game.menus._make_steel()
	check(int(game.bars.get(Forge.STEEL, 0)) == 1 and game.iron == 2, "no limestone, no steel")
	check(game.menus._note != "", "and the note says why")

	# Forging steel gear: the level first, then the steel.
	var helm := "ritterhelm"
	var cost := Forge.forge_cost(helm, game)
	game.bars[Forge.STEEL] = cost.steel
	game.coins = cost.gold + 50
	_set_level(Forge.FORGING, Forge.STEEL_FORGING_LEVEL - 1)
	check(not Forge.can_afford(game, helm), "steel bars are not enough without the level")
	game.menus._forge(helm)
	check(not p.bag.has(helm) and int(game.bars[Forge.STEEL]) == cost.steel, "without Schmiedekunst %d no steel helmet" % Forge.STEEL_FORGING_LEVEL)
	check(game.menus._note.contains(str(Forge.STEEL_FORGING_LEVEL)), "and the note names the level: %s" % game.menus._note)
	_set_level(Forge.FORGING, Forge.STEEL_FORGING_LEVEL)
	game.bars[Forge.STEEL] = cost.steel - 1
	game.iron = 50
	game.menus._forge(helm)
	check(not p.bag.has(helm) and game.iron == 50, "iron does not stand in for steel")
	game.bars[Forge.STEEL] = cost.steel
	p.bag.clear()
	var xp_before := float(p.xp.get(Forge.FORGING, 0.0))
	game.menus._forge(helm)
	check(p.bag.has(helm) and not game.bars.has(Forge.STEEL) and game.iron == 50 and game.coins == 50, "steel bars and gold become a knight's helmet")
	check(float(p.xp.get(Forge.FORGING, 0.0)) > xp_before, "forging trains Schmiedekunst")
	xp_before = float(p.xp.get(Forge.FORGING, 0.0))
	game.menus._forge("schwert")
	check(float(p.xp.get(Forge.FORGING, 0.0)) > xp_before, "any piece forged trains it")
	game.menus.close()

	# The steel bars are kept in the saved game and in the house's metal chest.
	check(HomeStores.store_of(Forge.STEEL) == HomeStores.METAL and HomeStores.store_of(Forge.CHARCOAL) == HomeStores.METAL, "steel and charcoal go into the metal chest")
	game.bars = {Forge.STEEL: 6}
	await _wait(5)
	check(game.save_game(), "the game saves")
	var data: Dictionary = game._read_save(game.save_path())
	game.bars = {}
	game._apply_save(data)
	await _wait(5)
	check(int(game.bars.get(Forge.STEEL, 0)) == 6, "after loading the steel bars are back (%s)" % str(game.bars))
	_finish()
