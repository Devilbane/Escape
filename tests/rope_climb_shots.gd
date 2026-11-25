extends SceneTree
## Pose sheet of the hero climbing on a rope (see RopeClimbPose): one screenshot per pose. Run with:
## SHOTS=<folder> xvfb-run -a godot -s tests/rope_climb_shots.gd (needs a display).

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
const ORDER := ["hang", "reach_l", "pull", "hammer_up", "hammer_hit", "thread", "fall", "kneel"]


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
	game.hero_name = "Rope"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	for e in lvl.enemies:
		if is_instance_valid(e):
			e.queue_free()
	lvl.enemies.clear()
	game.day_hour = 12.0
	lvl.set_hour(12.0)
	game.weather = Weather.CLEAR
	game.weather_hours = 9999.0
	var spot: Dictionary = ClimbSpots.SPOTS["Apfeltal"][0]
	var mid := lvl.cell_to_world(spot.cell)
	var start := Vector3(mid.x, 0.0, mid.z + Level.TILE * 0.5 + 0.6)
	hero.global_position = start
	hero.reset_physics_interpolation()
	await _wait(10)
	hero._start_rock(spot)
	await _wait(2)
	# Hold the climb still on one pose at a time, a little up the face.
	hero._rock_phase = Player.RockPhase.THREAD
	var cam := Camera3D.new()
	cam.fov = 34.0
	root.add_child(cam)
	cam.make_current()
	var n := 0
	for pose_name: String in ORDER:
		hero._rock_u = 0.0
		hero._rock_place(1.6)
		hero._rock_pose = RopeClimbPose.POSES[pose_name]
		hero._rock_phase = Player.RockPhase.TOP if false else Player.RockPhase.THREAD
		# Freeze the step: apply the pose directly each frame.
		for i in 6:
			await _wait(1)
			hero.global_position = hero._rock_start + Vector3(0, 1.6, 0) + Player.ROCK_DIR * (2.0 * 1.6 / 3.6)
			ClimbPose.apply(hero._skeleton, hero._pit_base, RopeClimbPose.POSES[pose_name])
			cam.global_position = hero.global_position + Vector3(4.5, 0.5, 0.3)
			cam.look_at(hero.global_position + Vector3(0, 0.55, -0.6))
		if shots != "":
			root.get_texture().get_image().save_png(shots.path_join("pose_%02d_%s.png" % [n, pose_name]))
		n += 1
	quit(0)
