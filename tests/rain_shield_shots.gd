extends SceneTree
## Screenshots of Elsbeth's rain shield (see RainShield): close up and from the side in the rain.
## Run with: SHOTS=<folder> godot -s tests/rain_shield_shots.gd (needs a display); without SHOTS it only builds the village.

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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


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
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	var elsbeth: Villager
	for v: Villager in lvl.villagers:
		if v.role == RainShield.ROLE:
			elsbeth = v
	print("elsbeth=", elsbeth, " outdoor=", lvl.name)
	elsbeth.at_home = false
	elsbeth.visible = true
	elsbeth._start("work", 1e6)
	elsbeth.threat = null
	game.village_talk._timer = 1e9
	var at := elsbeth.global_position
	game.player.global_position = at + Vector3(0, 0, 4)
	game.set_weather(Weather.RAIN, 5.0)
	game._set_atmosphere(true)
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.make_current()
	var views := {"close": [Vector3(2.4, 1.9, 3.4), 0.0], "side": [Vector3(4.0, 2.6, 0.5), 0.0]}
	for n in 110:
		await _wait(1)
		if shots != "" and n == 100:
			elsbeth.global_position = at
		if n % 20 == 0:
			print("n=", n, " pos=", elsbeth.global_position, " vis=", elsbeth.visible, " home=", elsbeth.at_home, " up=", elsbeth._rain_shield.up(), " amt=", elsbeth._rain_shield.amount(), " weather=", lvl.weather)
		var head := elsbeth.global_position + Vector3(0, 2.1, 0)
		cam.global_position = head + (views["close"][0] as Vector3)
		cam.look_at(head + Vector3(0, -0.2, 0))
		cam.make_current()
		if shots != "" and n in [30, 60, 95]:
			await _shot("cast_%03d" % n)
	print("up=", elsbeth._rain_shield.up(), " amount=", elsbeth._rain_shield.amount())
	if shots != "":
		var head := elsbeth.global_position + Vector3(0, 2.1, 0)
		cam.global_position = head + (views["side"][0] as Vector3)
		cam.look_at(head + Vector3(0, -0.3, 0))
		await _wait(5)
		await _shot("side")
		game.set_weather(Weather.CLEAR, 5.0)
		await _wait(40)
		await _shot("fading")
	game.delete_save(game.save_path())
	print("PASS: rain shield shots")
	quit(0)
