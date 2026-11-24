extends SceneTree
## Pictures of the rock climber Wolfram on his face (see ClimberRoute): at the foot, pulling up, hammering a nail,
## at the top, and on the way down. Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/rock_climber_shots.gd

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
## The phase each picture waits for, and how far into it (0..1) the picture is taken.
const WANTED := [[ClimberRoute.Phase.WAIT, 0.1, "foot"], [ClimberRoute.Phase.PULL, 0.7, "pull"], [ClimberRoute.Phase.HAMMER, 0.55, "hammer"],
		[ClimberRoute.Phase.THREAD, 0.4, "thread"], [ClimberRoute.Phase.VIEW, 0.05, "view"], [ClimberRoute.Phase.DOWN, 0.5, "down"], [ClimberRoute.Phase.UNCLIP, 0.35, "unclip"]]


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
	var climber: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == ClimberNpc.ROLE:
			climber = v
	var spot := ClimbSpots.at(lvl, ClimberNpc.SPOT_CELL)
	var mid := lvl.cell_to_world(spot.cell)
	game.player.global_position = mid + Vector3(8, 0, 12)
	game.player.reset_physics_interpolation()
	var cam := Camera3D.new()
	cam.fov = 50
	lvl.add_child(cam)
	cam.make_current()
	var next := 0
	var guard := 0
	Engine.time_scale = 4.0
	while next < WANTED.size() and guard < 6000:
		await _wait(1)
		guard += 1
		game.player.hp = game.player.max_hp
		if climber._climb == null:
			continue
		var r: ClimberRoute = climber._climb
		var want: Array = WANTED[next]
		var u := r.u if r.phase != ClimberRoute.Phase.VIEW else r.u
		if r.phase == want[0] and u >= want[1]:
			Engine.time_scale = 0.02
			var at := climber.global_position
			cam.global_position = at + Vector3(2.6, 1.4, 5.0)
			cam.look_at(at + Vector3(0, 0.9, 0))
			await _wait(6)
			root.get_texture().get_image().save_png("%s/climber_%s.png" % [shots, want[2]])
			Engine.time_scale = 4.0
			next += 1
	quit()
