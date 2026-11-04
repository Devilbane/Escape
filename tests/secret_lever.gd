extends SceneTree
## Headless test for the secret wall's lever torch: it is never one of the
## torches by the stairs, so climbing on to the next level does not open the
## secret room. In Die Zuflucht those are the torch on the stairs and the two
## in the alcove before them; the lever hangs in the hall in front of the
## secret wall instead.
## Run with: godot --headless -s tests/secret_lever.gd

var failures := 0
var game: Node
var frames := 0
## How often Die Zuflucht is built: its lever is a new torch each run.
const RUNS := 30
## How often every other level with a secret wall is built.
const OTHER_RUNS := 4


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
		print("PASS: secret_lever")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _test() -> void:
	var refuge: int = game.level_files.find("res://levels/05_die_zuflucht.txt")
	check(refuge >= 0, "Die Zuflucht is a level")
	var levers := {}
	for i in RUNS:
		game.load_level(refuge)
		var lv: Level = game.level
		check(lv._secrets.size() == 1, "Die Zuflucht has one secret wall")
		for s in lv._secrets:
			check(s.lever != null, "Die Zuflucht's secret wall has a lever")
			check(not lv._on_way_out(s.lever_cell), "Die Zuflucht's lever is not by the stairs: %s" % s.lever_cell)
			check(s.lever_cell.y >= 3, "Die Zuflucht's lever hangs in the hall, not the stairs alcove: %s" % s.lever_cell)
			levers[s.lever_cell] = true
	check(levers.size() > 1, "Die Zuflucht's lever is a different torch from run to run")
	# Every level with a secret wall follows the same rule.
	for i in game.level_files.size():
		for run in OTHER_RUNS:
			game.load_level(i)
			var lv: Level = game.level
			for s in lv._secrets:
				check(s.lever != null, "%s: the secret wall has a lever" % game.level_files[i])
				if s.lever == null or s.lever_on_wall:
					continue # The torch on the secret wall itself is always fine.
				check(not lv._on_way_out(s.lever_cell), "%s: the lever is not by the stairs: %s" % [game.level_files[i], s.lever_cell])
