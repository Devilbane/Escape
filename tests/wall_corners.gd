extends SceneTree
## Walls of a built house never share a face: where two wall pieces meet (a corner, a T, a wall
## running on, a door or window between walls) their boxes lie side by side, never over one
## another, and the corner column is filled by one of them. Two faces in one place flicker
## through each other (z-fighting). See HouseSketcher._wall_cuts.
## Run with: godot --headless -s tests/wall_corners.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var sketcher := HouseSketcher.new()
	var house := HouseSketch.new()
	# A closed ring of 3 x 2 cells, a door and a window in its front, and a wall across the middle (a T).
	var edges: Array = []
	for x in 3:
		edges.append([x, 0, HouseSketch.ORIENT_X, HouseSketch.WALL])
		edges.append([x, 2, HouseSketch.ORIENT_X, HouseSketch.DOOR if x == 1 else HouseSketch.WALL])
	for y in 2:
		edges.append([0, y, HouseSketch.ORIENT_Y, HouseSketch.WALL])
		edges.append([3, y, HouseSketch.ORIENT_Y, HouseSketch.WINDOW if y == 1 else HouseSketch.WALL])
	edges.append([1, 0, HouseSketch.ORIENT_Y, HouseSketch.WALL])
	edges.append([1, 1, HouseSketch.ORIENT_Y, HouseSketch.WALL])
	for e: Array in edges:
		house.pieces[HouseSketch.key_of(e[0], e[1], e[2], 0)] = {"kind": e[3], "state": HouseSketch.BUILT}
	# The plan view of each piece's box: x and z ranges in metres.
	var rects: Array = []
	var cell := HouseSketch.CELL
	var half := HouseSketcher.THICK * 0.5
	for e: Array in edges:
		var cut: Vector2 = sketcher._wall_cuts(house, e, 0)
		var along_x: bool = e[2] == HouseSketch.ORIENT_X
		var a := Vector2(e[0] * cell, e[1] * cell)
		var lo := (a.x if along_x else a.y) - half + cut.x
		var hi := (a.x if along_x else a.y) + cell + half - cut.y
		var across := (a.y if along_x else a.x)
		rects.append(Rect2(Vector2(lo, across - half), Vector2(hi - lo, half * 2.0)) if along_x
				else Rect2(Vector2(across - half, lo), Vector2(half * 2.0, hi - lo)))
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var both: Rect2 = (rects[i] as Rect2).intersection(rects[j])
			check(both.get_area() < 1e-6, "wall pieces %s and %s lie side by side, not over one another (overlap %.4f m2)" % [edges[i].slice(0, 3), edges[j].slice(0, 3), both.get_area()])
	# Every node of the ring has its corner column filled.
	for node: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 2), Vector2i(3, 2), Vector2i(1, 0), Vector2i(1, 2)]:
		var middle := Vector2(node.x * cell, node.y * cell)
		var covered := false
		for r: Rect2 in rects:
			if r.grow(0.001).has_point(middle):
				covered = true
		check(covered, "the corner column at node %s is filled" % [node])
	sketcher.free()
	print("FAIL: wall corners" if failures > 0 else "PASS: wall corners")
	quit(1 if failures > 0 else 0)
