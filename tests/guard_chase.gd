extends SceneTree
## Headless test for Guard Ulrich chasing Spooknortz (see GuardChase): when the guard spots the thief on his
## night round he shouts that he should stop and runs after him, but never catches up; then he gives up,
## grumbles and goes back to his post.
## Run with: godot --headless --fixed-fps 60 -s tests/guard_chase.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Chase test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var raid: SpookRaid = level.spook_raid
	for text in GuardChase.SHOUTS + GuardChase.GRUMBLES:
		check(Lang.EN.has(text), "English for: " + text)
	for i in GuardChase.SHOUT_SOUNDS:
		check(ResourceLoader.exists("res://assets/sounds/guard_shout_%d.wav" % i), "shout sound %d exists" % i)
	game.player.global_position = level.cell_to_world(Vector2i(40, 24))
	game._snap_camera()
	var ulrich: Villager = null
	for v: Variant in level.villagers:
		if is_instance_valid(v) and v.role == SpookRaid.GUARD_ROLE:
			ulrich = v
	check(ulrich != null, "the village has its guard")
	if ulrich == null:
		quit(1)
		return
	game.day_hour = 23.5
	level.set_hour(23.5)
	await _wait(5)
	for v: Variant in level.villagers:
		if is_instance_valid(v) and v.goes_to_bed():
			v.at_home = true
	ulrich.at_home = false
	ulrich.visible = true
	ulrich.global_position = Vector3(0.0, 0.0, 4000.0)
	raid._done_tonight = false
	raid.begin(game, true)
	for i in 30:
		raid.step(0.1)
	var here: Vector3 = raid.figure.global_position
	var placed := false
	for a in range(0, 360, 30):
		var spot_pos := here + Vector3(cos(deg_to_rad(a)), 0.0, sin(deg_to_rad(a))) * 13.0
		var cell := level.world_to_cell(spot_pos)
		if level.astar.is_in_boundsv(cell) and not level.astar.is_point_solid(cell) and level.has_line_of_sight(spot_pos, here):
			ulrich.global_position = Vector3(spot_pos.x, 0.0, spot_pos.z)
			placed = true
			break
	check(placed, "a spot to put the guard where he sees the thief")
	for i in 5:
		raid.step(0.1)
	check(raid.chase != null, "the guard who spots the thief starts a chase")
	if raid.chase != null:
		check(raid.chase.shouts == 1 and ulrich._bubble_time > 0.0, "he shouts at once (a speech bubble)")
	var nearest := INF
	var t := 0.0
	while raid.chase != null and t < 40.0:
		await _wait(6)
		raid.step(0.1)
		t += 0.1
		if raid.figure != null and is_instance_valid(raid.figure):
			nearest = minf(nearest, Vector2(ulrich.global_position.x - raid.figure.global_position.x, ulrich.global_position.z - raid.figure.global_position.z).length())
	check(raid.chase == null, "the chase ends (%d s)" % t)
	check(t <= GuardChase.MAX_TIME + 2.0, "and does not go on for ever")
	check(nearest > 2.0, "he never catches up (nearest %.1f m)" % nearest)
	check(ulrich._bubble_time > 0.0 or raid.state == SpookRaid.IDLE or t > 1.0, "he grumbles when he gives up")
	check(raid._chase_ok > raid._clock, "the next chase has to wait a while")
	print("guard chase: ", "OK" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
