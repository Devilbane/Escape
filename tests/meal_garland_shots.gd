extends SceneTree
## Screenshots of the frame round the dining tables (see MealGarland): the
## ivy-covered poles and ropes with their lamps at noon, at dusk and at night,
## wide and close up, in autumn, and in the game's own view at night.
## Run with: SHOTS=<folder> godot -s tests/meal_garland_shots.gd (needs a display); without SHOTS it only builds the village.

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


func _shoot(name: String, middle: Vector3, from: Vector3, at: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.global_position = middle + from
	cam.look_at(middle + at)
	cam.make_current()
	await _wait(6)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _views(prefix: String, middle: Vector3) -> void:
	await _shoot(prefix + "_wide", middle, Vector3(-4, 13, 21), Vector3(0, 1.5, 0))
	await _shoot(prefix + "_close", middle, Vector3(-11, 3.2, 8.5), Vector3(-7, 2.8, 0))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Diner"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.set_weather(Weather.CLEAR, 0.0)
	var meals: TownMeals = lvl.meals
	var middle: Vector3 = (meals.tables[0] + meals.tables[-1]) * 0.5
	game.player.global_position = middle + Vector3(-3, 0, 9)
	for hour in [12.0, 20.2, 23.0]:
		game.day_hour = hour
		lvl.set_hour(hour)
		await _wait(30)
		await _views("garland_%02d" % int(hour), middle)
	# The game's own camera at night, the hero by the tables.
	game.camera.make_current()
	game.player.global_position = meals.tables[0] + Vector3(-2, 0, 4.5)
	game.player.reset_physics_interpolation()
	await _wait(90)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("garland_game_night.png"))
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	await _wait(40)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("garland_game_day.png"))
	# Autumn: the ivy on the poles and ropes turns with the village's.
	game.camera.current = false
	IvySeasons.apply(lvl.ivy, _autumn_day())
	await _wait(10)
	await _shoot("garland_autumn", middle, Vector3(-4, 13, 21), Vector3(0, 1.5, 0))
	game.delete_save(game.save_path())
	print("PASS: meal garland shots")
	quit(0)


func _autumn_day() -> int:
	for d in 400:
		if IvySeasons.stage(d) == IvySeasons.TURN_DAYS:
			return d
	return 0
