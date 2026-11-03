extends SceneTree
## Headless test: the inventory window keeps one size while the player works
## in it. Picking items with short and very long descriptions, pointing at
## them, switching tabs, dropping and equipping must not move its frame.
## Run with: godot --headless -s tests/inventory_fixed_size.gd
## With SHOTS=<folder> and a display it also saves screenshots.

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


func _rect() -> Rect2:
	var menus: Menus = game.menus
	return menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)


## The bag's items, the one with the longest description first, the shortest last.
func _by_description() -> Array:
	var ids := Items.ALL.keys()
	ids.sort_custom(func(a, b): return Items.describe(a).length() > Items.describe(b).length())
	return ids


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _test() -> void:
	game.hero_name = "Inventory size test"
	game.load_level(game._outdoor_index(), false)
	await _wait()
	root.size = Vector2i(1280, 720)
	for lang in ["de", "en"]:
		Lang.language = lang
		Lang._apply()
		await _run(lang)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: the inventory keeps its size")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _run(lang: String) -> void:
	var p: Player = game.player
	var menus: Menus = game.menus
	p.bag.clear()
	p.equipped.clear()
	p.equipped["rucksack"] = "grosser_rucksack"
	var ids := _by_description()
	# The longest descriptions and the longest names, then the shortest.
	var names := Items.ALL.keys()
	names.sort_custom(func(a, b): return Items.item_name(a).length() > Items.item_name(b).length())
	for id in ids.slice(0, 4) + names.slice(0, 4) + ids.slice(ids.size() - 3):
		if p.bag.size() < p.bag_size() - 1:
			p.bag.append(id)
	menus.open("inventar")
	await _wait()
	var start := _rect()
	await _shot("inventory_none_" + lang)
	# A name too long for two lines ends in "…"; its cell does not grow a third line.
	for b in menus._box.find_children("*", "Button", true, false):
		if b.custom_minimum_size == Menus.INVENTORY_CELL:
			check(b.size == Menus.INVENTORY_CELL, "the cell %s keeps its size (%s): %s" % [b.text.replace("\n", " "), lang, b.size])
	for i in p.bag.size():
		menus._select(i)
		await _wait()
		check(_rect() == start, "picking %s keeps the window (%s): %s, was %s" % [p.bag[i], lang, _rect(), start])
		menus._show_info(p.bag[i])
		await _wait()
		check(_rect() == start, "pointing at %s keeps the window (%s): %s, was %s" % [p.bag[i], lang, _rect(), start])
	menus._show_info("")
	menus._select(0)
	await _wait()
	await _shot("inventory_long_" + lang)
	menus._select(p.bag.size() - 1)
	await _wait()
	await _shot("inventory_short_" + lang)
	# Dropping leaves a note; the line for it is there from the start.
	menus._drop_selected()
	await _wait()
	check(_rect() == start, "dropping keeps the window (%s): %s, was %s" % [lang, _rect(), start])
	menus._show_inventory_tab("beutel")
	await _wait()
	check(_rect() == start, "the pouch tab keeps the window (%s): %s, was %s" % [lang, _rect(), start])
	menus._show_inventory_tab("tasche")
	# Equipping a weapon with a long name keeps the slot buttons' width.
	for i in p.bag.size():
		if Items.ALL[p.bag[i]].has("slot") and Items.ALL[p.bag[i]].get("requires", {}).is_empty():
			menus._select(i)
			menus._equip_selected()
			await _wait()
			check(_rect() == start, "equipping %s keeps the window (%s): %s, was %s" % [p.bag[i] if i < p.bag.size() else "", lang, _rect(), start])
			break
	# A helmet brings its show/hide button; its place was kept from the start.
	var hat := ""
	for id in Items.ALL:
		if Items.ALL[id].has("hat") and Items.ALL[id].get("requires", {}).is_empty():
			hat = id
			break
	check(hat != "", "there is a helmet to try")
	p.bag[0] = hat
	menus._select(0)
	menus._equip_selected()
	await _wait()
	check(p.equipped.get("kopf", "") == hat, "the helmet is worn (%s)" % lang)
	check(_rect() == start, "putting on a helmet keeps the window (%s): %s, was %s" % [lang, _rect(), start])
	await _shot("inventory_helmet_" + lang)
	menus._toggle_helmet()
	await _wait()
	check(_rect() == start, "hiding the helmet keeps the window (%s): %s, was %s" % [lang, _rect(), start])
	menus.close()
