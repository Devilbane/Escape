extends SceneTree
## Pictures of the ferns, the stand of spruces (see Fern, Outdoor.SPRUCE_PATCH) and the spruces in
## the other forests of Apfeltal.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/fern_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
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
	game.hero_name = "Fern shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	await _wait(10)
	var level: Outdoor = game.level
	# The road past the stand, and the stand west of it.
	var road := level.cell_to_world(Vector2i(11, 19))
	var stand := level.cell_to_world(Vector2i(8, 19))
	game.player.global_position = road
	await _shot("stand_road", road + Vector3(9, 7, 12), stand + Vector3(0, 2.5, 0))
	await _shot("stand_close", road + Vector3(3, 2.2, 5), stand + Vector3(1, 1.5, 0))
	await _shot("stand_high", road + Vector3(14, 22, 20), stand)
	# From above, as the game's camera looks down on the crowns.
	await _shot("stand_top", stand + Vector3(1, 13, 7), stand + Vector3(0, 0, 0.5))
	# Ferns low down at the stand's edge.
	await _shot("ferns_low", road + Vector3(1.5, 1.2, 3), stand + Vector3(2.5, 0.2, 0))
	# The spruces in the other forests: the woods north of the village, and round the road east.
	var village := level.cell_to_world(Vector2i(50, 20))
	await _shot("village_woods", village + Vector3(6, 16, 26), village + Vector3(0, 0, -14))
	var east := level.cell_to_world(Vector2i(83, 6))
	game.player.global_position = east
	game.player.reset_physics_interpolation()
	await _shot("east_woods", east + Vector3(4, 9, 14), east + Vector3(0, 2, -6))
	# As the player sees them, through the game's own camera.
	if shots != "":
		await _wait(40)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("east_game.png"))
	game.player.global_position = road
	game.player.reset_physics_interpolation()
	# The game's own camera at the stand: how much it draws, and how the player sees it.
	game.player.global_position = stand + Vector3(2, 0, 0)
	game.player.reset_physics_interpolation()
	await _wait(30)
	if shots != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("stand_game.png"))
	print("drawn by the game camera at the stand: %d objects, %d primitives, %d draw calls" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("PASS: fern shots")
	quit(0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
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
