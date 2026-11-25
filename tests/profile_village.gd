extends SceneTree
## Profiling helper (not a pass/fail test): times how long the village (the open map) takes to build.
## Run with: godot --headless -s tests/profile_village.gd

func _initialize() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var t := Time.get_ticks_msec()
	game.load_level(10)
	print("village load: %d ms" % (Time.get_ticks_msec() - t))
	game.delete_save(game.save_path())
	quit()
