extends SceneTree
## Pictures of the apiary (see Apiary, HiveModels, BeeVeil): the hives close and from afar in summer, in spring and in
## winter, the bees in flight, the beekeeper with his veil, and the vexed hive.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/bees_shots.gd

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
	Storage.use(Storage.Memory.new())
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


## Lets the bees fly for `seconds` without drawing frames: the apiary's own tick, the hero beside it.
func _fly(api: Apiary, seconds: float, hero_here := false) -> void:
	var hero: Vector3 = game.player.global_position
	var t := 0.0
	while t < seconds:
		api.tick(1.0 / 30.0, hero, 11.0, false, game.level.season_day, "clear")
		t += 1.0 / 30.0


func _season(season: String) -> void:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			if "season_shift" in game:
				game.season_shift += d + 2 - game.level.season_day
			else:
				game.day = d + 2
			break
	game.day_hour = 11.0
	await _wait(3)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Bee shots"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Outdoor = game.level
	var api: Apiary = level.apiary
	check(api != null, "the apiary stands")
	var keeper: Villager = null
	for v: Villager in level.villagers:
		if v.role == Beekeeper.ROLE:
			keeper = v
	var mid: Vector3 = api.hives[0].pos.lerp(api.hives[api.hives.size() - 1].pos, 0.5)
	game.player.global_position = mid + Vector3(0, 0, 9)
	await _season(Weather.SUMMER)
	_fly(api, 60.0)
	await _shot("hives_wide_summer", mid + Vector3(9, 8, 15), mid)
	var skep: Dictionary = api.hives.filter(func(h: Dictionary) -> bool: return h.skep)[0]
	var box: Dictionary = api.hives.filter(func(h: Dictionary) -> bool: return not h.skep)[0]
	await _shot("skep_close", skep.pos + Vector3(1.6, 1.3, 2.6), skep.pos + Vector3(0, 0.7, 0))
	await _shot("box_hive_close", box.pos + Vector3(-1.7, 1.3, 2.6), box.pos + Vector3(0, 0.6, 0))
	await _shot("bees_close", skep.gate + Vector3(0.6, 0.5, 1.6), skep.gate)
	if keeper != null:
		var k := keeper.global_position
		await _shot("beekeeper_close", k + Vector3(0.9, 2.6, 2.4), k + Vector3(0, 1.6, 0))
		await _shot("beekeeper_front", k + Vector3(0.0, 1.9, 3.2), k + Vector3(0, 1.5, 0))
	await _season(Weather.SPRING)
	_fly(api, 30.0)
	await _shot("hives_wide_spring", mid + Vector3(9, 8, 15), mid)
	await _season(Weather.WINTER)
	await _shot("hives_wide_winter", mid + Vector3(9, 8, 15), mid)
	await _season(Weather.SUMMER)
	game.player.global_position = box.pos + Vector3(0, 0, 3.0)
	api.vex(api.hives.find(box))
	_fly(api, 1.5, true)
	await _shot("vexed_hive", game.player.global_position + Vector3(1.5, 3.0, 5.0), game.player.global_position + Vector3(0, 1.2, 0))
	print("PASS: bees shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "" or (OS.get_environment("ONLY") != "" and not name in OS.get_environment("ONLY").split(",")):
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
