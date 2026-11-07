extends SceneTree
## Headless test for the map workshop (see LevelEditor, LevelMap, Creations):
## every map of the game reads and writes back unchanged and passes the
## checks, the checks catch broken maps, a map's own monsters, people and
## gear come to life in a built level, and the workshop paints, undoes,
## saves, opens and keeps its layout when pages and slots change.
## Run with: godot --headless -s tests/level_editor.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var shots := OS.get_environment("SHOTS")
var frames := 0
var editor: LevelEditor
var _started := false

const SAVE_FILE := "user://karten/_test_editor.txt"

const CUSTOM_MAP := """name: Probe
hint: Eine Probe.
secret: normal
traps: 2 stacheln, teleport
writing: MUT | In die Wand geritzt: Nur Mut.
custom: 1 {"type": "monster", "base": "krieger", "name": "Knochenfürst", "hp": 10000, "damage": 2, "tint": "#aa3322"}
custom: 2 {"type": "npc", "name": "Bruder Anselm", "model": "Mage", "show": ["Mage_Hat"], "lines": ["Friede sei mit dir.", "Geh mit Gott."]}
custom: 3 {"type": "item", "id": "eigen_probekrone", "base": "knochenhelm", "name": "Probekrone", "power": 3, "price": 40}
####################
########E###########
#..................#
#..1...............#
#..................#
#...2.....3........#
#..................#
#..................#
#..................#
#........P.........#
####################
"""


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.setup()
	_check_palette()
	_check_shipped_maps()
	_check_validation()
	_check_creations()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_check_level_build()
	if frames == 3:
		_check_boss_build()
	if frames == 4:
		editor = load("res://scenes/editor.tscn").instantiate()
		root.add_child(editor)
	if frames == 10 and not _started:
		_started = true
		_check_editor()
	return false


func _finish() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
	print("PASS: level editor" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## Every dungeon letter is in exactly one group of the palette, has a name,
## and every name and note has its English.
func _check_palette() -> void:
	for letter in Tiles.DUNGEON:
		var groups := EditorPalette.GROUPS.filter(func(g): return g[1].contains(letter)).size()
		check(groups == 1, "letter '%s' is in %d palette groups" % [letter, groups])
		check(EditorPalette.NAMES.has(letter) or Creations.LETTERS.contains(letter), "letter '%s' has no name in the palette" % letter)
	for g in EditorPalette.GROUPS:
		for letter in g[1]:
			check(Tiles.DUNGEON.has(letter), "palette letter '%s' is not in Tiles.DUNGEON" % letter)
		check(Lang.EN.has(g[0]), "no English for the group \"%s\"" % g[0])
	for text in EditorPalette.NAMES.values() + EditorPalette.NOTES.values():
		check(Lang.EN.has(text), "no English for \"%s\"" % text)
	# The open air has its own tiles, all of them in the palette too.
	for letter in Tiles.OUTDOOR:
		var groups := EditorPalette.OUTDOOR_GROUPS.filter(func(g): return g[1].contains(letter)).size()
		check(groups == 1, "outdoor letter '%s' is in %d palette groups" % [letter, groups])
		check(EditorPalette.OUTDOOR_NAMES.has(letter), "outdoor letter '%s' has no name in the palette" % letter)
	for g in EditorPalette.OUTDOOR_GROUPS:
		for letter in g[1]:
			check(Tiles.OUTDOOR.has(letter), "outdoor palette letter '%s' is not in Tiles.OUTDOOR" % letter)
		check(Lang.EN.has(g[0]), "no English for the group \"%s\"" % g[0])
	for text in EditorPalette.OUTDOOR_NAMES.values() + EditorPalette.OUTDOOR_NOTES.values():
		check(Lang.EN.has(text), "no English for \"%s\"" % text)


func _check_shipped_maps() -> void:
	for f in DirAccess.get_files_at("res://levels/"):
		if not f.ends_with(".txt"):
			continue
		var path := "res://levels/" + f
		var text := FileAccess.get_file_as_string(path)
		var m := LevelMap.parse(text)
		var lines := Array(text.split("\n")).map(func(l): return l.strip_edges(false, true)).filter(func(l): return l != "")
		var back := Array(m.to_text().split("\n")).filter(func(l): return l != "")
		check(lines == back, "%s does not read and write back unchanged" % f)
		var errors := m.validate().filter(func(i): return i.error)
		check(errors.is_empty(), "%s fails the checks: %s" % [f, errors.map(func(i): return i.text)])


func _errors_of(text: String) -> Array:
	return LevelMap.parse(text).validate().filter(func(i): return i.error).map(func(i): return i.text)


func _check_validation() -> void:
	var good := "name: A\nhint: B\n#####\n##E##\n#...#\n#.P.#\n#####\n"
	check(_errors_of(good).is_empty(), "a plain map has errors: %s" % [_errors_of(good)])
	check(_errors_of(good.replace("P", ".")).any(func(t): return t.contains("Start")), "a map without a start passes")
	check(_errors_of(good.replace("E", "#")).any(func(t): return t.contains("Ausgang")), "a map without an exit passes")
	check(_errors_of(good.replace("#...#\n#.P.#", "#.P.#\n#.P.#")).any(func(t): return t.contains("Starts")), "two starts pass")
	# A door with its key behind it: the exit cannot be reached.
	var locked := "name: A\nhint: B\n#####\n##E##\n#...#\n##D##\n#KP.#\n#####\n"
	check(_errors_of(locked).is_empty(), "a door with its key in front fails")
	var behind := "name: A\nhint: B\n#####\n##E##\n#K..#\n#####\n##D##\n#.P.#\n#####\n"
	check(_errors_of(behind).any(func(t): return t.contains("hinter der Tür")), "a key behind its own door passes")
	check(_errors_of(good.replace("#...#", "#.D.#")).any(func(t): return t.contains("Schlüssel")), "a door without a key passes")
	check(_errors_of(good.replace("#...#", "#_._#")).any(func(t): return t.contains("Steinblöcke")), "plates without blocks pass")
	check(_errors_of(good.replace("#...#", "#.€.#")).any(func(t): return t.contains("kennt das Spiel nicht")), "an unknown letter passes")
	check(_errors_of(good.replace("#...#", "#.4.#")).any(func(t): return t.contains("Geschöpf")), "a digit without a creation passes")
	# A wall of furniture cuts the exit off.
	check(_errors_of(good.replace("#...#", "#bbb#")).any(func(t): return t.contains("nicht zu erreichen")), "a cut-off exit passes")


func _check_creations() -> void:
	var m := LevelMap.parse(CUSTOM_MAP)
	var made := m.creations()
	check(made.size() == 3, "the map has %d creations, not 3" % made.size())
	check(_errors_of(CUSTOM_MAP).is_empty(), "the map with creations has errors: %s" % [_errors_of(CUSTOM_MAP)])
	# Writing a creation back gives the same line.
	var again := LevelMap.parse(m.to_text()).creations()
	check(again == made, "creations change when written back")
	# Values are kept in bounds.
	var wild := Creations.checked({"type": "monster", "base": "einhorn", "hp": 99999, "speed": -3})
	check(wild.base == "krieger" and wild.hp == Creations.MONSTER_MAX_HP and wild.hp == 10000 and wild.speed == 1.0, "a monster's values are not kept in bounds: %s" % wild)
	# Every kind that fights is a base, the bosses too, listed once by family
	# and named in both languages.
	var listed := []
	for family in Creations.MONSTER_FAMILIES:
		check(Lang.EN.has(family[0]), "no English for the family \"%s\"" % family[0])
		listed += family[1]
	check(listed == Creations.MONSTER_BASES, "the families and MONSTER_BASES disagree: %s" % [listed])
	for kind in Enemy.KINDS:
		check(kind in Creations.MONSTER_BASES, "the kind %s cannot be a base in the workshop" % kind)
	for kind in Creations.MONSTER_BASES:
		check(Enemy.KINDS.has(kind), "the base %s is no kind of Enemy" % kind)
		check(Creations.MONSTER_NAMES.has(kind) and Lang.EN.has(Creations.MONSTER_NAMES.get(kind, "")), "the base %s has no name in both languages" % kind)
		check(Creations.checked({"type": "monster", "base": kind}).base == kind, "the base %s is not kept" % kind)
	for kind in Creations.MONSTER_BOSSES:
		check(kind in HeroLevel.BOSSES, "%s is no boss" % kind)
	# The biggest base's own numbers fit the form.
	check(Enemy.KINDS.bergkoenig.hp <= 400 and Enemy.KINDS.bergkoenig.damage <= 10, "the Mountain King's numbers do not fit the form")
	var npc := Creations.checked({"type": "npc", "model": "Knight", "sex": "female", "show": ["Mage_Hat", "Knight_Helmet"], "colors": ["nix"]})
	check(npc.sex == "male" and npc.show == ["Knight_Helmet"] and npc.colors.size() == 3, "a person's look is not checked: %s" % npc)
	check(Creations.item_id("Große Krone!") == "eigen_grosse_krone", "item ids: %s" % Creations.item_id("Große Krone!"))
	# Gear made in the workshop joins the items, but never a shop or the loot.
	Creations.register(made["3"])
	check(Items.ALL.has("eigen_probekrone"), "the workshop's gear is not in Items.ALL")
	check(Items.ALL["eigen_probekrone"].power == 3 and Items.ALL["eigen_probekrone"].slot == "kopf", "the workshop's gear lost its values")
	check(not Items.merchant_sells("eigen_probekrone"), "the workshop's gear is sold")
	var rng := RandomNumberGenerator.new()
	for i in 200:
		rng.seed = i
		check(Items.random_item(rng) != "eigen_probekrone", "the workshop's gear turned up as loot")
	check(Items.merchant_sells("schwert"), "a plain sword is no longer sold")


## The map's own creations come to life in a built level.
func _check_level_build() -> void:
	var path := "user://karten/_test_build.txt"
	DirAccess.make_dir_recursive_absolute("user://karten/")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(CUSTOM_MAP)
	f.close()
	var level := Level.new()
	level.load_from_file(path)
	level.playtest = true
	root.add_child(level)
	level.build()
	var custom := level.enemies.filter(func(e): return not e.custom.is_empty())
	check(custom.size() == 1, "%d custom monsters, not 1" % custom.size())
	if custom.size() == 1:
		var e: Enemy = custom[0]
		check(e.kind == "krieger" and e.hp >= 10000, "the custom monster fights with hp %d, not the 10000 it was made with" % e.hp)
		check(e.custom.get("title", "") == "Knochenfürst", "the custom monster has no name")
		check(e.custom.has("tint"), "the custom monster has no colour")
	var figures := level.stations.filter(func(s): return s.kind == "figur")
	check(figures.size() == 1, "%d people, not 1" % figures.size())
	if figures.size() == 1:
		var npc: DungeonNpc = figures[0].figure
		check(npc.display_name == "Bruder Anselm", "the person is called %s" % npc.display_name)
		npc.talk(level)
		check(npc.is_talking(), "the person does not talk")
	check(level._pickups.any(func(p): return p.get("id", "") == "eigen_probekrone"), "the custom gear does not lie on the floor")
	check(level.traps != null and level.traps.traps.size() == 2, "the header's traps are not laid")
	check(level._writing.get("word", "") == "MUT", "the header's wall writing is not used")
	check(not Traps.can_drop(level), "a tested map has a level below")
	level.queue_free()
	DirAccess.remove_absolute(path)


## The bosses and horrors made in the workshop come to life as what they
## are: the boss's own fight, its health bar under the creation's name, and
## none of the real one's rewards.
const BOSS_MAP := """name: Bossprobe
hint: Eine Probe.
custom: 1 {"type": "monster", "base": "drache", "name": "Aschenschwinge", "hp": 40}
custom: 2 {"type": "monster", "base": "hauptmann", "name": "Graubart"}
custom: 3 {"type": "monster", "base": "bergkoenig", "name": "Der Kleine König", "hp": 120, "damage": 6}
custom: 4 {"type": "monster", "base": "schlund"}
custom: 5 {"type": "monster", "base": "fog_wraith"}
custom: 6 {"type": "monster", "base": "klippenschuetze"}
##########################
###########E##############
#........................#
#..1.....2.....3.........#
#........................#
#..4.....5.....6.........#
#........................#
#...........P............#
##########################
"""


func _check_boss_build() -> void:
	check(_errors_of(BOSS_MAP).is_empty(), "the boss map has errors: %s" % [_errors_of(BOSS_MAP)])
	var made := LevelMap.parse(BOSS_MAP).creations()
	check(made.size() == 6 and made["1"].base == "drache" and made["3"].hp == 120, "the boss map reads as %s" % [made])
	check(LevelMap.parse(LevelMap.parse(BOSS_MAP).to_text()).creations() == made, "the bosses change when written back")
	var path := "user://karten/_test_bosses.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(BOSS_MAP)
	f.close()
	var level := Level.new()
	level.load_from_file(path)
	level.playtest = true
	root.add_child(level)
	level.build()
	var kinds := {}
	for e in level.enemies:
		kinds[e.kind] = e
	for kind in ["drache", "hauptmann", "bergkoenig", "schlund", "fog_wraith", "klippenschuetze"]:
		check(kinds.has(kind), "no %s on the boss map" % kind)
	if kinds.has("drache"):
		check(kinds.drache is Dragon and kinds.drache.boss_title() == "Aschenschwinge" and kinds.drache.hp >= 40, "the made dragon is no dragon of its own")
		check(level.dragon == kinds.drache and level.dragon_bar != null, "the made dragon has no health bar")
	if kinds.has("hauptmann"):
		check(kinds.hauptmann is BanditChief and kinds.hauptmann.boss_title() == "Graubart", "the made chief is no chief of his own")
	if kinds.has("bergkoenig"):
		check(kinds.bergkoenig is MountainKing and kinds.bergkoenig.boss_title() == "Der Kleine König", "the made king is no king of his own")
		check(level.mine_boss == null, "the made king counts as the mine's boss")
	if kinds.has("schlund"):
		check(kinds.schlund.is_horror(), "the made horror is no horror")
	var bars := level.get_children().filter(func(c): return c is BossBar)
	check(bars.size() == 3, "%d health bars, not 3 (dragon, chief, king)" % bars.size())
	level.queue_free()
	DirAccess.remove_absolute(path)


## Nothing on a page is wider than its scroll region (it would be cut off).
func _check_fits(page: int, what: String) -> void:
	var room: float = editor._page_scroll.size.x - 12
	for child in editor._page_boxes[page].get_children():
		if child is Control and child.visible:
			check(child.get_combined_minimum_size().x <= room, "%s: %s is %d wide, the page %d" % [what, child.get_class(), child.get_combined_minimum_size().x, room])


func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _check_editor() -> void:
	var canvas := editor.canvas
	check(canvas.size.x > 300 and canvas.size.y > 300, "the grid is too small: %s" % canvas.size)
	check(not LevelMap.has_errors(editor.issues), "a new map has errors: %s" % [editor.issues])
	await _shot("editor_new")
	# Paint a key and a door: the door needs the key, then the checks pass again.
	var side: Control = editor._page_scroll.get_parent().get_parent()
	var side_rect := _rect(side)
	var canvas_rect := _rect(canvas)
	editor.pick_letter("D")
	canvas.stroke_started.emit()
	canvas._paint(Vector2i(3, 4), "D")
	check(editor.map.cell(Vector2i(3, 4)) == "D", "painting does not change the map")
	check(editor.dirty, "painting does not mark the map changed")
	check(LevelMap.has_errors(editor.issues), "a door without a key passes in the workshop")
	editor.undo()
	check(editor.map.cell(Vector2i(3, 4)) == ".", "undo does not take the paint back")
	editor.redo()
	check(editor.map.cell(Vector2i(3, 4)) == "D", "redo does not paint again")
	canvas.stroke_started.emit()
	canvas._paint(Vector2i(2, 5), "K")
	check(not LevelMap.has_errors(editor.issues), "a door with its key fails: %s" % [editor.issues])
	# Rectangle and fill.
	canvas.stroke_started.emit()
	canvas._paint_rect(Vector2i(10, 3), Vector2i(12, 4), "c")
	check(editor.map.count("c") == 6, "the rectangle painted %d coins, not 6" % editor.map.count("c"))
	canvas._fill(Vector2i(11, 3), "x")
	check(editor.map.count("c") == 0 and editor.map.count("x") == 6, "the fill did not fill the patch")
	# Pages and creation slots never move or resize the window.
	for page in LevelEditor.PAGES.size():
		editor.show_page(page)
		await process_frame
		check(_rect(side) == side_rect, "page %d resizes the side panel: %s vs %s" % [page, _rect(side), side_rect])
		check(_rect(canvas) == canvas_rect, "page %d resizes the grid" % page)
		_check_fits(page, "page %d" % page)
	editor.show_page(1)
	for type in ["monster", "npc", "item"]:
		editor.creations_page._create(type)
		await process_frame
		await process_frame
		check(_rect(side) == side_rect, "a %s form resizes the side panel" % type)
		_check_fits(1, type + " form")
		await _shot("editor_" + type)
		editor.creations_page.pick(str(editor.creations_page.slot.to_int() % 9 + 1))
	check(editor.map.creations().size() == 3, "the forms made %d creations, not 3" % editor.map.creations().size())
	# The dragon as the base of the monster: the list shows every kind by family.
	editor.creations_page.pick("1")
	var dragon: Dictionary = editor.map.creations()["1"]
	dragon.base = "drache"
	dragon.name = "Aschenschwinge"
	editor.creations_page._fill_monster_stats(dragon)
	editor.creations_page._store(dragon)
	editor.creations_page.rebuild()
	await process_frame
	await process_frame
	check(editor.map.creations()["1"].base == "drache" and editor.map.creations()["1"].hp == Enemy.KINDS.drache.hp, "the dragon base did not take its numbers")
	check(_rect(side) == side_rect, "the dragon form resizes the side panel")
	var lists := editor._page_boxes[1].find_children("*", "OptionButton", true, false)
	check(not lists.is_empty() and lists[0].get_selected_metadata() == "drache", "the base list does not show the dragon")
	if not lists.is_empty():
		var list: OptionButton = lists[0]
		var count := 0
		for i in list.item_count:
			if not list.is_item_separator(i):
				count += 1
		check(count == Creations.MONSTER_BASES.size(), "the base list has %d kinds, not %d" % [count, Creations.MONSTER_BASES.size()])
		list.show_popup()
		await process_frame
		await process_frame
		await _shot("editor_monster_bases")
		list.get_popup().hide()
	await _shot("editor_monster_dragon")
	# Saving and opening again.
	editor.map.set_header("name", "Werkstattprobe")
	check(editor.save_as(SAVE_FILE), "saving fails")
	check(not editor.dirty, "a saved map still counts as changed")
	var saved := LevelMap.load_file(SAVE_FILE)
	check(saved.get_header("name") == "Werkstattprobe" and saved.creations().size() == 3, "the saved file lost its name or creations")
	check(LevelEditor.map_files().any(func(e): return e[0] == SAVE_FILE), "the saved map is not offered to open")
	editor.new_map()
	check(editor.map.creations().is_empty(), "a new map keeps the old creations")
	editor.open_file(SAVE_FILE)
	check(editor.map.get_header("name") == "Werkstattprobe" and editor.map.cell(Vector2i(3, 4)) == "D", "opening does not bring the map back")
	editor.show_page(2)
	await process_frame
	await _shot("editor_checks")
	# A map with errors is not tested.
	editor.canvas.stroke_started.emit()
	editor.canvas._paint(editor.map.find_all("P")[0], ".")
	editor.playtest()
	check(not Engine.has_meta(preload("res://scripts/game.gd").PLAYTEST_FLAG), "a map with errors is tested")
	# Opening every map of the game works and shows no errors.
	for entry in LevelEditor.map_files():
		if entry[0].begins_with("res://"):
			editor.open_file(entry[0])
			check(not LevelMap.has_errors(editor.issues), "%s shows errors in the workshop" % entry[0])
	await _check_outdoor()
	editor.open_file("res://levels/04_die_gruft.txt")
	check(editor._tile_buttons.has("_") and not editor._tile_buttons.has("("), "a dungeon after the open air keeps the outdoor tiles")
	editor.show_page(0)
	await process_frame
	await _shot("editor_gruft")
	_finish()


## The open-air map: its own tiles, its size, painting and saving it.
func _check_outdoor() -> void:
	var side: Control = editor._page_scroll.get_parent().get_parent()
	var side_rect := _rect(side)
	editor.open_file("res://levels/11_die_freiheit.txt")
	await process_frame
	await process_frame
	check(editor.map.is_outdoor() and editor.map.width() == 172, "the open-air map does not open")
	check(editor._tile_buttons.has("&") and editor._tile_buttons.has("h") and editor._tile_buttons.has("_") and editor._tile_buttons.has("\\"), "the palette does not show the open air's tiles")
	check(not LevelMap.has_errors(editor.issues), "the open-air map shows errors: %s" % [editor.issues])
	check(_rect(side) == side_rect, "the open-air map resizes the side panel")
	for page in LevelEditor.PAGES.size():
		editor.show_page(page)
		await process_frame
		check(_rect(side) == side_rect, "page %d of the open-air map resizes the side panel" % page)
		_check_fits(page, "outdoor page %d" % page)
	var canvas := editor.canvas
	check(canvas.zoom >= EditorCanvas.MIN_ZOOM and canvas.zoom * 172 <= canvas.size.x + 1.0, "the open-air map does not fit in view (zoom %s)" % canvas.zoom)
	# Painting a tree on the meadow and saving keeps the rest of the map as it was.
	var meadow := editor.map.find_all(".")[0]
	editor.pick_letter("T")
	canvas.stroke_started.emit()
	canvas._paint(meadow, "T")
	check(editor.map.cell(meadow) == "T", "painting on the open-air map does not work")
	check(editor.save_as(SAVE_FILE), "saving the open-air map fails")
	var before := Array(FileAccess.get_file_as_string("res://levels/11_die_freiheit.txt").split("\n")).map(func(l): return l.strip_edges(false, true)).filter(func(l): return l != "")
	var after := Array(FileAccess.get_file_as_string(SAVE_FILE).split("\n")).filter(func(l): return l != "")
	var changed := 0
	for i in mini(before.size(), after.size()):
		if before[i] != after[i]:
			changed += 1
	check(before.size() == after.size() and changed == 1, "saving the open-air map changed %d lines, not 1" % changed)
	editor.show_page(0)
	canvas.zoom_at(canvas.size / 2.0, 3.0)
	await _shot("editor_outdoor")


func _shot(file: String) -> void:
	if shots == "":
		return
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(shots.path_join(file + ".png"))
