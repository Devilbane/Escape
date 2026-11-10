extends SceneTree
## Headless test: the cattle pen on the village's east meadow (see Corral):
## - the fence is on the map, its tiles are no ground to walk on, and the hero, the villagers
##   and the animals cannot pass it; the gate is the one way in;
## - the cows and the bull start inside the pen, and keep inside it while they graze, stroll and
##   bolt from a hero who comes too close.
## Run with: godot --headless --fixed-fps 60 -s tests/corral.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
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


func _in_pen(lvl: Outdoor, a: FarmAnimal) -> bool:
	return Corral.PEN.has_point(lvl.world_to_cell(a.global_position))


func _run() -> void:
	game.hero_name = "Herdsman"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(3)
	var lvl: Outdoor = game.level as Outdoor
	lvl.night = false
	check(Corral.present(lvl), "the village map has the pen")

	# The fence line: a closed ring round the pen with the gate on the north side.
	var ring := Rect2i(Corral.PEN.position - Vector2i.ONE, Corral.PEN.size + Vector2i(2, 2))
	var gates := 0
	var fences := 0
	for x in range(ring.position.x, ring.end.x):
		for y in range(ring.position.y, ring.end.y):
			var c := Vector2i(x, y)
			if Corral.PEN.has_point(c):
				continue
			var ch := lvl.cell_char(c)
			if ch == Corral.GATE:
				gates += 1
				check(lvl.is_open(c), "the gate is open ground")
			elif ch == Corral.FENCE:
				fences += 1
				check(not lvl.is_open(c), "a fence tile is no ground to walk on %s" % c)
	check(gates == 1, "one gate (%d)" % gates)
	check(fences >= 8, "the fence is there (%d)" % fences)

	# From the pen to the road the only way out is the gate.
	var gate := Vector2i(Corral.PEN.position.x + 1, Corral.PEN.position.y - 1)
	var inside := Corral.PEN.position + Vector2i(1, 1)
	var road := gate + Vector2i(0, -4)
	check(lvl.is_open(road), "the road in front of the gate is open")
	var path: Array[Vector2i] = lvl.grid_path(inside, road)
	check(not path.is_empty() and path.has(gate), "the way from the pen to the road leads through the gate")
	for c in path:
		check(lvl.cell_char(c) != Corral.FENCE, "the way crosses no fence %s" % c)

	# The hero cannot walk through the fence (but through the gate).
	var space := lvl.get_world_3d().direct_space_state
	var fence_at := lvl.cell_to_world(Vector2i(Corral.PEN.position.x + 2, Corral.PEN.position.y - 1))
	var ray := PhysicsRayQueryParameters3D.create(fence_at + Vector3(0, 0.8, -3.0), fence_at + Vector3(0, 0.8, 3.0))
	check(not space.intersect_ray(ray).is_empty(), "the fence stops the hero")
	var gate_at := lvl.cell_to_world(gate)
	ray = PhysicsRayQueryParameters3D.create(gate_at + Vector3(0, 0.8, -3.0), gate_at + Vector3(0, 0.8, 3.0))
	check(space.intersect_ray(ray).is_empty(), "the gate lets the hero through")

	# Nobody who walks the village steps into the fence (see WalkRules).
	check(WalkRules.blocked_at(lvl, fence_at), "the shared walk rules block the fence")
	check(not WalkRules.blocked_at(lvl, gate_at), "the shared walk rules let the gate through")
	# A villager does not step into the fence.
	var v: Villager = lvl.villagers[0]
	check(v.blocked_at(fence_at), "a villager is blocked by the fence")
	check(not v.blocked_at(gate_at), "the gate does not block a villager")

	# The herd starts inside.
	var cattle: Array = lvl.farm_animals.filter(func(a: FarmAnimal): return a.kind in ["cow", "bull"])
	check(cattle.size() == 3, "two cows and a bull (%d)" % cattle.size())
	for a: FarmAnimal in cattle:
		check(_in_pen(lvl, a), "%s starts in the pen" % a.kind)
		check(a.pen == Corral.PEN, "%s knows its pen" % a.kind)

	# And never leaves: while it strolls, and while the hero scares it from all sides.
	var hero: Node3D = lvl.player
	var ever_fled := false
	for round in 4:
		var side: Vector2i = [Vector2i(-2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(2, 0)][round]
		var middle := Corral.PEN.position + Corral.PEN.size / 2
		hero.global_position = lvl.cell_to_world(middle + side / 2)
		for i in 15:
			await _wait(60)
			for a: FarmAnimal in cattle:
				check(_in_pen(lvl, a), "%s stays in the pen (%s, %s)" % [a.kind, a.global_position, a.state])
				ever_fled = ever_fled or a.is_fleeing()
	check(ever_fled, "the herd was scared at least once")
	print("PASS: the cattle pen" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
