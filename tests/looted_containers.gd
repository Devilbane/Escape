extends SceneTree
## Headless test for looted containers: furniture the hero searched and coins
## they picked up stay gone after a save and load (a night in bed or the
## "Load" window) and after walking out of a level and back in. A new game
## fills everything up again.
## Run with: godot --headless -s tests/looted_containers.gd

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
	if game.has_save():
		DirAccess.remove_absolute(game.SAVE_FILE)
	if failures == 0:
		print("PASS: looted containers")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file_part: String) -> int:
	for i in game.level_files.size():
		if file_part in game.level_files[i]:
			return i
	return -1


func _object(label: String) -> Dictionary:
	for obj in game.level.interactables:
		if obj.label == label:
			return obj
	return {}


func _coins_left() -> int:
	return game.level._pickups.filter(func(p): return p.kind == "coin").size()


func _test() -> void:
	game.hero_name = "Loot test"
	game.escaped = false
	var refuge := _index_of("zuflucht")
	check(refuge >= 0, "the refuge exists")
	game.load_level(refuge, false)
	var table := _object("Tisch")
	var chest := _object("Schatztruhe")
	check(not table.is_empty() and not chest.is_empty(), "the refuge has a table and a treasure chest")
	check(_coins_left() == 1, "the refuge has one coin on the floor")
	check(not table.searched and not chest.searched, "nothing is searched at first")

	# Search the table and the chest, and walk over the coin.
	game.level.search(table)
	game.level.search(chest)
	var coin: Dictionary = game.level._pickups.filter(func(p): return p.kind == "coin")[0]
	game.player.global_position = coin.node.global_position
	game.level._check_pickups()
	check(_coins_left() == 0, "the coin is picked up")

	# Out and back in, without saving.
	game.load_level(refuge, false)
	check(_object("Tisch").searched and _object("Schatztruhe").searched, "searched furniture stays searched when coming back")
	check(_coins_left() == 0, "a picked up coin stays gone when coming back")

	# A night in bed: save, then load.
	game.save_game(true)
	game.looted.clear()
	game._apply_save(game._read_save())
	check(_object("Tisch").searched and _object("Schatztruhe").searched, "searched furniture stays searched after loading")
	check(_coins_left() == 0, "a picked up coin stays gone after loading")
	check(game.level.search(_object("Tisch")).is_empty(), "a searched table gives nothing again")

	# A new game starts with everything full again.
	game.looted.clear()
	game.load_level(refuge, false)
	check(not _object("Tisch").searched and _coins_left() == 1, "a new game fills everything up again")
