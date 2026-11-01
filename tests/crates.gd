extends SceneTree
## Headless test for the crates and the food basket in the village: the
## crates by the pedestal go into the bag and come out again in front of the
## hero, a second one lands on top of the first, the hero walks up a step
## crate onto the stack by themselves and eats from the basket up there, and
## standing on crates above a skeleton does not count as stacked.
## Run with: godot --headless --fixed-fps 60 -s tests/crates.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: crates")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## Puts the hero somewhere, standing still and facing a direction.
func _place(p: Player, pos: Vector3, facing := Vector3.ZERO) -> void:
	p.path.clear()
	p.velocity = Vector3.ZERO
	p.global_position = pos
	if facing != Vector3.ZERO:
		p.face(facing)


func _run() -> void:
	var p: Player = game.player
	check(not p.equip("kiste"), "a crate cannot be worn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rolled := false
	for i in 3000:
		if Items.random_item(rng) == "kiste":
			rolled = true
	check(not rolled, "crates are never found as loot or sold")

	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	check(not lvl._basket.is_empty(), "the village has the pedestal with the food basket")
	if lvl._basket.is_empty():
		_finish()
		return
	var top: Vector3 = lvl._basket.pos
	var base := Vector3(top.x, 0.0, top.z)
	check(is_equal_approx(top.y, Outdoor.PEDESTAL_HEIGHT), "the basket stands on top of the pedestal")
	var near := lvl.crates.filter(func(c): return c.global_position.distance_to(base) < 4.5)
	check(near.size() == 3, "three crates lie by the pedestal (found %d)" % near.size())
	await _wait(3)

	# Pick all three up: each goes into the bag.
	var picked := 0
	for crate in near.duplicate():
		var c: Crate = crate
		var away: Vector3 = c.global_position - base
		away.y = 0.0
		_place(p, c.global_position + away.normalized() * 1.5)
		await _wait(2)
		var why: String = game.pick_up_crate()
		check(why == "", "picking up a crate works (%s)" % why)
		if why == "":
			picked += 1
		await _wait(30)
	check(p.bag.count("kiste") == 3 and picked == 3, "the three crates are in the bag")
	check(lvl.crates.filter(func(c): return is_instance_valid(c) and c.global_position.distance_to(base) < 4.5).is_empty(), "the crates are gone from the floor")
	check(game.pick_up_crate() != "", "no crate in reach: nothing to pick up")

	# Two crates on top of each other beside the pedestal...
	var stack_x := 1.7 * 0.5 + Crate.SIZE * 0.5 + 0.2
	_place(p, base + Vector3(stack_x + Level.CRATE_AHEAD, 0, 0), Vector3.LEFT)
	await _wait(3)
	check(game.put_down_crate() == "", "setting a crate down works")
	await _wait(30)
	var bottom: Crate = lvl.crates[-1]
	check(absf(bottom.global_position.y) < 0.05 and absf(bottom.global_position.x - (base.x + stack_x)) < 0.05, "the crate stands on the floor in front of the hero")
	check(game.put_down_crate() == "", "setting a second crate down works")
	await _wait(30)
	var upper: Crate = lvl.crates[-1]
	check(absf(upper.global_position.y - Crate.SIZE) < 0.05 and lvl.crate_on(bottom) == upper, "the second crate is stacked on the first")
	check(lvl.crate_in_reach(p) == upper, "only the top crate of a stack can be picked up")
	# ...and a step crate in front of them.
	var step_x := stack_x + Crate.SIZE + 0.25
	_place(p, base + Vector3(step_x + Level.CRATE_AHEAD, 0, 0), Vector3.LEFT)
	await _wait(3)
	check(game.put_down_crate() == "", "setting the step crate down works")
	await _wait(30)
	var step: Crate = lvl.crates[-1]
	check(absf(step.global_position.y) < 0.05, "the step crate stands on the floor")
	check(not p.bag.has("kiste"), "the bag holds no more crates")
	check(game.put_down_crate() != "", "without a crate there is nothing to set down")

	# Walk at the pedestal: up the step, up the stack, and eat.
	p.hp = 1
	_place(p, base + Vector3(step_x + 2.6, 0, 0))
	await _wait(3)
	var was_on_step := false
	var climbed := false
	for i in 400:
		if p.path.is_empty() and not p.is_climbing() and p.global_position.y < 1.4:
			p.path.assign([base])
		await physics_frame
		if p.is_climbing():
			climbed = true
		if p.on_crate() and absf(p.global_position.y - Crate.SIZE) < 0.1:
			was_on_step = true
		if not lvl._basket.full:
			break
	p.path.clear()
	print("hero at %s, hp %d" % [p.global_position, p.hp])
	check(climbed and was_on_step, "walking into the step crate climbs it")
	check(p.global_position.y > Crate.SIZE * 2.0 - 0.1, "from the step the hero climbs onto the stack")
	check(not lvl._basket.full and p.hp >= mini(p.max_hp, 1 + Outdoor.BASKET_HEAL), "up on the stack the hero eats from the basket")
	await _wait(10)
	check(p.on_crate(), "the hero stands on the crates")

	# Up on the crates, a skeleton right below is not stacked with the hero.
	var foe: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and not e.dead:
			foe = e
	if foe:
		# Frozen in place, but still a body the push apart looks at.
		foe.set_physics_process(false)
		foe.set_process(false)
		foe.collision_layer = 0
		foe.collision_mask = 0
		var hero_spot := p.global_position
		foe.global_position = Vector3(hero_spot.x, 0.0, hero_spot.z + 0.3)
		check(not lvl.stacked(p, foe), "a hero on crates is not stacked with a skeleton below")
		await _wait(30)
		check(p.global_position.distance_to(hero_spot) < 0.1, "nobody shoves the hero off the crates")
		foe.queue_free()
		lvl.enemies.erase(foe)
	else:
		print("no skeleton in the village to check stacking with")

	# A walk into a crate stack two high is no step: the hero stays below.
	_place(p, base + Vector3(stack_x, 0, 2.6))
	await _wait(3)
	p.path.assign([base + Vector3(stack_x, 0, 0)])
	for i in 90:
		await physics_frame
	check(p.global_position.y < 0.3, "two crates are too high to just walk up")
	_finish()
