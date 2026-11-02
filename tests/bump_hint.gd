extends SceneTree
## Headless test for the hint over villagers: "Run into X to talk" shows until
## the hero has run into a person once. After that it is left out for every
## person, also after saving and loading, while the hints for things stay.
## Run with: godot --headless -s tests/bump_hint.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Bump hint test"


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
	game.delete_save(game.save_path())
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: bump hint")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## Stands the hero right next to a station and lets the game write its hint.
func _hint_at(station: Dictionary) -> String:
	game.player.global_position = station.pos + Vector3(0.6, 0, 0)
	game.player.path.clear()
	game._process(0.016)
	return game._prompt.text


func _test() -> void:
	game.hero_name = HERO
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	check(game.level is Outdoor, "the village is loaded")
	check(not game.bumped_person, "a new hero has not run into anyone yet")
	var talker: Dictionary = {}
	var trader: Dictionary = {}
	for s in game.level.stations:
		if s.kind == "npc" and talker.is_empty():
			talker = s
		elif s.kind == "haendler" and trader.is_empty():
			trader = s
	check(not talker.is_empty() and not trader.is_empty(), "a villager and a trader are there")
	if talker.is_empty() or trader.is_empty():
		return

	check(_hint_at(talker).contains(talker.npc.display_name), "before the first bump the hint names the villager")

	game._on_player_bumped(talker.pos)
	check(game.bumped_person, "running into a villager is remembered")
	check(_hint_at(talker) == "", "after the bump the villager's hint is gone")
	check(_hint_at(trader) == "", "the hint is gone for the trader too")

	# Kept in the saved game.
	check(game.save_game(), "the game saves")
	game.bumped_person = false
	game._apply_save(game._read_save(game.save_path()))
	check(game.bumped_person, "the bump is still known after loading")

	# A new game starts without it.
	game._name_box.visible = true
	game._name_edit.text = HERO
	game.begin_new_game()
	check(not game.bumped_person, "a new game shows the hint again")
