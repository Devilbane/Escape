extends SceneTree
## Headless test for the hero's companions (see Companions): a doe and a stag
## are won over with apples and a salt lick like the fox with sausages, each
## gives its perk only while it goes with the hero (doe +10 % Tempo, stag
## +1 Kampfkraft, fox +1 Erkunden), the hero names each new friend, the one
## at the hero's side so far goes home, and at home the others rest on the
## straw in the corner by the door, where the companions window swaps and
## renames them without changing its size. Everything is kept in the saved
## game, and an old saved game with a fox still has its fox.
## Run with: godot --headless --fixed-fps 60 -s tests/companions.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

const HERO := "Companions test"

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
	game._title.visible = false
	game._fade.color.a = 0.0
	game._message.text = ""
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _finish() -> void:
	game.delete_save(game.save_path())
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	print("PASS: companions" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Feeds a wild animal of this kind until it trusts the hero; the naming
## window opens and is answered with `given`.
func _tame(kind: String, given: String) -> void:
	var lvl: Outdoor = game.level
	var animal: Animal = lvl.animals.filter(func(a): return a.kind == kind)[0]
	var food: String = Companions.SPECIES[kind].food
	game.player.bag.clear()
	for i in Companions.TRUST_NEEDED:
		game.player.bag.append(food)
	check(animal.is_curious(), "a %s is curious about a hero who carries %s" % [kind, food])
	for i in Companions.TRUST_NEEDED:
		game._on_animal_fed(animal)
	check(not game.player.bag.has(food), "the %s ate all of it" % kind)
	check(game.owns_companion(kind), "the %s is the hero's companion now" % kind)
	check(game.menus.current == "gefaehrte_name", "the hero is asked to name the %s" % kind)
	await _wait()
	await _shot("naming_" + kind)
	game.menus._name_text = given
	game.menus._give_name()
	check(not game.menus.is_open(), "naming the %s closes the window" % kind)
	check(game.companion().kind == kind and game.companion().name == given.strip_edges().substr(0, Companions.NAME_MAX).strip_edges(), "the %s is called %s" % [kind, given])
	check(is_instance_valid(game.pet) and game.pet.kind == kind, "the new %s goes with the hero" % kind)


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	game.escaped = true
	game.companions = []
	game.following = -1
	game.trust = {}
	if Homes.house_of(HERO) > 0:
		Homes.release(Homes.house_of(HERO))
	Lang.language = "de"

	# Every kind has its texts, its food and a picture for its food.
	for kind in Companions.ORDER:
		var s: Dictionary = Companions.SPECIES[kind]
		check(Items.is_food(s.food), "%s eats %s, which is animal food" % [kind, s.food])
		check(Companions.eater_of(s.food) == kind, "%s is eaten by %s" % [s.food, kind])
		check(Animal.KINDS.has(kind), "%s lives in the woods" % kind)
		for key in ["name", "plural", "perk", "fed", "tamed", "ask"]:
			check(Lang.EN.has(s[key]), "%s's %s has an English text" % [kind, key])
		check(Lang.EN.has(Items.ALL[s.food].name) and Lang.EN.has(Items.ALL[s.food].effect), "%s has English texts" % s.food)
	check(Lang.EN.has(Companions.LEARN) and Lang.EN.has(Companions.WHERE_DEER), "the compendium texts have English")

	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var speed_alone := p.base_speed
	var power_alone := p.power
	check(game.pet == null and p.companion_perks.is_empty(), "a new hero has no companion")

	# The shopkeeper always has apples and salt licks too.
	game.menus.open("haendler")
	for kind in Companions.ORDER:
		check(game.shop_stock.count(Companions.SPECIES[kind].food) >= 2, "the merchant sells %s" % Companions.SPECIES[kind].food)
	game.coins = 10
	p.bag.clear()
	game.lore.clear()
	game.menus._buy(game.shop_stock.find("apfel"))
	check(p.bag.has("apfel") and game.lore.has(Companions.WHERE_DEER), "buying an apple says where the does live")
	game.menus.close()

	# A doe: +10 % Tempo while it comes along.
	await _tame("reh", "  Liesel  ")
	check(is_equal_approx(p.base_speed, speed_alone * 1.1), "the doe gives +10 %% Tempo (%.2f -> %.2f)" % [speed_alone, p.base_speed])
	check(p.power == power_alone, "the doe gives no Kampfkraft")
	check(not game.level.animals.any(func(a): return a.kind == "reh" and a.is_curious()), "no second doe can be won over")
	await _wait(30)
	await _shot("doe_follows")

	# A stag: +1 Kampfkraft; the doe goes home and her perk with her.
	await _tame("hirsch", "Hubert der Große und Prächtige")
	check(p.power == power_alone + 1, "the stag gives +1 Kampfkraft")
	check(is_equal_approx(p.base_speed, speed_alone), "the doe at home gives no Tempo")
	check(game.companions.size() == 2 and game.following == 1, "two companions, the stag comes along")
	check(game.companions[1].name.length() <= Companions.NAME_MAX, "a long name is cut to %d letters" % Companions.NAME_MAX)

	# An empty name gives the kind's name.
	check(Companions.clean_name("   ", "reh") == Lang.t("Reh"), "an empty name becomes the kind's name")

	# Saved and loaded: both, their names and who comes along are kept.
	check(game.save_game(), "the game is saved")
	game.companions = []
	game.following = -1
	game.trust = {}
	game._apply_save(game._read_save())
	check(game.companions.size() == 2 and game.companions[0].name == "Liesel" and game.following == 1, "the saved game keeps the companions")
	check(game.trust.get("reh", 0) == Companions.TRUST_NEEDED, "the saved game keeps the trust")

	# An old saved game with a tame fox still has its fox, at the hero's side.
	var old := Companions.from_save({"fox": {"trust": 3, "tame": true}})
	check(old.list.size() == 1 and old.list[0].kind == "fuchs" and old.following == 0 and old.trust.fuchs == 3, "an old saved game keeps its fox")
	check(Companions.from_save({}).list.is_empty() and Companions.from_save({}).following == -1, "an old saved game without a fox has no companion")

	# Home: the doe rests on the straw by the door.
	var house := 1
	while Homes.owner_of(house) != "":
		house += 1
	check(Homes.claim(HERO, house), "the hero moves into a town house")
	game.inside_house = house
	game.load_level(game.interiors["^"], false)
	game.state = game.State.PLAYING
	var lvl: Level = game.level
	check(lvl.is_home, "the hero is at home")
	check(lvl.companion_spots.size() == 3, "the straw has room for three companions")
	var corner: Array = lvl.stations.filter(func(s): return s.kind == "gefaehrten")
	check(corner.size() == 1, "the companions' corner is a station")
	check(game.home_pets.size() == 1 and game.home_pets[0].kind == "reh" and game.home_pets[0].state == "home", "the doe waits at home")
	check(is_instance_valid(game.pet) and game.pet.kind == "hirsch", "the stag came home with the hero")
	await _wait(20)
	check(Pet._flat(game.home_pets[0].global_position - lvl.companion_spots[0].pos).length() < 0.05, "the doe stays on the straw")
	# The ways through the house stay open (the straw is solid, not furniture).
	var start: Vector2i = lvl.start_cell
	for s in lvl.stations.filter(func(s): return s.kind in ["bett", "lager"]):
		var near := false
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			near = near or not lvl.grid_path(start, s.cell + d).is_empty() or start == s.cell + d
		check(near or lvl.storey_of(s.cell) != lvl.storey_of(start), "the %s can still be reached" % s.kind)
	await _shot("home_straw")

	# Running into the straw opens the companions window.
	game._use_station(corner[0])
	var m: Menus = game.menus
	check(m.current == "gefaehrten", "running into the straw opens the companions window")
	await _wait()
	await _shot("companions_window")
	var size_before: Vector2 = m._panel.size
	# Swap: the doe comes along, the stag stays.
	m._take_companion(0)
	await _wait()
	check(game.following == 0 and game.pet.kind == "reh", "the doe comes along now")
	check(game.home_pets.size() == 1 and game.home_pets[0].kind == "hirsch", "the stag waits at home now (%s)" % [game.home_pets.map(func(h): return h.kind if is_instance_valid(h) else "freed")])
	check(is_equal_approx(p.base_speed, speed_alone * 1.1) and p.power == power_alone, "the perks follow the swap")
	check(m._note != "", "the window says who comes along now")
	check(m._panel.size == size_before, "swapping does not change the window's size (%s -> %s)" % [size_before, m._panel.size])
	# Nobody along.
	m._take_companion(-1)
	await _wait()
	check(game.following == -1 and game.pet == null and game.home_pets.size() == 2, "both can stay at home")
	check(p.companion_perks.is_empty() and is_equal_approx(p.base_speed, speed_alone), "nobody along, no perk")
	check(m._panel.size == size_before, "leaving all at home does not change the window's size")
	# Rename the stag from the window, then back to it.
	m._rename_companion(1)
	check(m.current == "gefaehrte_name", "renaming opens the name window")
	m._name_text = "Krone"
	m._give_name()
	check(m.current == "gefaehrten" and game.companions[1].name == "Krone", "the stag is renamed and the window is back")
	check(game.home_pets.any(func(h): return h.given_name == "Krone"), "the stag at home has its new name")
	# Esc in the name window keeps the old name.
	m._rename_companion(1)
	m._name_text = "Nichts"
	m.close()
	check(game.companions[1].name == "Krone", "closing the name window keeps the old name")
	game.take_companion(1)
	check(game.pet.kind == "hirsch" and p.power == power_alone + 1, "the stag comes along again")
	# English: the window's texts are all translated.
	Lang.language = "en"
	Lang._apply()
	m.open("gefaehrten")
	await _wait()
	for l in m._box.find_children("*", "Label", true, false):
		var t: String = l.text
		check(not (t.contains("Gefährten") or t.contains("wartet") or t.contains("Gabe") or t.contains("Zähmen")), "the window is in English: %s" % t)
	await _shot("companions_window_en")
	m.close()
	_finish()
