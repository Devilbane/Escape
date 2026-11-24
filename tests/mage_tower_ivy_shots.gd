extends SceneTree
## Screenshots of the mage tower's outside, ivy and snow on its walls and roof, in summer and winter.
## Run with: SHOTS=<folder> godot --fixed-fps 60 -s tests/mage_tower_ivy_shots.gd (needs a display).

## name: [camera offset from the tower's top room, look-at offset]
const VIEWS := {
	"front": [Vector3(0, 2.0, 17.0), Vector3(0, -1.5, 0)],
	"corner": [Vector3(-12.0, 5.0, 12.0), Vector3(0, -1.5, 0)],
}
## season: [day, snow on the ground]
const SEASONS := {
	"summer": [Weather.SPRING_DAYS + 2, 0.0],
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
		if OS.get_environment("SEASON") != "" and OS.get_environment("SEASON") != season:
			continue
		game.season_shift = int(SEASONS[season][0]) - Seasons.today()
		game.day_hour = 12.0
		game.snow_cover = SEASONS[season][1]
		game.set_weather(Weather.CLEAR, 100.0)
		game._weather_look = Weather.look(Weather.CLEAR)
		await _wait(10)
		var rec: Dictionary = lvl.walk_in.buildings.filter(func(r): return r.kind == "mage")[0]
		var tower: Node3D = rec.node
		var centre := tower.global_transform * Vector3(0, float(rec.layout.deck) + MageTower.TOP_H * 0.5, 0)
		var door: Vector3 = lvl.walk_in.door_points(rec)[0]
		for name: String in VIEWS:
			game.player.global_position = door + Vector3(0, 0, 7.0)
			game.player.reset_physics_interpolation()
			var cam := Camera3D.new()
			cam.fov = 50.0
			root.add_child(cam)
			cam.global_position = centre + (VIEWS[name][0] as Vector3)
			cam.look_at(centre + (VIEWS[name][1] as Vector3))
			cam.make_current()
			await _wait(80)
			await RenderingServer.frame_post_draw
			if shots != "":
				root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % [name, season]))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: mage tower ivy shots")
	quit(0)
