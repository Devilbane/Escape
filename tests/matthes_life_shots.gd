extends SceneTree
## Screenshots of Matthes at his field work and courting. Run with:
## SHOTS=<folder> xvfb-run -a godot --rendering-method gl_compatibility --rendering-driver opengl3 -s tests/matthes_life_shots.gd
## (needs a display). Writes close-ups of him with the hoe, the sack, the flower and the hearts.

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	if shots == "":
		print("PASS (screenshot helper: set SHOTS to run it)")
		quit(0)
		return
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


func _snap(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(shots.path_join("%s.png" % name))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Besom"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.season_shift = (Weather.YEAR_DAYS - posmod(Seasons.today(), Weather.YEAR_DAYS)) + Weather.SPRING_DAYS + 2
	lvl.set_hour(10.0)
	game.day_hour = 10.0
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	await _wait(80)
	var sweeper: Villager = null
	var hanna: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == StreetSweeper.ROLE:
			sweeper = v
		if v.role == "9":
			hanna = v
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	var spot := lvl.cell_to_world(sweeper.home)
	game.player.global_position = spot + Vector3(12, 0, 12)
	sweeper.global_position = spot
	sweeper.at_home = false
	sweeper._start("idle", 600.0)
	if OS.get_environment("HEARTS_ONLY") == "":
		# The tools, held still, from the front and the side.
		for prop: String in [MatthesLife.SACK, MatthesLife.FLOWER]:
			MatthesLife.show_prop(sweeper, prop, true)
			sweeper.play("Idle")
			await _wait(8)
			cam.global_position = spot + Vector3(2.0, 1.8, 5.5)
			cam.look_at(spot + Vector3(0, 1.0, 0))
			await _snap("prop_%s" % prop)
			MatthesLife.show_prop(sweeper, "", false)
		# Hoeing: the chop animation with the hoe, a few frames of it.
		MatthesLife.show_prop(sweeper, MatthesLife.HOE, true)
		sweeper._job = {"anim": "2H_Melee_Attack_Chop", "face": spot + Vector3(0, 0, -3)}
		sweeper._start("tend", 600.0)
		sweeper.set_meta("tend", {"kind": "hoe", "phase": "work", "t": 600.0, "face": spot + Vector3(0, 0, -3), "spot": spot})
		for i in 4:
			await _wait(16)
			cam.global_position = spot + Vector3(4.5, 2.2, 3.5)
			cam.look_at(spot + Vector3(0, 1.0, -0.4))
			await _snap("hoe_%d" % i)
	# A flower, offered to Hanna: the shy stand, the offer and the hearts.
	sweeper.remove_meta("tend")
	MatthesLife.show_prop(sweeper, "", false)
	hanna.global_position = spot + Vector3(2.0, 0, 0.2)
	hanna.at_home = false
	hanna.visible = true
	hanna._start("idle", 600.0)
	var plan := {"kind": "visit", "phase": "shy", "her": hanna, "t": 99.0, "tries": 0, "fond": 1}
	sweeper.set_meta("tend", plan)
	sweeper._start("tend", 600.0)
	sweeper.set_meta("tend", plan)
	sweeper._turn_to(hanna.global_position - sweeper.global_position, 1.0)
	for i in 1:
		await _wait(12)
		cam.global_position = spot + Vector3(1.0, 2.0, 7.0)
		cam.look_at(spot + Vector3(1.0, 1.1, 0.1))
		await _snap("shy_%d" % i)
	plan.phase = "offer"
	MatthesLife.show_prop(sweeper, MatthesLife.FLOWER, true)
	sweeper.play("Interact")
	for i in 1:
		await _wait(10)
		await _snap("offer_%d" % i)
	MatthesLife._hearts_at(lvl, spot + Vector3(1.0, 2.2, 0.1))
	cam.global_position = spot + Vector3(1.0, 2.0, 7.0)
	cam.look_at(spot + Vector3(1.0, 1.6, 0.1))
	for i in 3:
		await _wait(1)
		await _snap("hearts_%d" % i)
	quit(0)
