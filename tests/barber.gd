extends SceneTree
## Headless test for the barber in the village: he stands there with his own
## mohawk and opens his menu, the hero's hair style, colour and tattoo change
## the head, a hat hides the mohawk, and the look comes back from a saved game.
## Run with: godot --headless -s tests/barber.gd

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


## The game needs a few frames to set itself up first.
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: barber")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _head_mesh() -> Mesh:
	var head := game.player.find_child("Rogue_Head", true, false) as MeshInstance3D
	return head.mesh


func _crest_shown() -> bool:
	var crest := game.player.find_child("Crest", true, false) as Node3D
	return crest != null and crest.visible


func _test() -> void:
	game.hero_name = "Barber test"
	var p: Player = game.player
	check(p.hair.style == "natural" and p.hair.color == "natural", "a hero starts with natural hair")
	var natural_head := _head_mesh()
	check(not _crest_shown(), "no mohawk at the start")

	# The barber stands in the village and has his own station.
	game.load_level(game._outdoor_index(), false)
	var barber: Dictionary = {}
	for s in game.level.stations:
		if s.kind == "barbier":
			barber = s
	check(not barber.is_empty(), "the barber has a station in the village")
	if not barber.is_empty():
		check(barber.npc.find_child("Crest", true, false) != null, "the barber wears a mohawk")
		game.menus.open("barbier")
		check(game.menus.is_open(), "the barber's menu opens")
		game.menus.close()

	p.set_hair({"style": "mohawk", "color": "fire", "tattoo": "Pig!"})
	check(p.hair.style == "mohawk" and p.hair.color == "fire" and p.hair.tattoo == "Pig!", "the barber's look is taken")
	check(_head_mesh() != natural_head, "a mohawk shaves the head")
	check(_crest_shown(), "the mohawk is shown")
	check(p.find_child("TattooInk", true, false) != null, "the tattoo is inked")

	p.equip("knochenhelm")
	check(not _crest_shown(), "a helmet hides the mohawk")
	p.unequip("kopf")
	check(_crest_shown(), "the mohawk is back without the helmet")

	p.set_hair({"style": "punk", "color": "plaid", "tattoo": "A word much too long"})
	check(p.hair.style == "natural" and p.hair.color == "natural" and p.hair.tattoo.length() <= HairLook.TATTOO_MAX, "unknown looks fall back to natural")

	p.set_hair({"style": "bald", "color": "rainbow", "tattoo": "Pig!"})
	game.save_game()
	p.set_hair(HairLook.DEFAULT)
	game._apply_save(game._read_save())
	check(p.hair.style == "bald" and p.hair.color == "rainbow" and p.hair.tattoo == "Pig!", "the look comes back from the saved game")
	check(not _crest_shown(), "a shaved head has no mohawk")
	p.set_hair(HairLook.DEFAULT)
	check(_head_mesh() == natural_head, "the hair grows back")
