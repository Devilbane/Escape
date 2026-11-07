extends SceneTree
## Headless test for the names of the villagers: nobody wears a name over
## their head until the hero has talked to them, after that the name stays
## (also while they talk: speech goes into the event log), and the
## villagers the hero has met are remembered in the hero's own saved game.
## Run with: godot --headless -s tests/npc_names.gd

var failures := 0
var game: Node
var frames := 0
const HEROES := ["Names test Alpha", "Names test Beta"]


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
	for i in HEROES.size():
		game.delete_save(game.save_path(i + 1))
	if failures == 0:
		print("PASS: npc names")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _tag(v: Villager) -> Label3D:
	return v._name_tag


func _test() -> void:
	game.hero_name = HEROES[0]
	game.save_slot = 1
	game.met.clear()
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor and not game.level.villagers.is_empty(), "the village has villagers")
	var benno := _villager("Z")
	var mira := _villager("6")
	var aldo := _villager("0")
	check(benno != null and mira != null and aldo != null, "the barber, the shopkeeper and the elder are there")
	if benno == null or mira == null or aldo == null:
		return
	for v in game.level.villagers:
		check(not _tag(v).visible, "%s shows no name before the hero talked to them" % v.display_name)
	check(_tag(benno).text == benno.display_name, "the name tag carries the villager's name")

	# A talk: the name stays, the others stay unknown.
	benno.talk(game.player)
	check(_tag(benno).visible, "the barber wears his name after a talk")
	check(not _tag(mira).visible, "the shopkeeper is still unknown")
	check(game.met.has("Z") and not game.met.has("6"), "the game remembers who the hero has met")

	# Speech shows in a bubble over the head (and goes into the event log); the
	# name tag stays while the barber talks and after.
	benno._update_bubble(1.0)
	check(benno._bubble.is_shown(), "a speech bubble shows over the head")
	check(_tag(benno).visible and _tag(benno).modulate.a > 0.95, "the name tag stays while he talks")
	benno._bubble_time = 0.0
	for i in 10:
		benno._update_bubble(0.5)
	check(_tag(benno).visible and _tag(benno).modulate.a > 0.95, "the name tag stays after the talk")

	# The elder's welcome counts as a talk too.
	aldo.greet_newcomer(game.player)
	check(_tag(aldo).visible and game.met.has("0"), "the elder's welcome makes him known")

	# The met villagers come back from the hero's own saved game.
	check(game.save_game(), "the game is saved")
	game.hero_name = HEROES[1]
	game.save_slot = 2
	game.met.clear()
	check(game.save_game(), "another hero's game is saved")
	game._apply_save(game._read_save(game.save_path(2)))
	check(game.met.is_empty(), "the other hero has met nobody")
	for v in game.level.villagers:
		check(not _tag(v).visible, "%s is a stranger to the other hero" % v.display_name)
	game._apply_save(game._read_save(game.save_path(1)))
	check(game.met.has("Z") and game.met.has("0") and not game.met.has("6"), "the saved game brings back who was met")
	check(_tag(_villager("Z")).visible and _tag(_villager("0")).visible, "the met villagers wear their names after loading")
	check(not _tag(_villager("6")).visible, "the unmet shopkeeper still shows no name")
	check(game.level.met == game.met, "the village and the game share the same list of met villagers")

	# Saved games from before this feature load fine.
	var data: Dictionary = game._read_save(game.save_path(1))
	data.erase("met")
	game._apply_save(data)
	check(game.met.is_empty(), "an older saved game without the list starts with nobody met")
