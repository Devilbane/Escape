extends SceneTree
## Screenshots of Matthes the street sweeper at work. Run with:
## SEASON=autumn|winter SHOTS=<folder> xvfb-run -a godot --rendering-method gl_compatibility --rendering-driver opengl3 \
##   -s tests/street_sweeper_shots.gd (needs a display). Writes a close-up of him sweeping, a wide shot of the
## walkway before he starts and after he has swept it, and a portrait.

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var season := OS.get_environment("SEASON") if OS.get_environment("SEASON") != "" else "autumn"


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


func _snap(name: String) -> void:
	await _wait(3)
	if shots == "":
		return
	root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % [season, name]))


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
	print("loaded level")
	var winter := season == "winter"
	var day := (Weather.YEAR_DAYS - 3) if winter else (Weather.YEAR_DAYS - Weather.WINTER_DAYS - 3)
	game.season_shift = day - posmod(Seasons.today(), Weather.YEAR_DAYS)
	lvl.set_hour(10.0)
	game.day_hour = 10.0
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.snow_cover = 1.0 if winter else 0.0
	await _wait(80)
	print("settled")
	var sweeper: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == StreetSweeper.ROLE:
			sweeper = v
	if sweeper == null:
		print("no sweeper")
		quit(1)
		return
	var kind := "snow" if winter else "leaves"
	var way := SnowSweep.route(lvl, sweeper.home, RandomNumberGenerator.new(), Callable() if winter else Callable(LeafSweep, "is_clear").bind(lvl))
	print("kind ", kind, " wanted ", sweeper._sweep_wanted(), " route ", way.size())
	var cam := Camera3D.new()
	cam.fov = 36.0
	root.add_child(cam)
	cam.make_current()
	game.player.global_position = way[0] + Vector3(10, 0, 10)
	# Wide, before.
	var mid: Vector3 = way[way.size() / 2]
	cam.global_position = mid + Vector3(0, 16, 14)
	cam.look_at(mid)
	await _snap("wide_before")
	# Portrait.
	sweeper.global_position = way[0]
	sweeper._start("idle", 60.0)
	cam.global_position = sweeper.global_position + Vector3(0.9, 1.6, 3.2)
	cam.look_at(sweeper.global_position + Vector3(0, 1.1, 0))
	await _wait(10)
	await _snap("portrait")
	# Sweep the route.
	sweeper._sweep_kind = kind
	sweeper._sweep_way = way
	sweeper._hold_broom(true)
	sweeper._start("sweep", 400.0)
	var n := 0
	var worked := 0
	while sweeper._task == "sweep" and worked < 3000:
		worked += 1
		game.weather = Weather.CLEAR
		game.weather_hours = 9999.0
		await _wait(1)
		var spot := sweeper.global_position
		var side: Vector3 = sweeper._sweep.heading.cross(Vector3.UP) if sweeper._sweep else Vector3.RIGHT
		cam.global_position = spot + side * 5.0 + Vector3(0, 2.4, 0)
		cam.look_at(spot + Vector3(0, 0.6, 0) + (sweeper._sweep.heading * 0.8 if sweeper._sweep else Vector3.ZERO))
		if worked % 70 == 20 and n < 4:
			await _snap("work_%d" % n)
			n += 1
	print("done sweeping after ", worked)
	await _wait(20)
	cam.global_position = mid + Vector3(0, 16, 14)
	cam.look_at(mid)
	await _snap("wide_after")
	cam.global_position = mid + Vector3(5, 5.5, 8)
	cam.look_at(mid)
	await _snap("near_after")
	quit(0)
