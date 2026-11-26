extends SceneTree
## Screenshots of the sunflower riddle's field (see SunflowerRiddle) on a plain meadow without the game: straight
## down, as the game's camera sees it, and close up, in summer and autumn.
## Run with: SHOTS=<folder> xvfb-run godot --rendering-driver opengl3 -s tests/sunflower_riddle_shots.gd
## Nightly only: it needs a display.

var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.28, 0.2, 0.13)
	ground.material_override = soil
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -20, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.64, 0.7)
	world.add_child(env)
	# The field lies around the origin, as on the map: tiles are 4 m.
	var mids: Array = []
	var origin := SunflowerRiddle.centre()
	for c in SunflowerRiddle.cells():
		mids.append(Vector3(c.x * 4.0, 0, c.y * 4.0) - origin)
	var fields := CropFields.grow(world, {CropFields.RIDDLE: mids}, 4.0, 5, [Vector3.ZERO])
	var scarecrow := ScarecrowModel.build()
	world.add_child(scarecrow)
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.make_current()
	var views := {
		"top": [Vector3(0, 30, 0.01), Vector3(0, 0, 0)],
		"game": [Vector3(0, 19, 15), Vector3(0, 0, 0)],
		"close": [Vector3(0, 4.5, 10), Vector3(0, 1.8, 0)],
	}
	var days := {"summer": Weather.SPRING_DAYS + 2, "autumn": Weather.AUTUMN_FROM + 1}
	for season: String in days:
		fields.set_season(days[season])
		for view: String in views:
			cam.look_at_from_position(views[view][0], views[view][1], Vector3(0, 0, -1) if view == "top" else Vector3.UP)
			for i in 4:
				await process_frame
			if shots != "":
				root.get_texture().get_image().save_png(shots.path_join("riddle_%s_%s.png" % [view, season]))
	# The fireworks over the field.
	var show := SunflowerRiddle.new()
	world.add_child(show)
	cam.look_at_from_position(Vector3(0, 6, 22), Vector3(0, 6, 0))
	show.fireworks()
	for i in 240:
		await process_frame
		if shots != "" and i == 200:
			root.get_texture().get_image().save_png(shots.path_join("riddle_fireworks.png"))
	print("PASS: riddle shots")
	quit(0)
