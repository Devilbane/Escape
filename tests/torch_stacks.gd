extends SceneTree
## Headless test: torches bundle up to five in one bag slot. The inventory
## shows one cell per bundle with its count; a full bag still takes a torch
## while a bundle has room; dropping takes one off the bundle (it lies on
## the floor and can be picked up again); the bag comes back the same after
## a save and load; and a torch lit on request takes one off a bundle.
## Run with: godot --headless --fixed-fps 60 -s tests/torch_stacks.gd

const TORCH := HandTorch.ITEM

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


func _index_of(file_part: String) -> int:
	for i in game.level_files.size():
		if file_part in game.level_files[i]:
			return i
	return -1


## Something plain to fill the bag with: carried, never bundled.
func _filler() -> String:
	for id in Items.ALL:
		if Items.ALL[id].slot in Items.SLOTS and Items.ALL[id].slot != "rucksack" and Items.stack_size(id) == 1:
			return id
	return ""


func _torches_on_floor() -> int:
	return game.level._pickups.filter(func(p): return p.kind == "item" and p.get("id", "") == TORCH).size()


## The texts of the bag's cells in the open window.
func _cells(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c is Button and not c.disabled:
			out.append(c.text)
		_cells(c, out)
	return out


func _test() -> void:
	game.hero_name = "Torch stack test"
	game.escaped = false
	var refuge := _index_of("zuflucht")
	game.load_level(refuge, false)
	await _wait()
	var p: Player = game.player
	var menus: Menus = game.menus
	var filler := _filler()
	check(filler != "", "there is a plain item to fill the bag with")
	p.equipped.erase("rucksack")
	p.bag.clear()

	# Counting: five share a slot, the sixth opens the next.
	check(Items.stack_size(TORCH) == 5, "torches bundle up to 5")
	for n in [[1, 1], [5, 1], [6, 2], [10, 2], [11, 3]]:
		var bag := []
		for i in n[0]:
			bag.append(TORCH)
		check(Items.slots_used(bag) == n[1], "%d torches take %d slots (%d)" % [n[0], n[1], Items.slots_used(bag)])
	var mixed := [TORCH, filler, TORCH, TORCH, filler, TORCH, TORCH, TORCH, TORCH]
	var cells := Items.stacks(mixed)
	check(cells.size() == 4 and cells[0].count == 5 and cells[3].count == 2, "a mixed bag: bundles of 5 and 2 among the rest")
	check(cells[0].indices == [0, 2, 3, 5, 6], "a bundle knows where its torches lie: %s" % [cells[0].indices])

	# A full bag with a bundle that has room still takes a torch, and nothing else.
	for i in Items.BAG_SIZE - 1:
		p.bag.append(filler)
	for i in 3:
		p.bag.append(TORCH)
	check(p.bag_used() == p.bag_size(), "the bag is full: %d / %d" % [p.bag_used(), p.bag_size()])
	check(p.bag_fits(TORCH), "a torch still fits on the bundle of 3")
	check(not p.bag_fits(filler), "anything else does not fit")

	# The inventory: one cell for the bundle, with its count; the tab counts slots.
	menus.open("inventar")
	await _wait()
	var texts := _cells(menus._box, [])
	var torch_cells := texts.filter(func(t): return t.begins_with(Items.item_name(TORCH)))
	check(torch_cells.size() == 1 and "× 3" in torch_cells[0], "one cell shows the bundle with its count: %s" % [torch_cells])
	check(texts.any(func(t): return "(8 / 8)" in t), "the bag tab counts slots, not torches")

	# Dropping takes one off the bundle; the rest stays picked.
	var at: int = Items.stacks(p.bag).filter(func(c): return c.id == TORCH)[0].indices.back()
	menus._select(at)
	menus._drop_selected()
	await _wait()
	check(p.bag.count(TORCH) == 2, "dropping takes one torch off the bundle (%d left)" % p.bag.count(TORCH))
	check(menus._selected >= 0 and p.bag[menus._selected] == TORCH, "the bundle stays picked after dropping one")
	check(_torches_on_floor() == 1, "the dropped torch lies on the floor")
	texts = _cells(menus._box, [])
	check(texts.any(func(t): return t.begins_with(Items.item_name(TORCH)) and "× 2" in t), "the cell now shows 2")
	menus.close()

	# Picked up again with a full bag: it goes back on the bundle.
	var spot: Vector3 = game.level._pickups.filter(func(q): return q.kind == "item" and q.get("id", "") == TORCH)[0].node.global_position
	p.global_position = Vector3(spot.x + 20.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	p.global_position = Vector3(spot.x, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(p.bag.count(TORCH) == 3 and _torches_on_floor() == 0, "a full bag picks the torch back up onto the bundle")

	# A full bundle in a full bag: a torch on the floor stays there.
	p.bag.append(TORCH)
	p.bag.append(TORCH)
	check(not p.bag_fits(TORCH), "a bundle of 5 in a full bag takes no sixth torch")
	game.level._drop_item(TORCH, spot)
	p.global_position = Vector3(spot.x + 20.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	p.global_position = Vector3(spot.x, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(p.bag.count(TORCH) == 5 and _torches_on_floor() == 1, "the sixth torch stays on the floor")

	# The shop: a full bag can buy a torch while a bundle has room.
	p.bag.erase(TORCH)
	game.shop_stock.clear()
	game.shop_stock.append(TORCH)
	game.coins = 100
	menus._buy(0)
	check(p.bag.count(TORCH) == 5, "buying a torch fills up the bundle in a full bag")

	# Save and load: the torches come back as they were, one bundle of 5.
	p.bag.clear()
	for i in 7:
		p.bag.append(TORCH)
	p.bag.append(filler)
	check(game.save_game(true), "the game saves")
	p.bag.clear()
	game._apply_save(game._read_save())
	check(game.player.bag.count(TORCH) == 7 and game.player.bag_used() == 3, "after loading 7 torches are back in 2 bundles (%d torches, %d slots)" % [game.player.bag.count(TORCH), game.player.bag_used()])
	p = game.player

	# Lit on request, one torch of a bundle burns; the rest stays bundled.
	game.level.pitch_dark = true
	p.torch.left = 0.0
	p.torch._process(0.1)
	check(not p.torch.lit and p.bag.count(TORCH) == 7, "the dark alone lights no torch")
	p.torch.toggle()
	check(p.torch.lit and p.bag.count(TORCH) == 6, "lit on request, 6 stay in the bag (%d)" % p.bag.count(TORCH))
	check(p.bag_used() == 3, "the bundles are 5 and 1 now")
	p.torch.toggle()
	game.level.pitch_dark = false
	p.torch._process(0.1)

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: torch stacks")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
