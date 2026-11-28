extends SceneTree
## Headless test: the climb on a placed wall (see WallScreens.open_climb) fills the screen. A stage hung straight
## under a CanvasLayer once stayed 0 x 0, which left an empty screen over the paused game.
## Run with: godot --headless --fixed-fps 60 -s tests/wall_climb_screen.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Screen test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	for i in 30:
		await physics_frame
	game.state = game.State.PLAYING
	var file: String = WallPlacements.all()[0].wall
	WallScreens.open_climb(game, file)
	for i in 10:
		await physics_frame
	var stage: WallStage = null
	for layer in game.get_children():
		for c in layer.get_children():
			if c is WallStage:
				stage = c
	check(stage != null, "the climb opens a stage")
	if stage != null:
		var screen := root.get_visible_rect().size
		check(stage.size.is_equal_approx(screen), "the stage fills the screen (%s of %s)" % [stage.size, screen])
		check(stage.view.size.x > 8 and stage.view.size.y > 8, "its 3D view has a size (%s)" % stage.view.size)
	game.delete_save(game.save_path())
	print("PASS: wall climb screen" if failures == 0 else "FAILED: %d" % failures)
	quit(failures)
