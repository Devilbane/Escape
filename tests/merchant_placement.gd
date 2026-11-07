extends SceneTree
## Headless test: a merchant (map letter V) in a dungeon map stands in the open
## middle of its room, not at the rim or in a corner: all eight cells around it
## are floor (not wall, not off the map), so it is seen from every side and
## never blocks a doorway or a corridor.
## Run with: godot --headless -s tests/merchant_placement.gd

var failures := 0
var merchants := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for f in DirAccess.get_files_at("res://levels/"):
		if not f.ends_with(".txt"):
			continue
		var m := LevelMap.parse(FileAccess.get_file_as_string("res://levels/" + f))
		if m.is_outdoor():
			continue  # outdoors "V" is a stag
		for c in m.find_all("V"):
			merchants += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					check(m.in_bounds(n) and m.cell(n) != "#", "%s: the merchant at %s is at a rim or corner (wall at %s)" % [f, c, n])
	check(merchants > 0, "no merchant found in any map")
	print("PASS" if failures == 0 else "FAILED", ": merchant_placement, %d merchants" % merchants)
	quit(1 if failures else 0)
