extends SceneTree
## Headless test: a ladder is climbed only by clicking it, never by walking into it. The way off the foot of
## a ladder, in its corner (or at a dead end in the sewers), leads along the way up, and a held key used to
## start the next climb at once (up and down and up and down in Mira's shop).
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
	var ladder: Node3D = null
	for l: Node3D in get_nodes_in_group(Player.LADDER_GROUP):
		if (l.get_meta("edge") as Vector3).is_equal_approx(rec.ladder_edge):
			ladder = l
	check(ladder != null, "the ladder is there to click")
	var foot: Vector3 = rec.ladder
	# Down from the top (the sewers' and the shop's way), with the key towards the wall held: out along the
	# ladder's way up never climbs it again.
	hero.global_position = rec.ladder_top
	hero.reset_physics_interpolation()
	await _wait(10)
	Input.action_press(key)
	await _wait(60)
	check(not hero.on_ladder(), "walking into the top of the ladder does not climb down")
	Input.action_release(key)
	hero.global_position = rec.ladder_top
	hero.reset_physics_interpolation()
	await _wait(5)
	check(hero.use_ladder(ladder), "clicking it at the top")
	await _wait(5)
	Input.action_press(key)
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
	check(climbs == 0, "holding the key at the foot of the ladder does not climb it (%d climbs)" % climbs)
	# A click on the ladder, from the middle of the room: the mouse's ray picks it, and it glows under it.
	hero.global_position = foot + Vector3(0, 0.05, 0)
	hero.reset_physics_interpolation()
	game._snap_camera()
	await _wait(10)
	var mid: Vector3 = (rec.ladder_edge as Vector3) + Vector3(0, float(rec.ladder_tall) * 0.5, 0) - push * 0.1
	var from: Vector3 = game.camera.global_position
	var dir := (mid - from).normalized()
	check(LadderClick.under_ray(self, hero, from, dir) == ladder, "the ray over the ladder points at it")
	check(LadderClick.under_ray(self, hero, from, (from - hero.global_position).normalized() * -1.0 + Vector3(0.6, 0, 0)) == null, "a ray far from it does not")
	LadderClick.glow(ladder, true)
	check(LadderClick.visuals(ladder).size() > 0 and LadderClick.visuals(ladder).all(func(m: MeshInstance3D): return m.material_overlay != null), "it glows under the mouse")
	LadderClick.glow(ladder, false)
	check(LadderClick.visuals(ladder).all(func(m: MeshInstance3D): return m.material_overlay == null), "and stops glowing")
	game._click(from + dir * ((hero.global_position.y - from.y) / dir.y))
	await _wait(20)
	check(hero.on_ladder(), "clicking the ladder climbs it")
	await _wait(60 * 8)
	check(hero.global_position.y > float(rec.top), "and the hero is upstairs (%s)" % hero.global_position)
	print("PASS: ladder exit" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
