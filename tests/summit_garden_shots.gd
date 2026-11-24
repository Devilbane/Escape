extends SceneTree
## Pictures of the secret garden on the mountain (see SummitGarden): the whole ledge, a silver edelweiss close up,
## the tablet and the spring. Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/summit_garden_shots.gd

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
	game.hero_name = "Shots"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var lvl: Outdoor = game.level
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	game.player.global_position = SummitGarden.middle(lvl) + Vector3(0, 0.05, 1.8)
	game.player.reset_physics_interpolation()
	game.player.visible = false
	var cam := Camera3D.new()
	cam.fov = 50
	lvl.add_child(cam)
	cam.make_current()
	await _wait(20)
	var mid := SummitGarden.middle(lvl)
	var views := {
		"ledge": [Vector3(0, 4.2, 6.2), Vector3(0, 0.3, -0.6)],
		"plant": [Vector3(-0.6, 0.8, 1.9) + Vector3(SummitGarden.PLANTS[1].x, 0, SummitGarden.PLANTS[1].y), Vector3(SummitGarden.PLANTS[1].x, 0.3, SummitGarden.PLANTS[1].y)],
		"tablet": [Vector3(SummitGarden.TABLET_AT.x + 0.4, 1.3, SummitGarden.TABLET_AT.y + 2.6), Vector3(SummitGarden.TABLET_AT.x, 0.9, SummitGarden.TABLET_AT.y)],
		"spring": [Vector3(SummitGarden.SPRING_AT.x - 0.3, 1.5, SummitGarden.SPRING_AT.y + 2.3), Vector3(SummitGarden.SPRING_AT.x, 0.3, SummitGarden.SPRING_AT.y)],
	}
	for name: String in views:
		cam.global_position = mid + views[name][0]
		cam.look_at(mid + views[name][1])
		await _wait(8)
		root.get_texture().get_image().save_png("%s/garden_%s.png" % [shots, name])
	quit()
