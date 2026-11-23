extends SceneTree
## Pictures of the mages' practice duel (see MageDuel): each of the four spells in flight and
## as it lands, and a line of banter between the two.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/mage_duel_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
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
		await process_frame


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Duel shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	game.mage_duel._timer = 1e9
	level.set_weather(Weather.CLEAR)
	level.set_hour(12.0)
	var aldo := MageDuel.mage(level, MageDuel.ALDO)
	var odo := MageDuel.mage(level, MageDuel.ODO)
	check(aldo != null and odo != null, "both mages are there")
	for v in level.villagers:
		v._start("idle", 600.0)
	# Odo 7 m east of Aldo on the square, in plain sight.
	var spot := MageDuel.new(game).find_spot(level, aldo, odo)
	check(spot != Vector3.INF, "there is a duel ground near Aldo")
	odo.global_position = spot
	odo.reset_physics_interpolation()
	game.player.global_position = aldo.global_position + Vector3(0, 0, 10)
	var mid := (aldo.global_position + odo.global_position) * 0.5
	var side := (spot - aldo.global_position).cross(Vector3.UP).normalized()
	var eye := mid + side * 9.0 + Vector3(0, 4.0, 0)
	for kind in DuelSpells.KINDS:
		aldo.strike_pose("Spellcast_Shoot", 2.0)
		var from := aldo.global_position + Vector3(0, 1.4, 0)
		var to := odo.global_position + Vector3(0, 1.3, 0)
		DuelSpells.cast(level, kind, from, to, true)
		await _wait(14)
		await _shot(kind + "_flight", eye, mid + Vector3(0, 1.3, 0))
		await _wait(60)
		await _shot(kind + "_burst", eye, mid + Vector3(0, 1.3, 0))
		await _wait(60)
	# The banter.
	odo.chat_say("The sun! It blinded me!", 6.0)
	await _wait(20)
	await _shot("banter", eye, mid + Vector3(0, 1.8, 0))
	print("PASS: mage duel shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
