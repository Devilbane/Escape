extends SceneTree
## Headless test: the stairs of every dungeon style (stone, bone, rock, obsidian, crystal and
## the mine settings) get built, and keep a look of their own (see StairsDown.look).
## Run with: godot --headless --fixed-fps 60 -s tests/stairs_shots.gd
## With SHOTS=<folder> and a display it also saves a close screenshot of each stairs there.

## Level number (as in the file name), and the letters of its stairs worth a picture.
const FLOORS := {1: "E", 8: "E", 19: "E", 20: "E", 21: "^", 22: "^", 25: "^", 31: "^"}

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	if shots != "":
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
	if shots != "":
		game._title.visible = false
	game.hero_name = "Stairs test"
	await _wait(10)
	for number: int in FLOORS:
		game.load_level(number - 1, false)
		await _wait(15)
		var lvl: Level = game.level
		var ch: String = FLOORS[number]
		var cell := Vector2i(-1, -1)
		for y in lvl.height:
			for x in lvl.grid[y].length():
				if lvl.grid[y][x] == ch:
					cell = Vector2i(x, y)
		check(cell.x >= 0, "level %d has a '%s' tile" % [number, ch])
		if cell.x < 0:
			continue
		await _shot("stairs_%02d" % number, lvl, cell)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	game.delete_save(game.save_path())
	print("PASS: stairs shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, lvl: Level, cell: Vector2i) -> void:
	var ch_up := lvl.cell_char(cell) == "E"
	if shots == "":
		return
	var at: Vector3 = lvl.cell_to_world(cell)
	var side := lvl._open_side(cell)
	var out: Vector3 = lvl.cell_to_world(side) - at
	out.y = 0.0
	out = out.normalized()
	game.player.global_position = Vector3(at.x, 0.0, at.z) + out * 3.0
	if lvl.fog:
		lvl.fog.visible = false
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = at + out * 6.5 + Vector3(0, 5.5 if ch_up else 4.5, 0)
	cam.look_at(at + Vector3(0, -0.3, 0))
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
