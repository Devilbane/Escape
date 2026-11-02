extends SceneTree
## Headless test for the saved game out of the dungeon: once the hero has
## escaped, every load starts on the graveyard in front of the crypt door,
## wherever the game was saved, until the hero steps into the house the elder
## gave: from then on every load starts in that house. Inside the dungeon a
## load still starts where the game was saved.
## Run with: godot --headless -s tests/graveyard_start.gd

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
	if Homes.house_of(game.hero_name) > 0:
		Homes.release(Homes.house_of(game.hero_name))
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: graveyard start")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file_part: String) -> int:
	for i in game.level_files.size():
		if file_part in game.level_files[i]:
			return i
	return -1


## Saves on the given level, then loads that save again.
func _save_and_load(index: int, going_away := false) -> void:
	game.load_level(index, false)
	game.save_game(going_away)
	game._apply_save(game._read_save())


func _at_graveyard() -> bool:
	var lvl: Level = game.level
	return lvl is Outdoor and game.player.global_position.distance_to(lvl.cell_to_world(lvl.start_cell)) < 0.5


func _test() -> void:
	game.hero_name = "Graveyard test"
	var outdoor: int = game._outdoor_index()
	var vaults := _index_of("tresorkeller")
	var refuge := _index_of("zuflucht")
	check(outdoor >= 0 and vaults >= 0 and refuge >= 0, "the village, the vault cellar and the refuge exist")

	# Still in the dungeon: the refuge's save loads in the refuge.
	game.escaped = false
	_save_and_load(refuge)
	check(game.level_index == refuge, "a save in the refuge loads in the refuge")

	# Out of the dungeon: saved in the vault cellar, loaded on the graveyard.
	game.escaped = true
	_save_and_load(vaults)
	check(game.escaped, "the escape is kept in the saved game")
	check(game.level_index == outdoor and _at_graveyard(), "a save in the vault cellar loads on the graveyard")

	# The elder has given the house, but the hero has not been inside yet:
	# still the graveyard.
	game.home_given = true
	_save_and_load(outdoor)
	check(_at_graveyard(), "a house not yet entered leaves the start on the graveyard")
	check(game.save_info().escaped and not game.save_info().home, "the load window knows the save is on the graveyard")

	# Walking into the house makes it the hero's own: saved at once, and
	# every load from then on starts next to the bed, wherever it was saved.
	game.level.home_claimed.emit()
	check(game.home_claimed and game.save_info().home, "stepping into the house saves it as the new starting point")
	game._apply_save(game._read_save())
	check(_at_home(), "the save made on claiming the house loads in the house")
	_save_and_load(vaults)
	check(_at_home(), "a save in the vault cellar loads in the hero's house")
	_save_and_load(outdoor)
	check(_at_home(), "a save in the village loads in the hero's house")
	_save_and_load(outdoor, true)
	check(_at_home(), "after sleeping in the bed the hero wakes at home")
	check(game.home_claimed, "a loaded house does not greet the hero as new again")


## Beside the bed of the hero's own town house on Weavers' Lane.
func _at_home() -> bool:
	var lvl: Level = game.level
	return lvl.is_home and lvl.house_number == Homes.house_of(game.hero_name) and lvl.house_number > 0 \
			and lvl.bed_side != Vector3.ZERO and game.player.global_position.distance_to(lvl.bed_side) < 0.5
