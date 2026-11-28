extends SceneTree
## Screenshots of Herald Konrad as the town crier: his podium and NEWS! sign, his hat, and the climb, the loudhailer
## and the speech. Run with: SHOTS=<folder> xvfb-run -a godot -s tests/crier_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var cam: Camera3D
var n := 0


func _initialize() -> void:
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("%s.png" % name))
	n += 1


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Anna"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.season_shift = 20 - posmod(Seasons.today(), Weather.YEAR_DAYS)
	lvl.set_hour(11.0)
	game.day_hour = 11.0
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	await _wait(40)
	var konrad: Villager = lvl.herald()
	print("stage ", lvl.crier_stage)
	if konrad == null or lvl.crier_stage.is_empty():
		print("FAIL: no stage")
		quit(1)
		return
	game.player.global_position = konrad.global_position + Vector3(0, 0, 14)
	cam = Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.make_current()
	var pos: Vector3 = lvl.crier_stage.pos
	_look(pos + Vector3(-3, 4.6, 11.0), pos + Vector3(-0.8, 1.4, 0))
	await _shot("01_stage_front")
	_look(pos + Vector3(7.5, 3.2, 6.0), pos + Vector3(0.2, 1.3, 0))
	await _shot("02_stage_steps")
	_look(pos + Vector3(-9.0, 2.4, 3.5), pos + Vector3(-3.3, 1.6, 0.5))
	await _shot("03_sign")
	_look(pos + Vector3(-3.3, 2.2, 3.4), pos + Vector3(-3.3, 1.75, 0.5))
	await _shot("04_sign_close")
	_look(pos + Vector3(0.0, 2.4, 3.8), pos + Vector3(0.0, 1.5, 0.3))
	await _shot("05_lectern")
	# The hat, from the front and from the side.
	var head := konrad.global_position + Vector3(0, 2.0, 0)
	_look(head + Vector3(0, 0.25, 3.4), head + Vector3(0, 0.0, 0))
	await _shot("06_hat_front")
	_look(head + Vector3(3.2, 0.5, 1.6), head)
	await _shot("07_hat_side")
	_look(head + Vector3(-2.2, 0.9, -2.8), head)
	await _shot("08_hat_back")
	# The announcement.
	lvl._call_the_village(INF, true, "Hear ye, hear ye! Anna has completed the task \"Bandit Plague\"!")
	var phases := {}
	for i in 900:
		await _wait(1)
		var c: TownCrier = konrad._crier
		var ph := c.phase if c != null else ""
		if konrad._task != TownCrier.TASK:
			ph = konrad._task
		if not phases.has(ph):
			phases[ph] = i
			print("phase ", ph, " at frame ", i, " pos ", konrad.global_position)
		var spot := konrad.global_position
		if ph in ["climb", "raise", "speak", "lower", "descend"]:
			_look(pos + Vector3(-1.0, 3.2, 9.0), spot + Vector3(0, 1.6, 0))
			if ph == "climb" and not phases.has("shot_climb") and spot.y > 0.3:
				phases["shot_climb"] = true
				await _shot("10_climb")
			if ph == "raise" and not phases.has("shot_raise") and c.clock > 0.55:
				phases["shot_raise"] = true
				_look(spot + Vector3(1.6, 2.1, 2.6), spot + Vector3(0, 1.9, 0))
				await _shot("11_raise")
			if ph == "speak" and not phases.has("shot_speak") and c.clock > 0.8:
				phases["shot_speak"] = true
				await _shot("12_speak_wide")
				_look(spot + Vector3(1.6, 2.1, 2.6), spot + Vector3(0, 1.9, 0))
				await _shot("13_speak_close")
				_look(spot + Vector3(-2.5, 2.2, 2.4), spot + Vector3(0, 1.9, 0))
				await _shot("14_speak_other_side")
		if konrad._task == "idle" and phases.has("descend"):
			break
	print("done ", phases.keys())
	quit(0)
