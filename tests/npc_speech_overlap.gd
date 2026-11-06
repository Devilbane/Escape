extends SceneTree
## Headless test that villagers standing close together never show their
## speech bubbles at the same time (they lay over each other and nothing
## could be read). A villager who answers the hero silences the bubbles
## beside them; a chat line waits until a talker nearby is done.
## Run with: godot --headless -s tests/npc_speech_overlap.gd

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
		print("PASS: npc speech overlap")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _test() -> void:
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	var a := _villager("2")
	var b := _villager("7")
	var c := _villager("8")
	check(a != null and b != null and c != null, "three villagers are there")
	if a == null or b == null or c == null:
		return
	# Nobody talks yet; B and C stand right beside A.
	for v in game.level.villagers:
		v.hush()
	var at: Vector3 = a.global_position
	b.global_position = at + Vector3(2.0, 0, 0)
	c.global_position = at + Vector3(0, 0, 3.0)
	check(not a.is_talking() and not b.is_talking() and not c.is_talking(), "nobody talks yet")

	# A says something; then the hero talks to C right beside her.
	a.say("Erste Zeile")
	check(a.is_talking() and a.talker_near() == null, "A talks, nobody else near")
	check(c.talker_near() == a, "C sees that A is talking beside him")
	game._use_station(c.station)
	check(c.is_talking(), "C answers the hero")
	check(not a.is_talking() and not a._bubble.visible, "A's bubble is gone at once, so C's line can be read")
	var shown := 0
	for v in [a, b, c]:
		if v.is_talking():
			shown += 1
	check(shown == 1, "only one bubble shows among the three")

	# A chat between A and B waits while C is still talking to the hero.
	var talk := VillageTalk.new(game)
	a.join_chat(b, false)
	b.join_chat(a, false)
	talk._chat = {"key": "test", "a": a, "b": b, "lines": [[a, "Hallo Pip"], [b, "Hallo Mama"]], "wait": 0.0, "time": 0.0}
	talk._run_chat(0.1)
	check(not a.is_talking(), "the chat line waits while C is talking")
	check(talk._chat.lines.size() == 2, "the line is kept for later, not dropped")
	# C is done: now the chat goes on, one line at a time.
	c._update_bubble(Villager.SAY_TIME + 7.0)
	talk._run_chat(0.1)
	check(a.is_talking() and a._bubble.text.ends_with("Hallo Pip"), "the chat line comes once C is done")
	check(not b.is_talking(), "B waits for A's line")
	talk.stop()

	# Far apart, two villagers may talk at the same time.
	b.hush()
	b.global_position = at + Vector3(Villager.BUBBLE_ROOM + 3.0, 0, 0)
	b.say("Weit weg")
	check(a.is_talking() and b.is_talking(), "villagers far apart keep their own bubbles")

	# A new task told while a villager beside the hero talks: the message at
	# the bottom shows it, no words float up over the speech bubble.
	game.player.global_position = at + Vector3(1.0, 0, 0)
	check(game._villager_talking_near_hero(), "a villager beside the hero is talking")
	var before: int = game.level.get_child_count()
	game.quest_news("Neuer Auftrag: Test\nZiel", Color.WHITE)
	check(game.level.get_child_count() == before, "no floating words cover the bubble")
	for v in game.level.villagers:
		v.hush()
	game.quest_news("Neuer Auftrag: Test\nZiel", Color.WHITE)
	check(game.level.get_child_count() > before, "with nobody talking the words float up as before")
