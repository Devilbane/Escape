extends SceneTree
## Screenshots of the village's ivy through the seasons (IvySeasons): summer, autumn, winter.
## Run with: SHOTS=<folder> godot -s tests/ivy_seasons_shots.gd (needs a display); without SHOTS it only builds the village.

## name: [map letter of the door, camera offset from the front, look-at offset from the front]
const TARGETS := {
	"guild": ["w", Vector3(0, 6.0, 10), Vector3(0, 3.5, -3)],
	"house": ["h", Vector3(0, 5.0, 8), Vector3(0, 3.0, -3)],
}
## season: [day, snow on the ground]
const SEASONS := {
	"summer": [Weather.SPRING_DAYS + 2, 0.0],
	"autumn": [Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + IvySeasons.TURN_DAYS - 1, 0.0],
	"winter": [Weather.YEAR_DAYS - Weather.WINTER_DAYS + 1, 1.0],
}

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
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for season: String in SEASONS:
		game.season_shift = int(SEASONS[season][0]) - Seasons.today()
		game.day_hour = 12.0
		game.snow_cover = SEASONS[season][1]
		game.set_weather(Weather.CLEAR, 100.0)
		game._weather_look = Weather.look(Weather.CLEAR)
		await _wait(10)
		for name: String in TARGETS:
			var key: String = TARGETS[name][0]
			if shots == "" or not lvl.doors.has(key):
				continue
			var front: Vector3 = lvl.doors[key]
			game.player.global_position = front + Vector3(0, 0, 3)
			var cam := Camera3D.new()
			cam.fov = 55.0
			root.add_child(cam)
			cam.global_position = front + (TARGETS[name][1] as Vector3)
			cam.look_at(front + (TARGETS[name][2] as Vector3))
			cam.make_current()
			await _wait(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % [name, season]))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: ivy seasons shots")
	quit(0)
