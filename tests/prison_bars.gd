extends SceneTree
## Headless test: a prison cell is closed by its bars. A run of iron bars is
## turned with the wall it belongs to (Level.bars_rotation), so a column of bars
## is a solid wall north to south and not a row of loose slabs with gaps
## between the tiles that a prisoner (or the hero) could walk through.
## Run with: godot --headless -s tests/prison_bars.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var across := 0.0
	var along := PI * 0.5
	# Left, right, above, below.
	check(Level.bars_rotation("#", "#", ".", ".") == across, "bars between two walls west and east span west to east")
	check(Level.bars_rotation(".", ".", "#", "#") == along, "bars between two walls north and south run north to south")
	check(Level.bars_rotation("#", ".", "#", "=") == along, "a column of bars hanging on a wall runs north to south")
	check(Level.bars_rotation(".", ".", "=", "=") == along, "bars in a column of bars run north to south")
	check(Level.bars_rotation("=", "=", ".", ".") == across, "bars in a row of bars span west to east")
	check(Level.bars_rotation(".", ".", ".", ".") == across, "lone bars keep the old default")

	# A barred door between two stretches of cell bars ("=/=") lies across them.
	check(Level.bars_rotation("=", "=", ".", ".") == across, "a barred door between cell bars spans west to east")

	# The prisoner's cell of the archive (Brother Orlan): a column of bars on each side.
	var rows := _map_rows("res://levels/34_das_archiv_sonnet.txt")
	check(rows.size() > 13, "the archive map was read")
	if rows.size() > 13:
		for c in [Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(5, 10), Vector2i(5, 11), Vector2i(5, 12)]:
			check(_at(rows, c) == "=", "the archive has bars at %s" % c)
			var rot := Level.bars_rotation(_at(rows, c + Vector2i(-1, 0)), _at(rows, c + Vector2i(1, 0)), _at(rows, c + Vector2i(0, -1)), _at(rows, c + Vector2i(0, 1)))
			check(rot == along, "the cell's bars at %s run north to south" % c)
		var door := Vector2i(4, 13)
		check(_at(rows, door) == "=", "the archive has bars at the foot of the cell")
		check(Level.bars_rotation(_at(rows, door + Vector2i(-1, 0)), _at(rows, door + Vector2i(1, 0)), _at(rows, door + Vector2i(0, -1)), _at(rows, door + Vector2i(0, 1))) == across, "the bars at the foot of the cell span west to east")

	if failures == 0:
		print("PASS: prison bars")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _at(rows: Array, c: Vector2i) -> String:
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
		return ""
	return rows[c.y][c.x]


## The map lines of a level file (everything after the header lines).
func _map_rows(path: String) -> Array:
	var rows := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	for line in f.get_as_text().split("\n"):
		if line.begins_with("#") and not line.begins_with("# "):
			rows.append(line)
	return rows
