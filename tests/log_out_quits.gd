extends SceneTree
## Headless test: "sleep and log out" saves the game first and only then
## closes it. The quit is not called here (it would end the test); the
## `logged_out` signal that comes right before it must find the save already
## on disk, and a failed save keeps the game open.
## Run with: godot --headless --fixed-fps 60 -s tests/log_out_quits.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var seen := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _on_logged_out(saved: bool) -> void:
	seen["saved"] = saved
	# At the moment of logging out the save is already written.
	seen["file"] = FileAccess.file_exists(game.save_path())


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if not started:
		started = true
		game.hero_name = "Log out test"
		game.escaped = false
		game.load_level(2, false)
		game.state = game.State.PLAYING
		game.delete_save(game.save_path())
		game.logged_out.connect(_on_logged_out)
		check(game.quit_on_log_out, "the game quits after logging out by default")
		game.quit_on_log_out = false  # keep the test alive, see Game._log_out
		game.sleep()
		return false
	if seen.has("saved") or frames > 1500:
		check(seen.get("saved", false), "the save went through before logging out")
		check(seen.get("file", false), "the save file exists when the game would close")
		game.delete_save(game.save_path())
		print("PASS: log_out_quits" if failures == 0 else "FAILED: %d" % failures)
		quit(1 if failures > 0 else 0)
	return false
