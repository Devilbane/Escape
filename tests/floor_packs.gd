extends SceneTree
## Headless test for backpacks set down on the floor (see FloorPack): they
## hold items of their own, can be pushed, are saved with place and contents,
## survive a full floor list and the dragon's morning, and never duplicate or
## lose an item. Run with: godot --headless -s tests/floor_packs.gd

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
		_run()
	return false


func _run() -> void:
	await _test()
	game.delete_save(game.save_path())
	print("PASS: floor packs" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The physics space only knows a new level after a few ticks.
func _settle() -> void:
	for i in 4:
		await physics_frame


func _index_of(part: String) -> int:
	for i in game.level_files.size():
		if part in game.level_files[i]:
			return i
	return -1


func _test() -> void:
	game.hero_name = "Pack test"
	game.escaped = false
	var refuge := _index_of("zuflucht")
	game.load_level(refuge, false)
	var singles: Array = Items.ALL.keys().filter(func(k): return Items.stack_size(k) == 1 and not Items.is_backpack(k) and Items.ALL[k].slot in ["waffe", "kopf"])
	var filler: String = singles[0]
	var extra: String = singles[1]
	await _settle()
	var p: Player = game.player
	var lvl: Level = game.level
	p.bag.clear()
	p.equipped.erase("rucksack")
	p.bag.append("lederrucksack")
	p.bag.append("wurfmesser")
	p.bag.append(extra)

	# Dropping sets a pack down, not a pickup; the bag keeps the rest.
	var spot: Vector3 = game.pack_spot()
	check(spot != Vector3.INF, "there is room ahead")
	p.bag.erase("lederrucksack")
	game.drop_on_floor("lederrucksack")
	check(lvl.packs.size() == 1, "the dropped backpack is a pack")
	check(lvl._pickups.filter(func(q): return q.get("id", "") == "lederrucksack").is_empty(), "it is no pickup")
	var pack: FloorPack = lvl.packs[0]
	check(pack.is_empty() and pack.capacity() == Items.bag_size("lederrucksack"), "it is empty with its backpack's size")
	check(lvl.pack_in_reach(p) == pack, "it is in reach")

	# Putting in: rules.
	check(pack.why_not("lederrucksack") != "", "no backpack inside a backpack")
	check(pack.why_not(extra) == "", "an item fits")
	for i in pack.capacity():
		pack.contents().append(filler)
	check(pack.why_not(extra) != "" and pack.used() == pack.capacity(), "a full pack takes no more")
	game.open_pack = pack
	game.menus.open("bodenrucksack")
	check(game.menus.current == "bodenrucksack", "the window opens")
	game.menus._pack_store(p.bag.find(extra))
	check(p.bag.has(extra) and pack.contents().count(extra) == 0, "a full pack leaves the item in the bag")
	game.menus._pack_take(0)
	check(pack.contents().size() == pack.capacity() - 1 and p.bag.count(filler) == 1, "one item moved to the bag")
	game.menus._pack_store(p.bag.find(filler))
	check(pack.contents().size() == pack.capacity() and not p.bag.has(filler), "and back: nothing lost or doubled")
	check(game.take_floor_pack(pack) != "" and lvl.packs.size() == 1, "a pack with contents is not picked up")
	# The window keeps one size, full or empty, in both languages, and fits.
	var sizes := []
	for code in ["de", "en"]:
		Lang.choose(code)
		for fill in [true, false]:
			if fill:
				while pack.contents().size() < pack.capacity():
					pack.contents().append(filler)
			else:
				pack.contents().clear()
			p.bag.clear()
			for i in p.bag_size():
				p.bag.append(filler if fill else extra)
			game.menus._rebuild()
			await process_frame
			var content: Vector2 = game.menus._box.get_combined_minimum_size()
			var fixed := Menus.fixed_size("bodenrucksack")
			check(content.x <= fixed.x and content.y <= fixed.y, "pack window (%s, full %s) needs %s, more than %s" % [code, fill, content, fixed])
			sizes.append(game.menus._panel.size)
	check(sizes.all(func(z): return z == sizes[0]), "the pack window keeps its size: %s" % [sizes])
	Lang.choose("de")
	pack.contents().clear()
	for i in pack.capacity():
		pack.contents().append(filler)
	p.bag.clear()
	p.bag.append(extra)
	game.menus.close()

	# Pushing.
	var before := pack.global_position
	var from := before + Vector3(-1.2, 0, 0)
	await _settle()
	check(lvl.push_pack(pack, from), "the pack is pushed")
	check(is_equal_approx(float(pack.entry[2]), snappedf(before.x + FloorPack.PUSH_STEP, 0.01)), "its entry moved with it")
	check(lvl.packs.size() == 1 and lvl.floor_items.has(pack.entry), "still listed on the floor")

	# A full floor list does not push it out, the dragon does not take it.
	for i in Level.FLOOR_MAX + 5:
		lvl._remember_on_floor("item", extra, Vector3(i, 0, 40))
	check(lvl.floor_items.has(pack.entry), "it survives a full floor list")
	check(not DragonHoard.takes(pack.entry), "the dragon's helpers leave it")
	for i in range(lvl.floor_items.size() - 1, -1, -1):
		if lvl.floor_items[i][2] == float(i) and lvl.floor_items[i][3] == 40.0:
			lvl.floor_items.remove_at(i)

	# Save and load, old saves too.
	var spot_x := float(pack.entry[2])
	check(game.save_game(true), "the game saves")
	game.floors.clear()
	game._apply_save(game._read_save())
	game.load_level(refuge, false)
	await _settle()
	check(game.level.packs.size() == 1, "the pack is back after loading")
	var again: FloorPack = game.level.packs[0]
	check(is_equal_approx(float(again.entry[2]), spot_x) and again.contents().size() == Items.bag_size("lederrucksack"), "same place, same contents")
	game.floors.clear()
	game._apply_save(game._read_save())
	var raw: Dictionary = game._read_save()
	raw.erase("floors")
	game._apply_save(raw)
	check(game.floors.values().all(func(f): return f.is_empty()), "a save without floors loads")
	game._apply_save(game._read_save())
	game.load_level(refuge, false)
	await _settle()

	# Bad data is cleaned: unknown ids, backpacks inside, too many.
	var bad := ["pack", "lederrucksack", 1.0, 1.0, ["nope", "leinenrucksack"] + Array(range(0, 1).map(func(_i): return extra))]
	FloorPack.clean(bad)
	check(bad[4] == [extra], "unknown items and nested backpacks are dropped from a loaded pack")

	# Empty it and pick it up again.
	game.level.packs[0].contents().clear()
	p.bag.clear()
	check(game.take_floor_pack(game.level.packs[0]) == "" and p.bag == ["lederrucksack"] and game.level.packs.is_empty(), "an empty pack goes back into the bag")
