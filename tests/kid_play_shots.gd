extends SceneTree
## Frames of the children's tricks (see KidPlay): Pip's cartwheel and somersault, one contact sheet each.
## Run with: SHOTS=<folder> godot -s tests/kid_play_shots.gd (needs a display); without SHOTS it only builds the village.

var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func _initialize() -> void:
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
	game._title.visible = false
	game.hero_name = "Tester"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	lvl.set_hour(12.0)
	var pip: Villager = lvl.villagers.filter(func(v: Villager): return v.role == "7")[0]
	var spot := lvl.cell_to_world(VillageFarm.pippi_home(lvl))
	game.player.global_position = spot + Vector3(-12, 0, 12)
	await _wait(60)
	pip.set_physics_process(false)
	pip.global_position = spot
	pip.rotation.y = 0.0
	pip.reset_physics_interpolation()
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.global_position = spot + Vector3(0, 1.6, -7.0)
	cam.look_at(spot + Vector3(0, 0.9, 0))
	cam.make_current()
	var steps := 8
	for kind: String in KidPlay.TRICKS:
		var info: Dictionary = KidPlay.TRICKS[kind]
		var dir := Vector3(1, 0, 0) if kind == "cartwheel" else Vector3(0, 0, 1)
		var sheet: Image = null
		for i in steps:
			var t := (i + 0.5) / steps
			var eased := t * t * (3.0 - 2.0 * t)
			pip.global_position = spot + dir * float(info.dist) * (eased - 0.5)
			pip.reset_physics_interpolation()
			if kind == "somersault":
				pip._anim.play("Cheer" if t < 0.1 or t > 0.92 else "Sit_Floor_Pose")
			else:
				pip._anim.play("Cheer" if t < 0.12 or t > 0.9 else "Jump_Idle")
			pip._anim.seek(0.4, true)
			var p := KidPlay.pose(kind, t, dir, 0.0, pip._model.scale.x)
			pip._model.basis = p.basis
			pip._model.position = p.position
			await _wait(4)
			if shots != "":
				var img := root.get_texture().get_image()
				if sheet == null:
					sheet = Image.create(img.get_width() * steps / 2, img.get_height() * 2, false, img.get_format())
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() * (i % (steps / 2)), img.get_height() * (i / (steps / 2))))
		if shots != "" and sheet != null:
			sheet.save_png(shots.path_join("kid_%s.png" % kind))
	game.delete_save(game.save_path())
	print("PASS: kid play shots")
	quit(0)
