extends SceneTree
## Headless test for look-alike furniture (Level.LOOKALIKES): two chests, or
## two boards of one kind, never stand on touching tiles, not even corner to
## corner. Checked on every dungeon map as written, and again after
## Level._clear_passages has moved furniture out of the way.
## Run with: godot --headless -s tests/furniture_spacing.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_check_groups()
	_check_maps()
	_check_moved_furniture()
	await _check_wall_pieces()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Every chest is in the chests' group, and the groups do not overlap.
func _check_groups() -> void:
	var group := Level.lookalike_group("C")
	check(group != "" and group == Level.lookalike_group("k") and group == Level.lookalike_group("L"),
			"treasure chest, trunk and storage chest are one group")
	check(Level.lookalike_group("t") != "", "tables are a group")
	check(Level.lookalike_group("j") != "", "pit props are a group")
	check(Level.lookalike_group(".") == "", "open floor is in no group")
	var seen := {}
	for g in Level.LOOKALIKES:
		for ch in g:
			check(not seen.has(ch), "the letter '%s' is in two groups of Level.LOOKALIKES" % ch)
			seen[ch] = true


func _check_maps() -> void:
	var dir := DirAccess.open("res://levels")
	var files := Array(dir.get_files()).filter(func(f): return f.ends_with(".txt"))
	check(files.size() > 0, "no level files found")
	for file in files:
		var path: String = "res://levels/" + file
		if Level.is_outdoor_file(path):
			continue
		var lv := Level.new()
		lv.load_from_file(path)
		_check_grid(lv, file + " (as written)")
		lv._clear_passages()
		_check_grid(lv, file + " (after clearing the passages)")
		lv.free()


## No two pieces of one look-alike group on touching tiles.
func _check_grid(lv: Level, what: String) -> void:
	for y in lv.height:
		for x in lv.width:
			var c := Vector2i(x, y)
			var group := Level.lookalike_group(lv.cell_char(c))
			if group == "":
				continue
			# Only look ahead, so each pair is reported once.
			for d in [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				var n: Vector2i = c + d
				check(not group.contains(lv.cell_char(n)), "%s: '%s' at %s touches '%s' at %s"
						% [what, lv.cell_char(c), c, lv.cell_char(n), n])


## Furniture moved out of a passage does not land beside one of its kind.
func _check_moved_furniture() -> void:
	var lv := Level.new()
	lv.grid = [
		"#########",
		"#P......#",
		"#.......#",
		"#.......#",
		"####C####",
		"#.......#",
		"#.k.k.k.#",
		"#.......#",
		"#########",
	]
	lv.height = lv.grid.size()
	lv.width = 9
	# The chest blocks the only way down: it has to move, and not next to a
	# trunk, though every free tile below the gap touches one.
	lv._clear_passages()
	check(lv.cell_char(Vector2i(4, 4)) != "C", "the chest left the passage")
	var chest := Vector2i(-1, -1)
	for y in lv.height:
		var x: int = lv.grid[y].find("C")
		if x >= 0:
			chest = Vector2i(x, y)
	check(chest.x >= 0, "the chest was set down again")
	_check_grid(lv, "moved chest")
	lv.free()


## Bookcases and wall decorations of one kind hang at least Level.WALL_GAP
## apart, on every dungeon map as built.
func _check_wall_pieces() -> void:
	await process_frame
	var dir := DirAccess.open("res://levels")
	var shelves_seen := 0
	for file in dir.get_files():
		var path: String = "res://levels/" + file
		if not file.ends_with(".txt") or Level.is_outdoor_file(path):
			continue
		var lv := Level.new()
		lv.load_from_file(path)
		root.add_child(lv)
		lv.build()
		var pieces: Array = lv._wall_pieces
		for obj in lv.interactables:
			if obj.label == "Regal":
				shelves_seen += 1
		check(lv.interactables.filter(func(o): return o.label == "Regal").size()
				== pieces.filter(func(w): return w.kind == "shelves").size(),
				"%s: every searchable bookcase is a counted one" % file)
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				var a: Dictionary = pieces[i]
				var b: Dictionary = pieces[j]
				if a.kind == b.kind:
					check(a.pos.distance_to(b.pos) >= Level.WALL_GAP, "%s: two %s at %s and %s"
							% [file, a.kind, a.pos, b.pos])
		lv.queue_free()
		await process_frame
	check(shelves_seen > 10, "the dungeon still has bookcases (%d)" % shelves_seen)
