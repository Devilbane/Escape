extends SceneTree
## Headless test for the run to the village (see VillageRun): stepping out of
## the crypt makes the hero safe from blows, poison, bleeding and fire for two
## minutes, with a boon icon and the shout; it does not stack, a cure leaves
## it, it is saved, it ends with the time or at the village, and it says so.
## Run with: godot --headless -s tests/village_run.gd

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
	if frames == 5:
		_test()
	return false


func _test() -> void:
	var p: Player = game.player
	game.state = game.State.PLAYING
	check(not p.protected(), "no protection at the start")
	game._start_village_run()
	check(p.protected(), "protected after the exit")
	check(is_equal_approx(p.ailments[VillageRun.KIND], VillageRun.TIME), "two minutes")
	check(game.hero_boons().any(func(b): return b[0] == VillageRun.KIND), "a boon icon is shown")
	check(game._message.text.contains("RUN FORREST! RUN!") and game._message.text.contains("FOLLOW THE WAY!"), "the shout is shown")
	# Nothing hurts.
	var hp := p.hp
	p.take_damage(5, Vector3.ZERO, null, false)
	p.take_damage(5, Vector3.ZERO)
	p.scorched(3, Color.RED)
	p.ailments["gift"] = 10.0
	p.ailments["brand"] = 10.0
	p._tick_ailments(Player.POISON_TICK + 0.1)
	p._tick_ailments(Player.BURN_TICK + 0.1)
	check(p.hp == hp, "no damage while protected")
	# A cure keeps it; a second exit does not stack.
	p.cure()
	check(p.protected(), "a cure leaves the protection")
	p.ailments[VillageRun.KIND] = 50.0
	game._start_village_run()
	check(is_equal_approx(p.ailments[VillageRun.KIND], VillageRun.TIME), "a new exit restarts, never adds")
	# It is saved.
	p.ailments[VillageRun.KIND] = 42.0
	p.cure("gift")
	p.cure("brand")
	p.ailments.erase(VillageRun.KIND)
	game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(float(data.get("village_run", 0.0)) == 0.0, "no protection, nothing saved")
	p.ailments[VillageRun.KIND] = 42.0
	game.save_game()
	data = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(float(data.get("village_run", 0.0)) == 42.0, "the time left is saved")
	# It ends with the time.
	p.ailments[VillageRun.KIND] = 0.05
	game._village_run_on = true
	p._tick_ailments(0.1)
	game._watch_village_run()
	check(not p.protected(), "the protection ends with the time")
	check(game._message.text.contains("ended"), "the end is told")
	p._invulnerable = 0.0
	p.take_damage(20, Vector3.ZERO, null, false)
	check(p.hp < hp, "hurt again afterwards")
	_finish()


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: village run")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
