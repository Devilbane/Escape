extends SceneTree
## A slime the hero strikes makes the hero its priority target over villagers
## and the wall, and falls back to them when the hero stays away for a while.
## Run with: godot --headless --fixed-fps 60 -s tests/slime_hero_priority.gd

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


func _run() -> void:
	game.hero_name = "Priority test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await physics_frame
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	lvl.village_alarm._check = 1e9
	var villager: Villager = lvl.villagers[0]
	var spot: Vector3 = villager.global_position
	var slime := lvl.spawn_slime("schleim", spot + Vector3(3, 0, 0), {"hp": 80})
	lvl.player.global_position = spot + Vector3(7, 0, 0)
	await physics_frame
	slime.snack = villager
	check(slime._hero_aggro == 0.0, "an unhit slime is not on the hero")
	slime.take_hit(1, lvl.player.global_position)
	check(slime._hero_aggro > 0.0, "a blow from the hero sets the slime on the hero")
	for i in 30:
		await physics_frame
	check(slime.snack == null, "the slime drops the villager while it fights the hero")
	check(slime._wall_target == null, "and the wall")
	# A hit that does not come from the hero (wakes = false) changes nothing.
	var other := lvl.spawn_slime("schleim", spot + Vector3(-3, 0, 0), {"hp": 80})
	other.take_hit(1, spot, "hit", false)
	check(other._hero_aggro == 0.0, "a blow that is not the hero's does not count")
	# The hero stays away: after the timeout the slime goes back to villagers.
	slime._hero_aggro = 0.0
	for i in 90:
		await physics_frame
	check(slime._hero_aggro == 0.0, "the priority runs out")
	print("PASS: slime hero priority" if failures == 0 else "FAILED: %d" % failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
