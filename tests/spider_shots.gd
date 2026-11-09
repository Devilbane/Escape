extends SceneTree
## Headless test: spiders, the Spider Queen and the Hollow Mother get a bristly coat.
## Run with: godot --headless --fixed-fps 60 -s tests/spider_shots.gd
## With SHOTS=<folder> and a display it also saves close screenshots of them there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(3)
	if shots != "":
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
	if shots != "":
		game._title.visible = false
	game.hero_name = "Spider test"
	await _wait(10)
	game.load_level(15, false)
	await _wait(15)
	var lvl: Level = game.level
	var cell: Vector2i = lvl.world_to_cell(game.player.global_position)
	var kinds := ["spinne", "spinnenkoenigin", "hohle_mutter"]
	var spiders: Array[Enemy] = []
	for i in kinds.size():
		var e: Enemy = lvl._spawn_enemy(kinds[i], cell)
		e.set_physics_process(false)
		e.set_process(false)
		e.global_position = game.player.global_position + Vector3(40.0 + i * 12.0, 0, 0)
		spiders.append(e)
	await _wait(10)
	for e in spiders:
		var found := false
		for mesh: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			for s in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(s) as ShaderMaterial
				if mat != null and mat.shader == GearLook.SHADER and int(mat.get_shader_parameter("stuff")) == GearLook.KINDS.get("bristle", 11):
					found = true
		check(found, "%s has a bristly coat" % e.kind)
	if shots != "":
		if lvl.fog:
			lvl.fog.visible = false
		for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		var cam := Camera3D.new()
		cam.fov = 40.0
		root.add_child(cam)
		cam.make_current()
		var light := DirectionalLight3D.new()
		root.add_child(light)
		light.rotation_degrees = Vector3(-50, 30, 0)
		var views := {"spider_close": [0, 2.6, 3.4], "spider_game": [0, 9.0, 11.0], "queen": [1, 6.0, 8.0]}
		for name: String in views:
			var v: Array = views[name]
			var at: Vector3 = spiders[int(v[0])].global_position
			cam.global_position = at + Vector3(float(v[2]) * 0.35, float(v[1]), float(v[2]))
			cam.look_at(at + Vector3(0, 0.4, 0))
			await _wait(10)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	game.delete_save(game.save_path())
	print("PASS: spider shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
