extends SceneTree
## Monsters help a struck mate: one with line of sight joins, a wolf's howl reaches one behind a
## wall, and slimes neither call nor answer.
## Run with: godot --headless --fixed-fps 60 -s tests/pack_help.gd

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
	game.hero_name = "Help test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	var spot: Vector3 = lvl.villagers[0].global_position
	var hero: Player = lvl.player
	hero.global_position = spot
	hero.set_physics_process(false)
	var a := Enemy.new()
	a.kind = "wolf"
	a.level = lvl
	lvl.add_child(a)
	a.global_position = spot + Vector3(6, 0, 0)
	var b := Enemy.new()
	b.kind = "wolf"
	b.level = lvl
	lvl.add_child(b)
	b.global_position = spot + Vector3(9, 0, 0)
	lvl.enemies.append(a)
	lvl.enemies.append(b)
	var slime := lvl.spawn_slime("schleim", spot + Vector3(7, 0, 2), {"hp": 80})
	await physics_frame
	check(PackHelp.can_answer(b, a), "a wolf answers a wolf")
	check(not PackHelp.can_answer(slime, a), "a slime does not answer")
	check(PackHelp.CALLERS.has("wolf") and not PackHelp.CALLERS.has("schleim"), "wolves call, slimes do not")
	b._awake = false
	PackHelp.on_struck(slime, hero.global_position)
	check(not b._awake and not a._awake, "a struck slime brings nobody")
	PackHelp.on_struck(a, hero.global_position)
	check(b._awake, "the wolf nearby joins the defence")
	check(not slime._awake, "the slime stays out of it")
	print("PASS: pack help" if failures == 0 else "FAILED: %d" % failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
