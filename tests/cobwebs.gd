extends SceneTree
## Headless test for the cobwebs (DungeonLife): every dungeon floor has
## plenty of them, of several kinds, spread out instead of piled up. None
## hangs over a floor grate, a door, a trap or the stairs, none reaches the
## floor of a corridor, and none sits by a wall torch.
## Run with: godot --headless --fixed-fps 60 -s tests/cobwebs.gd

var failures := 0
var game: Node
var frames := 0
var index := 0
var wait := 0
var total := 0
var floors := 0
var kinds := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	check(floors > 0, "some floors have cobwebs at all")
	# Webs between two pieces of furniture are rare: furniture seldom stands
	# on neighbouring tiles.
	for k in ["corner", "low_corner", "ledge", "prop", "prop_wall"]:
		check(kinds.get(k, 0) > 0, "some cobwebs are of the kind '%s'" % k)
	if failures == 0:
		print("PASS: cobwebs (%d webs on %d floors: %s)" % [total, floors, kinds])
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _check_level() -> void:
	var lvl: Level = game.level
	var file: String = game.level_files[index]
	var life: DungeonLife = lvl.get_node_or_null("DungeonLife")
	if life == null:
		return
	floors += 1
	var webs := life.webs
	total += webs.size()
	if OS.get_environment("VERBOSE") != "":
		print(file, " ", webs.size())
	var open := 0
	for y in lvl.height:
		for x in lvl.width:
			if DungeonLife.OPEN_FLOOR.contains(lvl.cell_char(Vector2i(x, y))):
				open += 1
	# Most floors have a web for every eight tiles or so; the hot mines and
	# caves fewer, but never less than one for every thirty.
	check(webs.size() * 30 >= open, "%s: %d cobwebs on %d tiles of floor" % [file, webs.size(), open])
	for i in webs.size():
		var w: Dictionary = webs[i]
		kinds[w.kind] = kinds.get(w.kind, 0) + 1
		var mid := Vector2(w.mid.x, w.mid.z)
		for j in i:
			var o: Dictionary = webs[j]
			var gap := mid.distance_to(Vector2(o.mid.x, o.mid.z))
			check(gap >= DungeonLife.WEB_SPACING - 0.001, "%s: two cobwebs only %.2f apart at %s" % [file, gap, lvl.world_to_cell(w.mid)])
		for spot: Vector3 in lvl._torch_spots:
			check(mid.distance_to(Vector2(spot.x, spot.z)) >= DungeonLife.WEB_TORCH_GAP, "%s: a cobweb by the torch at %s" % [file, lvl.world_to_cell(spot)])
		for p: Vector3 in w.points:
			var c := lvl.world_to_cell(p)
			var ch := lvl.cell_char(c)
			check(not lvl.grates.has(c), "%s: a cobweb over the grate at %s" % [file, c])
			check(ch == "#" or DungeonLife.OPEN_FLOOR.contains(ch) or DungeonLife.WEBBED.contains(ch),
				"%s: a cobweb reaches the tile '%s' at %s" % [file, ch, c])
			if p.y < 0.6 and w.kind != "low_corner" and DungeonLife.OPEN_FLOOR.contains(ch):
				var corridor := (lvl.cell_char(c + Vector2i(1, 0)) == "#" and lvl.cell_char(c + Vector2i(-1, 0)) == "#") \
					or (lvl.cell_char(c + Vector2i(0, 1)) == "#" and lvl.cell_char(c + Vector2i(0, -1)) == "#")
				check(not corridor, "%s: a cobweb lies on the floor of the corridor at %s" % [file, c])


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if game.player:
		game.player.hp = game.player.max_hp
	if wait == 0:
		if index >= game.level_files.size():
			_finish()
			return true
		game.hero_name = "Cobweb test"
		game.load_level(index, false)
		game.state = game.State.PLAYING
	wait += 1
	if wait >= 3:
		_check_level()
		index += 1
		wait = 0
	return false
