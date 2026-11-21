extends SceneTree
## Pictures of the village fountain (see VillageFountain): from the square, close up on the
## goddess on top, and from the game's camera. Run with a display:
## SHOTS=<folder> godot --fixed-fps 60 -s tests/fountain_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
## Only these pictures, comma separated (all when empty).
var only := OS.get_environment("ONLY")


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
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
	game.hero_name = "Fountain shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var fountain := Vector3.ZERO
	for y in level.height:
		for x in level.width:
			if level.cell_char(Vector2i(x, y)) == "F":
				fountain = level.cell_to_world(Vector2i(x, y))
	game.player.global_position = fountain + Vector3(-9, 0, -6)
	game.day_hour = 11.0
	if "season_shift" in game:
		game.season_shift += 30 - level.season_day
	else:
		game.day = 30
	await _wait(40)
	await _shot("square", fountain + Vector3(9, 6.5, 13), fountain + Vector3(0, 1.6, 0))
	await _shot("front", fountain + Vector3(0.5, 2.6, 9.5), fountain + Vector3(0, 2.4, 0))
	await _shot("goddess", fountain + Vector3(0.4, 4.3, 2.6), fountain + Vector3(0, 4.15, 0))
	await _shot("goddess_side", fountain + Vector3(-2.4, 4.2, 1.2), fountain + Vector3(0, 4.15, 0))
	await _shot("game_view", fountain + Vector3(0, 15, 12), fountain)
	quit(0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "" or (only != "" and not only.split(",").has(name)):
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
