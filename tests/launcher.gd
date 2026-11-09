extends SceneTree
## Headless test for the Windows launcher (scripts/launcher.gd): what it does with the
## release's version.json (play, fetch the game, fetch a new launcher), that a broken
## version.json is not used, and that its window keeps its layout through every step
## (looking, downloading, checking, ready, offline, failed) in both languages: the status
## line, progress bar and buttons stay exactly where they are.
## With SHOTS=<folder> and a display it also saves screenshots there.
## Run with: godot --headless -s tests/launcher.gd

const LauncherScript := preload("res://scripts/launcher.gd")

var failures := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test.call_deferred()


func _test() -> void:
	_test_plan()
	_test_notes()
	await _test_window()
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _test_plan() -> void:
	var release := {"build": "12", "launcher": "abc", "pack_size": 10, "pack_sha256": "0".repeat(64)}
	check(LauncherScript.plan(release, {}, "abc") == "game", "nothing installed: the game is fetched")
	check(LauncherScript.plan(release, {"build": "11"}, "abc") == "game", "an older build is replaced")
	check(LauncherScript.plan(release, {"build": "12"}, "abc") == "play", "the newest build just plays")
	check(LauncherScript.plan(release, {"build": "12"}, "old") == "launcher", "a changed launcher comes first")
	check(LauncherScript.plan(release, {}, "old") == "launcher", "a changed launcher comes before the first download")
	check(LauncherScript.plan(release, {"build": "12"}, "") == "play", "no self-update outside an exported launcher")
	release.engine_sha256 = "1".repeat(64)
	check(LauncherScript.plan(release, {"build": "12"}, "abc") == "engine", "no game engine yet: it is fetched")
	check(LauncherScript.plan(release, {"build": "11", "engine": "0".repeat(64)}, "abc") == "engine", "a changed engine comes before the game")
	check(LauncherScript.plan(release, {"build": "11", "engine": "1".repeat(64)}, "abc") == "game", "with the engine in place the game follows")
	check(LauncherScript.plan(release, {"build": "12", "engine": "1".repeat(64)}, "abc") == "play", "engine and game up to date")
	check(not LauncherScript.playable({"build": "12"}), "no game without its engine")
	check(LauncherScript.playable({"build": "12", "engine": "1"}), "engine and data make a game")
	check(LauncherScript.valid_manifest(release), "a complete version.json is used")
	check(not LauncherScript.valid_manifest({"build": "12"}), "a version.json without checksum is not used")
	check(not LauncherScript.valid_manifest(null), "an unreadable version.json is not used")
	check(not LauncherScript.valid_manifest({"build": "", "pack_size": 10, "pack_sha256": "0".repeat(64)}),
		"a version.json without build is not used")


func _test_notes() -> void:
	var lines: Array = LauncherScript.parse_notes("# a comment\n\n## New\n- First thing\n-  Second thing \nplain\n## Fixes\n- Bug")
	check(lines == [["h", "New"], ["li", "First thing"], ["li", "Second thing"], ["p", "plain"], ["h", "Fixes"], ["li", "Bug"]],
		"patch notes are split into headings, changes and text, comments left out")
	check(LauncherScript.parse_notes("").is_empty(), "no notes, no lines")
	check(LauncherScript.parse_notes("- x".repeat(LauncherScript.NOTES_MAX)).size() <= 1, "huge notes are cut off")
	var shipped := FileAccess.get_file_as_string("res://docs/patch_notes.txt")
	var dir := DirAccess.open("res://docs/patch_notes.d")
	var fragments_ok := dir != null
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".txt"):
				var frag_lines: Array = LauncherScript.parse_notes(FileAccess.get_file_as_string("res://docs/patch_notes.d/" + f))
				fragments_ok = fragments_ok and not frag_lines.is_empty() and frag_lines.all(func(l): return l[0] == "li")
				shipped = "## Latest changes\n" + FileAccess.get_file_as_string("res://docs/patch_notes.d/" + f) + "\n" + shipped
	check(fragments_ok, "every patch note fragment holds only '- ' change lines")
	var parsed: Array = LauncherScript.parse_notes(shipped)
	check(not parsed.is_empty() and parsed[0][0] == "h", "docs/patch_notes.txt starts with a heading")
	var recent: String = LauncherScript.recent_notes(shipped)
	check(recent.length() < LauncherScript.NOTES_MAX, "the shipped patch notes (newest two sections) fit the launcher's limit")
	check(LauncherScript.recent_notes("# c\n## A\n- 1\n## B\n- 2\n## C\n- 3\n").count("## ") == 2, "only the newest two sections ship")


## Rectangles of everything the player looks at or clicks.
func _rects(l) -> Array:
	return [l._notes_scroll.get_global_rect(), l._status.get_global_rect(), l._progress.get_global_rect(), l._play.get_global_rect(),
		l._quit.get_global_rect(), l._lang_buttons.de.get_global_rect(), l._lang_buttons.en.get_global_rect()]


func _test_window() -> void:
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	var l = load("res://scenes/launcher.tscn").instantiate()
	l.auto_check = false
	root.add_child(l)
	await process_frame
	await process_frame
	var Texts = LauncherScript.Texts
	var before := []
	var cases := [
		["looking", LauncherScript.Step.CHECKING, {"version": "0.5", "build": "41", "engine": "e"}, "Suche nach einer neuen Version …", []],
		["download", LauncherScript.Step.DOWNLOADING, {}, "Lade das Spiel: %s von %s MB", ["1234,5", "1234,5"]],
		["update", LauncherScript.Step.DOWNLOADING, {"version": "0.5", "build": "41", "engine": "e"}, "Lade die neue Version: %s von %s MB", ["12,3", "70,2"]],
		["checking", LauncherScript.Step.VERIFYING, {"version": "0.5", "build": "41", "engine": "e"}, "Prüfe die heruntergeladene Datei …", []],
		["ready", LauncherScript.Step.READY, {"version": "0.5", "build": "42", "engine": "e"}, "Version %s ist bereit. Viel Glück auf der Flucht!", ["0.5.42"]],
		["offline", LauncherScript.Step.OFFLINE, {"version": "0.5", "build": "41", "engine": "e"}, "Keine Verbindung zum Server. Du spielst die installierte Version.", []],
		["failed", LauncherScript.Step.FAILED, {}, "Das Spiel konnte nicht geladen werden. Prüfe die Internetverbindung und versuche es erneut.", []],
	]
	var long_notes := "## Big update\n" + "- A change with enough words to wrap onto a second line in the notes box.\n".repeat(40)
	for code in ["de", "en"]:
		# Short and very long notes must leave the window exactly as it is; long ones scroll.
		l.show_notes("")
		await process_frame
		var empty_rect: Rect2 = l._notes_scroll.get_global_rect()
		l.show_notes(long_notes)
		await process_frame
		await process_frame
		check(l._notes_scroll.get_global_rect() == empty_rect, "long notes keep the notes box in place (%s)" % code)
		check(l._notes_list.get_combined_minimum_size().y > l._notes_scroll.size.y, "long notes scroll (%s)" % code)
		check(l._notes_list.get_combined_minimum_size().x <= l._notes_scroll.size.x, "notes never scroll sideways (%s)" % code)
		l.show_notes(FileAccess.get_file_as_string("res://docs/patch_notes.txt"))
		Texts.language = code
		Texts._apply()
		for c in cases:
			l.step = c[1]
			l.installed = c[2]
			l._set_status(c[3], c[4])
			l._refresh()
			await process_frame
			await process_frame
			var rects := _rects(l)
			if before.is_empty():
				before = rects
			check(rects == before, "%s (%s): the window keeps its layout" % [c[0], code])
			check(l._status.get_line_count() <= 2, "%s (%s): the status fits its two lines" % [c[0], code])
			check(l._play.get_minimum_size().x <= 220.0, "%s (%s): the play button fits its text" % [c[0], code])
			check(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(l._play.get_global_rect()), "the buttons are on screen")
			var wants_play: bool = c[1] in [LauncherScript.Step.FAILED] or (not c[2].is_empty() and c[1] != LauncherScript.Step.VERIFYING)
			check(l._play.disabled != wants_play, "%s (%s): Play is %s" % [c[0], code, "enabled" if wants_play else "disabled"])
			check(l._progress.modulate.a == (1.0 if c[1] in [LauncherScript.Step.DOWNLOADING, LauncherScript.Step.VERIFYING] else 0.0),
				"%s (%s): the progress bar shows only while downloading" % [c[0], code])
			if shots != "" and DisplayServer.get_name() != "headless":
				l._progress.value = 18.0 if c[0] == "update" else 0.0
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png(shots.path_join("launcher_%s_%s.png" % [c[0], code]))
	# The title must not run into the language buttons.
	var box: Node = l.get_child(1).get_child(0)
	var header: Node = box.get_child(0)
	var emblem: TextureRect = header.get_child(0)
	check(emblem.texture != null and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(emblem.get_global_rect()),
		"the emblem is on screen")
	var title: Label = header.get_child(1)
	check(not title.get_global_rect().intersects(l._lang_buttons.en.get_parent().get_global_rect()),
		"the title keeps clear of the language buttons")
	Texts.language = ""
	Texts._apply()
