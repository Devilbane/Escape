extends SceneTree
## Screenshots of the shared meals on the square (see TownMeals): the townsfolk
## seated at the dining tables at noon, from the side and close up.
## Run with: SHOTS=<folder> godot -s tests/town_meals_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Diner"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	game.set_weather(Weather.CLEAR, 0.0)
	var meals: TownMeals = lvl.meals
	var middle: Vector3 = (meals.tables[0] + meals.tables[-1]) * 0.5
	game.player.global_position = middle + Vector3(-3, 0, 9)
	# Everyone who comes to meals sits down at once, for the picture.
	var i := 0
	for v: Villager in lvl.villagers:
		if not TownMeals.goes(v):
			continue
		var seat: Dictionary = meals.seats[(i * 5) % meals.seats.size()]
		i += 1
		if seat.taker != null:
			seat = meals.free_seat()
		seat.taker = v
		v.global_position = seat.stand
		v.reset_physics_interpolation()
		v.meal_seat = seat
		v._start("dine", 1.0)
		v._meal_step = "sitting"
		v._meal_clock = 0.0
	await _wait(120)
	var talker: Villager = meals.seated()[0] if not meals.seated().is_empty() else null
	if talker:
		talker.say(Lang.t(TownMeals.TABLE_TALK[0][0]), Vector3.INF, 30.0)
	await _wait(20)
	if shots != "":
		var views := {"meal": [Vector3(-9, 9, 11), Vector3(0, 0.8, 0)], "meal_close": [Vector3(-3.5, 3.5, 5), Vector3(-2, 0.8, 0)]}
		for name: String in views:
			var cam := Camera3D.new()
			cam.fov = 55.0
			root.add_child(cam)
			cam.global_position = middle + (views[name][0] as Vector3)
			cam.look_at(middle + (views[name][1] as Vector3))
			cam.make_current()
			await _wait(5)
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: town meals shots")
	quit(0)
