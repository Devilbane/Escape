extends SceneTree
## Headless test for the floor grates: nothing is placed on one. On every
## floor of the game a grate lies only on plain floor ("."), never under a
## letter of the map (a merchant, a bed, a chest, the start, ...), and no
## trap or hidden find of the fox sits on one. Every grate tile the level
## built is listed in Level.grates.
## Run with: godot --headless --fixed-fps 60 -s tests/grates_clear.gd

var failures := 0
var game: Node
var frames := 0
var index := 0
var wait := 0
var grates_seen := 0


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
	check(grates_seen > 0, "the floors have grates at all")
	if failures == 0:
		print("PASS: grates clear (%d grates on %d floors)" % [grates_seen, game.level_files.size()])
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _check_level() -> void:
	var lvl: Level = game.level
	var file: String = game.level_files[index]
	for child in lvl.get_children():
		if child is Node3D and child.scene_file_path.ends_with("floor_tile_big_grate.glb"):
			var c: Vector2i = lvl.world_to_cell(child.position)
			check(lvl.grates.has(c), "%s: the grate at %s is listed" % [file, c])
	for c: Vector2i in lvl.grates:
		grates_seen += 1
		check(lvl.cell_char(c) == ".", "%s: the grate at %s lies on plain floor, not under '%s'" % [file, c, lvl.cell_char(c)])
	if lvl.traps:
		for t in lvl.traps.traps:
			check(not lvl.grates.has(t.cell), "%s: no trap on the grate at %s" % [file, t.cell])
	for f in lvl.hidden_finds:
		check(not lvl.grates.has(f.cell), "%s: nothing hidden under the grate at %s" % [file, f.cell])


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
		game.hero_name = "Grate test"
		game.load_level(index, false)
		game.state = game.State.PLAYING
	wait += 1
	if wait < 4:
		return false
	_check_level()
	index += 1
	wait = 0
	return false
