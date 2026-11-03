extends SceneTree
## Headless test for what stone blocks are good for: a wall of blocks across
## a corridor walls it off for the path finding of skeletons and bandits
## (and a single block does not), and the puzzle chamber of level 3: heavy
## blocks slide but never go into the bag, and once a block lies on every
## pressure plate the iron gate to the rich chest opens for good.
## Run with: godot --headless --fixed-fps 60 -s tests/stone_puzzle.gd

const HERO := "Stone puzzle test"
## Tiles of level 3 (see levels/03_das_labyrinth.txt).
const CORRIDOR := Vector2i(3, 11)
const PLATES: Array[Vector2i] = [Vector2i(3, 15), Vector2i(15, 15), Vector2i(9, 19)]
const GATE := Vector2i(17, 17)
const CHEST := Vector2i(19, 17)

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
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: stone puzzle")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _nearest(blocks: Array, to: Vector3) -> StoneBlock:
	var best: StoneBlock = null
	for b in blocks:
		if best == null or b.global_position.distance_to(to) < best.global_position.distance_to(to):
			best = b
	return best


func _place(p: Player, pos: Vector3, facing := Vector3.ZERO) -> void:
	p.path.clear()
	p.velocity = Vector3.ZERO
	p.global_position = pos
	if facing != Vector3.ZERO:
		p.face(facing)


func _run() -> void:
	var p: Player = game.player
	game.hero_name = HERO
	var index: int = game.level_files.find("res://levels/03_das_labyrinth.txt")
	check(index >= 0, "level 3 is there")
	game.load_level(index, false)
	await _wait(5)
	var lvl: Level = game.level
	_place(p, lvl.cell_to_world(lvl.start_cell))
	await _wait(5)

	# The chamber as it starts.
	var heavy: Array = lvl.stones.filter(func(s): return s.heavy)
	check(heavy.size() == 3, "three heavy blocks lie in the chamber (%d)" % heavy.size())
	check(lvl.plate_count() == 3 and lvl.plates_pressed() == 0, "three pressure plates, none pressed")
	check(not lvl.gates_open() and lvl.astar.is_point_solid(GATE), "the iron gate is shut")
	check(lvl.built.is_empty(), "heavy blocks are not kept in the saved game")
	var chest: Dictionary = {}
	for obj in lvl.interactables:
		if obj.cell == CHEST:
			chest = obj
	check(not chest.is_empty() and int(chest.loot.get("gold", 0)) == int(Level.TIERS["selten"].gold) and chest.loot.has("item"), "the chest behind the gate holds a rare reward")

	# A heavy block is pushed with E, but never goes into the bag.
	var block: StoneBlock = null
	for s in heavy:
		if lvl.world_to_cell(s.global_position) == Vector2i(9, 17):
			block = s
	check(block != null, "a heavy block lies in the middle of the chamber")
	if block == null:
		_finish()
		return
	_place(p, block.global_position + Vector3(-2.4, 0, 0.4), Vector3.RIGHT)
	await _wait(5)
	var bag_before := p.bag.size()
	var from_cell := block.cell
	check(lvl.stone_in_reach(p) == block, "the heavy block is in reach")
	check(game.take_stone() == "", "E pushes the heavy block")
	await _wait(30)
	check(block.cell == from_cell + Vector2i(1, 0) and p.bag.size() == bag_before and lvl.stones.has(block), "it slid one cell away from the hero, not into the bag")
	# Dragged, it goes anywhere on the floor nearby, sideways and turned too.
	var aside := block.global_position + Vector3(-1.6, 0.0, -2.4)
	var moved := lvl.stone_drop_spot(block, aside, false, p)
	check(moved.ok and not moved.along_x and moved.layer == 0, "a dragged heavy block may go sideways and be turned")
	check(lvl.stone_drop_spot(block, lvl.cell_to_world(Vector2i(9, 18)), true, p).ok == false, "but not into a pillar")
	# Never through a wall: the tile north of the chamber is behind one.
	_place(p, lvl.cell_to_world(Vector2i(9, 17)) + Vector3(0.0, 0.0, -1.2))
	await _wait(3)
	var behind := lvl.stone_drop_spot(block, lvl.cell_to_world(Vector2i(8, 15)) + Vector3(1.0, 0.0, 0.0), true, p)
	check(not behind.ok, "a heavy block is never dragged through a wall")
	# Within 5 tiles of where it started, and no further.
	check(Level.HEAVY_RANGE == 5.0 * Level.TILE, "the range is five tiles")
	_place(p, block.home + Vector3(-Level.HEAVY_RANGE + 2.0, 0.0, 1.4))
	await _wait(3)
	var edge := lvl.stone_drop_spot(block, block.home + Vector3(-Level.HEAVY_RANGE - 3.0, 0.0, 0.0), true, p)
	check(edge.edge, "a point beyond the range is pulled back to its edge")
	check(lvl._flat_distance(StoneBlock.spot_of(edge.cell, edge.along_x, 0), block.home) <= Level.HEAVY_RANGE, "and the spot stays within it")
	check(edge.ok, "a spot on the edge is fine (%s)" % str(edge))
	lvl.move_stone(block, edge.cell, true, 0)
	await _wait(30)
	_place(p, block.global_position + Vector3(2.4, 0, 0.4), Vector3.LEFT)
	await _wait(5)
	var why := ""
	for k in 3:
		_place(p, block.global_position + Vector3(2.4, 0, 0.4), Vector3.LEFT)
		await _wait(3)
		why = game.push_stone(block)
		await _wait(20)
		if why != "":
			break
	check(why == Lang.t("Weiter als 5 Felder von seinem Platz rückt der Block nicht."), "E does not push it past the edge (%s)" % why)
	check(lvl._flat_distance(block.global_position, block.home) <= Level.HEAVY_RANGE, "it stays within the range")
	lvl.move_stone(block, StoneBlock.cell_for(block.home, true), true, 0)
	await _wait(30)

	# The whole puzzle played the way a player does: walk up to each block,
	# drag it a few metres along the way round the pillars towards its plate,
	# let go, and again until it lies on the plate.
	for i in 3:
		var goal := lvl.cell_to_world(PLATES[i])
		var s: StoneBlock = _nearest(heavy, goal)
		var steps := 0
		while lvl._flat_distance(s.global_position, goal) > 0.5 and steps < 8:
			steps += 1
			var route := lvl.grid_path(lvl.world_to_cell(s.global_position), PLATES[i])
			var spot := {}
			# The farthest tile on the way that a drag reaches.
			for k in range(route.size() - 1, 0, -1):
				var to := lvl.cell_to_world(route[k])
				if lvl._flat_distance(to, s.global_position) > 6.0:
					continue
				var way := Vector3(to.x - s.global_position.x, 0.0, to.z - s.global_position.z)
				var side := Vector3(-way.z, 0.0, way.x).normalized() * 1.6
				for hero_at in [(s.global_position + to) * 0.5 + side, (s.global_position + to) * 0.5 - side]:
					if lvl.astar.is_point_solid(lvl.world_to_cell(hero_at)):
						continue
					_place(p, hero_at)
					await _wait(3)
					spot = lvl.stone_drop_spot(s, to, true, p)
					if spot.ok:
						break
				if spot.get("ok", false):
					break
			check(spot.get("ok", false), "block %d, step %d: a free spot on the way to plate %s" % [i, steps, str(PLATES[i])])
			if not spot.get("ok", false):
				break
			game._drag_stone = s
			game._drag_spot = spot
			game._drag_time = 1.0
			game._drop_stone()
			await _wait(30)
		await _wait(10)
		check(lvl.plates_pressed() == i + 1, "%d plates pressed (%d)" % [i + 1, lvl.plates_pressed()])
		check(lvl.gates_open() == (i == 2), "the gate opens only with all plates pressed (%d)" % (i + 1))
	check(not lvl.astar.is_point_solid(GATE), "the open gate lets everyone through")
	check(lvl.built.is_empty(), "moved heavy blocks are still not kept in the saved game")
	var off_plate: StoneBlock = _nearest(heavy, lvl.cell_to_world(PLATES[0]))
	lvl.move_stone(off_plate, StoneBlock.cell_for(lvl.cell_to_world(Vector2i(5, 17)), true), true, 0)
	await _wait(10)
	check(lvl.plates_pressed() == 2 and lvl.gates_open(), "taking a block off a plate leaves the gate open")

	# Every shipped map keeps its plates within reach of a block of their own.
	for file in game.level_files:
		var map := LevelMap.load_file(file)
		check(map.plates_out_of_reach().is_empty(), "%s: every plate has a block within 5 tiles" % file.get_file())
	var lonely := LevelMap.parse("name: Fern\n##########\n#Q.......#\n#.......P#\n#......._#\n##########")
	check(lonely.plates_out_of_reach().size() == 1, "a plate 7 tiles from the only block is flagged")

	# Walling off a corridor: one block leaves room to pass, two do not.
	_place(p, lvl.cell_to_world(lvl.start_cell))
	await _wait(5)
	var row := StoneBlock.grid_cell(lvl.cell_to_world(CORRIDOR)).y
	check(lvl.stone_fits(Vector2i(13, row), true, 0) and lvl.stone_fits(Vector2i(15, row), true, 0), "two blocks fit across the corridor")
	var first := lvl.put_stone(Vector2i(13, row), true, 0)
	check(not lvl.stone_cut(CORRIDOR) and not lvl.astar.is_point_solid(CORRIDOR), "a single block leaves a gap wide enough")
	var second := lvl.put_stone(Vector2i(15, row), true, 0)
	check(lvl.stone_cut(CORRIDOR) and lvl.astar.is_point_solid(CORRIDOR), "two blocks wall the corridor off")
	var way := lvl.grid_path(CORRIDOR + Vector2i(0, -1), CORRIDOR + Vector2i(0, 1))
	check(not way.is_empty() and way[-1] == CORRIDOR + Vector2i(0, 1) and not way.has(CORRIDOR), "skeletons go the long way round")
	var out := lvl.grid_path(CORRIDOR, CORRIDOR + Vector2i(0, 1))
	check(out.size() >= 2, "someone standing on the walled-off tile can still set out from it")
	check(lvl.built.size() == 2, "the hero's own blocks are kept in the saved game")
	lvl.take_stone(second)
	await _wait(20)
	check(not lvl.stone_cut(CORRIDOR) and not lvl.astar.is_point_solid(CORRIDOR), "with a block taken away the way is free again")
	lvl.take_stone(first)
	await _wait(20)
	_finish()
