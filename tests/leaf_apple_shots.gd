extends SceneTree
## Top-down and game-camera pictures of the apple trees that explain the autumn leaves (see AppleTree.plant_for_leaves).
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/leaf_apple_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


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
	game.hero_name = "Leaf shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var autumn := 0
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == Weather.AUTUMN:
			autumn = d + 2
			break
	if "season_shift" in game:
		game.season_shift += autumn - level.season_day
	else:
		game.day = autumn
	game.day_hour = 12.0
	await _wait(60)
	var all := level.square_trees + level.leaf_trees
	# The village and the east, straight down.
	await _shot("top_west", Vector3(64, 150, 100), Vector3(64, 0, 99.5))
	await _shot("top_village", Vector3(200, 150, 105), Vector3(200, 0, 104.5))
	await _shot("top_east", Vector3(320, 150, 100), Vector3(320, 0, 99.5))
	# Standing at a tree as at the game's camera.
	var tree: Vector3 = (level.leaf_trees[level.leaf_trees.size() / 2].node as Node3D).position
	await _shot("screen", tree + Vector3(0, 22, 16), tree)
	print("trees: ", all.size())
	quit()


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.far = 600.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at, Vector3.FORWARD)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
