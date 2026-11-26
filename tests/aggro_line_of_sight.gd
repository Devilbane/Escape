extends SceneTree
## Aggro needs line of sight: a noisy hero 5 m away wakes a monster that sees them, but not one
## that has no line of sight (a footstep behind a wall wakes nobody).
## Run with: godot --headless --fixed-fps 60 -s tests/aggro_line_of_sight.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	game.hero_name = "Sight test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var spot: Vector3 = lvl.villagers[0].global_position
	var slime := lvl.spawn_slime("schleim", spot + Vector3(5, 0, 0), {"hp": 80})
	var hero: Player = lvl.player
	hero.global_position = spot
	hero.set_physics_process(false)
	hero.sneaking = false
	hero.velocity = Vector3(3, 0, 0)
	await physics_frame
	var to := hero.global_position - slime.global_position
	to.y = 0.0
	check(hero.is_noisy(), "the test hero makes noise")
	check(slime._notices(hero, to, 5.0, true), "a noisy hero in sight is noticed")
	check(not slime._notices(hero, to, 5.0, false), "a noisy hero without line of sight is not noticed")
	print("PASS: aggro line of sight" if failures == 0 else "FAILED: %d" % failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
