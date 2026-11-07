extends SceneTree
## Headless test for MeleePath, the way a melee monster takes when the plain
## route to its target fails: a target behind a crate or on a blocked tile is
## struck from a neighbouring tile, a target walled off completely makes the
## monster wait at the nearest tile, and the search stays within its radius.
## Run with: godot --headless -s tests/melee_path.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## An open grid of `size` tiles with the given tiles solid.
func _grid(size: int, solid: Array[Vector2i]) -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, size, size)
	a.cell_size = Vector2(1, 1)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	for c in solid:
		a.set_point_solid(c, true)
	return a


func _initialize() -> void:
	# The target stands on a blocked tile (a crate): strike from the next tile.
	var a := _grid(11, [Vector2i(8, 5)])
	var r := MeleePath.approach(a, Vector2i(2, 5), Vector2i(8, 5), 1.0)
	check(r.reached, "a target on a blocked tile can be struck from a neighbour")
	check(r.path.size() == 5 and r.path[-1] == Vector2i(7, 5), "the way ends on the nearest striking tile, got %s" % [r.path])
	check(not r.path.has(Vector2i(8, 5)), "the way never enters the blocked tile")

	# A wall with a gap: the way leads through the gap, not into the wall.
	var wall: Array[Vector2i] = []
	for y in 11:
		if y != 9:
			wall.append(Vector2i(5, y))
	a = _grid(11, wall)
	r = MeleePath.approach(a, Vector2i(2, 5), Vector2i(7, 5), 1.0)
	check(r.reached and r.path.has(Vector2i(5, 9)), "the way goes through the gap in the wall")
	for c: Vector2i in r.path:
		check(not a.is_point_solid(c), "every step is on floor: %s" % [c])

	# No cutting round a corner of two blocked tiles.
	a = _grid(5, [Vector2i(2, 1), Vector2i(1, 2)])
	r = MeleePath.approach(a, Vector2i(1, 1), Vector2i(3, 3), 0.0)
	check(r.reached and r.path.size() >= 3, "a diagonal between two blocks is not walked, got %s" % [r.path])

	# The strike test can veto tiles (no line of sight from them).
	a = _grid(11, [Vector2i(8, 5)])
	var no_west := func(c: Vector2i) -> bool: return c.x >= 8
	r = MeleePath.approach(a, Vector2i(2, 5), Vector2i(8, 5), 1.0, no_west)
	check(r.reached and r.path[-1].x >= 8, "the strike test picks the tile, got %s" % [r.path])

	# Walled off completely: wait at the nearest reachable tile.
	var ring: Array[Vector2i] = []
	for x in range(6, 11):
		for y in range(3, 8):
			if x == 6 or x == 10 or y == 3 or y == 7:
				ring.append(Vector2i(x, y))
	a = _grid(13, ring)
	r = MeleePath.approach(a, Vector2i(1, 5), Vector2i(8, 5), 1.0)
	check(not r.reached, "a target inside a closed ring cannot be reached")
	check(not r.path.is_empty() and r.path[-1].x == 5, "the monster waits at the ring's outside edge, got %s" % [r.path])
	var again := MeleePath.approach(a, r.path[-1], Vector2i(8, 5), 1.0)
	check(again.path.is_empty() or again.path[-1].x == 5, "planning again from the waiting spot stays put, got %s" % [again.path])

	# Already in reach: no steps.
	r = MeleePath.approach(a, Vector2i(1, 5), Vector2i(2, 5), 1.0)
	check(r.reached and r.path.is_empty(), "within reach it takes no step")
	r = MeleePath.approach(a, Vector2i(1, 5), Vector2i(1, 5), 1.0)
	check(r.reached and r.path.is_empty(), "on the target's tile it takes no step")

	# The search is bounded.
	a = _grid(80, [])
	r = MeleePath.approach(a, Vector2i(5, 5), Vector2i(70, 70), 1.0)
	check(not r.reached, "a target beyond the radius is not searched for")
	check(r.path.size() <= MeleePath.RADIUS, "the fallback stays within the radius")

	# A monster starting inside a blocked tile can still leave it.
	a = _grid(7, [Vector2i(3, 3)])
	r = MeleePath.approach(a, Vector2i(3, 3), Vector2i(5, 3), 1.0)
	check(r.reached and r.path[-1] == Vector2i(4, 3), "leaves a blocked start tile, got %s" % [r.path])

	print("PASS: melee_path" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
