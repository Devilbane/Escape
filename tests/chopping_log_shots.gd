extends SceneTree
## Screenshots of the trunk the woodcutter chops at his spot (see Outdoor._build_chopping_log).
## Run with: SHOTS=<folder> godot -s tests/chopping_log_shots.gd (needs a display); without SHOTS it only builds the village.

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
	game.hero_name = "Cutter"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	var spot: Node3D = lvl.get_node_or_null("ChoppingLog")
	if spot == null:
		print("FAIL: no chopping log")
		quit(1)
		return
	var centre := spot.to_global(Villager.LOG_CENTRE)
	var yard := centre
	for s in lvl.stations:
		if s.kind == WoodLogs.KIND:
			yard = s.pos
			break
	game.player.global_position = centre + Vector3(-14, 0, 16)
	await _wait(240)
	if shots != "":
		var views := {"chop_close": [Vector3(-2.4, 1.6, 2.8), Vector3(0, 0.3, 0)], "chop_end": [Vector3(-3.4, 0.9, 0.4), Vector3(0, 0.3, 0)], "chop_wide": [Vector3(-4, 5, 7), Vector3(0, 0.5, 0)], "yard_close": [Vector3.ZERO, Vector3.FORWARD], "chop_top": [Vector3(0.3, 4, 0.3), Vector3(0, 0, 0)]}
		for name: String in views:
			var cam := Camera3D.new()
			cam.fov = 60.0
			root.add_child(cam)
			cam.global_position = centre + (views[name][0] as Vector3)
			cam.look_at(centre + (views[name][1] as Vector3))
			if name == "yard_close":
				cam.global_position = yard + Vector3(-2.4, 1.6, 2.8)
				cam.look_at(yard + Vector3(0, 0.3, 0))
			cam.make_current()
			await _wait(5)
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: chopping log shots")
	quit(0)
