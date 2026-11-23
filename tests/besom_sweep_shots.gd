extends SceneTree
## Screenshots of Konrad sweeping the snow with his birch broom, as a pose sheet. Run with:
## SHOTS=<folder> xvfb-run -a godot -s tests/besom_sweep_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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


func _wait(n: int) -> void:
	for i in n:
		await process_frame


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
	game.season_shift = (Weather.YEAR_DAYS - 3) - posmod(Seasons.today(), Weather.YEAR_DAYS)
	lvl.set_hour(10.0)
	game.day_hour = 10.0
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.snow_cover = 1.0
	await _wait(60)
	var konrad: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "K":
			konrad = v
	print("konrad ", konrad, " winter ", Weather.is_winter(lvl.season_day), " wants ", SnowSweep.wants(lvl))
	if konrad == null:
		quit(1)
		return
	game.player.global_position = konrad.global_position + Vector3(6, 0, 6)
	var way := SnowSweep.route(lvl, konrad.home, RandomNumberGenerator.new())
	print("route points ", way.size())
	konrad.global_position = way[0]
	konrad._sweep_way = way
	konrad._hold_broom(true)
	konrad._start("sweep", 60.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	var cam := Camera3D.new()
	cam.fov = 36.0
	root.add_child(cam)
	cam.make_current()
	var n := 0
	for i in 200:
		await _wait(1)
		var spot := konrad.global_position
		var side: Vector3 = konrad._sweep.heading.cross(Vector3.UP) if konrad._sweep else Vector3.RIGHT
		cam.global_position = spot + side * 7.0 + Vector3(0, 2.2, 0)
		cam.look_at(spot + Vector3(0, 0.75, 0) + (konrad._sweep.heading * 0.6 if konrad._sweep else Vector3.ZERO))
		if shots != "" and i % 14 == 0 and i >= 98 and n < 8:
			root.get_texture().get_image().save_png(shots.path_join("sweep_%02d.png" % n))
			n += 1
	print("task ", konrad._task)
	quit(0)
