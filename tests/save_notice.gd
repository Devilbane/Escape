extends SceneTree
## Headless test for the "Game saved" plate (see SaveNotice): every save shows
## it in the top right corner, it fades away on its own (also while a window
## pauses the world), a second save starts it over, and it moves no other part
## of the HUD.
## Run with: godot --headless -s tests/save_notice.gd
## With SHOTS=<folder> and a display it also saves a screenshot there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	if shots != "":
		Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 2) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s, true).timeout


## Where every HUD control is, so the test can tell that nothing moved (the
## message lines are left out: they follow the hero over the world).
func _hud_rects() -> Dictionary:
	var out := {}
	for c in game._hud.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c != game._message_box and not game._message_box.is_ancestor_of(c):
			out[c.get_path()] = c.get_global_rect()
	return out


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Save notice test"
	game.load_level(game._outdoor_index(), false)
	await _wait(20)
	var notice: SaveNotice = game.save_notice
	check(notice != null, "the game has a save notice")
	check(not notice.showing(), "the plate is hidden before a save")

	var before := _hud_rects()
	check(game.save_game(), "the game saves")
	await _wait(2)
	check(notice.showing(), "a save shows the plate")
	check(notice.label.text == Lang.t("Spiel gespeichert"), "it says the game was saved: %s" % notice.label.text)
	check(Lang.EN.get("Spiel gespeichert") == "Game saved", "in English it says \"Game saved\"")
	check(notice.plate.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it never takes the pointer")
	await _seconds(SaveNotice.FADE_IN + 0.1)
	var screen: Rect2 = root.get_visible_rect()
	var rect: Rect2 = notice.plate.get_global_rect()
	check(screen.encloses(rect), "the plate is on screen: %s" % rect)
	check(is_equal_approx(rect.end.x, screen.end.x - SaveNotice.EDGE), "it keeps the HUD margin to the right edge: %s" % rect)
	check(is_equal_approx(rect.position.y, SaveNotice.EDGE), "it keeps the HUD margin to the top edge: %s" % rect)
	check(notice.plate.modulate.a > 0.99, "it is fully shown after fading in")
	var after := _hud_rects()
	for path in before:
		if after.has(path) and after[path] != before[path]:
			check(false, "the HUD stays where it was: %s moved" % path)
			break
	for path in after:
		if after[path].intersects(rect) and not before.has(path):
			check(false, "nothing new is laid over the HUD: %s" % path)
	await _shot("save_notice")

	# A second save while it shows starts it over: still one plate.
	await _seconds(SaveNotice.HOLD * 0.8)
	game.save_game()
	await _seconds(SaveNotice.HOLD * 0.5)
	check(notice.showing() and notice.plate.modulate.a > 0.99, "a second save keeps the plate up")
	check(notice.get_child_count() == 1, "a second save does not stack a second plate")

	# It fades out on its own.
	await _seconds(SaveNotice.FADE_IN + SaveNotice.HOLD + SaveNotice.FADE_OUT + 0.3)
	check(not notice.showing(), "the plate fades away")

	# A save while a window is open and the world is paused shows it too.
	game.menus.open("inventar")
	await _wait(5)
	check(game.menus.is_open(), "a window is open")
	game.save_game()
	await _seconds(SaveNotice.FADE_IN + 0.1)
	check(notice.showing(), "a save while a window is open shows the plate")
	await _seconds(SaveNotice.HOLD + SaveNotice.FADE_OUT + 0.3)
	check(not notice.showing(), "it fades away with the window open, too")
	game.menus.close()

	# A play test from the map workshop saves nothing and shows nothing.
	game.playtest_file = "res://levels/test.txt"
	check(not game.save_game(), "a play test does not save")
	await _wait(2)
	check(not notice.showing(), "no plate without a save")
	game.playtest_file = ""
	_finish()


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: save notice" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
