extends SceneTree
## Screenshots of the stonemason's house and his yard of stone blocks beside it (see Outdoor._build_stone_yard).
## Run with: SHOTS=<folder> godot -s tests/mason_yard_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Mason"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	var mason: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "S":
			mason = v
	var home: Vector2i = mason.station.cell
	var middle := lvl.cell_to_world(home + Vector2i(0, -2))
	game.player.global_position = middle + Vector3(-12, 0, 14)
	await _wait(240)
	if shots != "":
		var views := {"front": [Vector3(0, 9, 16), Vector3(0, 1, 0)], "side": [Vector3(14, 8, 10), Vector3(2, 1, 0)], "top": [Vector3(1, 26, 0.5), Vector3(1, 0, 0)]}
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
	print("PASS: mason yard shots")
	quit(0)
