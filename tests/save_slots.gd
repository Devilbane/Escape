extends SceneTree
## Headless test for several saved games, one per hero: each hero saves into
## a file of their own, the load window lists them all, any of them can be
## loaded and deleted, and the single saved game of older versions becomes
## the saved game of its hero.
## Run with: godot --headless -s tests/save_slots.gd

var failures := 0
var game: Node
var frames := 0
const HEROES := ["Slot test Alpha", "Slot test Beta", "Slot test Old"]


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
	_clean_up()
	_test()
	_clean_up()
	if failures == 0:
		print("PASS: save slots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _clean_up() -> void:
	for hero in HEROES:
		game.delete_save(game.save_path(hero))
	if FileAccess.file_exists(game.OLD_SAVE_FILE):
		DirAccess.remove_absolute(game.OLD_SAVE_FILE)


func _names() -> Array:
	return game.save_list().map(func(info): return info.name)


func _test() -> void:
	var before: int = game.save_list().size()

	# A saved game from before there were several moves to its hero.
	var old := FileAccess.open(game.OLD_SAVE_FILE, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "name": HEROES[2], "level": 0, "coins": 7, "hp": 3, "knives": 2,
			"gift_hp": 0, "gift_power": 0, "gift_speed": 0.0, "equipped": {}, "bag": [], "storage": [], "shop": []}))
	old.close()
	game._move_old_save()
	check(not FileAccess.file_exists(game.OLD_SAVE_FILE), "the old save file is gone after moving it")
	check(game.has_save_of(HEROES[2]), "the old saved game became its hero's saved game")
	check(int(game.save_info(game.save_path(HEROES[2])).get("coins", -1)) == 7, "the moved saved game keeps its gold")

	# Two heroes, two saved games, side by side.
	game.load_level(0, false)
	game.hero_name = HEROES[0]
	game.coins = 11
	check(game.save_game(), "Alpha's game is saved")
	game.hero_name = HEROES[1]
	game.coins = 22
	check(game.save_game(), "Beta's game is saved")
	check(game.save_list().size() == before + 3, "the load window lists every hero's saved game")
	for hero in HEROES:
		check(hero in _names(), "%s is in the list" % hero)
	check(int(game.save_info(game.save_path(HEROES[0])).coins) == 11, "Beta's save did not overwrite Alpha's")

	# Loading another hero's saved game makes that hero the one playing.
	game._apply_save(game._read_save(game.save_path(HEROES[0])))
	check(game.hero_name == HEROES[0] and game.coins == 11, "loading Alpha's saved game plays Alpha")

	# Saving again replaces only this hero's own saved game.
	game.coins = 33
	game.save_game()
	check(game.save_list().size() == before + 3, "saving again adds no new saved game")
	check(int(game.save_info(game.save_path(HEROES[1])).coins) == 22, "Alpha's save left Beta's alone")

	# The one saved last comes first.
	var newest: Dictionary = game.save_list()[0]
	check(newest.time >= game.save_info(game.save_path(HEROES[1])).time, "the list starts with the newest saved game")

	# Deleting one keeps the others.
	game.delete_save(game.save_path(HEROES[1]))
	check(not game.has_save_of(HEROES[1]), "Beta's saved game is deleted")
	check(game.has_save_of(HEROES[0]) and game.has_save_of(HEROES[2]), "the other saved games are still there")
