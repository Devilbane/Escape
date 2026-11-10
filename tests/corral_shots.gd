extends SceneTree
## Screenshots of the village's cattle pen (see Corral): the whole pen from the south-west, and the gate.
## Run with: SHOTS=<folder> godot -s tests/corral_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Herdsman"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	var middle := lvl.cell_to_world(Vector2i(59, 26))
	game.player.global_position = middle + Vector3(-14, 0, 16)
	await _wait(240)
	if shots != "":
		var views := {"pen": [Vector3(-10, 15, 17), Vector3(1, 0, 0)], "pen_close": [Vector3(-4, 8, 12), Vector3(1, 0, 0)]}
		for name: String in views:
			var cam := Camera3D.new()
			cam.fov = 55.0
			root.add_child(cam)
			cam.global_position = middle + (views[name][0] as Vector3)
			cam.look_at(middle + (views[name][1] as Vector3))
			await _wait(5)
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: corral shots")
	quit(0)
