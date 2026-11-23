extends SceneTree
## Pictures of every item lying on the floor (see GroundItem), laid out in rows on a stone slab, and a few
## piles of growing size. Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/ground_item_shots.gd

var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Lang.language = "en"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	root.add_child(sun)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.3, 0.28)
	floor_mesh.material_override = mat
	root.add_child(floor_mesh)
	var ids: Array = Items.ALL.keys()
	var per_row := 8
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var pages := int(ceil(ids.size() / float(per_row * 3)))
	var by := 0
	for page in pages:
		for child in root.get_children():
			if child.has_meta("gallery"):
				child.queue_free()
		for i in per_row * 3:
			var k := page * per_row * 3 + i
			if k >= ids.size():
				break
			var node := GroundItem.build(str(ids[k]))
			node.set_meta("gallery", true)
			node.position = Vector3((i % per_row) * 1.0 - per_row * 0.5, 0, floori(i / float(per_row)) * 1.3 - 1.3)
			root.add_child(node)
		cam.position = Vector3(0, 5.2, 3.6)
		cam.look_at(Vector3(0, 0, -0.3))
		await process_frame
		await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/gallery_%d.png" % [shots, page])
	for child in root.get_children():
		if child.has_meta("gallery"):
			child.queue_free()
	var piles := ["fackel", "wurfmesser", "heiltrank", "kupferring", "amulett_kraft", "apfel"]
	for r in piles.size():
		for n in [1, 2, 4, 8, 14]:
			for i in n:
				var node := GroundItem.build(str(piles[r]), i)
				node.set_meta("gallery", true)
				node.position = Vector3(n_col([1, 2, 4, 8, 14].find(n)), 0, r * 1.5 - 3.5)
				root.add_child(node)
	cam.position = Vector3(0, 6.5, 4.0)
	cam.look_at(Vector3(0, 0, -0.5))
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/piles.png" % shots)
	print("PASS")
	quit()


func n_col(c: int) -> float:
	return c * 2.2 - 4.4
