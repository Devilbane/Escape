extends SceneTree
## A monster that has spotted the hero shows its red "!" once: losing and re-noticing
## the hero at once (a leash, a calm) does not repeat it; only a long time off the hunt does.
## Run with: godot --headless --fixed-fps 60 -s tests/enemy_alert_once.gd

var game: Node
var frames := 0
var started := false
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _alerts(lvl: Node) -> int:
	var n := 0
	for c in lvl.find_children("*", "Label3D", true, false):
		if c is DamageNumber and (c as DamageNumber).text == "!":
			n += 1
	return n


func _run() -> void:
	game.hero_name = "Alert test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	lvl.village_alarm._check = 1e9
	var spot: Vector3 = lvl.villagers[0].global_position
	var slime := lvl.spawn_slime("schleim", spot + Vector3(3, 0, 0), {"hp": 80})
	lvl.player.global_position = spot + Vector3(4, 0, 0)
	lvl.player.set_physics_process(false)
	await physics_frame
	# The hunt keeps being dropped and picked up again within a moment.
	for i in 40:
		slime._awake = false
		await physics_frame
	check(_alerts(lvl) <= 1, "one \"!\" for a hunt dropped and picked up again at once (got %d)" % _alerts(lvl))
	check(_alerts(lvl) == 1, "the first notice does show the \"!\" (got %d)" % _alerts(lvl))
	# Fully off the hunt for long enough: noticing again shows it again.
	var before := _alerts(lvl)
	slime._awake = false
	slime._alert_gap = 0.0
	# Facing the hero: noticing from afar needs the hero in the monster's view cone, which a random spawn facing may miss.
	var to_hero: Vector3 = lvl.player.global_position - slime.global_position
	slime._model.rotation.y = atan2(to_hero.x, to_hero.z)
	for i in 5:
		await physics_frame
	check(_alerts(lvl) == before + 1, "a monster that lost track and re-spots the hero shows it again (%d -> %d)" % [before, _alerts(lvl)])
	print("PASS: enemy alert once" if failures == 0 else "FAILED: %d" % failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
