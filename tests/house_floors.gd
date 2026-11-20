extends SceneTree
## Headless test for where a companion can walk round a house (see HouseFloors):
## down into a cellar and up to an upper floor only by built stairs, never into
## a pit without stairs, and it waits at the rim instead.
## Run with: godot --headless -s tests/house_floors.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _built(house: HouseSketch, key: String, kind: String) -> void:
	house.pieces[key] = {"kind": kind, "state": HouseSketch.BUILT}


func _initialize() -> void:
	var house := HouseSketch.new()
	house.plot = Rect2i(10, 10, 4, 4)
	# A cellar of 2 x 2 squares with stairs down from the west (cells 0 and 1 of row 2).
	for c in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
		_built(house, HouseSketch.key_of(c.x, c.y, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY), HouseSketch.DIG)
	_built(house, HouseSketch.key_of(0, 2, "e", HouseSketch.CELLAR_STOREY), HouseSketch.STAIRS)
	# A pit of one square with no stairs.
	_built(house, HouseSketch.key_of(6, 6, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY), HouseSketch.DIG)
	# A sketched (not yet dug) square is still ground.
	house.pieces[HouseSketch.key_of(6, 0, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": HouseSketch.SKETCH}
	var floors := HouseFloors.new([house])
	var down := HouseSketch.DEPTH

	var ground := house.cell_world(5, 0)
	var cellar := house.cell_world(3, 3) + Vector3(0, -down, 0)
	var pit := house.cell_world(6, 6) + Vector3(0, -down, 0)
	check(floors.covers(ground) and floors.covers(house.cell_world(-2, -2)), "the floors cover the plot and its margin")
	check(not floors.covers(house.cell_world(-9, -9)), "the floors end a little beyond the plot")
	check(floors.storey_at(ground) == HouseFloors.GROUND, "beside the house is open ground")
	check(floors.storey_at(cellar) == HouseFloors.CELLAR, "down in the dug squares is the cellar")
	check(floors.storey_at(house.cell_world(6, 0)) == HouseFloors.GROUND, "a square only sketched is not dug yet")

	# Down the stairs: the way goes over the ramp, never down a pit wall.
	check(floors.reachable(ground, cellar), "the cellar with stairs is reached from the ground")
	var way := floors.route(ground, cellar)
	check(way.reached and not way.points.is_empty(), "there is a way down the stairs")
	var last_y := 0.0
	var smooth := true
	var over_stairs := false
	var top: Vector3 = house.cell_world(0, 2)
	for p: Vector3 in way.points:
		if absf(p.y - last_y) > down * 0.5 + 0.01:
			smooth = false
		last_y = p.y
		if HouseFloors.cell_of(p) == HouseFloors.cell_of(top):
			over_stairs = true
	check(smooth, "the way down never drops more than half a ramp at once")
	check(over_stairs, "the way down goes over the top of the stairs")
	check(is_equal_approx(way.points[-1].y, -down), "the way ends on the cellar floor")
	check(floors.route(cellar, ground).reached, "and back up the stairs")
	var middle := house.cell_world(1, 2) + Vector3(HouseSketch.CELL * 0.5, 0, 0)
	check(is_equal_approx(floors.height(floors.node_at(middle + Vector3(0, -down, 0)), middle), -down), "the ramp reaches the cellar floor at its foot")

	# A pit without stairs: no way in, and no way out.
	check(not floors.reachable(ground, pit), "a pit without stairs cannot be reached")
	check(not floors.reaches_ground(pit), "a pit without stairs has no way up")
	check(floors.reaches_ground(cellar), "a cellar with stairs has a way up")
	var rim := floors.route(ground, pit)
	check(not rim.reached, "the walk towards a hero in the pit does not get there")
	var stop: Vector3 = rim.points[-1] if not rim.points.is_empty() else ground
	check(is_zero_approx(stop.y) and Vector2(stop.x - pit.x, stop.z - pit.z).length() <= HouseSketch.CELL * 1.01, "it stops on the ground at the rim (%s)" % stop)
	check(floors.storey_at(floors.nearest_ground(pit)) == HouseFloors.GROUND, "the nearest ground to the pit is open ground")
	# Not even from the cellar next door: the pit walls stay walls.
	check(not floors.reachable(cellar, pit), "the cellar does not lead into the pit")

	# Up a floor: only by the stairs up.
	var up := HouseSketch.new()
	up.plot = Rect2i(30, 10, 3, 3)
	_built(up, HouseSketch.key_of(3, 1, HouseSketch.CELL_ORIENT, 0), HouseSketch.SLAB)
	_built(up, HouseSketch.key_of(4, 1, HouseSketch.CELL_ORIENT, 0), HouseSketch.SLAB)
	var floors2 := HouseFloors.new([up])
	var upper := up.cell_world(4, 1) + Vector3(0, HouseSketch.STOREY_HEIGHT, 0)
	check(floors2.storey_at(upper) == HouseFloors.UPPER, "on the slab is the upper floor")
	check(not floors2.reachable(up.cell_world(0, 0), upper), "an upper floor without stairs cannot be reached")
	_built(up, HouseSketch.key_of(1, 1, "e", 0), HouseSketch.UPSTAIRS)
	floors2 = HouseFloors.new([up])
	check(floors2.reachable(up.cell_world(0, 0), upper), "the stairs up lead to the upper floor")
	check(floors2.route(upper, up.cell_world(0, 4)).reached, "and back down")
	check(floors2.storey_at(up.cell_world(1, 1)) == HouseFloors.GROUND, "under the foot of the stairs up is still ground")

	print("PASS: house floors" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
