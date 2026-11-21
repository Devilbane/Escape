extends SceneTree
## Headless test for the winter clothes (see WinterWear): the village is dressed for winter in the
## night before it starts (nobody changes in the open), wears fur of several kinds and different
## headgear, takes it all off for spring, and talks about the first snow in the morning.
## Run with: godot --headless --fixed-fps 60 -s tests/winter_wear.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

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
	seed(5)
	# The herald and the clerk stand close together: their winter fur and hats differ.
	var herald := WinterWear.look_for("K", Villager.ROLES["K"])
	var clerk := WinterWear.look_for("¢", Villager.ROLES["¢"])
	check(herald.fur != clerk.fur and herald.hat != clerk.hat, "Herald Konrad and Clerk Gero wear different furs and hats")
	# The clerk holds his ledger, not a shield.
	var gero: Node3D = load("res://assets/characters/%s.glb" % Villager.ROLES["¢"].model).instantiate()
	Villager.dress_model(gero, Villager.ROLES["¢"])
	var ledger := gero.find_child("Ledger", true, false) as MeshInstance3D
	check(ledger != null and ledger.mesh != null, "Clerk Gero holds a book")
	for part: Node3D in gero.find_children("*Shield*", "Node3D", true, false):
		check(not part.visible, "Clerk Gero carries no shield")
	gero.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


## Moves the seasons so that it is season day `d` (see Seasons) and lets the game notice it.
func _season_to(d: int) -> void:
	game.season_shift += d - game.season_day()
	game._check_season()


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(4)
	for i in 600:
		if game.level.visible:
			break
		await _wait(1)
	var lvl: Outdoor = game.level
	# Summer: nobody wears anything.
	_season_to(Weather.SPRING_DAYS + 2)
	game.day_hour = 12.0
	await _wait(3)
	for v: Villager in lvl.villagers:
		check(not v.wears_winter, "%s wears no furs in summer" % v.role)
	# The last day before winter (the seasons follow the real calendar, see Seasons): still summer
	# clothes; when the calendar turns to winter, winter clothes for whoever is out of sight.
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS - 1)
	game.day_hour = 20.0
	await _wait(3)
	check(lvl.winter_wear == false, "no winter clothes before winter")
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS)
	await _wait(3)
	check(lvl.winter_wear == true, "the wardrobe turns to winter with the calendar")
	for v: Villager in lvl.villagers:
		if v.at_home or not v.visible:
			check(v.wears_winter, "%s changed while asleep" % v.role)
	# Everyone is dressed by the time the village wakes, and it looks different from person to person.
	for v: Villager in lvl.villagers:
		v.update_wear(true)
	var furs := {}
	var hats := {}
	for v: Villager in lvl.villagers:
		check(WinterWear.is_worn(v._model), "%s is in winter clothes" % v.role)
		var look := WinterWear.look_for(v.role, v._info)
		furs[look.fur] = true
		hats[look.hat] = true
		check(v._model.find_children("Winter_*", "BoneAttachment3D", true, false).size() >= 3, "%s wears fur, hem and scarf" % v.role)
		if look.hat != "":
			var hat := v._model.find_child("Hat", true, false) as MeshInstance3D
			check(hat != null and hat.mesh.get_aabb().end.y > 0.0, "%s wears a hat" % v.role)
		else:
			check(v._model.find_child("Hat", true, false) == null, "%s keeps their own hat" % v.role)
	check(furs.size() >= 4, "at least four kinds of fur: %d" % furs.size())
	check(hats.size() >= 3, "at least three kinds of headgear: %d" % hats.size())
	# Put on only once.
	var first: Villager = lvl.villagers[0]
	WinterWear.put_on(first._model, WinterWear.look_for(first.role, first._info))
	check(first._model.find_children("Hat", "", true, false).size() <= 1, "the hat is put on only once")
	# The calendar turns to winter: the first winter day brings the remarks.
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS - 1)
	lvl.season_talk = ""
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS)
	check(lvl.season_talk == "winter", "the first winter morning is marked")
	game.day_hour = 6.0
	await _wait(2)
	for v: Villager in lvl.villagers:
		v._plan_remark()
	var planned := lvl.villagers.filter(func(v: Villager): return v._remark_in >= 0.0)
	check(planned.size() > 0, "villagers plan a remark about the snow")
	planned[0]._remark_in = 0.0
	planned[0].at_home = false
	planned[0].visible = true
	planned[0]._season_remark(0.1)
	check(planned[0].is_talking(), "a villager talks about the snow")
	# Spring: everyone takes the furs off (the command is instant).
	game.day_hour = 12.0
	_season_to(Weather.YEAR_DAYS + 2)
	lvl.set_winter_wear(false, true)
	for v: Villager in lvl.villagers:
		check(not v.wears_winter and not WinterWear.is_worn(v._model), "%s took the furs off" % v.role)
		check(v._model.find_child("Hat", true, false) == null, "%s has no winter hat in spring" % v.role)
		for mi: MeshInstance3D in v._model.find_children("*_Body", "MeshInstance3D", true, false):
			check(not mi.has_meta("summer_look"), "%s has the summer coat back" % v.role)
	await _shots()
	game.delete_save(game.save_path())
	print("PASS: winter wear" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shots() -> void:
	if shots == "":
		return
	var lvl: Outdoor = game.level
	lvl.set_winter_wear(true, true)
	game.snow_cover = 1.0
	_season_to(Weather.YEAR_DAYS - 3)
	await _wait(120)
	var square := Vector3.ZERO
	var all := lvl.villagers.filter(func(v: Villager): return v.visible)
	for v: Villager in all:
		square += v.global_position / all.size()
	# A row of a few people in front of the camera for a close look.
	for v: Villager in all:
		v.set_physics_process(false)
	var i := 0
	var row := []
	for r in ["2", "5", "7", "9", "G", "6", "Z", "pippi"]:
		for v: Villager in all:
			if v.role == r:
				row.append(v)
	var spot: Vector3 = game.player.global_position
	for v: Villager in row:
		v.global_position = spot + Vector3(-5.0 + i * 1.4, 0, -3.0)
		v.rotation.y = 0.0
		v.reset_physics_interpolation()
		i += 1
	await _wait(10)
	await _shot("winter_row", spot + Vector3(-1.2, 1.4, -3.0), Vector3(0, 0.6, 7.5))
	for k in 3:
		if k < row.size():
			var v: Villager = row[k * 2]
			await _shot("winter_close_%d" % k, v.global_position + Vector3(0, 1.5, 0), Vector3(0.6, 0.5, 3.0))
	await _shot("winter_game_view", game.player.global_position, game.camera.global_position - game.player.global_position)


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3) -> void:
	var lvl: Level = game.level
	if lvl.fog:
		lvl.fog.visible = false
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = 45.0 if name.ends_with("close") else game.camera.fov
	root.add_child(cam)
	cam.global_position = at + from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
	if lvl.fog:
		lvl.fog.visible = true
	for layer in hidden:
		layer.visible = true
