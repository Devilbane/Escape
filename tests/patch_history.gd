extends SceneTree
## Headless test for the compendium's patch notes page (PatchHistory, Menus._build_patch_notes):
## the archive docs/patch_history.json parses, lists every build once, newest first, each with
## a version and notes; the page has its tab, lists the versions and shows the newest; picking
## another version refills the notes page without moving or resizing anything else; the tab
## row still fits the window in both languages.
## Run with: godot --headless --fixed-fps 60 -s tests/patch_history.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for c in node.get_children():
		var f := _find(c, wanted)
		if f != null:
			return f
	return null


func _run() -> void:
	# The archive.
	var all := PatchHistory.builds()
	check(all.size() >= 100, "the archive holds the backfilled builds: %d" % all.size())
	var seen := {}
	var last := 1 << 40
	for e in all:
		check(not seen.has(e.build), "build %s is listed once" % e.build)
		seen[e.build] = true
		check(e.build.to_int() < last, "newest first (%s)" % e.build)
		last = e.build.to_int()
		check(e.version.ends_with("." + e.build), "version %s names its build" % e.version)
		check(not e.notes.is_empty(), "build %s has notes" % e.build)
		for line: String in e.notes:
			check(not line.begins_with("- ") and not line.begins_with("#"), "a note is plain text: %s" % line)
		check(e.date == "" or e.date.length() == 10, "date of %s: %s" % [e.build, e.date])
	# The tab widths: even shares, a wide text keeps what it needs, the row fits.
	var w := Menus.compendium_tab_widths([45.0, 124.0, 24.0, 51.0, 95.0, 100.0, 50.0, 77.0], 962.0)
	var total := 0.0
	for x in w:
		total += x
	check(w[1] >= 124.0 + 8 and total <= 962.0 and w[0] == w[7], "tab widths: %s" % str(w))
	check(Menus.compendium_tab_widths([50.0, 60.0, 70.0], 962.0) == [240.0, 240.0, 240.0], "few tabs keep the widest width")
	check(PatchHistory.parse("") == [] and PatchHistory.parse("{oops") == [], "a missing or broken archive gives no builds")
	var parsed := PatchHistory.parse('{"builds": [{"version": "0.5.1", "build": "1", "notes": ["a"]}, {"version": "0.5.9", "build": "9", "notes": ["b", ""]}, {"build": "5", "notes": []}]}')
	check(parsed.size() == 2 and parsed[0].build == "9" and parsed[0].notes == ["b"], "parse sorts, drops empty notes and builds: %s" % str(parsed))
	for key in ["Patchnotes", "Versionen (%d)", "Version", "1 Änderung", "%d Änderungen", "deine Version", "deine", "Noch keine Patchnotes.", "Jede neue Version bringt ihre Patchnotes hierher."]:
		check(Lang.EN.has(key), "English for '%s'" % key)

	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	# Every page unlocked, so the tab row is at its fullest.
	for kind in Creations.MONSTER_NAMES:
		MonsterLore.kills[kind] = 9999
	game.crafting.learn_recipe(Crafting.RECIPES.keys()[0])
	var menus = game.menus
	var old_language := Lang.language
	for lang in ["de", "en"]:
		Lang.language = lang
		Lang._apply()
		menus.patch_notes_pick = ""
		menus.compendium_page = "patchnotes"
		menus.open("kompendium")
		await _wait(4)
		check(menus.is_open(), "the page opens (%s)" % lang)
		var tabs: HBoxContainer = menus._box.get_child(1)
		var last_tab: Button = tabs.get_child(tabs.get_child_count() - 1)
		check(last_tab.text == Lang.t("Patchnotes"), "the patch notes tab is last: %s" % last_tab.text)
		for b: Button in tabs.get_children():
			var font := b.get_theme_font("font")
			var wide := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			check(wide <= b.size.x - 8, "the tab text fits (%s): %d in %d" % [b.text, wide, b.size.x])
		var row := 0.0
		for b: Button in tabs.get_children():
			row += b.size.x
		check(row + tabs.get_theme_constant("separation") * (tabs.get_child_count() - 1) <= Menus.WINDOW_SIZES.kompendium.x, "the tab row fits the window: %d" % row)
		var panel: Vector2 = menus._panel.size
		check(panel.x <= Menus.WINDOW_SIZES.kompendium.x + 60, "the compendium keeps its width: %s" % panel)
		var versions: ScrollContainer = _find(menus._box, "PatchVersions")
		var notes: ScrollContainer = _find(menus._box, "PatchNotes")
		check(versions != null and notes != null, "both pages are there")
		if versions == null or notes == null:
			break
		var list: VBoxContainer = versions.get_child(0)
		check(list.get_child_count() == all.size(), "one button per version: %d" % list.get_child_count())
		check(menus.patch_notes_pick == all[0].build, "the newest version shows first")
		var lines: VBoxContainer = notes.get_child(0)
		check(lines.get_child_count() == all[0].notes.size(), "its notes show: %d" % lines.get_child_count())
		# Pick the version with the most notes: nothing outside the notes page moves.
		var big := 0
		for i in all.size():
			if all[i].notes.size() > all[big].notes.size():
				big = i
		var panel_rect: Rect2 = menus._panel.get_global_rect()
		var versions_rect: Rect2 = versions.get_global_rect()
		var notes_rect: Rect2 = notes.get_global_rect()
		var tab_rect: Rect2 = last_tab.get_global_rect()
		var button: Button = list.get_child(big)
		button.pressed.emit()
		await _wait(3)
		check(menus.patch_notes_pick == all[big].build, "picking shows that version")
		check(lines.get_child_count() == all[big].notes.size(), "its notes show: %d of %d" % [lines.get_child_count(), all[big].notes.size()])
		check(menus._panel.get_global_rect() == panel_rect, "the window keeps its place and size: %s vs %s" % [menus._panel.get_global_rect(), panel_rect])
		check(versions.get_global_rect() == versions_rect and notes.get_global_rect() == notes_rect, "both pages keep their place and size")
		check(last_tab.get_global_rect() == tab_rect, "the tabs stay put")
		# A rebuild (another language, a changed count...) keeps the picked version.
		menus._rebuild()
		await _wait(3)
		check(menus.patch_notes_pick == all[big].build, "a rebuild keeps the picked version")
		var shots := OS.get_environment("SHOTS")
		if shots != "":
			DirAccess.make_dir_recursive_absolute(shots)
			await _wait(4)
			root.get_texture().get_image().save_png(shots.path_join("patch_notes_%s.png" % lang))
		menus.close()
	Lang.language = old_language
	Lang._apply()
	if failures == 0:
		print("PASS: patch history")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
