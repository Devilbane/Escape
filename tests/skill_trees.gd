extends SceneTree
## Headless test for the skill trees (key Y, see SkillTrees and SkillTreePage):
## the data is whole (every skill in a tree, a row and a name in both
## languages, every need names a real skill, the needs never loop), every skill
## the game trains is in a tree and the other way round, a hero saved before the
## trees existed keeps every level, the window fits 1280 × 720 unshrunk and
## keeps its size on every tree, a skill picked shows in the card, and the
## text is 16 px or more.
## Run with: godot --headless -s tests/skill_trees.gd

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
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _labels(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		_labels(child, out)
	return out


func _find_page(node: Node) -> SkillTreePage:
	if node is SkillTreePage:
		return node
	for child in node.get_children():
		var found := _find_page(child)
		if found != null:
			return found
	return null


## Whether a skill's needs lead back to itself.
func _loops(id: String, seen: Array) -> bool:
	if id in seen:
		return true
	for need in SkillTrees.ALL[id].get("needs", {}):
		if _loops(need, seen + [id]):
			return true
	return false


func _test() -> void:
	# --- The data.
	check(SkillTrees.ALL.size() == 78, "78 skills in all (%d)" % SkillTrees.ALL.size())
	var tree_ids := SkillTrees.TREES.map(func(t): return t[0])
	for id in SkillTrees.ALL:
		var s: Dictionary = SkillTrees.ALL[id]
		check(s.tree in tree_ids, "%s stands in a real tree" % id)
		check(s.row in SkillTrees.ROWS, "%s stands in a real row" % id)
		check(s.levels == {"basic": 20, "advanced": 15, "master": 10}[s.row], "%s has the levels of its row" % id)
		for a in s.attributes:
			check(Training.ATTRIBUTES.has(a), "%s is governed by a real attribute (%s)" % [id, a])
		for need in s.get("needs", {}):
			check(SkillTrees.ALL.has(need), "%s needs a real skill (%s)" % [id, need])
			if SkillTrees.ALL.has(need):
				var rows := SkillTrees.ROWS
				check(rows.find(SkillTrees.ALL[need].row) <= rows.find(s.row), "%s needs nothing from a higher row (%s)" % [id, need])
		for a in s.get("attribute_needs", {}):
			check(Training.ATTRIBUTES.has(a), "%s needs a real attribute (%s)" % [id, a])
		check(not _loops(id, []), "the needs of %s do not loop" % id)
		if s.row != "basic":
			check(not s.get("needs", {}).is_empty(), "%s (above the basic row) needs something" % id)
		for lang in ["en", "de"]:
			Lang.language = lang
			Lang._apply()
			var shown := Lang.t(SkillTrees.name_of(id))
			check(shown != "", "%s has a name (%s)" % [id, lang])
			if lang == "en":
				check(shown != SkillTrees.name_of(id) or id in ["klingen", "schleichen", "tempo"] or not shown.contains("ä") and not shown.contains("ö") and not shown.contains("ü"),
						"%s has an English name (%s)" % [id, shown])
	# The game's own skills and crafts are exactly the tree's skills marked in game.
	for id in Training.SKILLS:
		check(SkillTrees.in_game(id), "the game's skill %s is in a tree" % id)
	for id in Training.CRAFTS:
		check(SkillTrees.in_game(id), "the game's craft %s is in a tree" % id)
	for id in SkillTrees.ALL:
		if SkillTrees.in_game(id):
			check(Training.SKILLS.has(id) or Training.CRAFTS.has(id), "%s is marked in game and the game has it" % id)
	# Each tree's rows fit the canvas and the plates do not overlap.
	for t in SkillTrees.TREES:
		var places := SkillTreePage.layout(t[0])
		var ids := places.keys()
		for i in ids.size():
			var r: Rect2 = places[ids[i]]
			check(Rect2(Vector2.ZERO, Vector2(SkillTreePage.WIDTH, SkillTreePage.HEIGHT)).encloses(r), "%s fits the canvas" % ids[i])
			for j in range(i + 1, ids.size()):
				check(not r.intersects(places[ids[j]]), "%s and %s do not overlap" % [ids[i], ids[j]])

	# --- A hero saved before the trees keeps every level: nothing was
	# renamed or moved, the trees only read what is there.
	game.hero_name = "Skill tree test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var menus: Menus = game.menus
	root.size = Vector2i(1280, 720)
	p.xp = {"klingen": Training.skill_xp_for(4), "alchemie": Training.skill_xp_for(2), "erkunden": Training.skill_xp_for(1)}
	p.sleep_state = SleepRoll.empty()
	check(SkillTrees.level_of(p, "klingen") == p.trained_level("klingen") and p.trained_level("klingen") >= 1, "an old hero's Klingen shows in the tree")
	check(SkillTrees.status(p, "klingen") == "known", "a trained skill is known")
	check(SkillTrees.status(p, "blocken") == "open", "an untrained skill without needs is open")
	check(SkillTrees.status(p, "schwertkampf") == "planned", "a skill the game does not have is planned")
	check(SkillTrees.unmet(p, "schwertkampf").size() >= 1, "Schwertkampf still needs Klingen 10")
	check(SkillTrees.crosses_trees("schlachtenbrecher") and not SkillTrees.crosses_trees("schwertkampf"), "cross-tree needs are found")
	check(SkillTrees.opens("klingen").has("schwertkampf") and SkillTrees.opens("klingen").has("meucheln"), "what a skill opens is found")

	for id in SkillTrees.ALL:
		var d: Dictionary = SkillTreePage.new(p, game.TEXT_FONT, SkillTrees.ALL[id].tree).details(id)
		check(d.title != "" and not d.lines.is_empty(), "the card has a text for %s" % id)

	# --- The window.
	var sizes := {}
	for lang in ["en", "de"]:
		Lang.language = lang
		Lang._apply()
		for t in SkillTrees.TREES:
			game.menus.skill_tree = t[0]
			menus.open("fertigkeiten")
			await _wait()
			var where := "%s, %s" % [t[0], lang]
			check(is_equal_approx(menus._panel.scale.x, 1.0), "the window fits 1280 × 720 unshrunk (%s): scale %s" % [where, menus._panel.scale.x])
			var panel_size: Vector2 = menus._panel.size
			if not sizes.has(lang):
				sizes[lang] = panel_size
			check(panel_size.is_equal_approx(sizes[lang]), "the window keeps its size on every tree (%s): %s vs %s" % [where, panel_size, sizes[lang]])
			for l in _labels(menus._box, []):
				if l.text != "":
					check(l.get_theme_font_size("font_size") >= UiKit.sized(16), "'%s' is 16 px or more (%s)" % [l.text, where])
			var page := _find_page(menus._box)
			check(page != null, "the window holds the tree page (%s)" % where)
			if page == null:
				continue
			check(SkillTreePage.NAME_SIZE >= 16 and SkillTreePage.LINE_SIZE >= 16, "plate text is 16 px or more")
			# Pointing at a skill shows it; a click keeps it; the card keeps its size.
			var first: String = SkillTrees.in_row(t[0], "basic")[0]
			var at: Vector2 = SkillTreePage.layout(t[0])[first].get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = at
			page._gui_input(motion)
			check(page.shown() == first, "pointing at %s shows it (%s)" % [first, where])
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = at
			page._gui_input(click)
			page.point("")
			check(page.shown() == first, "a click keeps %s in the card (%s)" % [first, where])
			check(page.details(first).title == Lang.t(SkillTrees.name_of(first)), "the card shows %s (%s)" % [first, where])
			check(menus._panel.size.is_equal_approx(panel_size), "picking a skill does not resize the window (%s)" % where)
			menus.close()
	Lang.language = "de"
	Lang._apply()
	print("PASS" if failures == 0 else "FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
