extends SceneTree
## Headless test for testing a map from the map workshop (see
## LevelEditor.playtest and Game.PLAYTEST_FLAG): the game starts right on the
## map with a new hero, the map's own monster, person and gear are there,
## nothing is saved, and leaving by the stairs goes back to the workshop with
## the map still open.
## Run with: godot --headless -s tests/playtest_map.gd

var failures := 0
var frames := 0
var editor: LevelEditor
var game: Node
var _step := 0

const MAP := """name: Probe
hint: Eine Probe.
custom: 1 {"type": "monster", "base": "schleim", "name": "Riesenschleim", "hp": 12, "size": 1.6}
custom: 2 {"type": "npc", "name": "Wirtin Edda", "model": "Rogue", "sex": "female", "lines": ["Willkommen!"]}
custom: 3 {"type": "item", "id": "eigen_testring", "base": "kupferring", "name": "Testring", "power": 2}
###########
#####E#####
#.........#
#..1...3..#
#.........#
#..2......#
#....P....#
###########
"""


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.setup()
	editor = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)


func _process(_delta: float) -> bool:
	frames += 1
	match _step:
		0:
			if frames < 4:
				return false
			editor.map = LevelMap.parse(MAP)
			editor.file_path = ""
			editor._after_load()
			editor.dirty = true
			check(not LevelMap.has_errors(editor.issues), "the test map has errors: %s" % [editor.issues])
			editor.playtest()
			editor.queue_free()
			_step = 1
			frames = 0
		1:
			if frames < 8:
				return false
			game = current_scene
			check(game != null and game.get("playtest_file") != null, "the game did not start")
			if game == null or game.get("playtest_file") == null:
				return _finish()
			check(game.playtest_file == LevelEditor.TEST_FILE, "the game does not test the map: %s" % game.playtest_file)
			check(game.level.playtest and game.level.level_name == "Probe", "the game is not on the tested map")
			check(game.state == game.State.PLAYING, "the test does not start at once")
			check(game.level.enemies.any(func(e): return e.custom.get("title", "") == "Riesenschleim"), "the map's monster is missing")
			check(game.level.stations.any(func(s): return s.kind == "figur"), "the map's person is missing")
			check(Items.ALL.has("eigen_testring"), "the map's gear is unknown")
			check(not game.save_game(), "a test saves the game")
			check(not Training.keep, "a test keeps what the hero learned")
			game._next_level()
			_step = 2
			frames = 0
		2:
			if frames < 8:
				return false
			var back := current_scene
			check(back is LevelEditor, "the stairs do not lead back to the workshop")
			if back is LevelEditor:
				check(back.map.get_header("name") == "Probe", "the workshop lost the tested map")
				check(back.dirty, "the workshop forgot the map was not saved")
			return _finish()
	return false


func _finish() -> bool:
	Training.keep = true
	if FileAccess.file_exists(LevelEditor.TEST_FILE):
		DirAccess.remove_absolute(LevelEditor.TEST_FILE)
	print("PASS: playtest map" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
	return true
