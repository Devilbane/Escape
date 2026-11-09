extends SceneTree
## Headless test for the birds and squirrels of the woods (see WoodsLife,
## Squirrel and the `wild` flock of VillageBirds): birds sit in the treetops
## along the forest's edge and fly off when the hero comes close, squirrels
## live at the foot of the trees, run up the trunk when the hero comes close
## and come down again once the hero has gone.
## Run with: godot --headless --fixed-fps 60 -s tests/woods_life.gd

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


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await process_frame
	var lvl: Outdoor = game.level
	var hero: Player = game.player
	_set_hour(12.0)
	lvl.night = false
	var woods: WoodsLife = lvl.woods
	check(woods != null, "the woods have wildlife")
	if woods == null:
		_finish()
		return
	var birds := woods.birds
	check(birds != null and birds.wild, "birds live in the trees")
	check(birds.birds.size() >= 8 and birds.birds.size() <= WoodsLife.MAX_BIRDS, "a good few birds, not a crowd (%d)" % birds.birds.size())
	check(birds.broods.is_empty() and birds.feeding.is_empty(), "the woods birds have no nests to tend or feeders")
	check(woods.squirrels.size() >= 3 and woods.squirrels.size() <= WoodsLife.MAX_SQUIRRELS, "a few squirrels (%d)" % woods.squirrels.size())
	check(lvl.birds == null or lvl.birds != birds, "the village flock is its own")
	for b: Dictionary in birds.birds:
		check(b.at.y > 2.0, "a bird sits up in a treetop (%.1f)" % b.at.y)
		if b.at.y <= 2.0:
			break
	for s: Squirrel in woods.squirrels:
		check(lvl.is_open(lvl.world_to_cell(s.global_position)), "a squirrel stands on open ground")
		check(not lvl.is_open(lvl.world_to_cell(s.tree.pos)) or s.tree.pos.distance_to(lvl.cell_to_world(s.tree.cell)) < Level.TILE * 1.5, "its tree is at the edge of the open ground")

	# A squirrel bolts for its tree and climbs it when the hero comes close.
	var sq: Squirrel = woods.squirrels[0]
	hero.global_position = sq.global_position + Vector3(40, 0, 0)
	for i in 120:
		await physics_frame
	check(sq.state in ["sit", "hop"], "a squirrel carries on while the hero is far (%s)" % sq.state)
	hero.global_position = sq.global_position + Vector3(Squirrel.SHY * 0.5, 0, 0)
	await physics_frame
	await physics_frame
	check(sq.state == "flee", "it bolts when the hero comes close (%s)" % sq.state)
	var climbed := false
	var high := 0.0
	for i in 60 * 8:
		hero.global_position = sq.tree.pos + Vector3(Squirrel.SHY * 0.5, 0, Squirrel.SHY * 0.5)
		await physics_frame
		climbed = climbed or sq.state == "climb"
		high = maxf(high, sq.global_position.y)
		if sq.state == "perch":
			break
	check(climbed and sq.state == "perch", "it runs up the trunk and waits there (%s)" % sq.state)
	check(high > float(sq.tree.height) * Squirrel.CLIMB_TO.x * 0.9, "high up the tree (%.1f of %.1f)" % [high, sq.tree.height])
	check(VillageBirds._flat_distance(sq.global_position, sq.tree.pos) < Squirrel.TRUNK + 0.2, "it clings to the trunk")
	check(not sq.visible, "and is lost among the leaves")
	# It stays while the hero is still there.
	for i in 60 * 14:
		hero.global_position = sq.tree.pos + Vector3(Squirrel.SHY * 0.5, 0, Squirrel.SHY * 0.5)
		await physics_frame
	check(sq.state == "perch", "it stays up while the hero is near (%s)" % sq.state)
	# And comes down when the hero has gone.
	var down := false
	for i in 60 * 20:
		hero.global_position = sq.tree.pos + Vector3(50, 0, 0)
		await physics_frame
		down = down or sq.state == "descend"
		if sq.state in ["sit", "hop"]:
			break
	check(down and sq.state in ["sit", "hop"] and sq.visible, "it comes down when the hero has gone (%s)" % sq.state)
	check(sq.global_position.y < 0.2, "and is on the ground again (%.2f)" % sq.global_position.y)

	# At night they sleep in the trees, out of sight.
	_set_hour(0.5)
	lvl.night = true
	hero.global_position = sq.tree.pos + Vector3(30, 0, 0)
	for i in 60 * 14:
		_set_hour(0.5)
		await physics_frame
		if sq.state == "den":
			break
	check(sq.state == "den" and not sq.visible, "a squirrel sleeps in its tree at night (%s)" % sq.state)
	_set_hour(12.0)
	lvl.night = false
	for i in 60 * 10:
		_set_hour(12.0)
		await physics_frame
		if sq.visible and sq.state != "den":
			break
	check(sq.visible and sq.state != "den", "and wakes at dawn")

	# A bird in a treetop flies off to another tree when the hero comes close.
	var bird: Dictionary = birds.birds[0]
	bird.state = "sit"
	bird.at = bird.home
	var old_home: Vector3 = bird.home
	hero.global_position = lvl.to_global(Vector3(old_home.x + 3.0, 0.0, old_home.z))
	for i in 3:
		await process_frame
	check(bird.state == "fly", "a bird takes off when the hero comes near (%s)" % bird.state)
	check(bird.home != old_home, "to another tree")
	check(VillageBirds._flat_distance(bird.home, lvl.to_local(hero.global_position)) > VillageBirds.WILD_SHY, "away from the hero")
	_finish()


## The sky of the hour, at once.
func _set_hour(hour: float) -> void:
	game.day_hour = hour
	game._tick_clock(0.0)


func _finish() -> void:
	if failures == 0:
		print("PASS")
	else:
		print("FAILED: %d" % failures)
	quit(1 if failures else 0)
