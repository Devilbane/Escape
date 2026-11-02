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
	# Dragged, it slides straight on until a pillar stops it, never sideways.
	var pushed := lvl.stone_drop_spot(block, block.global_position + Vector3(0.0, 0.0, 6.0), false, p)
	check(pushed.ok and pushed.along_x == block.along_x and pushed.layer == 0, "a dragged heavy block keeps lying the same way on the floor")
	var pillar := lvl.cell_to_world(Vector2i(9, 18))
	var stop := StoneBlock.spot_of(pushed.cell, pushed.along_x, 0)
	check(pushed.cell.x == block.cell.x and stop.z < pillar.z - 0.8, "it slides straight on and stops before the pillar")
	check(lvl.push_stone(block, Vector2i(-1, 0)), "pushed back again")
	await _wait(30)

	# Blocks onto the plates: the gate opens once all of them are pressed.
	for i in 3:
		var s: StoneBlock = heavy[i]
		lvl.move_stone(s, StoneBlock.cell_for(lvl.cell_to_world(PLATES[i]), true), true, 0)
		await _wait(10)
		check(lvl.plates_pressed() == i + 1, "%d plates pressed" % (i + 1))
		check(lvl.gates_open() == (i == 2), "the gate opens only with all plates pressed (%d)" % (i + 1))
	check(not lvl.astar.is_point_solid(GATE), "the open gate lets everyone through")
	check(lvl.built.is_empty(), "moved heavy blocks are still not kept in the saved game")
	lvl.move_stone(heavy[0], StoneBlock.cell_for(lvl.cell_to_world(Vector2i(5, 17)), true), true, 0)
	await _wait(10)
	check(lvl.plates_pressed() == 2 and lvl.gates_open(), "taking a block off a plate leaves the gate open")

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
