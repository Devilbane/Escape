extends SceneTree
## Headless test for the village wall and its gates (see VillageWall, WallBrick):
## - the map has bricks of 1000 HP and two gates, open at first and never in the
##   way of the path finding while they are open;
## - a hurt brick shows it (a stone falls off), a broken one lets everyone
##   through until it is mended, and a mended one blocks again;
## - the villagers shut the gates when a slime comes near, not on somebody
##   standing in the gate, and open them again once the slime is gone;
## - a slime walled out of the village eats into the wall;
## - the stonemason walks to a hurt brick and builds it up.
## Run with: godot --headless --fixed-fps 60 -s tests/village_wall.gd

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


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: village wall")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _slime(lvl: Outdoor, at: Vector3) -> Enemy:
	return lvl.spawn_slime("schleim", at, {})


func _run() -> void:
	game.hero_name = "Wall test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	lvl.night = false

	# The map: four bricks and a gate in the west, a gate in the east.
	check(wall.bricks.size() == 6, "the map has six wall tiles, got %d" % wall.bricks.size())
	check(wall.gates.size() == 2, "the village has two gates, got %d" % wall.gates.size())
	for b: WallBrick in wall.bricks.values():
		check(b.hp == WallBrick.MAX_HP and WallBrick.MAX_HP == 1000, "a brick has 1000 HP")
	var west: WallBrick = wall.brick_at(Vector2i(37, 27))
	var brick: WallBrick = wall.brick_at(Vector2i(37, 26))
	check(west != null and west.gate and brick != null and not brick.gate, "the west gate sits in the path, bricks beside it")
	check(not west.shut and not lvl.astar.is_point_solid(west.cell), "an open gate is no obstacle to the path finding")
	check(lvl.astar.is_point_solid(brick.cell), "a brick is an obstacle to the path finding")
	check(lvl.grid_path(Vector2i(34, 27), Vector2i(40, 27)).back() == Vector2i(40, 27), "the way through the open gate leads into the village")
	
	# Damage shows, a broken brick lets everyone through, a mended one blocks again.
	var stones_before := brick._stones.map(func(s: MeshInstance3D): return s.position)
	check(not brick.hurt(250) and brick.hp == 750, "a brick takes damage")
	var moved := 0
	for i in brick._stones.size():
		if brick._stones[i].position != stones_before[i]:
			moved += 1
	check(moved > 0, "a stone has fallen off a hurt wall")
	check(brick._label.visible and brick._label.text == "750 / 1000", "the hurt brick shows its HP")
	check(brick.hurt(10000), "a brick can be destroyed")
	check(not lvl.astar.is_point_solid(brick.cell) and not brick.blocks(), "a destroyed brick no longer blocks")
	check(lvl.cell_char(brick.cell) == ".", "a destroyed brick is open ground")
	check(brick._body_shape.disabled, "a destroyed brick has no body")
	check(not brick.mend(0.5) and brick.hp == 0, "building up needs whole points of HP")
	check(not brick.mend(100.0) and brick.hp == 100, "the mason builds a destroyed brick up")
	check(lvl.astar.is_point_solid(brick.cell) and lvl.cell_char(brick.cell) == "_", "a rebuilt brick blocks again")
	check(brick.mend(5000.0) and brick.hp == 1000 and not brick._label.visible, "a mended brick is whole and shows no number")

	# The villagers shut the gates when a slime is near, and open them later.
	var slime := _slime(lvl, west.global_position + Vector3(-16, 0, 0))
	slime._awake = false
	wall.tick(lvl, 1.1)
	check(wall.shut_wanted, "a slime near the gate has the villagers shut it")
	await _wait(2)
	check(west.shut and lvl.astar.is_point_solid(west.cell), "the gate is shut and blocks the way")
	check(not lvl.grid_path(Vector2i(34, 27), Vector2i(40, 27)).has(Vector2i(40, 27)), "no way into the village while the gates are shut")
	check(west._leaf_shape != null and not west._leaf_shape.disabled, "a shut gate has a body")
	slime.dead = true
	for i in int(VillageWall.OPEN_AFTER) + 2:
		wall.tick(lvl, 1.1)
	check(not wall.shut_wanted and not west.shut, "the gates open again once the slime is gone")
	check(not lvl.astar.is_point_solid(west.cell), "an open gate lets the path through again")

	# Never shut on somebody in the gate.
	lvl.player.global_position = west.global_position
	var slime2 := _slime(lvl, west.global_position + Vector3(-12, 0, 0))
	slime2._awake = false
	wall.tick(lvl, 1.1)
	check(wall.shut_wanted and not west.shut, "the gate stays open while the hero stands in it")
	lvl.player.global_position = west.global_position + Vector3(4.0 * 3, 0, 0)
	wall.tick(lvl, 1.1)
	check(west.shut, "the gate shuts once the way is clear")

	# A slime walled out eats into the wall: the hero stands just inside.
	slime2.global_position = west.global_position + Vector3(-5.0, 0, 0)
	lvl.player.global_position = west.global_position + Vector3(4.5, 0, 0)
	slime2._awake = true
	slime2._last_known = lvl.player.global_position
	slime2._lost = 0.0
	var hp_before := west.hp
	var waited := 0
	while west.hp == hp_before and waited < 900:
		slime2._awake = true
		slime2._lost = 0.0
		slime2._last_known = lvl.player.global_position
		await _wait(10)
		waited += 10
	check(west.hp < hp_before, "a slime blocked by the gate eats into it (%d frames)" % waited)
	check(hp_before - west.hp >= VillageWall.ACID * maxi(1, int(slime2._stats.damage)), "a slime's blow does ACID times its damage")

	# Defence: those outside are called in before the gate shuts, the brave take
	# posts inside, and a slime at the wall is struck over it.
	slime2.dead = true
	for i in int(VillageWall.OPEN_AFTER) + 2:
		wall.tick(lvl, 1.1)
	check(not west.shut, "the gate is open before the defence test")
	var farmer: Villager = null
	for v in lvl.villagers:
		if v.role == "2":
			farmer = v
	farmer._start("idle", 30.0)
	farmer.global_position = west.global_position + Vector3(-6, 0, 0)
	for v in lvl.villagers:
		v._start("idle", 30.0)
	check(not wall.is_inside(lvl.world_to_cell(farmer.global_position)) and wall.is_inside(lvl.world_to_cell(west.global_position + Vector3(8, 0, 0))), "the wall tells inside from outside")
	slime2.global_position = west.global_position + Vector3(-20.0, 0, 0)
	slime2.dead = false
	slime2._awake = false
	wall.tick(lvl, 1.1)
	check(wall.shut_wanted and not west.shut, "the gate waits for the villager outside")
	check(farmer._task == "walk", "a villager outside is called in")
	var defenders := lvl.villagers.filter(func(v: Villager): return v.defends())
	check(not defenders.is_empty(), "the brave villagers take posts at the wall")
	for i in 12:
		await _wait(30)
		wall.tick(lvl, 1.1)
		if west.shut:
			break
	check(wall.is_inside(lvl.world_to_cell(farmer.global_position)), "the villager outside came in through the gate")
	check(west.shut, "the gate shuts once everyone is in")
	var defender: Villager = lvl.villagers.filter(func(v: Villager): return v.defends())[0]
	defender.global_position = west.global_position + Vector3(1.8, 0, 0)
	defender._task = "defend"
	defender.defend_post = defender.global_position
	slime2.global_position = west.global_position + Vector3(-2.2, 0, 0)
	slime2._awake = false
	var life := slime2.hp
	await _wait(400)
	check(slime2.dead or slime2.hp < life, "a defender strikes a slime at the wall over the wall")

	# The mason builds hurt bricks up.
	slime2.dead = true
	for i in int(VillageWall.OPEN_AFTER) + 2:
		wall.tick(lvl, 1.1)
	await _wait(2)
	west.hurt(300)
	brick.hurt(400)
	var mason: Villager = null
	for v in lvl.villagers:
		if v.role == "S":
			mason = v
	check(mason != null, "the village has a stonemason")
	mason._start("idle", 5.0)
	lvl.player.global_position = Vector3(40.0 * 4, 0, 40.0 * 4)
	var worst := wall.job(lvl)
	check(worst == brick, "the mason takes the worst hurt brick first")
	mason.global_position = wall.stand_of(lvl, brick)
	wall.tick(lvl, 1.1)
	check(mason.mend_brick == brick, "the mason is sent to the hurt brick")
	var before := brick.hp
	await _wait(120)
	check(brick.hp >= before + int(VillageWall.MEND_PER_SECOND), "the mason builds the brick up over time (%d to %d)" % [before, brick.hp])
	for i in 80:
		await _wait(30)
		if wall.damaged().is_empty():
			break
	check(wall.damaged().is_empty(), "the mason mends every hurt brick in the end")

	# A slime near the wall keeps him from it.
	west.hurt(100)
	var slime3 := _slime(lvl, west.global_position + Vector3(-8, 0, 0))
	slime3._awake = false
	check(wall.job(lvl) == null or VillageWall.slime_near(lvl, west.global_position, VillageWall.MEND_SAFE), "the mason leaves the wall alone while a slime is about")
	_finish()
