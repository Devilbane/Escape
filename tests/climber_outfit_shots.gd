extends SceneTree
## Pictures of the climber's outfit (see ClimberOutfit): front, side and back, plain and with the hammer in the hand.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/climber_outfit_shots.gd

var frames := 0
var shots := OS.get_environment("SHOTS")
var model: Node3D


func _initialize() -> void:
	var info: Dictionary = Villager.ROLES[ClimberNpc.ROLE]
	model = load("res://assets/characters/%s.glb" % info.model).instantiate()
	root.add_child(model)
	Villager.dress_model(model, info)
	BodyLook.apply(model, info.get("sex", BodyLook.DEFAULT))
	var look := TownsfolkLook.look_for(ClimberNpc.ROLE, info)
	HairLook.apply(model, TownsfolkLook.hair_of(info, look))
	TownsfolkLook.apply(model, info, look)
	GearLook.dress_body(model, "outfit")
	ClimberOutfit.put_on(model)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.68, 0.76)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, 4.6)
	cam.fov = 36
	root.add_child(cam)
	root.size = Vector2i(560, 760)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _run() -> void:
	var views := [["front", 0.0, false], ["side", 90.0, false], ["back", 180.0, false], ["hammer", 0.0, true]]
	for v: Array in views:
		model.rotation_degrees.y = v[1]
		ClimberOutfit.hammer_in_hand(model, v[2])
		if v[2]:
			var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
			ClimbPose.apply(sk, ClimbPose.base_of(sk), RopeClimbPose.POSES["hammer_up"])
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/outfit_%s.png" % [shots, v[0]])
	quit()
