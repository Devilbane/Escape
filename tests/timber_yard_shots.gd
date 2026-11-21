extends SceneTree
## Screenshots of the woodcutter's felled trunks beside his yard (see WoodLogs.build).
## Run with: SHOTS=<folder> godot -s tests/timber_yard_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Cutter"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	var home := Vector2i(-1, -1)
	for s in lvl.stations:
		if s.kind == "holzfaeller":
			home = s.cell
	for y in range(home.y - 4, home.y + 5):
		var row := ""
		for x in range(home.x - 6, home.x + 4):
			row += lvl.cell_char(Vector2i(x, y))
		print(row)
	var middle := lvl.cell_to_world(home + Vector2i(-2, 0))
	game.player.global_position = middle + Vector3(-14, 0, 16)
	await _wait(240)
	if shots != "":
		var west := lvl.cell_to_world(home + Vector2i(-2, -2)) - middle
		var views := {"front": [Vector3(-3, 7, 11), Vector3(0, 0.5, 0)], "close": [west + Vector3(-2.2, 1.6, 3.0), west + Vector3(0, 0.3, 0)], "end": [west + Vector3(-3.2, 1.0, 0.6), west + Vector3(-1.0, 0.3, 0)], "top": [Vector3(0.5, 22, 0.5), Vector3(0, 0, 0)]}
		for name: String in views:
			var cam := Camera3D.new()
			cam.fov = 60.0
			root.add_child(cam)
			cam.global_position = middle + (views[name][0] as Vector3)
			cam.look_at(middle + (views[name][1] as Vector3))
			cam.make_current()
			await _wait(5)
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: timber yard shots")
	quit(0)
