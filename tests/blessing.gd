extends SceneTree
## Headless test for the temple's blessing (see Blessing): the six gods, a
## blessing in thirds that every rescue thins out until it is gone, the effects
## on the hero's stats, the temple window, the title on the character page and
## the saved game.
## Run with: godot --headless -s tests/blessing.gd

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
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	print("PASS: blessing" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	game.hero_name = "Blessing test"
	var p: Player = game.player
	p.reset_gifts()
	check(Blessing.ORDER.size() == Blessing.GODS.size() and Blessing.ORDER.size() >= 5, "a small pantheon is listed")
	for id in Blessing.ORDER:
		check(not Blessing.GODS[id].boon.is_empty(), "%s gives a boon" % id)
		check(ItemIcon.make(Blessing.GODS[id].icon, 20) != null, "%s has a picture" % id)
	check(p.blessing_god == "" and not p.blessed_before, "a new hero is not blessed")
	var base_hp := p.max_hp
	var base_power := p.power

	# Aurel: life, at full strength and thinner.
	Blessing.bless(p, "aurel")
	check(p.blessing_thirds == 3 and p.max_hp == base_hp + 3, "Aurel gives 3 life at full strength")
	check(Blessing.weaken(p) and p.blessing_thirds == 2 and p.max_hp == base_hp + 2, "a rescue takes a third of the boon")
	check(Blessing.weaken(p) and p.max_hp == base_hp + 1, "two rescues take two thirds")
	check(Blessing.weaken(p) and p.blessing_god == "" and p.blessing_thirds == 0 and p.max_hp == base_hp, "the third rescue ends the blessing")
	check(not Blessing.weaken(p), "an unblessed hero loses nothing")
	check(p.blessed_before, "the hero remembers having been blessed")

	# Boons and burdens.
	Blessing.bless(p, "ashkar")
	check(p.power == base_power + 6 and p.max_hp == base_hp - 3, "Ashkar gives power and takes life")
	Blessing.weaken(p)
	check(p.power == base_power + 4 and p.max_hp == base_hp - 2, "the burden shrinks with the boon")
	Blessing.bless(p, "korr")
	check(p.power == base_power + 3 and p.max_hp == base_hp, "blessing again replaces the old god")
	var speed := p.base_speed
	Blessing.bless(p, "skyra")
	check(p.base_speed > speed, "Skyra is quick")
	Blessing.bless(p, "dunmar")
	check(p.hardening >= 3, "Dunmar hardens")
	Blessing.bless(p, "veyl")
	check(p.block_chance >= 0.12 - 0.001, "Veyl blocks")
	check(p.max_hp >= 1, "life never drops under one")

	# Prices.
	check(Blessing.price_new(false) == 0 and Blessing.price_new(true) == Blessing.OFFERING, "the first blessing is free")
	check(Blessing.price_renew(3) == 0 and Blessing.price_renew(1) == 2 * Blessing.RENEW, "renewing costs per lost third")

	# The saved game keeps it.
	Blessing.bless(p, "skyra")
	Blessing.weaken(p)
	var saved := Blessing.for_save(p)
	Blessing.load_from(p, {})
	check(p.blessing_god == "", "loading an old save gives no blessing")
	Blessing.load_from(p, JSON.parse_string(JSON.stringify(saved)))
	check(p.blessing_god == "skyra" and p.blessing_thirds == 2 and p.blessed_before, "the blessing comes back from a saved game")
	Blessing.load_from(p, {"god": "nobody", "thirds": 3})
	check(p.blessing_god == "", "an unknown god is ignored")

	# The temple in the village.
	game.load_level(game._outdoor_index(), true)
	var priestess: Dictionary = {}
	for s in game.level.stations:
		if s.kind == "tempel":
			priestess = s
	check(not priestess.is_empty(), "Elsbeth opens the temple window")
	p.blessing_god = ""
	p.blessing_thirds = 0
	p.blessed_before = false
	game.coins = 100
	game.menus.open("tempel")
	check(game.menus.is_open(), "the temple window opens")
	game.menus._bless("korr", Blessing.price_new(false))
	check(p.blessing_god == "korr" and p.blessing_thirds == 3 and game.coins == 100, "the first blessing is free")
	Blessing.weaken(p)
	game.menus._bless("korr", Blessing.price_renew(p.blessing_thirds))
	check(p.blessing_thirds == 3 and game.coins == 100 - Blessing.RENEW, "a weakened blessing is renewed for an offering")
	game.menus.close()

	# The character page shows it.
	game.menus.open("charakter")
	check(game.menus.is_open() and (_has_text(game.menus._box, "Blessed by Korr") or _has_text(game.menus._box, "Gesegnet von Korr")), "the character page says who blessed the hero")
	game.menus.close()
	var wheel := CharacterPage.new(p, game.TEXT_FONT)
	check(wheel.details(CharacterPage.BLESSING).title.begins_with("Korr"), "the blessing's card names the god")


func _has_text(node: Node, text: String) -> bool:
	if node is Label and text in (node as Label).text:
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false
