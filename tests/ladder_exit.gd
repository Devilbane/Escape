extends SceneTree
## Headless test: a hero who climbs down (or up) a house ladder and keeps walking is not sent up (or down)
## again: the way off the foot of the ladder, in its corner, leads along the way up, and a held key used to
## start the next climb at once (up and down and up and down in Mira's shop). Holding the key walks the
## hero clear of the ladder; standing still a moment and then pressing starts a new climb on purpose.
## Run with: godot --headless --fixed-fps 60 -s tests/ladder_exit.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
	else:
		print("ok   ", what)


func _initialize() -> void:
	WalkIn.lock_halls = false
	Storage.use(Storage.Memory.new())
	Lang.language = "en"
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
		await physics_frame


## The key that walks along `dir` (the keys read the world's axes).
func _key(dir: Vector3) -> String:
	if absf(dir.x) > absf(dir.z):
		return "ui_right" if dir.x > 0.0 else "ui_left"
	return "ui_down" if dir.z > 0.0 else "ui_up"


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(5)
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	var rec: Dictionary = {}
	for r: Dictionary in lvl.walk_in.buildings:
		if r.kind == "shop":
			rec = r
	check(rec.has("ladder"), "the shop has its ladder")
	var push: Vector3 = rec.ladder_push
	var key := _key(push)
	# Down from the top with the key towards the wall held, then out along the ladder's way up.
	hero.global_position = rec.ladder_top
	hero.reset_physics_interpolation()
	await _wait(10)
	Input.action_press(key)
	hero.climb_down_at(rec.ladder_top)
	await _wait(60 * 8)
	check(not hero.on_ladder() and hero.global_position.y < float(rec.ladder.y) + 0.5, "the hero is down (%s)" % hero.global_position)
	var climbs := 0
	var was := false
	for k in 60 * 4:
		await physics_frame
		if hero.on_ladder() and not was:
			climbs += 1
		was = hero.on_ladder()
	Input.action_release(key)
	check(climbs == 0, "walking out of the foot of the ladder does not climb it again (%d climbs)" % climbs)
	var foot: Vector3 = rec.ladder
	check(Vector2(hero.global_position.x - foot.x, hero.global_position.z - foot.z).length() > Player.LADDER_REACH, "and the hero got clear of it (%s)" % hero.global_position)
	# Back to the foot, standing a moment first: a new press climbs on purpose.
	hero.global_position = foot
	hero.reset_physics_interpolation()
	await _wait(60)
	Input.action_press(key)
	var up := false
	for k in 60 * 3:
		await physics_frame
		if hero.on_ladder():
			up = true
			break
	Input.action_release(key)
	check(up, "walking at the foot of the ladder from clear of it climbs up")
	await _wait(60 * 8)
	check(hero.global_position.y > float(rec.top), "and the hero is upstairs (%s)" % hero.global_position)
	print("PASS: ladder exit" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
