extends SceneTree
## Screenshots of the snow on the stone mason's house front (lintel, sills, beams, doorstep).
## Run with: SHOTS=<folder> godot -s tests/house_snow_shots.gd (needs a display).

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
	game.hero_name = "Snowman"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	game.set_weather(Weather.SNOW, 3.0)
	game.snow_cover = 1.0
	var spot := Vector3.ZERO
	for st: Dictionary in lvl.stations:
		if st.kind == "steinmetz":
			spot = st.pos
	game.player.global_position = spot + Vector3(0, 0, 6)
	await _wait(200)
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	for view: Array in [["front", Vector3(-1.5, 4.5, 5.5)], ["close", Vector3(-1.0, 2.6, 3.4)]]:
		cam.global_position = spot + (view[1] as Vector3)
		cam.look_at(spot + Vector3(-0.5, 1.6, 0))
		cam.make_current()
		await _wait(20)
		root.get_texture().get_image().save_png(shots.path_join("mason_" + view[0] + ".png"))
	quit()
