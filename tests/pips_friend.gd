extends SceneTree
## Headless test for Pippi, Pip's friend (see Villager.ROLES["pippi"], VillageFarm):
## a little red-haired girl with pigtails and freckles who stands beside Pip in
## the village, minds the geese and goats with him on tiles where no door or
## way is blocked, plays and chats with him, and has English texts.
## Run with: godot --headless --fixed-fps 60 -s tests/pips_friend.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait()
	var lvl: Outdoor = game.level
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	var pip: Villager = null
	var pippi: Villager = null
	for v: Villager in lvl.villagers:
		if v.role == "7":
			pip = v
		elif v.role == "pippi":
			pippi = v
	check(pip != null and pippi != null, "Pip and Pippi are both in the village")
	if pip == null or pippi == null:
		_finish()
		return
	check(lvl.villagers.filter(func(v: Villager): return v.role == "pippi").size() == 1, "there is exactly one Pippi")

	# Her look: pigtails, ginger hair, freckles, a child's size.
	var info: Dictionary = Villager.ROLES["pippi"]
	check(info.hair.tails and info.hair.freckles and info.hair.color == "ginger", "she has pigtails, red hair and freckles")
	check(HairLook.COLORS.has("ginger") and float(info.scale) < 0.9, "ginger hair exists and she is a child")
	var tails := pippi._model.find_child("Tails", true, false) as MeshInstance3D
	check(tails != null and tails.visible, "her pigtails hang from her head")
	check(tails != null and tails.mesh.get_faces().size() > 0, "the pigtails have a shape")
	var head := pippi._model.find_child("Rogue_Head", true, false) as MeshInstance3D
	check((head.material_override as ShaderMaterial).get_shader_parameter("freckles") == true, "her face is freckled")
	var plain := pip._model.find_child("Tails", true, false) as MeshInstance3D
	check(plain == null or not plain.visible, "Pip has no pigtails")

	# Where she minds the animals: tiles no door or way is blocked at.
	check(VillageFarm.pippi_home(lvl) != Vector2i(-1, -1), "she has a place beside Pip")
	check(lvl.world_to_cell(pippi.global_position) != Vector2i(-1, -1) and pippi.home == VillageFarm.pippi_home(lvl), "she starts there")
	check(FarmAnimal.may_stand(lvl, pippi.home), "her starting tile blocks no door or way")
	var spots := {}
	for i in 40:
		var spot := VillageFarm.herd_spot(lvl, "pippi", i / 40.0)
		check(spot != Vector3.INF, "Pippi has a herding spot (roll %d)" % i)
		if spot != Vector3.INF:
			check(FarmAnimal.may_stand(lvl, lvl.world_to_cell(spot)), "her herding spot blocks no door or way")
			spots[lvl.world_to_cell(spot)] = true
	check(spots.size() == 2, "she minds both the geese and the goats (%d spots)" % spots.size())
	check(VillageFarm.herd_spot(lvl, "7", 0.9) == VillageFarm.pip_spot(lvl), "Pip still minds the goats")

	# They share the herds, play together and keep clear of paths.
	check(info.herds and info.pal == "7" and Villager.ROLES["7"].pal == "pippi", "the two are pals who herd")
	_hero_to(lvl, lvl.spots.square[0])
	var near_pip := 0
	var near_geese := 0
	var near_goats := 0
	var blocked := 0
	var geese := lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind == "goose")
	var goats := lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind in VillageFarm.GOATS)
	for step in 240:
		await _wait(60)
		if pippi._task == "home":
			continue
		if _flat(pippi.global_position, pip.global_position) < 4.0:
			near_pip += 1
		for a: FarmAnimal in geese:
			if _flat(pippi.global_position, a.global_position) < 7.0:
				near_geese += 1
				break
		for a: FarmAnimal in goats:
			if _flat(pippi.global_position, a.global_position) < 7.0:
				near_goats += 1
				break
		var c := lvl.world_to_cell(pippi.global_position)
		if Outdoor.BLOCK_CHARS.contains(lvl.cell_char(c)) or lvl.cell_char(c) == "\\":
			blocked += 1
	check(near_pip >= 5, "she spends time with Pip (%d of 240 checks)" % near_pip)
	check(near_goats >= 10, "she is at the goats (%d)" % near_goats)
	check(near_geese >= 5, "she is at the geese (%d)" % near_geese)
	check(blocked == 0, "she never stands in a doorway or a gate (%d)" % blocked)

	# Chats: a tie with Pip, her goal, her lines and the English texts.
	var tie := VillageTalk.tie_between("7", "pippi")
	check(not tie.is_empty() and game.village_talk.bond("7", "pippi") == "close", "Pip and Pippi are friends")
	check(tie.talks.size() >= 3, "they have things to say to each other")
	_hero_to(lvl, pip.global_position + Vector3(6, 0, 0))
	pip._start("idle", 30.0)
	pippi._start("idle", 30.0)
	check(game.village_talk.start_chat(lvl, VillageTalk.key_of(tie)), "they start a chat")
	check(VillageTalk.GOALS.has("pippi"), "Pippi wants something")
	var texts: Array = [VillageTalk.GOALS["pippi"], info.name] + info.lines + Villager.ROLES["7"].lines
	for lines in tie.talks:
		texts += lines
	for line: String in texts:
		check(Lang.EN.has(line), "English text: %s" % line)
	check(Villager.ROLES["7"].lines.any(func(l: String): return "Pippi" in l), "Pip mentions her")
	check(info.lines.any(func(l: String): return "Gänse" in l or "Ziegen" in l), "Pippi talks about the animals")

	# Night: she goes home like the other children.
	lvl.set_hour(23.0)
	game.day_hour = 23.0
	await _wait(60 * 40)
	check(pippi.at_home, "she goes to bed at night")
	_finish()


func _hero_to(lvl: Outdoor, at: Vector3) -> void:
	game.player.global_position = at
	game.player.reset_physics_interpolation()


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: pips_friend" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
