extends SceneTree
## Screenshots of the winter braziers by the dining tables (see MealBraziers):
## the square in snow by day and at night, wide and close up, and in the game's own view.
## Run with: SHOTS=<folder> godot -s tests/meal_braziers_shots.gd (needs a display); without SHOTS it only builds the village.

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
	await _wait(8)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Diner"
	# Move the seasons on to winter.
	for s in Weather.YEAR_DAYS:
		if Weather.is_winter(Seasons.today() + s):
			game.season_shift = s
			break
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.set_weather(Weather.CLEAR, 0.0)
	game.snow_cover = 1.0
	var meals: TownMeals = lvl.meals
	var middle: Vector3 = (meals.tables[0] + meals.tables[-1]) * 0.5
	game.player.global_position = middle + Vector3(-3, 0, 9)
	for hour in [13.0, 22.0]:
		game.day_hour = hour
		lvl.set_hour(hour)
		await _wait(40)
		await _shoot("braziers_%02d_wide" % int(hour), middle, Vector3(-3, 11, 15), Vector3(0, 1.0, 0))
		await _shoot("braziers_%02d_close" % int(hour), middle, Vector3(-9.5, 2.6, 5.0), Vector3(-5.5, 1.0, 0))
	game.camera.make_current()
	game.player.global_position = middle + Vector3(0, 0, -4.0)
	game.player.reset_physics_interpolation()
	await _wait(90)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("braziers_game_night.png"))
	game.delete_save(game.save_path())
	print("PASS: meal braziers shots")
	quit(0)
