extends SceneTree
## Screenshots of the wandering merchant's living wagon and his raven (see MerchantWagon, MerchantRaven)
## on his night: from the way up to him, close on the hangings, the porch, the back with the lantern, and
## from above. Run with: SHOTS=<folder> godot -s tests/merchant_wagon_shots.gd (needs a display); without
## SHOTS it only puts him up.

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
	game.hero_name = "Pedlar"
	game.day = 1
	game.day_hour = 22.0
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.day = 1
	lvl.set_hour(22.0)
	if lvl.wanderer == null:
		print("FAIL: the merchant is not there")
		quit(1)
		return
	var cart := lvl.cell_to_world(lvl._wanderer_cell + Outdoor.CART_OFFSET)
	game.player.global_position = cart + Vector3(-9, 0, 11)
	await _wait(120)
	if shots != "":
		var views := {"wagon": [Vector3(1.0, 3.2, 8.5), Vector3(-0.8, 1.6, 0)],
			"wagon_close": [Vector3(-0.9, 2.0, 4.2), Vector3(-1.1, 1.6, 0.5)],
			"porch": [Vector3(-6.5, 2.4, 3.6), Vector3(-3.2, 1.5, 0)],
			"merchant": [Vector3(5.8, 2.6, 8.8), Vector3(1.2, 1.4, 2.6)],
			"raven": [Vector3.ZERO, Vector3.FORWARD],
			"raven_on_hat": [Vector3.ZERO, Vector3.FORWARD],
			"top": [Vector3(4.5, 9.0, 8.0), Vector3(-1, 1, 0.5)]}
		for name: String in views:
			var cam := Camera3D.new()
			cam.fov = 55.0
			root.add_child(cam)
			cam.global_position = cart + (views[name][0] as Vector3)
			cam.look_at(cart + (views[name][1] as Vector3))
			if name.begins_with("raven"):
				# Close on the raven, sat on the porch rail or on the merchant's hat.
				var raven: Node3D = game.level.find_child("MerchantRaven", true, false)
				raven.set("_spot", -1 if name == "raven_on_hat" else 1)
				raven.set("_flying", 0.0)
				raven.set("_sit", 60.0)
				await _wait(2)
				var at := raven.global_position
				cam.global_position = at + (Vector3(1.6, 0.7, 2.4) if name == "raven_on_hat" else Vector3(-0.3, 0.35, 1.3))
				cam.look_at(at + Vector3(0, 0.1, 0))
			cam.make_current()
			await _wait(8)
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
			cam.queue_free()
	game.delete_save(game.save_path())
	print("PASS: merchant wagon shots")
	quit(0)
