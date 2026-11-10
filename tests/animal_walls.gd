extends SceneTree
## Headless test: animals walk by the same rules as villagers (see WalkRules):
## - nobody steps into a wall brick or a shut gate, whatever kind of walk it is
##   (a stroll along a path, a dog running up to the hero, a charge);
## - one caught inside a block can step out of it;
## - a walker whose path leads through a gate that has been shut waits on this side;
## - paths keep to the tile centres (as villagers' do) and bodies turn, never snap;
## - a model animal stands still with idle legs the moment it stops (no gliding).
## Run with: godot --headless --fixed-fps 60 -s tests/animal_walls.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game.hero_name = "Animal walkers"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	var wall: VillageWall = lvl.village_wall
	lvl.night = false
	var gate: WallBrick = wall.brick_at(Vector2i(37, 27))
	var brick: WallBrick = wall.brick_at(Vector2i(37, 26))
	var at_gate := gate.global_position
	var outside := at_gate + Vector3(-3, 0, 0)

	# The rule itself.
	check(WalkRules.blocked_at(lvl, brick.global_position), "a brick blocks")
	check(not WalkRules.blocked_at(lvl, at_gate), "an open gate does not block")
	check(not WalkRules.can_step(lvl, outside, brick.global_position), "nobody steps into a wall brick")
	check(WalkRules.can_step(lvl, outside, at_gate), "an open gate lets anyone through")
	check(WalkRules.can_step(lvl, brick.global_position, outside), "one caught inside a block can step out")
	check(WalkRules.can_step(lvl, outside, outside + Vector3(0.5, 0, 0)), "ordinary ground is fine")

	# Every kind of animal keeps out of a shut gate while walking a path through it.
	var walkers: Array = []
	var farm: Array = lvl.farm_animals
	for k in ["goose", "goat", "sheep", "dog", "cow", "bull", "billy"]:
		var pick = farm.filter(func(a: FarmAnimal): return a.kind == k)
		if not pick.is_empty():
			walkers.append(pick[0])
	if not lvl.animals.is_empty():
		walkers.append(lvl.animals[0])
	check(walkers.size() >= 4, "several kinds of animal live here (%d)" % walkers.size())
	gate.shut = true
	wall.changed(gate)
	check(WalkRules.blocked_at(lvl, at_gate), "a shut gate blocks")
	for a in walkers:
		a.global_position = outside
		a._begin("idle", 600.0)
		a._path.clear()
		a._path.append(at_gate)
		a._path.append(at_gate + Vector3(3, 0, 0))
		a._speed = 1.0
		a.state = "stroll"
		a.set_physics_process(true)
	# Hero out of everyone's way so nobody bolts or comes over.
	game.player.global_position = outside + Vector3(-60, 0, 0)
	for i in 120:
		await physics_frame
		for a in walkers:
			check(not WalkRules.blocked_at(lvl, a.global_position), "%s never stands in the shut gate (%s)" % [a.get("kind"), a.global_position])
	for a in walkers:
		check(a.global_position.x < at_gate.x, "%s waits on the outer side of the shut gate (%s)" % [a.get("kind"), a.global_position])
	# Later they may go round another way, never through.
	for i in 300:
		await physics_frame
		for a in walkers:
			check(not WalkRules.blocked_at(lvl, a.global_position), "%s never crossed the shut gate (%s)" % [a.get("kind"), a.global_position])
	gate.shut = false
	wall.changed(gate)

	# Paths keep to tile centres, within the same jitter as the villagers'.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var from := lvl.cell_to_world(Vector2i(30, 30))
	var to := lvl.cell_to_world(Vector2i(34, 30))
	var path := WalkRules.path(lvl, from, to, rng)
	check(not path.is_empty(), "there is a path over open ground")
	for p in path:
		var c := lvl.cell_to_world(lvl.world_to_cell(p))
		check(absf(p.x - c.x) <= WalkRules.JITTER + 0.001 and absf(p.z - c.z) <= WalkRules.JITTER + 0.001, "path points stay near their tile centre")

	# Turning is smooth: one tick turns only part of the way.
	var body := Node3D.new()
	root.add_child(body)
	body.rotation.y = 0.0
	WalkRules.turn(body, Vector3(1, 0, 0), 1.0 / 60.0)
	check(body.rotation.y > 0.0 and body.rotation.y < PI / 2.0 - 0.2, "a body turns, it does not snap (%f)" % body.rotation.y)
	body.queue_free()

	# A model animal stops walking the moment it stops moving.
	var deer: Animal = lvl.animals[0] if not lvl.animals.is_empty() else null
	if deer != null:
		game.player.global_position = deer.global_position + Vector3(-80, 0, 0)
		deer._path.clear()
		deer._begin("idle", 600.0)
		await _wait(5)
		check(deer._current_anim == "Idle", "an idle deer plays its idle animation (%s)" % deer._current_anim)
	for a in farm:
		if a._anim != null and a.state in ["idle", "graze"] and a.global_position.distance_to(game.player.global_position) < FarmAnimal.ACTIVE_RANGE:
			check(a._swing == 0.0, "a standing %s has no leg swing" % a.kind)

	if failures == 0:
		print("PASS: animal walls")
	else:
		print("FAILED: ", failures)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
