extends SceneTree
## Screenshots of the village's ivy fronts (temple, castle, guild hall, a house).
## Run with: SHOTS=<folder> godot -s tests/ivy_fronts_shots.gd (needs a display); without SHOTS it only builds the village.

const TARGETS := {"temple": "s", "castle": "k", "guild": "w", "house": "h"}

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
	var hour := 12.0
	lvl.set_hour(hour)
	for name: String in TARGETS:
		var key: String = TARGETS[name]
		if shots == "" or not lvl.doors.has(key):
			continue
		var front: Vector3 = lvl.doors[key]
		game.player.global_position = front + Vector3(0, 0, 3)
		var cam := Camera3D.new()
		cam.fov = 55.0
		root.add_child(cam)
		cam.global_position = front + Vector3(0, 7.5, 13)
		cam.look_at(front + Vector3(0, 3.5, -3))
		cam.make_current()
		await _wait(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
		cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: ivy fronts shots")
	quit(0)
