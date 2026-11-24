extends SceneTree
## Headless test: the waking up in bed always lets the hero go. Even when the tween of the get-out
## animation dies half-way (an error in one of its steps, a freed node), the watchdog of
## Game._rise_from_bed opens the eyes, stands the hero up beside the bed and gives the control back.
## Run with: godot --headless --fixed-fps 60 -s tests/wake_watchdog.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var clock := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _asleep() -> bool:
	var lids = game.player._eyelids
	return lids != null and lids.visible


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: wake watchdog" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	clock += delta
	match stage:
		0:
			game.hero_name = "Wake watchdog test"
			game.escaped = false
			var refuge := -1
			for i in game.level_files.size():
				if "zuflucht" in game.level_files[i]:
					refuge = i
			game.load_level(refuge, false)
			game.state = game.State.PLAYING
			check(game.save_game(true), "the game is saved in bed")
			var data: Dictionary = game._read_save()
			game._apply_save(data)
			game._after_load(data)
			game._start_playing()
			check(game._waking and game.player.frozen, "the hero lies in bed after loading")
			clock = 0.0
			stage = 1
		1:
			# Half-way through the get-out animation the tween dies.
			if clock < 3.2:
				return false
			check(game._waking and game.player.in_bed_pose(), "the hero is still getting up")
			game._rise_tween.kill()
			clock = 0.0
			stage = 2
		2:
			if game._waking and clock < 3.0:
				return false
			check(not game._waking, "the watchdog ends the waking up")
			game.menus.close()
			check(not game.player.frozen, "the hero can move again")
			check(not _asleep(), "the eyes are open")
			check(not game.player.in_bed_pose(), "the hero is out of the bed pose")
			check(game.state == game.State.PLAYING, "the game plays on")
			_finish()
			return true
	return false
