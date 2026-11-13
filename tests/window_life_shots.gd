extends SceneTree
## Screenshots of Weavers' Lane at night with the windows alive.
## Run with: SHOTS=<folder> godot -s tests/window_life_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Ivy"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	if shots != "" and not lvl.town_houses.is_empty():
		var mat: ShaderMaterial = lvl._life_material()
		var first: Node3D = lvl.town_houses[0]
		var last: Node3D = lvl.town_houses[lvl.town_houses.size() - 1]
		var mid := (first.global_position + last.global_position) * 0.5
		var out := Vector3(0, 0, 1).rotated(Vector3.UP, first.rotation.y)
		var cam := Camera3D.new()
		cam.fov = 60.0
		root.add_child(cam)
		cam.global_position = mid + out * 15.0 + Vector3(0, 2.6, 0)
		cam.look_at(mid + Vector3(0, 3.6, 0))
		cam.make_current()
		game.player.global_position = mid + out * 14.0
		# Normal odds, and a boosted set so the events are easy to catch.
		for variant: String in ["busy", "normal"]:
			mat.set_shader_parameter("curtain_chance", 0.22 if variant == "normal" else 0.5)
			mat.set_shader_parameter("figure_chance", 0.1 if variant == "normal" else 0.5)
			for hour: float in [20.6, 21.8]:
				game.day_hour = hour
				DayNight.apply(game._env, game._moon, hour)
				lvl.set_hour(hour)
				await _wait(6)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(shots.path_join("%s_%02d.png" % [variant, int(hour * 10)]))
	game.delete_save(game.save_path())
	print("PASS: window life shots")
