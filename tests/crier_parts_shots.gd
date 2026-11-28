extends SceneTree
## Light screenshots of the crier's parts on a bare ground, without the village: podium, NEWS! sign, Konrad's hat and
## the loudhailer at his mouth. Run with: SHOTS=<folder> xvfb-run -a godot -s tests/crier_parts_shots.gd

var shots := OS.get_environment("SHOTS")
var cam: Camera3D
var frames := 0


func _initialize() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.36, 0.5, 0.25)
	ground.material_override = green
	root.add_child(ground)
	var world := Node3D.new()
	root.add_child(world)
	CrierPodium.build(world, Vector3.ZERO)
	var info: Dictionary = Villager.ROLES["K"]
	var model: Node3D = load("res://assets/characters/Knight.glb").instantiate()
	root.add_child(model)
	Villager.dress_model(model, info)
	CrierHat.put_on(model)
	model.position = Vector3(5.0, 0, 3.0)
	model.rotation.y = 0.5
	var stand: Node3D = load("res://assets/characters/Knight.glb").instantiate()
	root.add_child(stand)
	Villager.dress_model(stand, info)
	CrierHat.put_on(stand)
	stand.position = CrierPodium.STAND
	cam = Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.make_current()
	_run.call_deferred(model, stand)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	for i in 6:
		await process_frame
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("%s.png" % name))


func _run(model: Node3D, stand: Node3D) -> void:
	await process_frame
	var anim := stand.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.play("Idle")
	var other := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	other.play("Idle")
	await _shot("01_stage", Vector3(-3, 4.5, 10.0), Vector3(-0.8, 1.4, 0))
	await _shot("02_steps", Vector3(8.5, 3.0, 6.0), Vector3(0.5, 1.3, 0))
	await _shot("03_sign", Vector3(-8.5, 2.4, 4.5), Vector3(-3.3, 1.6, 0.5))
	await _shot("04_sign_close", Vector3(-3.3, 2.2, 3.4), Vector3(-3.3, 1.75, 0.5))
	await _shot("05_hat_front", model.position + Vector3(0, 2.3, 2.6), model.position + Vector3(0, 2.0, 0))
	await _shot("06_hat_side", model.position + Vector3(2.6, 2.6, 1.4), model.position + Vector3(0, 2.0, 0))
	await _shot("07_hat_back", model.position + Vector3(-1.8, 2.9, -2.4), model.position + Vector3(0, 2.0, 0))
	# The loudhailer at the mouth of the one on the podium.
	var hailer := Loudhailer.build()
	hailer.top_level = true
	root.add_child(hailer)
	var skeleton := stand.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head"))
	var facing := Vector3(sin(stand.global_rotation.y), 0, cos(stand.global_rotation.y))
	var mouth := head.origin + Vector3.UP * TownCrier.MOUTH_UP + facing * TownCrier.MOUTH_OUT
	hailer.global_transform = Transform3D(Basis.looking_at(-(facing + Vector3(0, 0.12, 0)), Vector3.UP), mouth)
	await _shot("08_hailer_side", stand.position + Vector3(2.4, 2.1, 0.8), stand.position + Vector3(0, 1.9, 0.3))
	await _shot("09_hailer_front", stand.position + Vector3(0.4, 2.1, 3.4), stand.position + Vector3(0, 1.9, 0))
	print("done")
	quit(0)
