extends SceneTree
## Screenshots of the villagers' houses one walks into in the village,
## from the game's own camera with the hero standing inside.
## Run with: SHOTS=<folder> HOUR=<h> godot -s tests/walk_in_rooms_shots.gd (needs a display).

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
	game.day_hour = hour
	game._set_atmosphere(true)
	lvl.set_hour(hour)
	var i := 0
	for rec: Dictionary in lvl.walk_in.buildings:
		if rec.kind != "house":
			continue
		var node: Node3D = rec.node
		var room: Rect2 = rec.room
		var at: Vector3 = node.global_transform * Vector3(room.get_center().x, rec.floor, room.get_center().y + room.size.y * 0.25)
		game.player.global_position = at
		game.player.reset_physics_interpolation()
		game.day_hour = hour
		await _wait(40)
		await RenderingServer.frame_post_draw
		if shots != "":
			root.get_texture().get_image().save_png(shots.path_join("%02d_%s_%s_%dh.png" % [i, rec.kind, node.name, int(hour)]))
		print("shot ", i, " ", rec.kind, " ", node.name, " inside=", rec.get("inside"))
		i += 1
	game.delete_save(game.save_path())
	print("PASS: walk-in room shots")
	quit(0)
