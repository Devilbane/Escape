extends SceneTree
## Headless test: the inventory's box of bonuses and penalties (see GearEffects).
## Run with: godot --headless -s tests/gear_effects.gd
## With SHOTS=<folder> and a display it also saves screenshots of the inventory.

var failures := 0
var game: Node
var frames := 0
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
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _line(lines: Array, name: String) -> Array:
	for l in lines:
		if l[0] == name:
			return l
	return []


func _test() -> void:
	game.hero_name = "Gear effects test"
	game.load_level(game._outdoor_index(), false)
	await _wait()
	root.size = Vector2i(1280, 720)
	Lang.language = "en"
	Lang._apply()
	var p: Player = game.player
	p.bag.clear()
	p.equipped.clear()
	p.refresh_stats()
	# Nothing worn: every row is a dash, and the rows are always the same count.
	var none := GearEffects.equipment_lines(p)
	check(none.size() == GearEffects.EQUIPMENT_ROWS.size(), "one row per stat")
	check(GearEffects.weight_lines(p).size() == GearEffects.WEIGHT_ROWS.size(), "one row per weight line")
	for l in none:
		check(l[1] == "–" and l[2] == 0, "nothing worn, nothing shown: %s" % [l])
	# A full leather set with eilstiefel-free pieces: sums match the player's own stats.
	for id in ["lederkappe", "lederwams", "lederhandschuhe", "lederstiefel", "rundschild", "schwert"]:
		p.equipped[Items.ALL[id].slot] = id
	p.refresh_stats()
	var sum := GearEffects.equipment(p)
	check(sum.armour_value == p.armour_value, "armour value matches the hero's (%d / %d)" % [sum.armour_value, p.armour_value])
	check(is_equal_approx(sum.block, p.block_chance - Player.BLOCK_PER_LEVEL * p.skill("blocken")), "block matches")
	check(sum.dexterity == ArmourSets.dexterity(p.equipped) and sum.dexterity > 0, "the leather set's dexterity shows")
	check(_line(GearEffects.equipment_lines(p), "Dexterity")[2] == 1, "a bonus is marked good")
	check(_line(GearEffects.equipment_lines(p), "Power")[1] == "+1", "the sword's power shows: %s" % [_line(GearEffects.equipment_lines(p), "Power")])
	# Weight: gear and bag add up, the slowdown matches the hero's speed.
	p.bag.append("plattenpanzer")
	p.refresh_stats()
	var w := GearEffects.weight(p)
	check(w.raw > 14.0, "the bag's weight counts (%s)" % [w])
	check(is_equal_approx(p.speed, p.base_speed * (1.0 - w.slow)), "the slowdown matches the hero's speed")
	var slow := _line(GearEffects.weight_lines(p), "Speed")
	check(slow[2] == -1 and slow[1].begins_with("-"), "a slowdown is a penalty: %s" % [slow])
	# A heavy bag caps at the biggest slowdown.
	for i in 12:
		p.bag.append("kettenhemd")
	check(is_equal_approx(GearEffects.weight(p).slow, Items.MAX_WEIGHT_SLOW), "the slowdown stops at its cap")
	# The tab in the inventory: the window keeps its size whatever is worn.
	p.bag.clear()
	p.equipped.clear()
	p.refresh_stats()
	var menus: Menus = game.menus
	menus.open("inventar")
	await _wait()
	var bag_size: Vector2 = menus._panel.size
	menus._show_inventory_tab("effekte")
	await _wait()
	check(menus._panel.size == bag_size, "the bonuses tab keeps the window's size: %s vs %s" % [menus._panel.size, bag_size])
	await _shot("gear_effects_empty")
	for id in ["ritterhelm", "plattenpanzer", "panzerhandschuhe", "stahlstiefel", "wappenschild", "streitaxt", "schattenumhang"]:
		p.equipped[Items.ALL[id].slot] = id
	for id in ["kettenhemd", "eisenhaube", "schwert", "axt"]:
		p.bag.append(id)
	p.refresh_stats()
	menus._rebuild()
	await _wait()
	check(menus._panel.size == bag_size, "the window keeps its size with gear on: %s vs %s" % [menus._panel.size, bag_size])
	check(menus._box.get_combined_minimum_size().y <= menus._scroll.size.y, "no scrolling needed: %s / %s" % [menus._box.get_combined_minimum_size().y, menus._scroll.size.y])
	await _shot("gear_effects_worn")
	Lang.language = "de"
	Lang._apply()
	menus._rebuild()
	await _wait()
	check(menus._panel.size == bag_size, "the window keeps its size in German")
	await _shot("gear_effects_worn_de")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: the bonuses tab")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
