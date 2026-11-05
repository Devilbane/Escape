extends SceneTree
## Headless test for throwing knives: a thrown knife falls to the floor and
## is picked up again by walking over it; it stays on the floor after leaving
## and coming back. Only 3 + Messerwurf / 2 knives are ready for a fight;
## the rest go into the bag and are slipped back into the belt once no fight
## is on. The ammunition count under the life bar follows. One throw in five
## breaks the knife: it is gone instead of lying on the floor.
## Run with: godot --headless -s tests/thrown_knives.gd

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
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: thrown knives")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _index_of(file_part: String) -> int:
	for i in game.level_files.size():
		if file_part in game.level_files[i]:
			return i
	return -1


func _knives_on_floor() -> Array:
	return game.level._pickups.filter(func(p): return p.kind == "item" and p.get("id", "") == Items.KNIFE)


## The training a skill needs to reach `level`.
func _xp_for(id: String, level: int) -> float:
	var xp := 0.0
	while Training.skill_level(xp, id) < level:
		xp += 1.0
	return xp


func _test() -> void:
	game.hero_name = "Knife test"
	game.escaped = false
	var refuge := _index_of("zuflucht")
	check(refuge >= 0, "the refuge exists")
	game.load_level(refuge, false)
	var p: Player = game.player
	p.bag.clear()
	p.xp.erase("werfen")
	p.fight_cooldown = 0.0

	# How many are ready: 3, and one more per two levels of Messerwurf.
	check(p.knife_cap() == 3, "no skill: 3 knives ready (%d)" % p.knife_cap())
	p.xp["werfen"] = _xp_for("werfen", 3)
	check(p.knife_cap() == 4, "Messerwurf 3: 4 knives ready (%d)" % p.knife_cap())
	p.xp["werfen"] = _xp_for("werfen", 4)
	check(p.knife_cap() == 5, "Messerwurf 4: 5 knives ready (%d)" % p.knife_cap())
	p.xp.erase("werfen")

	# Taking knives: the belt first, the rest into the bag.
	p.knives = 0
	check(p.add_knives(5) == 0, "five knives all find a place")
	check(p.knives == 3 and p.spare_knives() == 2, "3 ready, 2 in the bag (%d, %d)" % [p.knives, p.spare_knives()])
	check(Items.slots_used(p.bag) == 1, "spare knives share one bag slot")
	check(not p.equip(Items.KNIFE), "a spare knife is not worn")

	# In a fight only what is ready can be thrown; after it, the belt fills.
	p.knives = 1
	p.mark_fight()
	check(not p._settle_knives() and p.knives == 1, "no refill while a fight is on")
	p.fight_cooldown = 0.0
	check(p._settle_knives() and p.knives == 3 and p.spare_knives() == 0, "after the fight the belt is filled from the bag")
	# Over the cap (an old save with many knives): the extras go to the bag.
	p.knives = 7
	p._settle_knives()
	check(p.knives == 3 and p.spare_knives() == 4, "knives over the cap go into the bag (%d, %d)" % [p.knives, p.spare_knives()])
	p.bag.clear()

	# The HUD's count and tooltip follow.
	game._update_hud()
	var label: Label = game._ammo_counts["knives"]
	check(label.text == "3", "the HUD shows 3 ready knives (%s)" % label.text)
	p.bag.append(Items.KNIFE)
	game._update_hud()
	var tip: String = (label.get_parent() as Control).tooltip_text
	check("3" in tip and "1" in tip, "the tooltip names the ready, the most and the spares: %s" % tip)
	p.bag.clear()

	# A knife thrown at a wall falls to the floor in front of it.
	var start := p.global_position
	var before := _knives_on_floor().size()
	var dirs := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var shot: Projectile = Projectile.spawn(game.level, start + Vector3(0, 1.5, 0), dirs[0], true)
	check(is_equal_approx(shot.break_chance, 0.2), "a thrown knife breaks one time in five (%.2f)" % shot.break_chance)
	shot.break_chance = 0.0
	for i in 400:
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			break
		shot._physics_process(1.0 / 60.0)
	check(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "the knife's flight ends")
	var lying := _knives_on_floor()
	check(lying.size() == before + 1, "the thrown knife lies on the floor")
	if lying.size() != before + 1:
		return
	var knife: Dictionary = lying[-1]
	var spot: Vector3 = knife.node.global_position
	var cell: Vector2i = game.level.world_to_cell(spot)
	check(not game.level.astar.is_point_solid(cell) and not game.level.is_opaque(cell), "it lies on open floor, not in the wall")
	check(spot.y < 0.2, "it lies flat on the floor (%.2f)" % spot.y)
	check(game.level.floor_items.any(func(e): return e[1] == Items.KNIFE), "it is on the floor list")

	# A knife that breaks is gone: nothing more lies on the floor.
	var listed: int = game.level.floor_items.filter(func(e): return e[1] == Items.KNIFE).size()
	var broken: Projectile = Projectile.spawn(game.level, start + Vector3(0, 1.5, 0), dirs[0], true)
	broken.break_chance = 1.0
	for i in 400:
		if not is_instance_valid(broken) or broken.is_queued_for_deletion():
			break
		broken._physics_process(1.0 / 60.0)
	check(not is_instance_valid(broken) or broken.is_queued_for_deletion(), "the breaking knife's flight ends")
	check(_knives_on_floor().size() == before + 1, "a broken knife does not lie on the floor")
	check(game.level.floor_items.filter(func(e): return e[1] == Items.KNIFE).size() == listed, "nor on the floor list")

	# It stays there when coming back.
	game.load_level(refuge, false)
	p = game.player
	p.bag.clear()
	check(_knives_on_floor().size() == before + 1, "the knife still lies there when coming back")
	knife = _knives_on_floor()[-1]
	spot = knife.node.global_position

	# Walking over it picks it up: into the belt while it has room.
	p.knives = 1
	p.global_position = Vector3(spot.x + 20.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	p.global_position = Vector3(spot.x, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(p.knives == 2, "the knife is back in the belt (%d)" % p.knives)
	check(_knives_on_floor().size() == before, "it is gone from the floor")
	check(not game.level.floor_items.any(func(e): return e[1] == Items.KNIFE and is_same(e, knife.floor)), "and from the floor list")
	check(game.lore.has(game.KNIFE_LORE), "the compendium explains it")

	# With the belt full it goes into the bag; with the bag full too it stays.
	p.knives = p.knife_cap()
	game.level.lay_knife(spot + Vector3(3, 0, 0))
	p.global_position = Vector3(spot.x + 3.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(p.spare_knives() == 1, "a full belt: the knife goes into the bag")
	var filler: String = Items.ALL.keys().filter(func(k): return Items.stack_size(k) == 1 and Items.ALL[k].slot == "waffe")[0]
	p.bag.clear()
	while Items.slots_used(p.bag) < p.bag_size():
		p.bag.append(filler)
	game.level.lay_knife(spot + Vector3(-3, 0, 0))
	p.global_position = Vector3(spot.x - 3.0, p.global_position.y, spot.z)
	game.level._check_pickups()
	check(_knives_on_floor().size() == before + 1, "belt and bag full: the knife stays on the floor")
	p.bag.clear()
	game.level._check_pickups()
	check(p.spare_knives() == 1, "room again: the knife is taken")
	game.level._pickups.clear()
	game.level.floor_items.clear()
	game.floors.clear()

	# Knives from a chest or the workbench: the belt first, the rest in the bag.
	p.knives = 0
	p.bag.clear()
	game.give_knives(5)
	check(p.knives == 3 and p.spare_knives() == 2, "given knives fill the belt, then the bag")
