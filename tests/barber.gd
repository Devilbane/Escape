extends SceneTree
## Headless test for the barber in the village: he stands there with his own
## mohawk under a tent of clean linen and opens his menu, the hero's hair
## style, colour and tattoo change the head, a hat hides the mohawk, and the
## look comes back from a saved game.
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
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: barber")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _head_mesh() -> Mesh:
	var head := game.player.find_child("Rogue_Head", true, false) as MeshInstance3D
	return head.mesh


func _bun_shown() -> bool:
	var bun := game.player.find_child("Bun", true, false) as Node3D
	return bun != null and bun.visible


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
		check(game.level.find_child("BarberPole", true, false) != null and game.level.find_child("ShopSign", true, false) != null, "the barber has a stall with a pole and a sign")
		var tent := game.level.find_child("BarberTent", true, false) as Node3D
		var linen := tent != null
		if tent:
			for mi: MeshInstance3D in tent.find_children("*", "MeshInstance3D", true, false):
				var m := mi.material_override as ShaderMaterial
				linen = linen and m != null and m.shader == WeatheredProps.SHADER and m.get_shader_parameter("linen") == true
		check(linen, "the barber's tent is of clean linen")
		var plain := WeatheredProps.palette_material(preload("res://assets/village/hexagons_medieval.png"), WeatheredProps.IRON)
		check(plain.get_shader_parameter("linen") != true, "other tents keep their weathered canvas")
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
	p.set_hair({"style": "mohawk", "color": "fire", "tattoo": "Pig!", "show_helmet": false})
	check(_crest_shown() and p.find_child("Headgear", true, false) == null, "a hidden helmet shows the mohawk")
	check(p.hardening > 0 or p.power > 1, "a hidden helmet still counts")
	p.set_hair({"style": "mohawk", "color": "fire", "tattoo": "Pig!"})
	check(not _crest_shown() and p.find_child("Headgear", true, false) != null, "the helmet can be shown again")
	p.unequip("kopf")
	check(_crest_shown(), "the mohawk is back without the helmet")

	# A short crop is the natural hair cut close; spikes stand on it.
	p.set_hair({"style": "short", "color": "black"})
	var short_head := _head_mesh()
	check(short_head != natural_head and not _crest_shown(), "a short crop cuts the hair without a crest")
	p.set_hair({"style": "spiky", "color": "blond"})
	check(_head_mesh() != short_head and _crest_shown(), "spikes stand on a crop shaved below the tufts")
	p.equip("knochenhelm")
	check(not _crest_shown(), "a helmet hides the spikes")
	p.unequip("kopf")
	check(not HairLook.shows_scalp("short") and not HairLook.shows_scalp("spiky") and HairLook.shows_scalp("mohawk"), "only shaved sides show a tattoo")
	var styles: Array = game.menus.BARBER_STYLES.map(func(c): return c[0])
	check(styles == HairLook.STYLES, "the barber offers every hair style")
	var pip_hair := {}
	for v in game.level.find_children("*", "Villager", true, false):
		if v.role == "7":
			pip_hair = v._info.get("hair", {})
	check(pip_hair.get("style", "") == "spiky", "Pip wears spikes")
	var spikes := game.player.find_child("Crest", true, false) as MeshInstance3D
	var box := spikes.mesh.get_aabb()
	check(box.size.x > HairLook.SKULL_RADII.x * 1.5 and box.size.z > HairLook.SKULL_RADII.z * 1.5, "the spikes cover the whole top of the head")
	check(box.position.y > HairLook.SKULL_CENTER.y, "the spikes stay clear of the ears and the collar")

	# A woman ties her natural hair in a knot at the back; a hat or a cut hides it.
	p.set_sex("female")
	p.set_hair(HairLook.DEFAULT)
	check(_bun_shown(), "a woman wears a hair knot")
	p.equip("knochenhelm")
	check(not _bun_shown(), "a helmet hides the hair knot")
	p.unequip("kopf")
	p.set_hair({"style": "short"})
	check(not _bun_shown(), "a short crop has no knot")
	p.set_sex("male")
	p.set_hair(HairLook.DEFAULT)
	check(not _bun_shown(), "a man wears no knot")

	p.set_hair({"style": "punk", "color": "plaid", "tattoo": "A word much too long"})
	check(p.hair.style == "natural" and p.hair.color == "natural" and p.hair.tattoo.length() <= HairLook.TATTOO_MAX, "unknown looks fall back to natural")

	p.set_hair({"style": "bald", "color": "rainbow", "tattoo": "Pig!", "tattoo_shape": "arch"})
	check(p.find_child("Word", true, false).get_child_count() == 4, "the tattoo is written letter by letter")
	game.save_game()
	p.set_hair(HairLook.DEFAULT)
	game._apply_save(game._read_save())
	check(p.hair.style == "bald" and p.hair.color == "rainbow" and p.hair.tattoo == "Pig!" and p.hair.tattoo_shape == "arch", "the look comes back from the saved game")
	check(not _crest_shown(), "a shaved head has no mohawk")
	p.set_hair(HairLook.DEFAULT)
	check(_head_mesh() == natural_head, "the hair grows back")
