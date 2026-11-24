extends SceneTree
## Headless test: Priestess Elsbeth never stands in the temple's doorway, running into her does not
## open her window, and asking for "heal" within earshot does.
## Run with: godot --headless -s tests/priestess_door.gd

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
	game.load_level(game._outdoor_index(), false)
	var level: Outdoor = game.level
	var els: Villager = null
	for v in level.villagers:
		if v.role == Outdoor.TEMPLE_KEEPER:
			els = v
	check(els != null, "Elsbeth is in the village")
	if els != null:
		_test(level, els)
	print("PASS: priestess door" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true


func _test(level: Outdoor, els: Villager) -> void:
	# Her place is clear of the way in: a tile or more to the side of the door line.
	for rec in level.walk_in.buildings:
		if rec.kind != "temple":
			continue
		var way := level.walk_in.door_points(rec)
		var out := way[0] - way[1]
		out.y = 0.0
		out = out.normalized()
		var side := Vector3(-out.z, 0, out.x)
		var off := absf((els.global_position - way[0]).dot(side))
		check(off >= Outdoor.TILE * 0.9, "Elsbeth waits beside the temple's doorway, not in it (%.2f m aside)" % off)
	# A bump does not open her window.
	game.player.global_position = els.global_position + Vector3(1.0, 0, 0)
	game._on_player_bumped(els.global_position)
	check(not game.menus.is_open(), "running into Elsbeth does not open her window")
	# Asking for healing within earshot does.
	var chat := HeroChat.new(game)
	check(chat.healer_asked("Please heal me", game.player.global_position) == els, "'heal' reaches the priestess")
	check(chat.healer_asked("hello", game.player.global_position) == null, "a greeting is not a request for healing")
	game.ask_priestess(els)
	check(game.menus.is_open(), "asking for healing opens her window")
