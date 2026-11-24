extends SceneTree
## Pictures of the dragon lair's stone arch (see Outdoor._build_lair_entrance), summer and winter, by day and at dusk.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/lair_arch_shots.gd

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
	game.hero_name = "Shots"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var lvl: Outdoor = game.level
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	var front: Vector3 = lvl.doors["E"] - Vector3(0, 0, 2.0)
	game.player.global_position = front + Vector3(0, 0.05, 4.0)
	game.player.reset_physics_interpolation()
	game.player.visible = false
	var cam := Camera3D.new()
	cam.fov = 50
	lvl.add_child(cam)
	cam.make_current()
	var views := {
		"front": [Vector3(0, 2.6, 7.5), Vector3(0, 1.8, 0)],
		"close": [Vector3(0.8, 1.8, 4.2), Vector3(0, 1.9, 0)],
		"wide": [Vector3(-5, 4, 12), Vector3(0, 2.5, -1)],
	}
	var seasons := {"summer": 10, "winter": 24}
	var hours := {"day": 12.0, "dusk": 18.0}
	var pick := OS.get_environment("ONLY").split(",", false)
	if not pick.is_empty():
		for k: String in seasons.keys() + hours.keys() + views.keys():
			if not pick.has(k):
				seasons.erase(k)
				hours.erase(k)
				views.erase(k)
	for s: String in seasons:
		game.season_shift = int(seasons[s]) - Seasons.today()
		game.snow_cover = 1.0 if s == "winter" else 0.0
		lvl.set_season(seasons[s])
		for h: String in hours:
			game.day_hour = hours[h]
			lvl.set_hour(hours[h])
			await _wait(20)
			for v: String in views:
				cam.global_position = front + (views[v][0] as Vector3)
				cam.look_at(front + (views[v][1] as Vector3))
				await _wait(6)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(shots.path_join("%s_%s_%s.png" % [v, s, h]))
	game.delete_save(game.save_path())
	quit(0)
