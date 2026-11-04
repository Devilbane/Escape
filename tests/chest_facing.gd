extends SceneTree
## Headless test for how chests stand (Level._back_to_wall): a chest beside a
## wall turns its back, a long side, to that wall and opens towards the room.
## Checked on small made-up rooms and on every chest of every dungeon map.
## Run with: godot --headless -s tests/chest_facing.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_check_rooms()
	_check_maps()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The way a chest turned by `rot` opens, as a step on the grid.
func _front(rot: float) -> Vector2i:
	return Vector2i(roundi(sin(rot)), roundi(cos(rot)))


func _level(rows: Array[String]) -> Level:
	var lv := Level.new()
	lv.grid = rows
	lv.height = rows.size()
	lv.width = rows[0].length()
	return lv


func _check_rooms() -> void:
	var lv := _level([
		"#######",
		"#C...C#",
		"#.....#",
		"C..C..#",
		"#x.C..#",
		"#C#####",
	])
	# Against the north wall in a corner: the open floor wins over the wall.
	check(_front(lv._back_to_wall(Vector2i(1, 1))) in [Vector2i(0, 1), Vector2i(1, 0)],
			"a chest in a corner opens into the room")
	check(_front(lv._back_to_wall(Vector2i(5, 1))) in [Vector2i(0, 1), Vector2i(-1, 0)],
			"a chest in the other corner opens into the room")
	# Only an east or west wall: it faces across the room, not along the wall.
	var east := _level(["#####", "#..C#", "#####"])
	check(_front(east._back_to_wall(Vector2i(3, 1))) == Vector2i(-1, 0), "a chest by an east wall opens west")
	var west := _level(["#####", "#C..#", "#####"])
	check(_front(west._back_to_wall(Vector2i(1, 1))) == Vector2i(1, 0), "a chest by a west wall opens east")
	var south := _level(["#####", "#...#", "#.C.#", "#####"])
	check(_front(south._back_to_wall(Vector2i(2, 2))) == Vector2i(0, -1), "a chest by a south wall opens north")
	# A crate in front of one wall: the chest turns to the other.
	check(_front(lv._back_to_wall(Vector2i(1, 5))) == Vector2i(0, -1), "a chest in a niche opens out of it")
	# No wall beside it: it keeps the way it was given.
	check(is_equal_approx(lv._back_to_wall(Vector2i(3, 3), 1.25), 1.25), "a chest in the open keeps its turn")
	lv.free()
	east.free()
	west.free()
	south.free()


## On the shipped maps, every chest beside a wall has a wall at its back and
## no wall in front of its lid.
func _check_maps() -> void:
	var dir := DirAccess.open("res://levels")
	var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".txt"))
	check(files.size() > 0, "no level files found")
	var seen := 0
	for file in files:
		var path: String = "res://levels/" + file
		if Level.is_outdoor_file(path):
			continue
		var lv := Level.new()
		lv.load_from_file(path)
		lv._clear_passages()
		for y in lv.height:
			for x in lv.width:
				var c := Vector2i(x, y)
				if not "Ck&L".contains(lv.cell_char(c)):
					continue
				var walled := false
				for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
					walled = walled or Level.CHEST_WALLS.contains(lv.cell_char(c + d))
				if not walled:
					continue
				seen += 1
				var front := _front(lv._back_to_wall(c, INF))
				check(Level.CHEST_WALLS.contains(lv.cell_char(c - front)),
						"%s: the chest at %s has no wall at its back" % [file, c])
				check(not Level.CHEST_WALLS.contains(lv.cell_char(c + front)),
						"%s: the chest at %s opens into a wall" % [file, c])
		lv.free()
	check(seen > 10, "too few chests beside walls found on the maps (%d)" % seen)
