extends SceneTree
## The flower beds in the valley's paved lane (see FlowerBeds): they sit at the corners four lane tiles share
## inside the village, the ground under them is paved solid, and the flowers follow the seasons (heads in
## spring, summer and autumn, mostly none in winter).
## Run with: godot --headless -s tests/flower_beds.gd   (SHOTS=<folder> with a display saves pictures)

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


func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Bed test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var spots: Array[Vector3] = level.bed_spots
	check(spots.size() >= 8, "the lane has its flower beds (%d)" % spots.size())
	check(level.flower_beds != null and level.flower_beds.bed_count() == spots.size(), "every spot has a bed")
	# Each bed lies where four lane tiles meet, inside the village.
	for at in spots:
		var c := level.world_to_cell(at)
		var corner := 0
		for d: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			if level.cell_char(c + d) == ",":
				corner += 1
		check(corner >= 3, "a bed lies on the lane (%s)" % at)
		check(level._paved_at(at), "the ground under a bed is paved (%s)" % at)
	# The beds follow the seasons.
	var heads := {}
	for season in Weather.SEASONS:
		level.set_season(_first(season))
		check(level.flower_beds.season() == season, "the beds wear the %s look" % season)
		heads[season] = level.flower_beds.visible_heads()
	check(heads[Weather.SUMMER] > spots.size() * 15, "summer: the beds are in full bloom (%d heads)" % heads[Weather.SUMMER])
	check(heads[Weather.SPRING] > spots.size() * 15, "spring: the beds bloom (%d heads)" % heads[Weather.SPRING])
	check(heads[Weather.AUTUMN] > spots.size() * 10, "autumn: most heads are still there (%d)" % heads[Weather.AUTUMN])
	check(heads[Weather.WINTER] < heads[Weather.SUMMER] / 2, "winter: the beds are bare (%d heads)" % heads[Weather.WINTER])
	if shots != "":
		var at := spots[spots.size() / 2]
		game.player.global_position = at + Vector3(4, 0, 3)
		for season in Weather.SEASONS:
			game.season_shift += _first(season) - level.season_day
			game.day_hour = 12.0
			await _wait(30)
			await _shot("bed_wide_" + season, at + Vector3(0, 13, 8), at)
			await _shot("bed_close_" + season, at + Vector3(0, 4.2, 3.6), at)
	print("PASS: flower beds" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
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
