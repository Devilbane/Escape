extends SceneTree
## A quick pose sheet of the water yoke on a bare Rogue (front, side, back, walking, full buckets), made
## without the village so it renders fast. Run with:
## SHOTS=<folder> xvfb-run -a godot -s tests/water_yoke_shots.gd (needs a display).

var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	root.size = Vector2i(900, 700)
	var model: Node3D = load("res://assets/characters/Rogue.glb").instantiate()
	root.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Walking_B", "Running_A"]:
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")
	await process_frame
	await process_frame
	var yoke := WaterYoke.attach(model, anim)
	var arms := YokeArms.attach(model.find_children("*", "Skeleton3D", true, false)[0], anim)
	arms.active = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	ground.material_override = mat
	root.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.make_current()
	var views := [["front_empty", 0.0, "Idle", false, 2.0], ["front_full", 0.0, "Idle", true, 2.0], ["side_full", 90.0, "Idle", true, 2.0],
			["back", 180.0, "Idle", true, 2.0], ["walk_a", 35.0, "Walking_A", true, 1.5], ["walk_b", 35.0, "Walking_A", true, 2.0],
			["run", 60.0, "Running_A", true, 2.4], ["top", 20.0, "Idle", true, 6.0]]
	for v in views:
		yoke.full = v[3]
		anim.play(v[2])
		anim.seek(0.0, true)
		await process_frame
		for i in 40 if v[2] != "Idle" else 10:
			await process_frame
		if v[0] == "walk_b":
			for i in 8:
				await process_frame
		var yaw := deg_to_rad(v[1])
		var d: float = v[4] * 1.6
		if v[0] == "top":
			cam.global_position = Vector3(sin(yaw) * 1.2, 4.0, cos(yaw) * 1.2)
			cam.look_at(Vector3(0, 1.0, 0))
		else:
			cam.global_position = Vector3(sin(yaw) * d, 1.2, cos(yaw) * d)
			cam.look_at(Vector3(0, 0.85, 0))
		await process_frame
		await process_frame
		if shots != "":
			root.get_texture().get_image().save_png(shots.path_join("sheet_%s.png" % v[0]))
	quit(0)
