extends SceneTree
## Headless test for the uses of thunder ore: Gorm forges the thunder weapons
## from iron, gold and lumps of thunder ore out of the bag (and nothing
## without the ore), the ore bundles in the bag, a thunder weapon's blow may
## stun an enemy for a moment, and bosses, horrors and big brutes shrug the
## stun off.
## Run with: godot --headless --fixed-fps 60 -s tests/thunder_ore.gd

const HERO := "Thunder ore test"
const ORE := "donnererz"
const WEAPONS := ["donnerklinge", "donnerhammer"]

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
		print("PASS: thunder ore")
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

	# The weapons and what they are made of.
	for id in WEAPONS:
		var item: Dictionary = Items.ALL[id]
		check(item.slot == "waffe" and item.get("shock", 0.0) > 0.0, "%s is a weapon whose blows may stun" % id)
		check(Forge.recipes().has(id), "Gorm forges %s" % id)
		check(int(Forge.forge_cost(id).ore) == int(item.thunder) and int(item.thunder) > 0, "%s takes thunder ore" % id)
		check(not Items.merchant_sells(id) and item.get("no_loot", false), "%s is never sold or found as loot" % id)
		check(Items.describe(id).contains("%"), "%s tells its stun chance: %s" % [id, Items.describe(id)])
	check(Forge.wares().has("streitkolben") and not Forge.wares().has("kriegshammer"), "the war hammer stays forge-only (the thunder hammer does not push it into Gorm's shop)")
	for id in Forge.recipes():
		if not WEAPONS.has(id):
			check(int(Forge.forge_cost(id).ore) == 0, "%s takes no thunder ore" % id)

	# The ore bundles in one bag slot.
	p.bag.clear()
	p.bag.append_array([ORE, ORE, ORE])
	check(p.bag_used() == 1, "three lumps of thunder ore share one bag slot")

	# Forging a thunder blade.
	game.menus.open("schmied")
	game.menus._show_forge_tab("schmieden")
	var cost := Forge.forge_cost("donnerklinge", game)
	game.iron = cost.iron
	game.coins = cost.gold
	p.bag.assign([ORE])
	game.menus._rebuild()
	check(not Forge.can_afford(game, "donnerklinge"), "one lump is not enough")
	var row: Dictionary = game.menus.trade._entries.get("donnerklinge", {})
	var told := false
	for line in row.get("detail", {}).get("lines", []):
		told = told or (str(line[0]).contains("2") and str(line[0]).contains(Lang.t("Donnererz")) and line[1] == TradeWindow.RED)
	check(told, "the forge's details tell the ore it needs, in red while the bag holds too little")
	check(not row.get("enabled", true), "the forge button waits for the ore")
	game.menus._forge("donnerklinge")
	check(not p.bag.has("donnerklinge") and p.bag.count(ORE) == 1 and game.iron == cost.iron, "without enough ore nothing is forged or taken")
	p.bag.append(ORE)
	check(Forge.can_afford(game, "donnerklinge"), "two lumps, iron and gold are enough")
	game.menus._forge("donnerklinge")
	check(Array(p.bag) == ["donnerklinge"] and game.iron == 0 and game.coins == 0, "iron, gold and the ore become a thunder blade (%s)" % str(p.bag))
	# A full bag keeps its ore.
	game.iron = 99
	game.coins = 999
	p.bag.assign([ORE, ORE, ORE])
	while p.bag_used() < p.bag_size():
		p.bag.append("lederwams")
	var before := p.bag.size()
	var ok := Forge.forge(game, "donnerhammer")
	check(ok == "" and p.bag.has("donnerhammer") and p.bag.count(ORE) == 0 and p.bag.size() == before - 2, "the used-up ore makes room for the hammer")
	game.menus.close()

	# The stun.
	p.bag.assign(["donnerklinge"])
	check(p.shock_chance() == 0.0, "an empty hand does not stun")
	check(p.equip("donnerklinge"), "the thunder blade can be held")
	check(is_equal_approx(p.shock_chance(), float(Items.ALL.donnerklinge.shock)), "held, it may stun")
	var e := Enemy.new()
	e.kind = "krieger"
	e.level = game.level
	game.level.add_child(e)
	game.level.enemies.append(e)
	await _wait(2)
	# Far from the hero and slow to strike, so nothing but the stun keeps it busy.
	e.global_position = p.global_position + Vector3(0, 0, 20)
	e._cooldown = 99.0
	e.hp = 50
	check(e.can_be_stunned() and e.shock(), "a skeleton warrior is stunned")
	check(e._busy >= Enemy.SHOCK_TIME - 0.05, "it stands still for a moment")
	await _wait(30)
	check(e._busy > 0.0, "still stunned half a second later")
	await _wait(80)
	check(e._busy <= 0.0, "and back on its feet after %.1f s" % Enemy.SHOCK_TIME)
	e._stats = e._stats.duplicate()
	e._stats["big"] = true
	check(not e.can_be_stunned() and not e.shock(), "a big brute shrugs it off")
	var chief := BanditChief.new()
	check(not chief.can_be_stunned(), "the bandit chief shrugs it off")
	chief.free()
	_finish()
