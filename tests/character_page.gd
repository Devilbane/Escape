extends SceneTree
## Headless test for the character page (key P, see CharacterPage): the wheel
## draws its text at 16 px or more, its skill plates and attribute blocks do
## not overlap each other or the middle circle, the window fits 1280 × 720
## without shrinking, pointing at an entry (on the wheel or in the list beside
## it) shows its details in the card, a click keeps them, and none of this
## moves or resizes anything in the window, in both languages.
## Run with: godot --headless -s tests/character_page.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var shots := OS.get_environment("SHOTS")


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


func _find_wheel(node: Node) -> CharacterPage:
	if node is CharacterPage:
		return node
	for child in node.get_children():
		var found := _find_wheel(child)
		if found != null:
			return found
	return null


func _labels(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		_labels(child, out)
	return out


func _has_text(node: Node, text: String) -> bool:
	for l in _labels(node, []):
		if l.text.contains(text):
			return true
	return false


## Moves the pointer over a point of the wheel (in the wheel's own coordinates).
func _move(wheel: CharacterPage, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	wheel._gui_input(e)


func _click(wheel: CharacterPage, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	wheel._gui_input(e)


func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _test() -> void:
	game.hero_name = "Character page test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var menus: Menus = game.menus
	root.size = Vector2i(1280, 720)

	# The values the player reads on the wheel are 16 px or more.
	check(CharacterPage.TEXT_SIZE >= 16, "the wheel's text is 16 px or more (%d)" % CharacterPage.TEXT_SIZE)

	for setup in ["dagger", "sword and shield", "level points"]:
		if setup == "sword and shield":
			p.equipped["waffe"] = "schwert"
			p.equipped["schild"] = "wappenschild"
			p.xp["klingen"] = 200.0
		if setup == "level points":
			# Two-digit numbers everywhere still fit the card.
			p.hero_xp = HeroLevel.total_for(HeroLevel.MAX)
			p.level_points = {"staerke": 10, "geschick": 10, "intelligenz": 10}
			p.refresh_stats()
		for lang in ["en", "de"]:
			Lang.language = lang
			Lang._apply()
			var where := "%s, %s" % [setup, lang]
			menus.open("charakter")
			await _wait()
			var wheel := _find_wheel(menus._box)
			check(wheel != null, "the character window holds the wheel (%s)" % where)
			if wheel == null:
				continue
			check(is_equal_approx(menus._panel.scale.x, 1.0), "the window fits 1280 × 720 unshrunk (%s): scale %s" % [where, menus._panel.scale.x])
			for l in _labels(menus._box, []):
				if l.text != "":
					check(l.get_theme_font_size("font_size") >= 16, "'%s' is 16 px or more (%s)" % [l.text, where])

			# Plates and blocks stay apart and inside the wheel; basic skills
			# keep off the middle circle.
			var c := Vector2(CharacterPage.SIZE, CharacterPage.SIZE) / 2.0
			var ids: Array = wheel._hits.keys()
			for i in ids.size():
				var a: Rect2 = wheel._hits[ids[i]]
				check(Rect2(Vector2.ZERO, wheel.size).encloses(a), "%s lies inside the wheel (%s)" % [ids[i], where])
				if Training.SKILLS.has(ids[i]) and Training.tier(ids[i]) == 1:
					check(CharacterPage._distance_to(a, c) >= CharacterPage.INNER, "%s keeps off the middle circle (%s)" % [ids[i], where])
				for j in range(i + 1, ids.size()):
					check(not a.intersects(wheel._hits[ids[j]]), "%s and %s do not overlap (%s)" % [ids[i], ids[j], where])

			# Pointing at each entry shows it in the card and moves nothing.
			var panel_before := _rect(menus._panel)
			var wheel_before := _rect(wheel)
			var close: Control = menus._box.get_child(menus._box.get_child_count() - 1)
			var close_before := _rect(close)
			var card: Control = null
			for l in _labels(menus._box, []):
				if l.text == Lang.t("Fertigkeitsprobe"):
					card = l.get_parent().get_parent()
			check(card != null, "the card shows how a roll works before anything is pointed at (%s)" % where)
			if card == null:
				menus.close()
				continue
			var card_before := _rect(card)
			for id in ids:
				_move(wheel, wheel._hits[id].get_center())
				await _wait(2)
				var name: String = Lang.t(Training.SKILLS[id].name if Training.SKILLS.has(id) else Training.ATTRIBUTES[id].name)
				check(wheel.shown() == id, "pointing at %s shows it (%s)" % [id, where])
				check(_has_text(card, name), "the card names %s (%s)" % [name, where])
				check(_rect(card) == card_before, "the card keeps its size for %s (%s): %s, was %s" % [id, where, _rect(card), card_before])
				check(_rect(menus._panel) == panel_before and _rect(wheel) == wheel_before and _rect(close) == close_before,
						"nothing moves while %s shows (%s)" % [id, where])
			# The main attributes show what they do now, with the real numbers.
			for id in Training.MAIN_ATTRIBUTES:
				wheel.point(id)
				await _wait(2)
				var live: Array = wheel.live_effects(id)
				check(live.size() >= 2 and live.all(func(line): return _has_text(card, line)), "the card shows what %s does now (%s)" % [id, where])
				if setup == "level points":
					await _shot("attribute_%s_%s" % [id, lang])
			if setup == "level points":
				wheel.point("staerke")
				await _wait(2)
				check(p.strength_points() >= 10 and _has_text(card, Lang.t("Nahkampf: +%d Schaden, Hieb %d (+1 je Punkt)") % [p.strength_points(), p.power]),
						"ten points of Stärke show as +%d damage (%s)" % [p.strength_points(), where])
			# The attributes in the list beside the wheel show theirs too.
			for id in Training.ATTRIBUTES:
				wheel.point(id)
				await _wait(2)
				check(_has_text(card, Lang.t(Training.ATTRIBUTES[id].name)) and _rect(card) == card_before,
						"the card shows %s in its own space (%s)" % [id, where])
			# A click keeps an entry; the pointer leaving brings it back.
			var blocking: Vector2 = wheel._hits["blocken"].get_center()
			_click(wheel, blocking)
			_move(wheel, Vector2(4, 4))
			await _wait(2)
			check(wheel.shown() == "blocken", "a click keeps Blocking in the card (%s)" % where)
			if setup == "dagger":
				check(_has_text(card, Lang.t("Gedimmt: braucht einen Schild.")), "the card says Blocking needs a shield (%s)" % where)
				await _shot("character_blocking_dimmed_" + lang)
			else:
				check(_has_text(card, Lang.t("Probe: %d %% = %s × %d").split(":")[0]), "the card shows how Blocking's roll is made up (%s)" % where)
			_move(wheel, wheel._hits["klingen"].get_center())
			await _wait(2)
			check(wheel.shown() == "klingen", "pointing at Blades shows it over the picked entry (%s)" % where)
			if setup == "sword and shield":
				await _shot("character_blades_" + lang)
			_click(wheel, Vector2(4, 4))
			_move(wheel, Vector2(4, 4))
			await _wait(2)
			check(wheel.shown() == "" and _has_text(card, Lang.t("Fertigkeitsprobe")), "a click on an empty spot lets go (%s)" % where)
			if setup == "dagger":
				await _shot("character_" + lang)
			check(_rect(menus._panel) == panel_before, "the window keeps its frame after all that (%s)" % where)
			menus.close()
			await _wait()

	p.hero_xp = 0
	p.level_points = {}
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: character page")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
