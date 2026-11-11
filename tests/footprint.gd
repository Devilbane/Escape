extends SceneTree
## Headless test: every creature claims its own place (see Footprint). Radii come from the
## templates, and when two stand inside each other the newest is moved to the nearest open,
## reachable spot, never into a wall, and never the hero.
## Run with: godot --headless -s tests/footprint.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	game.load_level(game._outdoor_index(), false)
	_run()
	if failures == 0:
		print("PASS: footprint")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _run() -> void:
	var level: Outdoor = game.level
	check(level is Outdoor, "the village is loaded")
	# Templates give their own radius: a cow takes more room than a goose, a big monster more than a small one.
	check(Footprint.FARM.cow > Footprint.FARM.goose, "a cow is wider than a goose")
	for kind in FarmAnimal.KINDS:
		check(Footprint.FARM.has(kind), "farm kind %s has a footprint" % kind)
	for kind in Animal.KINDS:
		check(Footprint.WILD.has(kind), "wild kind %s has a footprint" % kind)
	var v: Villager = level.villagers[0]
	var w: Villager = level.villagers[1]
	check(Footprint.radius_of(v) > 0.0, "a villager has a radius")
	game.player.global_position = v.global_position + Vector3(40, 0, 40)
	# A newer villager put right on an older one is moved off, to open ground.
	v.set_meta("fp_born", 1)
	w.set_meta("fp_born", 2)
	var v_at := v.global_position
	w.global_position = v.global_position
	check(Footprint.stacked(v, w), "the two start stacked")
	Footprint.resolve(level)
	check(v.global_position.distance_to(v_at) < 0.01, "the older one stays where it was")
	check(not Footprint.stacked(v, w), "the newer one is no longer inside it")
	check(Footprint.open_at(level, w.global_position), "the newer one stands on open ground")
	check(w.global_position.distance_to(v_at) < Level.TILE * 3.0, "and not far away")
	check(not level.grid_path(level.world_to_cell(v_at), level.world_to_cell(w.global_position)).is_empty(), "and it can be reached")
	# Nobody stands in the hero's place; the hero is never moved.
	var hero: Player = game.player
	hero.set_meta("fp_born", 99999)
	var hero_at := hero.global_position
	v.global_position = hero_at
	Footprint.resolve(level)
	check(hero.global_position.distance_to(hero_at) < 0.01, "the hero is not moved")
	check(not Footprint.stacked(hero, v), "the villager steps out of the hero's place")
	# A monster dropped onto a villager makes way when it is the newer one.
	var e := Enemy.new()
	e.kind = "wolf" if Enemy.KINDS.has("wolf") else Enemy.KINDS.keys()[0]
	e.level = level
	level.add_child(e)
	e.global_position = w.global_position
	e.set_meta("fp_born", 100000)
	Footprint.resolve(level)
	check(not Footprint.stacked(e, w), "a monster put on a villager is moved off")
	e.queue_free()
	# Peaceful animals have no hitbox and claim no place; only the red-horned goat does.
	var squirrel := Squirrel.new()
	check(Footprint.peaceful(squirrel), "a squirrel is peaceful")
	squirrel.free()
	var animals: Array = level.animals + level.farm_animals
	var kinds := {}
	for a in animals:
		kinds[a.kind] = a
	check(kinds.size() > 0, "animals live in the village")
	var anchor: Villager = level.villagers[0]
	anchor.set_meta("fp_born", 1)
	for kind in kinds:
		var a: Node3D = kinds[kind]
		check(a.is_in_group(Footprint.GROUP), "%s is in the footprint pass" % kind)
		check(Footprint.peaceful(a) == (kind != "billy"), "%s is peaceful unless it is the red-horned goat" % kind)
		a.set_meta("fp_born", 5000)
		a.visible = true
		var home_at := a.global_position
		a.global_position = anchor.global_position
		Footprint.resolve(level)
		if Footprint.peaceful(a):
			check(a.global_position.distance_to(anchor.global_position) < 0.01, "%s is left where it stands, a villager may stand on it" % kind)
		else:
			check(not Footprint.stacked(anchor, a), "%s claims its place: put on a villager, it is moved off" % kind)
		a.global_position = home_at
	# Peaceful animals ease away from each other instead of piling up.
	var herd: Array = []
	for a in animals:
		if Footprint.peaceful(a) and a is FarmAnimal:
			herd.append(a)
		if herd.size() == 2:
			break
	if herd.size() == 2:
		var first: Node3D = herd[0]
		var second: Node3D = herd[1]
		first.set_meta("fp_born", 1)
		second.set_meta("fp_born", 2)
		first.visible = true
		second.visible = true
		second.global_position = first.global_position + Vector3(0.1, 0, 0)
		var before := first.global_position.distance_to(second.global_position)
		for i in 40:
			Footprint.resolve(level)
		var after := first.global_position.distance_to(second.global_position)
		check(after > before + 0.2, "two peaceful animals ease apart (%.2f m to %.2f m)" % [before, after])
