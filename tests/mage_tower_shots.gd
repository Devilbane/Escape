extends SceneTree
## Screenshots of the mage tower from the game's own camera: from outside by day and by night, and
## with the hero on each floor and in the cellar.
## Run with: SHOTS=<folder> godot --fixed-fps 60 -s tests/mage_tower_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	WalkIn.lock_halls = false
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
	await _wait(45)
	await RenderingServer.frame_post_draw
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("shot ", name)


func _stand(hall: Node3D, local: Vector3) -> void:
	game.player.global_position = hall.global_transform * local
	game.player.reset_physics_interpolation()


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
	var hour := float(OS.get_environment("HOUR")) if OS.get_environment("HOUR") != "" else 12.0
	game.day_hour = hour
	if OS.get_environment("SEASON") == "autumn":
		for day in 400:
			if Weather.is_autumn(day):
				lvl.set_season(day)
				break
	game._set_atmosphere(true)
	lvl.set_hour(hour)
	var rec: Dictionary = lvl.walk_in.buildings.filter(func(r): return r.kind == "mage")[0]
	var hall: Node3D = rec.node
	var lay: Dictionary = rec.layout
	var way := lvl.walk_in.door_points(rec)
	game.player.global_position = way[0] + Vector3(0, 0, 3.0)
	game.player.reset_physics_interpolation()
	await _shot("1_outside_front")
	_stand(hall, Vector3(0, lay.floor, 1.5))
	await _shot("2_entrance_hall")
	_stand(hall, Vector3(0.3, lay.up_floor, 0.9))
	await _shot("3_library")
	_stand(hall, Vector3(0.3, lay.deck, 1.0))
	await _shot("4_sleeping_room")
	_stand(hall, Vector3(0.0, lay.deck, 0.2))
	await _shot("4b_top_middle")
	_stand(hall, Vector3(-2.0, lay.deck, -1.5))
	await _shot("4c_top_back")
	_stand(hall, Vector3(1.0, GuildHall.CELLAR, 1.0))
	await _shot("5_experiment_room")
	if OS.get_environment("SLEEPERS") != "":
		# Aldo and Odo asleep upstairs, the hero on the ground floor and then in the sleeping room.
		for role: String in MageTower.OWNERS:
			for v: Villager in lvl.villagers:
				if v.role == role:
					VillagePosts.leave_at_once(v)
					v.global_position = way[0]
					VillageBeds.enter(v, true)
		await _wait(20)
		_stand(hall, Vector3(0, lay.floor, 1.5))
		await _wait(20)
		await _shot("6_sleepers_from_ground_floor")
		_stand(hall, Vector3(0.3, lay.deck, 1.0))
		await _wait(20)
		await _shot("7_sleepers_from_sleeping_room")
	game.delete_save(game.save_path())
	print("PASS: mage tower shots")
	quit(0)
