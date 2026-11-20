extends SceneTree
## A companion that stands on the cellar stairs when they are taken away must not stay sunk into the
## ground (the pit rim step of the house playtest failed now and then because of it). Runs rounds
## with different timings: the fox follows the hero down, the stairs go, and the fox must come up.
## Run with: godot --headless --fixed-fps 60 -s tests/pet_stairs_removed.gd
var game: Node
var f := 0
var started := false
var bad := 0

func _initialize():
	Storage.use(Storage.Memory.new()); Plots.reload(); HouseSketch.reload()
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)

func _process(_d):
	f += 1
	if f == 5 and not started:
		started = true
		_run()
	return false

func _wait(n):
	for i in n: await process_frame

func _run():
	game.hero_name = "Pit hero"; game.escaped = true
	game.load_level(game._outdoor_index(), false); game.state = game.State.PLAYING
	game._title.visible = false
	game.player.godmode = true
	var lvl = game.level
	for e in lvl.enemies:
		if is_instance_valid(e): e.queue_free()
	lvl.enemies.clear()
	var plot := Rect2i(82, 22, 4, 4)
	Plots.register(lvl, game.hero_name, plot)
	game.plot_marker.refresh()
	var sk: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sk.plan
	plan.deposit("steinblock", 40); plan.deposit("bauholz", 40)
	plan.sketch_dig(plan.cells_between(Vector2i(2, 2), Vector2i(3, 3)))
	plan.sketch_stairs(0, 2, "e")
	plan.ordered = true
	for i in 12: sk.work_once()
	print("built: ", plan.open_pieces(), " open")
	sk._redraw()
	var top: Vector3 = plan.cell_world(0, 2)
	game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
	game.player.reset_physics_interpolation()
	await _wait(30)
	var stairs_key := plan.stairs_to(2, 2)
	for round in 14:
		game.companions.clear()
		game.companions.append(Companions.make("fuchs", "Fuchs"))
		game.following = 0
		game._spawn_pet()
		await _wait(20 + (round * 7) % 50)
		var pet: Pet = game.pet
		# the pet may follow the hero down first, as in the playtest
		plan.pieces[stairs_key].state = HouseSketch.BUILT
		sk._redraw()
		game.player.global_position = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
		game.player.reset_physics_interpolation()
		await _wait(60 + (round * 13) % 120)
		game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
		game.player.reset_physics_interpolation()
		await _wait((round * 11) % 90)
		plan.pieces[stairs_key].state = HouseSketch.SKETCH
		sk._redraw()
		game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
		game.player.reset_physics_interpolation()
		await _wait(60)
		game.player.global_position = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
		game.player.reset_physics_interpolation()
		var lowest := 0.0
		var info := ""
		for i in 240:
			await process_frame
			if is_instance_valid(pet):
				if pet.global_position.y < lowest - 0.3 and info == "":
					info = "frame %d y %.2f state %s cut %s" % [i, pet.global_position.y, pet.state, pet.is_cut_off()]
				lowest = minf(lowest, pet.global_position.y)
		if lowest < -0.3:
			bad += 1
			print("round ", round, " fell: lowest ", lowest, " ", info)
		if is_instance_valid(game.pet): game.pet.queue_free()
		await _wait(5)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: pet and removed stairs" if bad == 0 else "FAILED: %d rounds" % bad)
	quit(1 if bad > 0 else 0)
