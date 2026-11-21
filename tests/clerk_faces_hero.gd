extends SceneTree
## Headless test: Clerk Gero at his post turns to face the hero who comes near, instead of keeping
## his back to the street (see Villager.FACES_HERO).
## Run with: godot --headless --fixed-fps 60 -s tests/clerk_faces_hero.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(4)
	for i in 600:
		if game.level.visible:
			break
		await _wait(1)
	game.day_hour = 11.0
	var lvl: Outdoor = game.level
	var gero: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "¢":
			gero = v
	check(gero != null, "Clerk Gero is in the village")
	if gero != null:
		# At his post, his back to where the hero will stand.
		gero.global_position = lvl.cell_to_world(gero.home)
		gero.reset_physics_interpolation()
		gero._start("work", 30.0)
		var hero: Node3D = lvl.player
		var towards := Vector3(0, 0, 4.0)
		gero.rotation.y = atan2(-towards.x, -towards.z)
		hero.global_position = gero.global_position + towards
		hero.reset_physics_interpolation()
		for i in 120:
			await physics_frame
			hero.global_position = gero.global_position + towards
		var facing := Vector3(sin(gero.rotation.y), 0, cos(gero.rotation.y))
		var to_hero := hero.global_position - gero.global_position
		to_hero.y = 0.0
		check(facing.angle_to(to_hero) < 0.35, "Clerk Gero turns his face to the hero (off by %.2f rad)" % facing.angle_to(to_hero))
	print("clerk faces hero test: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures else 0)
