extends SceneTree
## Pictures of the mountain's foot where the rock meets the ground tiles, in autumn and summer.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/mountain_foot_shots.gd

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


func _shot(lvl: Level, name: String, cell: Vector2i, from: Vector3, to: Vector3, fov := 55.0) -> void:
	var mid := lvl.cell_to_world(cell)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = mid + from
	cam.look_at(mid + to)
	cam.make_current()
	await _wait(10)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Foot"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	lvl.set_hour(12.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.player.visible = false
	var cells := [Vector2i(76, 54), Vector2i(97, 56)]
	var seasons := {"autumn": Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + 3}
	if OS.get_environment("SEASONS") == "all":
		seasons["summer"] = Weather.SPRING_DAYS + 3
		seasons["winter"] = Weather.YEAR_DAYS - 3
	var styles: Array = MountainFoot.STYLES
	if OS.get_environment("STYLES") != "":
		styles = OS.get_environment("STYLES").split(",")
	for sname: String in seasons:
		game.season_shift = int(seasons[sname]) - posmod(Seasons.today(), Weather.YEAR_DAYS)
		game.player.global_position = lvl.cell_to_world(Vector2i(84, 58))
		game.snow_cover = 1.0 if sname == "winter" else 0.0
		await _wait(200 if sname == "winter" else 120)
		for style: String in styles:
			MountainFoot.restyle(lvl as Outdoor, "" if style == "old" else style)
			await _wait(8)
			for i in cells.size():
				var c: Vector2i = cells[i]
				await _shot(lvl, "%s_%d_%s_top" % [sname, i, style if style != "" else "old"], c, Vector3(0, 9.0, 8.0), Vector3(0, 0, -1))
				await _shot(lvl, "%s_%d_%s_down" % [sname, i, style if style != "" else "old"], c, Vector3(0, 16.0, 6.0), Vector3(0, 0, 3.0), 50.0)
				await _shot(lvl, "%s_%d_%s_low" % [sname, i, style if style != "" else "old"], c, Vector3(0, 2.0, 9.0), Vector3(0, 1.0, 0))
	print("PASS: mountain foot shots")
	quit(0)
