extends SceneTree
## Pictures of going to bed and waking up (see BedRise, BedBlanket): the hero hops onto a cosy bed, sits on its
## rim, lies back and pulls the blanket up; later the blanket is pushed off, one leg and then the other swings
## out, the hero sits on the rim, stretches, yawns and slides down. Frames at 12 per second go to SHOTS.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/bed_rise_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var side := float(OS.get_environment("SIDE") if OS.get_environment("SIDE") != "" else "-1")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
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
	game.hero_name = "Bed shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Level = game.level
	# A little stage far from the village: a lawn and a sun.
	var spot := Vector3(900, 0, 900)
	var lawn := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	lawn.mesh = plane
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.42, 0.6, 0.3)
	lawn.material_override = green
	level.add_child(lawn)
	lawn.global_position = spot + Vector3(0, -0.01, 0)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.35
	sun.shadow_enabled = false
	level.add_child(sun)
	sun.global_position = spot + Vector3(0, 8, 0)
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	game.day_hour = 12.0
	var at := spot
	var rot := 0.0
	var bed := CosyBed.build(level, at, rot)
	var hero: Player = game.player
	hero.frozen = true
	hero.path.clear()
	var sk: Skeleton3D = hero._model.find_child("Skeleton3D", true, false)
	hero._anim.play("Idle")
	hero._anim.seek(0.0, true)
	hero._anim.pause()
	var base := ClimbPose.base_of(sk)
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 42.0
	root.add_child(cam)
	cam.global_position = at + Vector3(side * 3.2, 2.5, 3.9)
	cam.look_at(at + Vector3(-0.45, 1.05, 0.1))
	cam.make_current()
	hero._model.rotation = Vector3.ZERO
	var n := 0
	for part in ["tuck", "rise"]:
		var keys: Array = BedRise.TUCK_KEYS if part == "tuck" else BedRise.RISE_KEYS
		var total := BedRise.length(keys) + 1.4
		var t := 0.0
		var blanket_done := false
		if part == "rise":
			BedBlanket.tuck(level, at, rot, true)
		else:
			BedBlanket.of(level, at, rot)
		var f := 0
		while t <= total:
			var state := BedRise.at(keys, t, side)
			hero.global_position = BedRise.pose(hero._model, sk, base, state, at, rot, side)
			hero.reset_physics_interpolation()
			hero.set_asleep(bool(state.shut))
			BedRise.yawn(hero._model, float(state.yawn))
			BedRise.arm(hero._model, part == "rise" and t >= 7.9)
			if part == "tuck" and t >= BedRise.BLANKET_ON_AT and not blanket_done:
				blanket_done = true
				BedBlanket.tuck(level, at, rot)
			if part == "rise" and t >= BedRise.BLANKET_OFF_AT and not blanket_done:
				blanket_done = true
				BedBlanket.push_off(level, at, rot)
			await process_frame
			t += 1.0 / 60.0
			f += 1
			if f % 5 == 0 and shots != "":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(shots.path_join("%s_%03d.png" % [part, n]))
				n += 1
	BedRise.arm(hero._model, true)
	print("PASS: bed rise shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
