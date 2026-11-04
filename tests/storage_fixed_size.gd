extends SceneTree
## Headless test: the storage chest (and the vault, which is built the same
## way) keeps one size while the player points at its items. A torch has a
## long description; it used to widen the window on hover, which moved the
## item away from the pointer and made the window flicker.
## Run with: godot --headless -s tests/storage_fixed_size.gd

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
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _rect() -> Rect2:
	var menus: Menus = game.menus
	return menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)


func _test() -> void:
	game.hero_name = "Storage size test"
	game.load_level(game._outdoor_index(), false)
	await _wait()
	root.size = Vector2i(1280, 720)
	for lang in ["de", "en"]:
		Lang.language = lang
		Lang._apply()
		await _run(lang)
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: the storage chest keeps its size")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _run(lang: String) -> void:
	var p: Player = game.player
	var menus: Menus = game.menus
	# Torches, the items with the longest and the shortest descriptions.
	var ids := Items.ALL.keys()
	ids.sort_custom(func(a, b): return Items.describe(a).length() > Items.describe(b).length())
	var mix: Array = ["fackel", "fackel", "fackel"] + ids.slice(0, 4) + ids.slice(ids.size() - 3)
	p.bag.clear()
	for id in mix:
		if p.bag.size() < p.bag_size() - 1:
			p.bag.append(id)
	game.storage.clear()
	for id in mix.slice(0, 6):
		game.storage.append(id)
	for kind in ["lager", "tresor"]:
		menus.open(kind)
		await _wait()
		var start := _rect()
		# Back and forth between torches and other items, as the player does.
		for pass_no in 2:
			for id in mix:
				menus._show_info(id)
				await _wait()
				check(_rect() == start, "pointing at %s keeps the %s window (%s): %s, was %s" % [id, kind, lang, _rect(), start])
				menus._show_info("")
				await _wait()
				check(_rect() == start, "leaving %s keeps the %s window (%s): %s, was %s" % [id, kind, lang, _rect(), start])
		# Moving a torch into the chest and back keeps the frame as well.
		if kind == "lager":
			menus._store(0)
			await _wait()
			check(_rect() == start, "storing a torch keeps the chest window (%s): %s, was %s" % [lang, _rect(), start])
			menus._take(game.storage.size() - 1)
			await _wait()
			check(_rect() == start, "taking it back keeps the chest window (%s): %s, was %s" % [lang, _rect(), start])
		menus.close()
