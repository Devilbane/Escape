extends SceneTree
## Screenshots of the crop fields (see CropFields) in each season, on a plain meadow without the game.
## Run with: SHOTS=<folder> godot --rendering-driver opengl3 -s tests/crop_fields_shots.gd (needs a display).
## It always checks the planting itself: every kind gets plants, and each season changes their look.

var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	var failed := false
	var world := Node3D.new()
	root.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 60)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.28, 0.2, 0.13)
	ground.material_override = soil
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	world.add_child(env)
	var cells := {"≡": [], "‡": [], "☼": []}
	var letters := ["≡", "‡", "☼"]
	for i in 3:
		for x in 3:
			for z in 2:
				cells[letters[i]].append(Vector3(-14 + i * 14 + x * 4, 0, -2 + z * 4))
	var fields := CropFields.grow(world, cells, 4.0, 5)
	for letter: String in CropFields.LETTERS:
		var mm: MultiMesh = fields._fields[letter].mm
		if mm.instance_count < 90:
			print("FAIL: ", letter, " has only ", mm.instance_count, " plants")
			failed = true
	var cam := Camera3D.new()
	cam.fov = 50
	world.add_child(cam)
	cam.look_at_from_position(Vector3(2, 9, 20), Vector3(2, 0.8, 2))
	cam.make_current()
	var looks := {}
	var days := {"spring": 3, "summer": Weather.SPRING_DAYS + 2, "autumn": Weather.AUTUMN_FROM + 1, "winter": Weather.YEAR_DAYS - 1}
	for season: String in days:
		fields.set_season(days[season])
		if fields.season() != season:
			print("FAIL: day ", days[season], " should be ", season, " but is ", fields.season())
			failed = true
		looks[season] = fields.height_scale("≡")
		if shots != "":
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png(shots.path_join("crops_" + season + ".png"))
	if looks.summer <= looks.spring or looks.summer <= looks.autumn:
		print("FAIL: wheat should stand tallest in summer: ", looks)
		failed = true
	print("FAIL" if failed else "PASS: crop fields")
	quit(1 if failed else 0)
