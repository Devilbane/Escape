extends SceneTree
## Headless test for things on the floor: an item the hero drops from the bag
## and loot left by the fallen stay where they lie after walking out of a
## level and back in, and after a save and load. Picked up, they are gone for
## good. A new game starts with clean floors.
## Run with: godot --headless -s tests/floor_items.gd

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
	if failures == 0:
		print("PASS: floor items")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file_part: String) -> int:
	for i in game.level_files.size():
		if file_part in game.level_files[i]:
			return i
	return -1


func _items(id: String) -> Array:
	return game.level._pickups.filter(func(p): return p.kind == "item" and p.get("id", "") == id)


func _test() -> void:
	game.hero_name = "Floor test"
	game.escaped = false
	var refuge := _index_of("zuflucht")
	check(refuge >= 0, "the refuge exists")
	game.load_level(refuge, false)
	var p: Player = game.player
	var id: String = Items.ALL.keys().filter(func(k): return Items.ALL[k].slot != "spezial")[0]
	p.bag.clear()
	p.bag.append(id)

	# Drop it from the bag: it lies at the hero's feet and is not taken back
	# at once.
	game.drop_on_floor(id)
	p.bag.clear()
	check(_items(id).size() == 1, "the dropped item lies on the floor")
	game.level._check_pickups()
	check(p.bag.is_empty() and _items(id).size() == 1, "it is not picked up again right away")
	var spot: Vector3 = _items(id)[0].node.global_position

	# Loot from a fallen foe, a few steps away.
	var loot_spot := spot + Vector3(4.0, 0, 0)
	game.level._drop_item(id, loot_spot)
	game.level._drop_coins(loot_spot + Vector3(0, 0, 4.0), 2)
	check(_items(id).size() == 2, "the loot lies there too")

	# Out and back in.
	game.load_level(_index_of("zuflucht"), false)
	check(_items(id).size() == 2, "both items still lie there when coming back")
	var piles: Array = game.level._pickups.filter(func(c): return c.kind == "coin" and c.has("floor"))
	var coins := 0
	for pile in piles:
		coins += CoinPile.count_of(pile.floor)
	check(piles.size() == 1 and coins == 2, "the spilt coins still lie there, in one pile (%d in %d)" % [coins, piles.size()])
	var near: Array = _items(id).filter(func(q): return Vector2(q.node.global_position.x - spot.x, q.node.global_position.z - spot.z).length() < 0.1)
	check(near.size() == 1, "the dropped item lies where it was dropped")

	# Save and load (a night in bed, or another slot loaded and back).
	check(game.save_game(true), "the game saves")
	game.floors.clear()
	game._apply_save(game._read_save())
	game.load_level(refuge, false)
	check(_items(id).size() == 2, "both items still lie there after loading")

	# Pick the dropped one up: gone for good.
	p.global_position = Vector3(spot.x + 20.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	p.global_position = Vector3(spot.x, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(id in p.bag, "the hero picks the item up")
	game.load_level(refuge, false)
	check(_items(id).size() == 1, "a picked up item stays gone when coming back")

	# Thunder ore that fades with the storm is not kept.
	game.level._drop_item(id, loot_spot, false)
	check(_items(id).size() == 2 and game.level.floor_items.filter(func(e): return e[0] == "item").size() == 1, "fading things are not put on the floor list")

	# A new game has clean floors.
	game.floors.clear()
	game.load_level(refuge, false)
	check(_items(id).is_empty(), "a new game starts with clean floors")
