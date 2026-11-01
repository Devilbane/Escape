extends SceneTree
## Headless test for the speech cooldown of the villagers: running into a
## villager again and again does not swap the line every bump (which made
## the text flicker). A new line only comes once the current one has shown
## for a while.
## Run with: godot --headless -s tests/npc_speech_cooldown.gd

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
	if failures == 0:
		print("PASS: npc speech cooldown")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	# A villager with plain talk: no trade, no tasks.
	var v: Villager = null
	for s in game.level.villagers:
		if s.role == "7":
			v = s
	check(v != null and v.station.kind == "npc", "a villager who only talks is there")
	if v == null:
		return

	game._use_station(v.station)
	var first: String = v._bubble.text
	check(v.is_busy_talking(), "the villager is busy with the first line")
	check(v._line == 1, "the first bump says the first line")

	# Bumping again right away keeps the same line.
	for i in 5:
		v._update_bubble(0.2)
		game._use_station(v.station)
	check(v._line == 1, "quick bumps do not start a new line")
	check(v._bubble.text == first, "the text stays the same while the hero keeps pushing")

	# Once the line has shown long enough, the next bump says the next one.
	v._update_bubble(Villager.MIN_SAY_TIME)
	check(not v.is_busy_talking(), "the line has been shown long enough")
	game._use_station(v.station)
	check(v._line == 2, "a bump after the pause says the next line")
	check(v._bubble.text != first, "the new line replaces the old one")
