extends SceneTree
## Headless test for the way out of a secret room: a level is built again
## with its secret wall closed (a loaded game, a night slept in a bed inside
## the room), so a hero standing in the room must be let out.
## Run with: godot --headless -s tests/secret_exit.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: secret_exit")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


## A floor tile inside the secret room: next to the wall, not reachable from the start.
func _room_cell(lv: Level, s: Dictionary) -> Vector2i:
	var outer := lv._outer_side()
	for d in Level.DIRS:
		var n: Vector2i = s.cell + d
		if not outer.has(n) and lv.cell_char(n) != "#" and lv.cell_char(n) != "?":
			return n
	return Vector2i(-1, -1)


func _test() -> void:
	var tested := 0
	for i in game.level_files.size():
		game.load_level(i)
		var count: int = game.level._secrets.size()
		for k in count:
			# A fresh build for each wall: a reset closes every secret wall again.
			game.load_level(i)
			var lv: Level = game.level
			var s: Dictionary = lv._secrets[k]
			var inside := _room_cell(lv, s)
			if inside.x < 0 or s.open:
				continue
			tested += 1
			var name: String = game.level_files[i]
			# At the start, outside the room, nothing happens.
			check(not lv.free_if_sealed_in(game.player.global_position), "%s: a hero outside the room is not freed" % name)
			check(not s.open, "%s: the wall stays closed for him" % name)
			# A reset while the hero is inside: the wall is closed until the hero is found in there.
			var spot := lv.cell_to_world(inside)
			check(lv.free_if_sealed_in(spot), "%s: a hero inside the closed room is let out" % name)
			check(s.open, "%s: the wall opened from the inside" % name)
			# A chain of sealed rooms is opened one wall after the other, then it is done.
			var rounds := 0
			while lv.free_if_sealed_in(spot) and rounds < 10:
				rounds += 1
			check(not lv.free_if_sealed_in(spot), "%s: in the end nothing is left to open" % name)
	check(tested > 0, "some level has a secret room to test")
	_test_archive_bed_room()


## The archive's bed room lies beside the prisoner's cell, parted from it by
## iron bars. The bars are solid, so the room is a secret room: a hero who
## sleeps in its bed and wakes in a rebuilt level is let out, not shut in.
func _test_archive_bed_room() -> void:
	var idx: int = game.level_files.find("res://levels/34_das_archiv_sonnet.txt")
	if idx < 0:
		for i in game.level_files.size():
			if str(game.level_files[i]).contains("34_das_archiv"):
				idx = i
	check(idx >= 0, "the archive map is in the list")
	if idx < 0:
		return
	game.load_level(idx)
	var lv: Level = game.level
	var bed := Vector2i(-1, -1)
	for st in lv.stations:
		if st.kind == "bett":
			bed = st.cell
	check(bed.x >= 0, "the archive has a bed")
	check(not lv._outer_side().has(bed), "the bed room is not reached through the cell's bars")
	var spot := lv.cell_to_world(bed + Vector2i(-1, 0))
	check(lv.free_if_sealed_in(spot), "a hero waking in the archive's bed room is let out")
