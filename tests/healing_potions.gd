extends SceneTree
## Headless test for healing potions (see HealingPotions): Priestess Elsbeth
## hands out the recipe, it is brewed at the alchemist's table from wild
## garlic and slime jelly, and the brewer's Intelligenz and Alchemie pick a
## low, medium or high potency. Five potions bundle in one bag slot. A potion
## heals 15-20, 25-35 or 40-60 % of the lives at once, then 1 life a second
## for 20 seconds whatever its potency, and the next one waits a minute. The
## potion button stands left of the torch button, as big, shows only while
## the hero carries a potion, counts them, shades while it waits and moves
## nothing on the rail; the key 1 and "Drink" in the inventory work too.
## Run with: godot --headless --fixed-fps 60 -s tests/healing_potions.gd

const HERO := "Healing potion test"

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _rail_rects() -> Array:
	var out := []
	for b in game._quick_buttons.values():
		out.append(b.get_global_rect())
	out.append(game._drawer_handle.get_global_rect())
	out.append(game._torch_button.get_parent().get_global_rect())
	return out


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	game._unhandled_input(e)
	await _wait(2)


## Finds a button with this text somewhere under a node.
func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


## Whether some label under a node starts with this text.
func _has_label(node: Node, start: String) -> bool:
	if node is Label and (node as Label).text.begins_with(start):
		return true
	for child in node.get_children():
		if _has_label(child, start):
			return true
	return false


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.crafting.clear()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var c: Crafting = game.crafting
	var potions: HealingPotions = p.potions
	check(potions != null and potions.player == p, "every hero carries the potion state")

	# The items: three potencies, five to a slot, never worn.
	for id in HealingPotions.POTIONS:
		check(Items.ALL.has(id) and Items.is_potion(id), "%s is a potion item" % id)
		check(Items.stack_size(id) == 5, "%s stacks 5 to a slot" % id)
		check(Lang.EN.has(Items.ALL[id].name) and Lang.EN.has(Items.ALL[id].effect), "%s has English texts" % id)
		check(Items.describe(id).contains("15") or Items.describe(id).contains("25") or Items.describe(id).contains("40"), "%s's card says how much it heals" % id)
		check(not Items.merchant_sells(id), "%s is not sold, only brewed" % id)
	check(Items.slots_used(["heiltrank", "heiltrank", "heiltrank", "heiltrank", "heiltrank"]) == 1, "five potions share one slot")
	check(Items.slots_used(["heiltrank", "heiltrank", "heiltrank", "heiltrank", "heiltrank", "heiltrank"]) == 2, "a sixth opens a second slot")
	check(Items.slots_used(["heiltrank", "heiltrank_stark"]) == 2, "different potencies do not share a slot")
	# Furniture gives potions to keep, mostly the weakest kind.
	check(HealingPotions.loot_potion(0.0) == "heiltrank_schwach" and HealingPotions.loot_potion(0.69) == "heiltrank_schwach", "furniture mostly holds weak potions")
	check(HealingPotions.loot_potion(0.8) == "heiltrank" and HealingPotions.loot_potion(0.99) == "heiltrank_stark", "medium ones are rarer, strong ones rarest")
	check(Training.CRAFTS.has("alchemie") and Lang.EN.has(Training.CRAFTS.alchemie.name), "alchemy is a craft")

	# Potency from Intelligenz + 2 x Alchemie.
	check(HealingPotions.points(10, 0) == 10, "brewing points: Intelligenz + 2 x Alchemie")
	check(HealingPotions.brewed(10) == "heiltrank_schwach", "a fresh brewer brews low potency")
	check(HealingPotions.brewed(15) == "heiltrank_schwach" and HealingPotions.brewed(16) == "heiltrank", "medium from 16 points")
	check(HealingPotions.brewed(25) == "heiltrank" and HealingPotions.brewed(26) == "heiltrank_stark", "high from 26 points")
	check(HealingPotions.brewed(80) == "heiltrank_stark", "nothing above high")

	# Elsbeth hands out the recipe.
	check(_villager("O") != null, "Priestess Elsbeth lives in the village")
	check(c.offer_of("O") == HealingPotions.RECIPE, "Elsbeth has the healing potion recipe")
	check(c.talk(_villager("O")) and c.knows(HealingPotions.RECIPE), "she hands it over")
	check(c.recipes_for("alchemie") == [HealingPotions.RECIPE], "the alchemist's table lists it")
	check(c.why_not(HealingPotions.RECIPE).begins_with(Lang.t("Es fehlt: %s").split("%")[0]), "without ingredients it cannot be brewed")

	# Brewing: a fresh hero brews low potency, and alchemy trains.
	p.bag.clear()
	p.xp.erase("alchemie")
	c.add("baerlauch", 3)
	c.add("schleimgelee", 3)
	check(c.why_not(HealingPotions.RECIPE) == "", "with the ingredients it can be brewed")
	check(c.potency_line(HealingPotions.RECIPE) != "", "the table says what potency the hero brews")
	game.menus.bench = "alchemie"
	game.menus.open("werkbank")
	await _wait()
	check(_has_label(game.menus._box, Lang.t("Du braust: %s (Stärke %s)").split("%")[0]), "the bench row shows the potency")
	var make := _button(game.menus._box, Lang.t("Herstellen"))
	check(make != null and not make.disabled, "the brew button is ready")
	await _shot("potion_bench")
	if make != null:
		make.pressed.emit()
		await _wait()
	check(p.bag.count("heiltrank_schwach") == 1, "a fresh brewer gets a weak potion")
	check(c.have("baerlauch") == 2 and c.have("schleimgelee") == 2, "the ingredients are used up")
	check(float(p.xp.get("alchemie", 0.0)) > 0.0, "brewing trains alchemy")
	game.menus.close()
	await _wait()
	p.xp["alchemie"] = 100000.0
	check(c.result_of(HealingPotions.RECIPE) == "heiltrank_stark", "a master alchemist brews high potency")
	check(c.make(HealingPotions.RECIPE) == "" and p.bag.has("heiltrank_stark"), "and gets a strong potion")
	p.xp.erase("alchemie")

	# The button: hidden without potions, left of the torch, nothing moves.
	p.bag.clear()
	p.bag.append(HandTorch.ITEM)
	await _wait()
	var button: Button = game._potion_button
	check(button != null and not button.visible, "without a potion the button is hidden")
	var before := _rail_rects()
	for i in 6:
		p.bag.append("heiltrank")
	await _wait()
	check(button.visible, "with potions the button shows")
	check(game._potion_count.text == "6", "it counts the potions (%s)" % game._potion_count.text)
	var after := _rail_rects()
	for i in before.size():
		check(before[i].is_equal_approx(after[i]), "the rail does not move when the potion button shows (%d)" % i)
	var r := button.get_global_rect()
	var tr: Rect2 = game._torch_button.get_global_rect()
	check(r.size.is_equal_approx(game.QUICK_SIZE), "the potion button is as big as the torch button")
	check(absf(r.position.y - tr.position.y) < 0.5, "it stands on the torch button's line")
	check(absf(tr.position.x - r.end.x - game.QUICK_GAP) < 0.5, "just left of the torch button")
	check(button.tooltip_text.ends_with("(Taste 1)") or button.tooltip_text.ends_with("(key 1)"), "the tooltip names the key: " + button.tooltip_text)
	var keys: Array = game.menus.SHORTCUTS.map(func(s): return s[0])
	check(keys.has("Heiltrank trinken"), "the key is in the list of shortcuts")
	await _shot("potion_button")

	# Drinking: heals 25-35 % at once, starts the minute and the 20 seconds.
	p.max_hp = 100
	p.hp = 10
	button.button_down.emit()
	button.pressed.emit()
	var healed := p.hp - 10
	check(healed >= 25 and healed <= 35, "a medium potion heals 25-35 %% (%d)" % healed)
	check(p.bag.count("heiltrank") == 5, "one potion is used up")
	check(is_equal_approx(potions.cooldown, HealingPotions.COOLDOWN), "the next one waits a minute")
	check(potions.pulses_left == HealingPotions.REGEN_TIME, "20 seconds of life to come")
	check(game.lore.has(HealingPotions.LEARN), "the compendium explains potions")
	await _wait(2)
	check(game._potion_shade.visible and game._potion_wait.text != "", "the button shades and counts the seconds")
	await _shot("potion_cooldown")

	# A second one waits for the cooldown, by key too.
	var hp_now := p.hp
	await _key(KEY_1)
	check(p.bag.count("heiltrank") == 5, "during the cooldown the key drinks nothing")
	check(potions.drink() != "", "and says why")

	# The life over time: 1 a second for 20 seconds, then no more.
	p.hp = 10
	potions.pulses_left = HealingPotions.REGEN_TIME
	potions._pulse_clock = 0.0
	for i in 25:
		potions.tick(1.0)
	check(p.hp == 30, "+1 life a second for 20 seconds (%d)" % p.hp)
	check(potions.cooldown > 0.0, "the minute is not over yet")
	for i in 40:
		potions.tick(1.0)
	check(potions.cooldown == 0.0 and p.hp == 30, "the minute is over after it, no more life")
	await _wait(2)
	check(not game._potion_shade.visible and game._potion_wait.text == "", "the shade is gone once it is ready")

	# Low and high potency.
	p.bag.append("heiltrank_schwach")
	p.hp = 10
	check(potions.drink("heiltrank_schwach") == "", "a weak potion can be named")
	check(p.hp - 10 >= 15 and p.hp - 10 <= 20, "a weak potion heals 15-20 %% (%d)" % (p.hp - 10))
	potions.cooldown = 0.0
	p.bag.append("heiltrank_stark")
	check(potions.best() == "heiltrank_stark", "the button drinks the strongest first")
	p.hp = 10
	check(potions.drink() == "", "a strong potion is drunk")
	check(p.hp - 10 >= 40 and p.hp - 10 <= 60, "a strong potion heals 40-60 %% (%d)" % (p.hp - 10))
	check(potions.pulses_left == HealingPotions.REGEN_TIME, "every potency gives the same 20 seconds")
	# Never more than the full lives.
	potions.cooldown = 0.0
	p.hp = p.max_hp - 1
	check(potions.drink() == "" and p.hp == p.max_hp, "healing stops at full life")

	# The inventory: "Drink", never "Wear".
	potions.cooldown = 0.0
	potions.pulses_left = 0
	check(not p.equip("heiltrank"), "a potion is not worn")
	game.menus.open("inventar")
	await _wait()
	var at := p.bag.find("heiltrank")
	game.menus._select(at)
	await _wait()
	var drink := _button(game.menus._box, Lang.t("Trinken"))
	check(drink != null, "the inventory offers to drink a potion")
	check(_button(game.menus._box, Lang.t("Anlegen")) == null, "and not to wear it")
	var count := p.bag.count("heiltrank")
	p.hp = 10
	if drink != null:
		drink.pressed.emit()
		await _wait()
	check(p.bag.count("heiltrank") == count - 1 and p.hp > 10, "Drink in the inventory drinks it")
	game.menus.close()
	await _wait()

	# No potion left: the key says why, the button hides.
	potions.cooldown = 0.0
	for id in HealingPotions.POTIONS:
		while p.bag.has(id):
			p.bag.erase(id)
	check(potions.drink() != "", "without a potion it says why")
	await _wait()
	check(not button.visible, "and the button is hidden again")
	p.refresh_stats()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: healing potions")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
