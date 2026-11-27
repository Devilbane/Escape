extends SceneTree
## Screenshots of the HUD's F2 lines (place and tile, then clock and season), one per season.
## Run with: SHOTS=<folder> godot -s tests/hud_clock_shots.gd (needs a display); without SHOTS it only checks the text.

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
	game.show_coords = true
	game.player.godmode = true
	var days := {"spring": 2, "summer": Weather.SPRING_DAYS + 2, "autumn": Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + 1,
			"winter": Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1}
	for season: String in days:
		game.season_shift = int(days[season]) - Seasons.today()
		game.day_hour = 14.0
		await _wait(10)
		var text: String = game._coords_label.text
		print(text.replace("\n", " | "))
		if not text.contains("14:00  " + season.capitalize()):
			print("FAIL: no clock and season in: ", text)
			quit(1)
			return
		if shots != "":
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var r := Rect2i(Vector2i(game._coords_label.global_position) - Vector2i(260, 120), Vector2i(560, 220))
			img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(shots.path_join("hud_%s.png" % season))
	game.delete_save(game.save_path())
	print("PASS: hud clock shots")
	quit(0)
