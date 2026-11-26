extends SceneTree
## Test of the owls (see Owls): they perch in the tall trees away from the village, are awake only from
## the evening to dawn, hoot (and one answers another), glide to another tree and back to a perch, doze by
## day and keep still when the hero is far. With SHOTS=<folder> and a display it also saves a close-up of an
## owl on its branch by night, mid-glide and asleep.
## Run with: godot --headless -s tests/owls.gd

var failures := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _trees() -> Array:
	var trees := []
	for i in 12:
		var p := Vector3((i % 4) * 24.0, 0.0, (i / 4) * 24.0)
		trees.append({"pos": p, "height": 7.0, "cell": Vector2i(i % 4 * 5, i / 4 * 5 + 1), "in_village": i == 11})
	# A short tree that gets no owl.
	trees.append({"pos": Vector3(90, 0, 0), "height": 2.0, "cell": Vector2i(1, 1), "in_village": false})
	return trees


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cell := func(c: Vector2i) -> Vector3: return Vector3(c.x * 4.0, 0.0, c.y * 4.0)
	var owls := Owls.new(_trees(), cell, 4.0, "test")
	root.add_child(owls)
	await process_frame
	check(owls.owls.size() >= 3 and owls.owls.size() <= Owls.MAX_OWLS, "a few owls (%d)" % owls.owls.size())
	for p in owls.perches:
		check(p.trunk.y >= Owls.MIN_TREE * Owls.PERCH_HEIGHT - 0.01, "perches are high in tall trees")
	check(Owls.awake_at(22.0) and Owls.awake_at(3.0) and Owls.awake_at(19.0), "awake in the evening and at night")
	check(not Owls.awake_at(12.0) and not Owls.awake_at(8.0), "asleep by day")
	var hero: Vector3 = (owls.owls[0].node as Node3D).global_position + Vector3(8, -5, 0)
	# By day: asleep, silent.
	var heard := [0]
	owls.hooted.connect(func(_i: int, _s: String): heard[0] += 1)
	for k in 400:
		owls.tick(0.25, hero, 12.0)
	check(heard[0] == 0, "no hoots by day")
	check(owls.owls[0].asleep, "dozing by day")
	# By night: hoots, answers, head turns.
	var yaw_seen := {}
	for k in 480:
		owls.tick(0.25, hero, 23.0)
		yaw_seen[snappedf(owls.owls[0].head_yaw, 0.3)] = true
	check(not owls.owls[0].asleep, "awake at night")
	check(heard[0] >= 4, "they hoot at night (%d)" % heard[0])
	check(yaw_seen.size() >= 4, "the head turns this way and that")
	# Gliding: every owl stays on a perch of its own, none on two.
	var perches_used := {}
	for o in owls.owls:
		perches_used[o.perch] = true
	check(perches_used.size() == owls.owls.size(), "no two owls on one perch")
	var flew := false
	var o0: Dictionary = owls.owls[0]
	o0.glide_t = 0.0
	for k in 40:
		owls.tick(0.25, hero, 23.0)
		flew = flew or o0.state == "glide"
	for k in 80:
		owls.tick(0.25, hero, 23.0)
	check(flew, "an owl glides to another tree")
	check(o0.state == "perch" and (o0.node as Node3D).global_position.distance_to(owls.perches[o0.perch].pos) < 0.05, "and lands on its perch")
	# Far away: nothing moves, nothing sounds.
	heard[0] = 0
	var yaw: float = o0.head_yaw
	for k in 400:
		owls.tick(0.25, Vector3(1000, 0, 1000), 23.0)
	check(heard[0] == 0 and o0.head_yaw == yaw, "far from the hero the owls keep still and quiet")
	for s in ["owl_hoot_0", "owl_hoot_1", "owl_hoot_2"]:
		check(ResourceLoader.exists("res://assets/sounds/" + s + ".wav"), s + " exists")
	print("owls: ", "OK" if failures == 0 else "FAILED")
	if shots == "":
		quit(1 if failures > 0 else 0)
		return
	_shots(owls)


func _shots(owls: Owls) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.05, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.55, 0.9)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, 25, 0)
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 0.9
	root.add_child(moon)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.45
	cm.height = 8.0
	trunk.mesh = cm
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = Owls.bark_texture()
	trunk.material_override = tm
	var o: Dictionary = owls.owls[0]
	var at: Vector3 = owls.perches[o.perch].trunk
	trunk.position = Vector3(at.x, 4.0, at.z)
	root.add_child(trunk)
	var cam := Camera3D.new()
	cam.fov = 35.0
	root.add_child(cam)
	var node: Node3D = o.node
	var views := [["perch", 23.0, 0], ["hoot", 23.0, 1], ["turned", 23.0, 2], ["glide", 23.0, 3], ["asleep", 12.0, 4]]
	for v in views:
		if v[2] == 1:
			o.puff_len = 2.9
			o.puff = 1.2
			o.state = "perch"
		if v[2] == 2:
			o.head_yaw = 1.5
			o.head_to = 1.5
			o.head_roll = 0.3
			o.roll_to = 0.3
		if v[2] == 3:
			o.state = "glide"
			o.wing_open = 1.0
			node.global_position += Vector3(2.0, -1.2, 0)
			node.rotation.y = 0.8
			owls._pose(o, 0.3)
		if v[2] == 4:
			o.state = "perch"
			o.asleep = true
			o.wing_open = 0.0
			o.puff = 0.0
			o.head_yaw = 0.0
			o.head_roll = 0.0
			o.node.global_position = owls.perches[o.perch].pos
			o.node.rotation.x = 0.0
		if v[2] != 3:
			owls._pose(o, 0.0)
		var look: Vector3 = node.global_position + Vector3(0, 0.3, 0)
		cam.global_position = look + Vector3(0.0, 0.25, 1.9).rotated(Vector3.UP, node.rotation.y + 0.5)
		cam.look_at(look)
		await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(shots.path_join("owl_%s.png" % v[0]))
	quit(1 if failures > 0 else 0)
