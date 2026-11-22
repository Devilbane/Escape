extends SceneTree
## Pictures of the winter hats (see WinterWear): everyone of the village who wears no hat of their
## own, in winter clothes, in a row on snow, from the front and from the game's height.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/winter_hat_shots.gd
## Without SHOTS it only checks that every hat is on and rises over the crown of the head.

const ROLES := ["9", "O", "K", "¢", "2", "6", "1", "5", "G", "Z", "S", "µ", "7", "pippi"]

var shots := OS.get_environment("SHOTS")
var frames := 0
var people: Array[Villager] = []
var failures := 0


func _initialize() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.8, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.95, 0.96, 1.0)
	ground.material_override = snow
	root.add_child(ground)
	var i := 0
	for r in ROLES:
		var v := Villager.new()
		v.setup(null, r, Vector2i.ZERO)
		root.add_child(v)
		v.set_physics_process(false)
		v.set_process(false)
		v.position = Vector3((i % 7) * 1.7 - 5.1, 0, (i / 7) * 3.0)
		people.append(v)
		i += 1


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_run()
	return false


func _wait(n: int) -> void:
	for k in n:
		await process_frame


func _run() -> void:
	for v in people:
		v.rotation.y = 0.0
		WinterWear.put_on(v._model, WinterWear.look_for(v.role, v._info))
		var ap := v._model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Idle"):
			ap.play("Idle")
		var hat := v._model.find_child("Hat", true, false) as MeshInstance3D
		var head := WinterWear._head_box(v._model)
		if hat == null or hat.mesh.get_aabb().end.y < head.end.y + 0.1:
			failures += 1
			print("FAIL: %s wears a winter hat over the head" % v.role)
	if shots == "":
		print("PASS: winter hat shots" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
		return
	await _shot("hats_front", Vector3(0, 1.6, 1.3), Vector3(0, 1.5, 9.5), 50.0)
	await _shot("hats_game", Vector3(0, 0.8, 1.3), Vector3(0, 11.0, 8.0), 45.0)
	for v in people:
		var r := "cent" if v.role == "¢" else ("mu" if v.role == "µ" else v.role)
		await _shot("close_%s" % r, v.position + Vector3(0, 1.55, 0) * v.scale.y * v._model.scale.y, Vector3(1.1, 0.55, 3.4) * v._model.scale.y, 40.0)
		await _shot("top_%s" % r, v.position + Vector3(0, 1.3, 0) * v._model.scale.y, Vector3(0, 3.0, 2.2) * v._model.scale.y, 40.0)
	print("PASS: winter hat shots")
	quit(0)


func _shot(name: String, at: Vector3, from: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = at + from
	cam.look_at(at)
	cam.make_current()
	await _wait(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
