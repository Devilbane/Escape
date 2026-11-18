extends SceneTree
## Screenshots of the penguin and banner on the temple tower.
## Run with: SHOTS=<folder> godot -s tests/penguin_shots.gd (needs a display); without SHOTS it only builds the village.

## name: [map letter of the door, camera offset from the front, look-at offset from the front]
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
	var hour := float(OS.get_environment("HOUR")) if OS.get_environment("HOUR") != "" else 12.0
	if OS.get_environment("FOG") != "":
		lvl.set_weather(Weather.FOG)
	game.day_hour = hour
	game._set_atmosphere(true)
	lvl.set_hour(hour)
	var peak: Node3D = lvl.find_child("ChapelPenguin", true, false)
	assert(peak != null, "the penguin is on the tower")
	var at := peak.global_position + Vector3(0, 0.2, 0)
	var views := {"penguin_front": Vector3(0, 6, 40), "penguin_game": Vector3(0, 20, 70), "penguin_close": Vector3(8, 4, 20), "penguin_back": Vector3(-6, 6, -40)}
	for name: String in views:
		if shots == "":
			break
		game.player.global_position = at + Vector3(0, -40, 30)
		var cam := Camera3D.new()
		cam.fov = 50.0
		root.add_child(cam)
		cam.global_position = at + (views[name] as Vector3)
		cam.look_at(at)
		cam.make_current()
		await _wait(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
		cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: penguin shots")
	quit(0)
