extends SceneTree
## Headless test for fireballs (see Ignition): flammable monsters catch fire
## and burn down a life a second; bone does not burn; Aldo's fireball hits
## far harder than Odo's.
## Run with: godot --headless -s tests/ignition.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _spawn(kind: String) -> Enemy:
	var lvl: Level = game.level
	var e := Enemy.new()
	e.kind = kind
	e.level = lvl
	lvl.add_child(e)
	e.global_position = lvl.player.global_position + Vector3(6, 0, 0)
	lvl.enemies.append(e)
	return e


func _run() -> void:
	var wolf := _spawn("wolf")
	var skeleton := _spawn("krieger")
	check(Ignition.wants_fireball(wolf), "a wolf can ignite")
	check(not Ignition.wants_fireball(skeleton), "bone does not ignite")
	var life: int = wolf.hp
	wolf.ignite()
	check(wolf.burning > 0.0, "the wolf burns")
	check(wolf.get_node_or_null("BurnFlames") != null, "a burning wolf shows flames")
	check(not Ignition.can_ignite(wolf), "a burning monster cannot be lit again")
	skeleton.ignite()
	check(skeleton.burning == 0.0, "the skeleton stays cold")
	wolf._tick_burning(Ignition.BURN_TICK + 0.01)
	check(wolf.hp == life - Ignition.BURN_DAMAGE, "burning costs a life each tick")
	wolf._tick_burning(Ignition.BURN_TIME)
	check(wolf.burning == 0.0, "the fire goes out")
	check(Ignition.VILLAGE_MAGES["0"] > Ignition.VILLAGE_MAGES["8"] * 2, "Aldo hits much harder than Odo")
	print("PASS: ignition" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
