extends SceneTree
## Headless test for building with stone blocks: the stonemason in the village
## sells them, a block from the bag is set down across the hero's way and a
## second one lands on top of it, a block grabbed with the mouse flies onto
## another spot within reach (but not too far), the hero climbs a block one
## high, blocks go back into the bag, and the buildings stay in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/stones.gd

const HERO := "Stone test"

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
		print("PASS: stones")
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
	check(not p.equip("steinblock"), "a stone block cannot be worn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rolled := false
	for i in 3000:
		if Items.random_item(rng) == "steinblock":
			rolled = true
	check(not rolled, "stone blocks are never found as loot")

	game.load_level(game._outdoor_index(), false)
	var lvl: Outdoor = game.level
	var mason: Dictionary = {}
	for s in lvl.stations:
		if s.kind == "steinmetz":
			mason = s
	check(not mason.is_empty() and mason.has("npc"), "the stonemason stands in the village")

	# Buying: as many as the gold pays for and the bag holds.
	p.bag.clear()
	var block := Items.buy_price("steinblock")
	game.coins = block * 5 + 2
	game.menus.open("steinmetz")
	game.menus._buy_stones(1)
	check(p.bag.count("steinblock") == 1 and game.coins == block * 4 + 2, "one block bought for %d gold" % block)
	game.menus._buy_stones(10)
	check(p.bag.count("steinblock") == 5 and game.coins == 2, "the rest of the gold buys four more")
	game.menus._sell_stone()
	check(p.bag.count("steinblock") == 4 and game.coins == 3, "a block given back brings 1 gold")
	game.coins = block
	game.menus._buy_stones(1)
	check(p.bag.count("steinblock") == 5 and game.coins == 0, "and can be bought again")
	game.menus.close()
	await _wait(3)

	# Set down on open grass west of the village, facing west: the block
	# lies across the way (along z).
	var field := lvl.cell_to_world(Vector2i(22, 33))
	_place(p, field, Vector3.LEFT)
	await _wait(3)
	check(game.place_stone() == "", "setting a block down works")
	await _wait(20)
	check(lvl.stones.size() == 1, "one block stands on the level")
	var bottom: StoneBlock = lvl.stones[0]
	check(bottom.layer == 0 and not bottom.along_x, "it lies on the floor, across the hero's way")
	check(bottom.global_position.x < p.global_position.x - 0.8, "it lies in front of the hero")
	check(game.place_stone() == "", "setting a second block down works")
	await _wait(20)
	var upper: StoneBlock = lvl.stones[-1]
	check(upper.layer == 1 and upper.cell == bottom.cell, "the second block lies on top of the first")
	check(absf(upper.global_position.y - StoneBlock.HEIGHT) < 0.01, "one block high up")
	check(not lvl.stone_free(bottom) and lvl.stone_free(upper), "only the top block is free")
	check(p.bag.count("steinblock") == 3, "two blocks left the bag")
	check(lvl.built.size() == 2 and game.builds[game.level_files[game.level_index].get_file()].size() == 2, "the level and the game keep a list of its blocks")

	# Dragging the top block with the mouse: it lands two cells further on.
	var screen: Vector2 = game.camera.unproject_position(upper.global_position + Vector3(0, StoneBlock.HEIGHT * 0.5, 0))
	check(game._stone_under(screen) == upper, "the mouse finds the block under it")
	check(game._grab_stone(screen) and game._drag_stone == upper, "the free block can be grabbed")
	var to := upper.global_position + Vector3(0, 0, StoneBlock.CELL * 3.0)
	game._drag_spot = lvl.stone_drop_spot(upper, to, upper.along_x, p)
	check(game._drag_spot.ok and game._drag_spot.layer == 0, "the spot next to it is free, on the floor")
	game._drag_time = 1.0
	game._drop_stone()
	check(game._drag_stone == null, "letting go ends the drag")
	await _wait(40)
	check(upper.layer == 0 and absf(upper.global_position.z - to.z) < 0.5, "the block flew onto the new spot")
	check(upper.model.top_level == false and upper.model.position.length() < 0.01, "and its model landed with it")
	check(lvl.stone_free(bottom), "the lower block is free again")
	var far := lvl.stone_drop_spot(upper, p.global_position + Vector3(0, 0, Level.STONE_DRAG_RANGE + 3.0), true, p)
	check(not far.ok, "a block cannot be thrown too far")
	# (Stepped back first: the hero would stand in the way of a block lying along x.)
	_place(p, field + Vector3(2.0, 0, 0))
	await _wait(3)
	var onto := lvl.stone_drop_spot(upper, bottom.global_position, true, p)
	check(onto.ok and onto.layer == 1, "a dragged block turned along x lands on top of another")
	check(not game._grab_stone(Vector2(-500, -500)) and game._drag_stone == null, "nothing to grab off the blocks")

	# Walking into a block one high climbs it.
	_place(p, bottom.global_position + Vector3(3.0, 0, 0))
	await _wait(3)
	var climbed := false
	for i in 200:
		if p.path.is_empty() and not p.is_climbing():
			p.path.assign([bottom.global_position + Vector3(-1.0, 0, 0)])
		await physics_frame
		if p.is_climbing():
			climbed = true
		if p.on_crate() and absf(p.global_position.y - StoneBlock.HEIGHT) < 0.1:
			break
	p.path.clear()
	check(climbed and absf(p.global_position.y - StoneBlock.HEIGHT) < 0.15, "walking into a block climbs on top (at %s)" % p.global_position)
	check(not lvl.stone_free(bottom), "a block someone stands on is not free")
	await _wait(10)

	# Saved and loaded again, the blocks stand where they were.
	_place(p, field + Vector3(0, 0, -3.0))
	await _wait(10)
	check(game.save_game(), "the game saves")
	var data: Dictionary = game._read_save(game.save_path())
	var file: String = game.level_files[game.level_index].get_file()
	check(data.has("builds") and data.builds.has(file) and data.builds[file].size() == 2, "the saved game holds the blocks")
	var spots := lvl.stones.map(func(s): return [s.cell, s.along_x, s.layer])
	game._apply_save(data)
	await _wait(5)
	var again: Level = game.level
	check(again != lvl and again.stones.size() == 2, "after loading the blocks are built again")
	check(again.stones.map(func(s): return [s.cell, s.along_x, s.layer]) == spots, "in the same spots")

	# Back into the bag.
	var a_block: StoneBlock = again.stones[0]
	_place(p, a_block.global_position + Vector3(2.0, 0, 0))
	await _wait(3)
	var bag_before := p.bag.count("steinblock")
	check(game.take_stone() == "", "taking a block back works")
	await _wait(30)
	check(p.bag.count("steinblock") == bag_before + 1 and again.stones.size() == 1 and again.built.size() == 1, "the block is in the bag again")
	_finish()
