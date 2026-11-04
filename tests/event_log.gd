extends SceneTree
## Headless test for the event log at the left edge of the screen (see
## EventLog): loot and speech go there instead of the message line, a spoken
## line is only written down when the hero is near enough to hear it, a
## reputation change is one short line, and the box keeps one size and place
## however many lines come, clear of the status block and the message line.
## Life shows as a small bar at a fixed spot under the hero, its colour by
## the life left.
## Run with: godot --headless -s tests/event_log.gd

var failures := 0
var game: Node
var frames := 0
var step := 0
var rect_before := Rect2()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: event log")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match step:
		0:
			_fill()
		1:
			_check_layout()
			_finish()
			return true
	step += 1
	return false


func _fill() -> void:
	var elog: EventLog = game.event_log
	var hero: Player = game.player
	check(elog.is_inside_tree(), "the event log is on the HUD")
	game.show_message("Vorher", 4.0)

	# Loot from a drop: into the log, not onto the message line.
	var item: String = Items.ALL.keys()[0]
	game._on_item_collected(item)
	check(elog.visible, "the log shows once something is in it")
	check(elog.entries().back().contains(Items.item_name(item)), "the find is in the log: %s" % elog.entries().back())
	check(game._message.text == "Vorher", "the find is not on the message line: %s" % game._message.text)

	# Coins picked up.
	game._on_coins_collected(3)
	check(elog.entries().back().contains("3"), "the gold is in the log: %s" % elog.entries().back())

	# Speech near the hero is heard, far away it is not.
	var count := elog.entries().size()
	Events.say("Mira", "Schönes Wetter heute!", hero.global_position + Vector3(3, 0, 0))
	check(elog.entries().size() == count + 1, "a line said nearby is written down")
	check(elog.entries().back().begins_with("Mira:"), "with the speaker's name: %s" % elog.entries().back())
	Events.say("Mira", "Schönes Wetter heute!", hero.global_position + Vector3(3, 0, 0))
	check(elog.entries().size() == count + 1, "the same line again at once is written once")
	Events.say("Bodo", "Ganz weit weg.", hero.global_position + Vector3(game.HEAR_RANGE + 20.0, 0, 0))
	check(elog.entries().size() == count + 1, "a line said far away is not")

	# A reputation change: one short line, no list on the message line.
	var role: String = Villager.ROLES.keys()[0]
	game.reputation_rose(role, 1)
	check(elog.entries().back().contains(Quests.villager_name(role)), "the reputation change is one line: %s" % elog.entries().back())
	check(not game._message.text.contains(Lang.t("Dein Ruf im Dorf steigt:")), "no reputation list on the message line")

	# Many lines at once: the box keeps its size and place.
	rect_before = elog.get_global_rect()
	for i in EventLog.KEEP + 15:
		Events.found("Gefunden: ein sehr langer Name für einen Gegenstand Nummer %d, der umbricht" % i)
	check(elog.entries().size() <= EventLog.KEEP, "old lines are let go (%d kept)" % elog.entries().size())
	check(EventLog.KEEP >= 50, "at least the last 50 lines can be scrolled back to")
	# A long message on the message line, for the layout check.
	game.show_message("Eine lange Nachricht, die über mehrere Zeilen geht. ".repeat(4), 4.0)


func _check_layout() -> void:
	var elog: EventLog = game.event_log
	# The first-steps card sits right under the log, on its left edge, clear
	# of the message lines and the list of keys at the bottom.
	var card: Control = game.tutorial.card
	var card_rect := Rect2(card.position, card.get_combined_minimum_size())
	var log_rect := elog.get_global_rect()
	check(card_rect.position.y >= log_rect.end.y and is_equal_approx(card_rect.position.x, log_rect.position.x), "the first-steps card sits under the log: %s vs %s" % [card_rect, log_rect])
	check(card_rect.end.x < game._message_box.get_global_rect().position.x, "the card keeps clear of the message lines: %s vs %s" % [card_rect, game._message_box.get_global_rect()])
	check(card_rect.end.y < game._help.get_global_rect().position.y, "the card keeps clear of the list of keys: %s vs %s" % [card_rect, game._help.get_global_rect()])
	# Scrolling back: within the lines there are, and back to the newest.
	elog.scroll_to(1e9)
	check(elog.scrolled() > 0.0, "the log scrolls back to older lines")
	check(elog.scrolled() <= elog._lines.get_combined_minimum_size().y, "but not past the oldest")
	elog.scroll_to(-50.0)
	check(is_zero_approx(elog.scrolled()), "and back down to the newest")
	var box := elog.get_global_rect()
	check(box.is_equal_approx(rect_before), "the box keeps its size and place: %s vs %s" % [box, rect_before])
	check(box.size.is_equal_approx(Vector2(EventLog.WIDTH, EventLog.HEIGHT)), "the box has its fixed size: %s" % box.size)
	check(box.position.x <= 40.0, "the box is at the very left: %s" % box.position)
	var status: Control = game._level_label.get_parent()
	check(not box.intersects(status.get_global_rect()), "the box keeps clear of the status block: %s vs %s" % [box, status.get_global_rect()])
	check(not box.intersects(game._message_box.get_global_rect()), "the box keeps clear of the message line: %s vs %s" % [box, game._message_box.get_global_rect()])
	# Life is a slim bar under the hero, its fill the share of life left.
	var hero: Player = game.player
	hero.hp = maxi(1, hero.max_hp / 2)
	game._update_hud()
	check(is_equal_approx(game._hp_bar.value, hero.hp) and is_equal_approx(game._hp_bar.max_value, hero.max_hp), "the life bar shows the hero's life")
	check(game.HP_BAR_SIZE.y <= 10.0, "the life bar is slim")
	# Its colour runs from green through yellow and red to deep red as life
	# is lost.
	check(game.hp_color(1.0).is_equal_approx(game.HP_COLORS[0][1]), "green at full life")
	check(game.hp_color(0.66).is_equal_approx(game.HP_COLORS[1][1]), "yellow at two thirds")
	check(game.hp_color(0.33).is_equal_approx(game.HP_COLORS[2][1]), "red at one third")
	check(game.hp_color(0.0).is_equal_approx(game.HP_COLORS[3][1]), "deep red at the end")
	var green: Color = game.hp_color(1.0)
	check(green.g > green.r * 2.0, "the full bar is green: %s" % green)
	var deep: Color = game.hp_color(0.05)
	check(deep.r > deep.g * 4.0 and deep.r < game.hp_color(0.33).r, "near the end a deep, darker red: %s" % deep)
	var last := -1.0
	var smooth := true
	for i in 21:
		var c: Color = game.hp_color(i / 20.0)
		if last >= 0.0 and absf(c.g - last) > 0.2:
			smooth = false
		last = c.g
	check(smooth, "the colour blends without jumps")
	hero.hp = hero.max_hp
	game._update_hud()
	check(game._hp_fill.bg_color.is_equal_approx(game.hp_color(1.0)), "the bar is green at full life")
	hero.hp = maxi(1, hero.max_hp / 10)
	game._update_hud()
	check(game._hp_fill.bg_color.is_equal_approx(game.hp_color(float(hero.hp) / hero.max_hp)), "and follows the life lost: %s" % game._hp_fill.bg_color)
	hero.ailments["gift"] = 5.0
	game._update_hud()
	check(game._hp_fill.bg_color.is_equal_approx(game.hp_color(float(hero.hp) / hero.max_hp)), "poison keeps the life colour (it has its icon)")
	hero.ailments.erase("gift")
	hero.hp = maxi(1, hero.max_hp / 2)
	game._update_hud()
	# The bar has one fixed spot on screen, centred across: the camera
	# shaking, trailing a running hero or zooming does not move it.
	game.state = game.State.PLAYING
	var ground: Vector3 = hero.global_position
	game._zoom = 0.0
	game.camera.rotation_degrees.x = -game.CAMERA_PITCH
	var settled: Vector3 = ground + game._camera_offset()
	game.camera.global_position = settled
	game._place_hp_bar()
	var steady: Vector2 = game._hp_bar.position
	var screen: Vector2 = game._hud.get_viewport().get_visible_rect().size
	check(is_equal_approx(game._hp_bar.get_global_rect().get_center().x, screen.x / 2.0), "the bar is centred across the screen")
	for moved in [Vector3(0.3, 0.2, -0.25), Vector3(0, 0, 1.5), Vector3(-1.5, 0, 0), Vector3(0, -3, -4)]:
		game.camera.global_position = settled + moved
		game._place_hp_bar()
		check(game._hp_bar.position == steady, "the life bar stays put with the camera moved by %s" % moved)
	game.camera.global_position = settled
	# In the normal view it sits below everything the hero's legs, arms and
	# blade can reach, and below the feet.
	var top: float = game._hp_bar.get_global_rect().position.y
	var clear := true
	for i in 16:
		var dir := Vector3(cos(TAU * i / 16.0), 0.0, sin(TAU * i / 16.0))
		for height in [0.0, 1.2, 2.2]:
			var tip: Vector2 = game.camera.unproject_position(ground + dir * game.HP_BAR_REACH + Vector3(0, height, 0))
			if tip.y >= top:
				clear = false
	check(clear, "nothing of the hero touches the bar in the normal view")
	# The icons under it keep clear of the message lines at the bottom.
	var icons_bottom: float = top + game.HP_BAR_SIZE.y + 5 + StatusIcon.SIZE
	check(icons_bottom < screen.y - game.MESSAGE_BOTTOM, "the icons under the bar end above the message line: %s" % icons_bottom)
	# Passing troubles show as little icons in a row under the bar; boons
	# go to the status block at the top left, just above the event log.
	var status_before: Rect2 = game._level_label.get_parent().get_global_rect()
	hero.ailments["gift"] = 5.0
	var hardening_before: int = hero.hardening
	hero.hardening = 2
	game._update_hud()
	game._place_hp_bar()
	var kinds := []
	for icon in game._status_row.get_children():
		kinds.append(icon.kind)
	check(kinds.has("gift") and not kinds.has("hardening"), "poison shows under the bar, hardening does not: %s" % [kinds])
	check(kinds == game.hero_ailments().map(func(c): return c[0]), "one icon per trouble: %s" % [kinds])
	for kind in kinds:
		check(not kind in StatusIcon.BOONS, "no boon under the bar: %s" % kind)
	var boons := []
	for icon in game._boon_row.get_children():
		boons.append(icon.kind)
	check(boons.has("hardening") and boons == game.hero_boons().map(func(c): return c[0]), "hardening shows in the boon row: %s" % [boons])
	for kind in boons:
		check(kind in StatusIcon.BOONS, "only boons in the boon row: %s" % kind)
	check(game._boon_row.get_parent() == game._level_label.get_parent(), "the boons sit in the status block at the top left")
	var boon_rect: Rect2 = game._boon_row.get_global_rect()
	check(boon_rect.position.x <= 40.0 and boon_rect.end.y <= EventLog.TOP, "the boon row is at the left, above the event log: %s" % boon_rect)
	check(boon_rect.position.y >= game._notice_row.get_global_rect().end.y, "under the notices: %s" % boon_rect)
	check(game._level_label.get_parent().get_global_rect().is_equal_approx(status_before), "a boon coming does not grow the status block")
	for row in [game._status_row, game._boon_row]:
		for icon in row.get_children():
			check(icon.tooltip_text != "" and icon.mouse_filter == Control.MOUSE_FILTER_PASS, "the %s icon explains itself under the pointer" % icon.kind)
	check(StatusIcon.frame_color("hardening") != StatusIcon.frame_color("gift") and StatusIcon.frame_color("hardening") != StatusIcon.frame_color("repair"), "boons, troubles and notices have frames of their own")
	var told := false
	for line in elog.entries():
		if line == game.icon_text("gift", ""):
			told = true
	check(told, "a new condition is explained once in the event log")
	check(not kinds.has("slow") or Items.load_factor(hero.load_weight()) < 1.0 - Items.MAX_WEIGHT_SLOW * 0.5 + 0.001, "no slow icon for a light load: %s" % [kinds])
	var row: Rect2 = game._status_row.get_global_rect()
	var bar_now: Rect2 = game._hp_bar.get_global_rect()
	check(row.position.y >= bar_now.end.y and is_equal_approx(row.position.x, bar_now.position.x), "the icons sit under the bar, from its left edge: %s vs %s" % [row, bar_now])
	hero.ailments.erase("gift")
	hero.hardening = hardening_before
	game._update_hud()
	check(game._boon_row.get_global_rect().is_equal_approx(boon_rect), "the boon row keeps its place when its icons go")
	# Worn gear shows as a gold-framed repair icon under the hero level.
	var shield_before: String = hero.equipped.get("schild", "")
	hero.equipped["schild"] = "rundschild"
	hero.wear["rundschild"] = 3
	game._update_hud()
	var notices := []
	for icon in game._notice_row.get_children():
		notices.append(icon.kind)
	check(notices.has("repair"), "a worn shield shows a repair icon: %s" % [notices])
	check(game._notice_row.get_parent() == game._xp_label.get_parent().get_parent(), "the notices sit in the status block under the hero level")
	hero.wear.erase("rundschild")
	if shield_before == "":
		hero.equipped.erase("schild")
	else:
		hero.equipped["schild"] = shield_before
	game._update_hud()
	notices = game.hero_notices().map(func(n): return n[0])
	check(not notices.has("repair"), "and it goes once the gear is mended: %s" % [notices])
	check(game._hp_bar.visible, "the life bar shows while playing")
	game.camera.global_position = hero.global_position + game._camera_offset()
	var feet: Vector2 = game.camera.unproject_position(hero.global_position)
	var bar: Rect2 = game._hp_bar.get_global_rect()
	check(bar.position.y > feet.y and absf(bar.get_center().x - feet.x) <= 1.0, "the life bar sits under the hero in the normal view: %s, feet %s" % [bar, feet])
	check(bar.size.is_equal_approx(game.HP_BAR_SIZE), "the life bar keeps its size: %s" % bar.size)
	for line in elog._lines.get_children():
		check((line as RichTextLabel).get_theme_font_size("normal_font_size") == EventLog.FONT_SIZE, "small type")
		break
