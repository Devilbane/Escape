extends SceneTree
## Headless test for the save slots: each game is saved into a slot of its
## own, the load window lists every slot's game, any of them can be loaded
## and deleted, each one's description names the hero level, saved games of
## older versions (the single file, and the files
## named after their hero) move into free slots, a new game picks its slot in
## the name box, and taking a slot whose hero has come further asks first.
## Run with: godot --headless -s tests/save_slots.gd

var failures := 0
var game: Node
var frames := 0
const HEROES := ["Slot test Alpha", "Slot test Beta", "Slot test Old", "Slot test Named"]


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
	check(game.save_dir == game.TEST_SAVE_DIR, "a test run saves apart from the player's saved games")
	_clean_up()
	_test_old_saves()
	_clean_up()
	_test_slots()
	_clean_up()
	_test_new_game()
	_clean_up()
	_test_hero_level()
	_clean_up()
	if failures == 0:
		print("PASS: save slots")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _clean_up() -> void:
	for f in DirAccess.get_files_at(game.save_dir):
		DirAccess.remove_absolute(game.save_dir + f)
	if FileAccess.file_exists(game.old_save_file):
		DirAccess.remove_absolute(game.old_save_file)


func _write(path: String, hero: String, coins: int, saved_at: float) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "name": hero, "level": 0, "coins": coins, "hp": 3, "knives": 2,
			"gift_hp": 0, "gift_power": 0, "gift_speed": 0.0, "equipped": {}, "bag": [], "storage": [], "shop": [], "saved_at": saved_at}))
	file.close()


func _names() -> Array:
	return game.save_list().map(func(info): return info.name)


## The single file and the per-hero files of older versions move into
## slots, the one saved last into the first.
func _test_old_saves() -> void:
	_write(game.old_save_file, HEROES[2], 7, 100.0)
	_write(game.save_dir + HEROES[3].md5_text() + ".json", HEROES[3], 9, 200.0)
	game._move_old_saves()
	check(not FileAccess.file_exists(game.old_save_file), "the old save file is gone after moving it")
	check(not FileAccess.file_exists(game.save_dir + HEROES[3].md5_text() + ".json"), "the per-hero file is gone after moving it")
	check(game.save_list().size() == 2, "both old saved games are in the load window")
	check(game.save_info(game.save_path(1)).name == HEROES[3], "the one saved last takes slot 1")
	check(int(game.save_info(game.save_path(2)).get("coins", -1)) == 7, "the older one takes slot 2 and keeps its gold")
	check(game.save_info(game.save_path(2)).slot == 2, "a saved game knows its slot")


func _test_slots() -> void:
	# Two heroes, two slots, side by side. The same name twice is fine too.
	game.load_level(0, false)
	game.hero_name = HEROES[0]
	game.save_slot = 1
	game.coins = 11
	check(game.save_game(), "Alpha's game is saved")
	game.save_slot = 2
	game.coins = 22
	check(game.save_game(), "a second game of the same name is saved")
	game.hero_name = HEROES[1]
	game.save_slot = 3
	game.coins = 33
	check(game.save_game(), "Beta's game is saved")
	check(game.save_list().size() == 3, "the load window lists every slot's saved game")
	check(_names().count(HEROES[0]) == 2, "two heroes of the same name keep a slot each")
	check(int(game.save_info(game.save_path(1)).coins) == 11, "the second save did not overwrite the first")

	# Loading a slot makes it the one the game saves into.
	game.state = game.State.TITLE
	game.continue_game(game.save_path(2))
	check(game.save_slot == 2, "loading slot 2 saves into slot 2 from now on")
	game._apply_save(game._read_save(game.save_path(2)))
	game.coins = 44
	game.save_game()
	check(game.save_list().size() == 3, "saving again adds no new saved game")
	check(int(game.save_info(game.save_path(2)).coins) == 44, "the loaded slot is saved")
	check(int(game.save_info(game.save_path(1)).coins) == 11, "the other slots are left alone")

	# The one saved last comes first.
	check(game.save_list()[0].slot == 2, "the list starts with the newest saved game")

	# Deleting one keeps the others.
	game.delete_save(game.save_path(3))
	check(not game.has_slot_save(3), "slot 3 is deleted")
	check(game.has_slot_save(1) and game.has_slot_save(2), "the other slots are still there")
	game.state = game.State.TITLE


## Strength: home beats graveyard beats dungeon, deeper beats higher, then gold.
func _test_strength() -> void:
	var fresh: Dictionary = game.fresh_info()
	check(not game.is_stronger({}, fresh), "an empty slot is never stronger")
	check(not game.is_stronger(fresh.duplicate(), fresh), "a fresh hero is not stronger than a fresh one")
	check(game.is_stronger({"level": 4, "coins": 0, "escaped": false, "home": false}, fresh), "a deeper level is stronger")
	check(game.is_stronger({"level": 1, "coins": 1, "escaped": false, "home": false}, fresh), "gold settles the same level")
	check(game.is_stronger({"level": 1, "coins": 0, "escaped": true, "home": false}, {"level": 9, "coins": 900, "escaped": false, "home": false}),
			"out of the dungeon beats any level")
	check(game.is_stronger({"level": 1, "coins": 0, "escaped": true, "home": true}, {"level": 1, "coins": 900, "escaped": true, "home": false}),
			"a house beats the graveyard")


func _note_rect() -> Rect2:
	return game._name_note.get_global_rect()


func _test_new_game() -> void:
	_test_strength()
	# Slot 1: a strong hero. Slot 2: a hero no further than a fresh one.
	_write(game.save_path(1), HEROES[0], 0, 100.0)
	var strong: Dictionary = game._read_save(game.save_path(1))
	strong.level = 5
	strong.coins = 120
	var file := FileAccess.open(game.save_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify(strong))
	file.close()
	_write(game.save_path(2), HEROES[1], 0, 200.0)

	game.state = game.State.TITLE
	game._title.visible = true
	game.new_game()
	check(game._name_box.visible, "a new game asks for the name")
	check(game._new_slot == 3, "the first free slot is picked for a new game")
	check(game._slot_buttons.size() == game.SAVE_SLOTS, "one button per slot")
	check((game._slot_buttons[1] as Button).text.contains(HEROES[0]), "a full slot's button names its hero")
	check((game._slot_buttons[3] as Button).text.contains(Lang.t("frei")), "a free slot's button says so")

	# Picking another slot changes the note, never the layout below.
	var go_rect := Rect2()
	for child in game._name_box.get_children():
		if child is Button:
			go_rect = child.get_global_rect()
	var note_rect := _note_rect()
	game._choose_slot(1)
	check(game._name_note.text.contains(HEROES[0]), "the note names the hero in the slot")
	check(_note_rect() == note_rect, "the note keeps its place and size")
	for child in game._name_box.get_children():
		if child is Button:
			check(child.get_global_rect() == go_rect, "the start button does not move")

	# A stronger hero in the slot: the game asks first.
	game._name_edit.text = "Slot test New"
	game._start_new_game()
	check(game.menus.current == "ueberschreiben", "taking a stronger hero's slot asks first")
	check(game.state == game.State.TITLE and game.has_slot_save(1), "nothing is overwritten yet")
	var texts := []
	for l in game.menus._box.find_children("*", "Label", true, false):
		texts.append(l.text)
	check(texts.any(func(t): return t.contains(HEROES[0]) and t.contains("120")), "the question says who would be lost")

	# Going back keeps the name box and the save.
	game.menus.close()
	check(game._name_box.visible and game._title.visible, "going back shows the name box again")
	check(game.has_slot_save(1), "going back keeps the saved game")

	# A hero no further than a fresh one: no question.
	game._choose_slot(2)
	game._start_new_game()
	check(game.menus.current == "", "a slot with a hero no further than a new one asks nothing")
	check(game.save_slot == 2 and not game.has_slot_save(2), "the new game takes slot 2")
	check(game.has_slot_save(1), "slot 1 stays untouched")
	check(game.hero_name == "Slot test New", "the new hero has the name given")

	# Confirming overwrites.
	game.state = game.State.TITLE
	game._name_box.visible = false
	game.new_game()
	game._choose_slot(1)
	game._start_new_game()
	check(game.menus.current == "ueberschreiben", "the question comes again for slot 1")
	for b in game.menus._box.find_children("*", "Button", true, false):
		if b.text == Lang.t("Überschreiben"):
			b.pressed.emit()
			break
	check(game.menus.current == "", "confirming closes the question")
	check(game.save_slot == 1 and not game.has_slot_save(1), "confirming replaces slot 1's saved game")


## The load window's description of a saved game names the hero level, in
## both languages. Games saved before the save kept the experience take it from
## the hero's training, and a hero who never trained is on level 1.
func _test_hero_level() -> void:
	game.load_level(0, false)
	game.hero_name = HEROES[0]
	game.save_slot = 1
	game.coins = 5
	game.player.hero_xp = HeroLevel.total_for(7)
	check(game.save_game(), "a game with some experience is saved")
	var info: Dictionary = game.save_info(game.save_path(1))
	check(int(info.get("hero_level", 0)) == 7, "the saved game knows its hero level")
	var summary: String = game.save_summary(info)
	check(summary.begins_with(HEROES[0] + ", Heldenstufe 7,"), "the description names the hero level beside the name: " + summary)
	var was := Lang.language
	Lang.language = "en"
	Lang._apply()
	summary = game.save_summary(info)
	Lang.language = was
	Lang._apply()
	check(summary.begins_with(HEROES[0] + ", hero level 7,"), "the English description names the hero level too: " + summary)

	# An older save of the same hero, without "xp", still knows the level.
	_write(game.save_path(2), HEROES[0], 3, 100.0)
	check(int(game.save_info(game.save_path(2)).hero_level) == 7, "an older save takes the hero level from the training")
	# An older save of a hero who never trained shows level 1 and no gap.
	var untrained := "Slot test Untrained %d" % Time.get_ticks_usec()
	_write(game.save_path(3), untrained, 4, 50.0)
	var old: Dictionary = game.save_info(game.save_path(3))
	check(int(old.hero_level) == 1, "an older save of an untrained hero is on hero level 1")
	check(game.save_summary(old) == untrained + ", Heldenstufe 1, auf Ebene 1 mit 4 Gold.", "the older save's description reads whole: " + game.save_summary(old))
	game.player.hero_xp = 0
	game.state = game.State.TITLE
