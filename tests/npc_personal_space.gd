extends SceneTree
## Headless test: villagers who walk about (the village kid Pip) never stand
## inside one who keeps to their spot (Mira the shopkeeper), and a bump or
## click next to both goes to the shop, not to the kid.
## Run with: godot --headless -s tests/npc_personal_space.gd

var failures := 0
var game: Node
var frames := 0
var pip: Villager
var mira: Villager
var mira_start := Vector3.ZERO
var closest := INF


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
	if frames == 5:
		_setup()
		return false
	if pip == null or mira == null:
		return _finish()
	# Pip runs about right next to Mira for a while; he must never get into her.
	if frames < 400:
		if frames % 40 == 0:
			pip._walk_to(mira.global_position, Villager.RUN_SPEED, "idle")
		# Pip starts inside Mira; he is pushed out on his first physics step,
		# which may come after this frame (with --fixed-fps it does), so the
		# gap only counts once that step has surely run.
		if frames > 10:
			closest = minf(closest, _gap())
		return false
	check(closest >= Villager.PERSONAL_SPACE - 0.05, "Pip keeps out of Mira while running at her (closest %.2f m)" % closest)
	check(mira.global_position.distance_to(mira_start) < 0.01, "Mira is not pushed off her spot")
	_test_priority()
	_test_errands()
	return _finish()


func _finish() -> bool:
	if failures == 0:
		print("PASS: npc personal space")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _gap() -> float:
	var d := pip.global_position - mira.global_position
	d.y = 0.0
	return d.length()


func _setup() -> void:
	game.load_level(game._outdoor_index(), false)
	check(game.level is Outdoor, "the village is loaded")
	for v in game.level.villagers:
		if v.role == "7":
			pip = v
		elif v.role == "6":
			mira = v
	check(pip != null and mira != null, "Pip and Mira are in the village")
	if pip == null or mira == null:
		return
	# Keep the hero well away so nobody waits for him.
	game.player.global_position = mira.global_position + Vector3(30, 0, 30)
	# Pip starts right inside Mira, as in the bug report.
	pip.home = mira.home + Vector2i(2, 0)
	pip.global_position = mira.global_position
	mira_start = mira.global_position
	mira._start("work", 1000.0)
	pip._start("idle", 0.5)


func _test_priority() -> void:
	var level: Outdoor = game.level
	# Pip squeezed right up to Mira: a bump between them, a little nearer
	# Pip, still opens the shop.
	pip.global_position = mira.global_position + Vector3(1.0, 0, 0)
	pip.station.pos = pip.global_position
	mira.station.pos = mira.global_position
	var bump := mira.global_position + Vector3(0.6, 0, 0)
	check(level.station_at(bump).get("npc") == mira, "a bump between Pip and Mira goes to Mira's shop")
	check(level.nearest_station(bump, 2.2).get("npc") == mira, "a click between Pip and Mira walks to Mira's shop")
	# Right on Pip, a fair way from Mira, Pip can still be talked to.
	pip.global_position = mira.global_position + Vector3(1.6, 0, 0)
	pip.station.pos = pip.global_position
	check(level.station_at(pip.global_position).get("npc") == pip, "a bump right on Pip still talks to Pip")


func _test_errands() -> void:
	# Pip never picks a place right at Mira's stall to run to.
	pip.home = mira.home + Vector2i(1, 0)
	for i in 200:
		var c: Vector2i = game.level.world_to_cell(pip._nearby(3))
		if c == pip.home:
			continue
		if maxi(absi(c.x - mira.home.x), absi(c.y - mira.home.y)) <= 1:
			check(false, "Pip picked a spot next to Mira's stall: %s" % c)
			return
