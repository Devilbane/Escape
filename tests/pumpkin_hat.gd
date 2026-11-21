extends SceneTree
## Headless test for the children's pumpkins (see PumpkinHat): in autumn Pip and Pippi now and then
## wear a pumpkin on their heads (hung from the head bone, above the eyes, the locks tucked away), and
## take it off again; nobody else wears one, and out of autumn it stays off.
## Run with: godot --headless --fixed-fps 60 -s tests/pumpkin_hat.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
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
	var kids: Array[Villager] = []
	for v: Villager in lvl.villagers:
		if v.role in PumpkinHat.WEARERS:
			kids.append(v)
	check(kids.size() == 2, "Pip and Pippi live in the village")
	# Summer: no pumpkins, however long they play.
	_season_to(Weather.SPRING_DAYS + 2)
	game.day_hour = 12.0
	await _wait(3)
	for v in kids:
		v._mind_pumpkin(1000.0)
		check(not PumpkinHat.worn(v._model), "%s wears no pumpkin in summer" % v.role)
	# Autumn, by day: each child puts it on before long, and takes it off again later.
	_season_to(Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + 1)
	game.day_hour = 12.0
	await _wait(3)
	for v in kids:
		v.night = false
		var seen_on := false
		var seen_off := false
		var on_ticks := 0
		for s in 3000:
			v._mind_pumpkin(1.0)
			if PumpkinHat.worn(v._model):
				seen_on = true
				on_ticks += 1
			elif seen_on:
				seen_off = true
		check(seen_on and seen_off, "%s puts the pumpkin on and takes it off again in autumn" % v.role)
		check(on_ticks > 300 and on_ticks < 1800, "%s wears it only some of the time (%d of 3000 s)" % [v.role, on_ticks])
		# On again, to look at it.
		while not PumpkinHat.worn(v._model):
			v._mind_pumpkin(1.0)
		var hat := v.find_child(PumpkinHat.TAG, true, false) as MeshInstance3D
		check(hat != null and hat.get_parent() is BoneAttachment3D and (hat.get_parent() as BoneAttachment3D).bone_name == "head", "%s's pumpkin hangs from the head bone" % v.role)
		var head := v.find_child("Rogue_Head", true, false) as MeshInstance3D
		if hat and head:
			var box := hat.mesh.get_aabb()
			var skull := head.mesh.get_aabb()
			check(box.end.y > skull.end.y + 0.1, "the pumpkin sits on top of %s's head" % v.role)
			check(box.position.y > BodyLook.LIP_HEIGHT + 0.2, "the pumpkin stays above %s's eyes" % v.role)
		var slot := HairLook.head_slot(v._model)
		check(slot.get_meta("covered", false), "%s's locks are tucked under the pumpkin" % v.role)
		PumpkinHat.put_on(v._model)
		check(slot.find_children(PumpkinHat.TAG, "", false, false).size() == 1, "the pumpkin is put on only once")
	for v: Villager in lvl.villagers:
		if not v.role in PumpkinHat.WEARERS:
			v._mind_pumpkin(1000.0)
			check(not PumpkinHat.worn(v._model), "%s wears no pumpkin" % v.role)
	# Night, or the end of autumn: off it comes, and the hair is out again.
	for v in kids:
		v.night = true
		v._mind_pumpkin(1.0)
		check(not PumpkinHat.worn(v._model), "%s takes the pumpkin off at night" % v.role)
		check(not HairLook.head_slot(v._model).get_meta("covered", false), "%s's locks are out again" % v.role)
		v.night = false
	game.delete_save(game.save_path())
	print("PASS: pumpkin hat" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)

