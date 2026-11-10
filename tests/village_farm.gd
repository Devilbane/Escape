extends SceneTree
## Headless test for the village's animals (see VillageFarm and FarmAnimal):
## the geese, goats, sheep, cows, bull and dogs are out on the meadows, never stand on a front
## step or at a gate, geese and goats bolt from the hero (the flock together),
## a dog comes over to say hello, and Pip, who looks after the goats, has a
## spot beside them and lines about the animals with an English text.
## With SHOTS=<folder> and a display it also saves screenshots there.
## Run with: godot --headless --fixed-fps 60 -s tests/village_farm.gd

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


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: village_farm" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _kinds(lvl: Outdoor, kind: String) -> Array:
	return lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind == kind)


func _hero_to(lvl: Outdoor, p: Vector3) -> void:
	game.player.global_position = p
	game.player.velocity = Vector3.ZERO


## A look at `at` from `from` (relative), without the HUD or the fog of war.
func _shot(name: String, at: Vector3, from: Vector3) -> void:
	if shots == "":
		return
	var lvl: Level = game.level
	if lvl.fog:
		lvl.fog.visible = false
	var hidden := []
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	var cam := Camera3D.new()
	cam.fov = 40.0
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
	for layer: CanvasLayer in hidden:
		layer.visible = true


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait()
	var lvl: Outdoor = game.level
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	var geese := _kinds(lvl, "goose")
	var goats := _kinds(lvl, "goat")
	var dogs := _kinds(lvl, "dog")
	check(geese.size() == 6, "a flock of six geese (%d)" % geese.size())
	check(goats.size() == 4, "four goats (%d)" % goats.size())
	check(dogs.size() == 2, "two dogs (%d)" % dogs.size())
	check(_kinds(lvl, "sheep").size() == 4, "four sheep (%d)" % _kinds(lvl, "sheep").size())
	check(_kinds(lvl, "cow").size() == 2, "two cows (%d)" % _kinds(lvl, "cow").size())
	check(_kinds(lvl, "bull").size() == 1, "a bull (%d)" % _kinds(lvl, "bull").size())
	if geese.is_empty() or goats.is_empty() or dogs.is_empty():
		_finish()
		return
	# Hide the villagers' own bustle: the hero stays far away for now.
	var far: Vector3 = lvl.spots.square[0]
	_hero_to(lvl, far)
	# They wander about for a good while and never end up on a front step.
	var max_off := 0.0
	var moved := 0.0
	var starts := {}
	for a: FarmAnimal in lvl.farm_animals:
		starts[a] = a.global_position
	for i in 40:
		await _wait(60)
		for a: FarmAnimal in lvl.farm_animals:
			var c := lvl.world_to_cell(a.global_position)
			# Only a stopped animal counts: the path may cross a doorstep.
			if a.state in ["graze", "idle", "rest"]:
				check(FarmAnimal.may_stand(lvl, c) or a.state == "flee", "%s stands on a free tile %s (%s)" % [a.kind, c, lvl.cell_char(c)])
			max_off = maxf(max_off, a.global_position.distance_to(lvl.cell_to_world(a.home)))
	for a: FarmAnimal in lvl.farm_animals:
		moved = maxf(moved, a.global_position.distance_to(starts[a]))
	check(moved > 1.0, "they wander about (%.1f m)" % moved)
	check(max_off < 40.0, "they stay near home (%.1f m)" % max_off)

	# The hero walks up to the geese: the whole flock bolts.
	var g: FarmAnimal = geese[0]
	for a: FarmAnimal in geese:
		a._path.clear()
		a.global_position = g.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		a._begin("graze", 20.0)
	_hero_to(lvl, g.global_position + Vector3(3.0, 0, 0))
	await _wait(10)
	var fleeing := geese.filter(func(a: FarmAnimal): return a.is_fleeing()).size()
	check(fleeing >= 3, "the flock bolts together (%d of 6)" % fleeing)
	await _wait(120)
	var gap := (geese[0] as FarmAnimal).global_position.distance_to(game.player.global_position)
	check(gap > 3.0, "geese keep clear of the hero (%.1f m)" % gap)

	# A goat flees too, but a dog comes over.
	_hero_to(lvl, far)
	await _wait(240)
	var goat: FarmAnimal = goats[0]
	goat._begin("graze", 20.0)
	_hero_to(lvl, goat.global_position + Vector3(0, 0, 3.0))
	await _wait(10)
	check(goat.is_fleeing(), "a goat bolts from the hero")
	var dog: FarmAnimal = dogs[0]
	_hero_to(lvl, dog.global_position + Vector3(6.0, 0, 0))
	var before := dog.global_position.distance_to(game.player.global_position)
	await _wait(120)
	var after := dog.global_position.distance_to(game.player.global_position)
	check(dog.state == "greet" and after < before, "the dog trots over (%.1f m to %.1f m)" % [before, after])
	check(after >= FarmAnimal.GREET_GAP - 0.5, "it stops a few steps away (%.1f m)" % after)
	# Well out of its sight, wherever it stands (it may have been given room, see Footprint).
	_hero_to(lvl, dog.global_position + Vector3(FarmAnimal.GREET_LOSE * 3.0, 0, 0))
	await _wait(240)
	check(not dog.state == "greet", "it loses interest when the hero leaves")

	# Night: they lie down.
	lvl.set_hour(23.0)
	game.day_hour = 23.0
	_hero_to(lvl, far)
	await _wait(60 * 45)
	var resting := lvl.farm_animals.filter(func(a: FarmAnimal): return a.state == "rest").size()
	check(resting >= 12, "most of them settle down at night (%d of %d)" % [resting, lvl.farm_animals.size()])

	# Pip minds the goats.
	check(VillageFarm.pip_spot(lvl) != Vector3.INF, "Pip has a spot beside the goats")
	var pip: Villager = lvl.villagers.filter(func(v: Villager): return v.role == "7")[0]
	check(pip._info.get("herds", false), "Pip looks after the animals")
	var talks := (Villager.ROLES["7"].lines as Array).filter(func(l: String): return "Ziegen" in l or "Gänse" in l or "Hund" in l)
	check(talks.size() >= 3, "Pip talks about the animals")
	for line: String in Villager.ROLES["7"].lines:
		check(Lang.EN.has(line), "Pip's line has an English text: %s" % line)

	# Pictures of the daytime village.
	lvl.set_hour(13.0)
	game.day_hour = 13.0
	for a: FarmAnimal in lvl.farm_animals:
		a._wake()
	_hero_to(lvl, lvl.cell_to_world(Vector2i(46, 33)))
	await _wait(60)
	await _shot("geese", (geese[0] as FarmAnimal).global_position, Vector3(0.0, 4.0, 6.5))
	await _shot("goats", (goats[0] as FarmAnimal).global_position, Vector3(0.0, 4.0, 6.5))
	await _shot("dog", (dogs[0] as FarmAnimal).global_position, Vector3(0.0, 3.0, 5.0))
	var sheep := _kinds(lvl, "sheep")
	await _shot("sheep", (sheep[0] as FarmAnimal).global_position, Vector3(3.0, 1.6, 3.0))
	_finish()
