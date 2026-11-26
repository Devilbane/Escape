extends SceneTree
## Pictures of Nohpaan: the gorge, the meadow and pond, the monastery gate and courtyard, the hall, the sealed gate.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/nohpaan_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
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


func _shot(lvl: Level, name: String, cell: Vector2, from: Vector3, to: Vector3, fov := 50.0) -> void:
	var mid := Vector3(cell.x * Level.TILE, 0, cell.y * Level.TILE)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = mid + from
	cam.look_at(mid + to)
	cam.make_current()
	await _wait(12)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Nohpaan shots"
	await _wait(10)
	game.load_level(Nohpaan.level_index(game), false)
	await _wait(30)
	var lvl: Level = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	lvl.fog.visible = false
	var which := OS.get_environment("ONLY")
	# The game's own camera, with the hero at a few places.
	for place: Array in [["play_gorge", Vector2i(32, 41)], ["play_hub", Vector2i(32, 33)], ["play_pond", Vector2i(32, 26)], ["play_gate", Vector2i(32, 18)],
			["play_courtyard", Vector2i(32, 14)], ["play_hall", Vector2i(32, 7)], ["play_wood", Vector2i(11, 29)], ["play_garden", Vector2i(53, 29)]]:
		if which != "" and not which.split(",").has(place[0]):
			continue
		game.player.global_position = lvl.cell_to_world(place[1])
		game.player.velocity = Vector3.ZERO
		game._snap_camera()
		await _wait(25)
		if shots != "":
			root.get_texture().get_image().save_png(shots.path_join(String(place[0]) + ".png"))
	var views := {
		"overview": [Vector2(32, 26), Vector3(0, 150, 95), Vector3(0, 0, 0), 55.0],
		"hub": [Vector2(32, 31), Vector3(0, 16, 22), Vector3(0, 1, -2), 55.0],
		"pond": [Vector2(32, 29), Vector3(0, 7, 12), Vector3(0, 0.5, 0), 55.0],
		"gate": [Vector2(32, 19), Vector3(0, 9, 16), Vector3(0, 3, -4), 55.0],
		"courtyard": [Vector2(32, 12), Vector3(0, 14, 20), Vector3(0, 1, -2), 55.0],
		"hall": [Vector2(32, 7), Vector3(0, 9, 14), Vector3(0, 1, -2), 55.0],
		"stupa": [Vector2(23, 12), Vector3(0, 5, 9), Vector3(0, 2.2, 0), 55.0],
		"wood": [Vector2(10, 28), Vector3(0, 16, 22), Vector3(0, 1, -2), 55.0],
		"sealed": [Vector2(7, 11), Vector3(0, 6, 10), Vector3(0, 2.5, -4), 55.0],
		"wheels": [Vector2(32, 19), Vector3(5, 4, 9), Vector3(-0.5, 1.4, 0), 55.0],
	}
	for name: String in views:
		if which != "" and not which.split(",").has(name):
			continue
		var v: Array = views[name]
		await _shot(lvl, name, v[0], v[1], v[2], v[3])
	quit(0)
