extends SceneTree
## Pictures of the rabbits (see Animal): one at a forest edge in summer, one bolting, and the tracks
## they leave in the snow in winter. Also checks the rabbits sit on the ground and hop.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/rabbit_shots.gd

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


## Moves the game's season to season day `d` (by the day count, or the season shift where the
## seasons follow the calendar).
func _season(d: int) -> void:
	if "season_shift" in game:
		game.season_shift += d - game.level.season_day
	else:
		game.day = d
	game.day_hour = 12.0
	await _wait(30)


func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Rabbit shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var rabbits := level.animals.filter(func(a): return a.kind == "kaninchen")
	check(rabbits.size() >= 6, "rabbits live in the meadows (%d)" % rabbits.size())
	var r: Animal = rabbits[2]
	# Far away it sits or hops about; close by it bolts at a run.
	game.player.global_position = r.global_position + Vector3(40, 0, 0)
	await _season(_first(Weather.SUMMER))
	await _wait(60)
	check(not r.is_fleeing(), "a rabbit does not bolt from a far hero")
	var at := r.global_position
	await _shot("rabbit_summer", at + Vector3(2.5, 1.6, 4.0), at + Vector3(0, 0.5, 0))
	game.player.global_position = r.global_position + Vector3(4.0, 0, 0)
	await _wait(30)
	check(r.is_fleeing(), "a rabbit bolts when the hero comes near")
	check(r._current_anim == "Gallop", "and bolts in its bounding run (%s)" % r._current_anim)
	await _shot("rabbit_bolting", r.global_position + Vector3(3.0, 1.6, 4.5), r.global_position + Vector3(0, 0.5, 0))
	game.player.global_position = r.global_position + Vector3(40, 0, 0)
	await _season(_first(Weather.WINTER))
	for i in 400:
		await process_frame
	game.player.global_position = r.global_position + Vector3(10, 0, 0)
	await _wait(240)
	await _shot("rabbit_snow", r.global_position + Vector3(0, 7, 7), r.global_position)
	print("PASS: rabbit shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


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
