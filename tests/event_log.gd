extends SceneTree
## Headless test for the event log at the left edge of the screen (see
## EventLog): loot and speech go there instead of the message line, a spoken
## line is only written down when the hero is near enough to hear it, a
## reputation change is one short line, and the box keeps one size and place
## however many lines come, clear of the status block and the message line.
## Life shows as a small bar with its numbers, under the hero.
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
	# A long message on the message line, for the layout check.
	game.show_message("Eine lange Nachricht, die über mehrere Zeilen geht. ".repeat(4), 4.0)


func _check_layout() -> void:
	var elog: EventLog = game.event_log
	var box := elog.get_global_rect()
	check(box.is_equal_approx(rect_before), "the box keeps its size and place: %s vs %s" % [box, rect_before])
	check(box.size.is_equal_approx(Vector2(EventLog.WIDTH, EventLog.HEIGHT)), "the box has its fixed size: %s" % box.size)
	check(box.position.x <= 40.0, "the box is at the very left: %s" % box.position)
	var status: Control = game._level_label.get_parent()
	check(not box.intersects(status.get_global_rect()), "the box keeps clear of the status block: %s vs %s" % [box, status.get_global_rect()])
	check(not box.intersects(game._message_box.get_global_rect()), "the box keeps clear of the message line: %s vs %s" % [box, game._message_box.get_global_rect()])
	# Life is a small bar with its numbers on it, under the hero.
	var hero: Player = game.player
	hero.hp = maxi(1, hero.max_hp / 2)
	game._update_hud()
	check(is_equal_approx(game._hp_bar.value, hero.hp) and is_equal_approx(game._hp_bar.max_value, hero.max_hp), "the life bar shows the hero's life")
	check(game._hp_label.text == "%d / %d" % [hero.hp, hero.max_hp], "with the numbers on it: %s" % game._hp_label.text)
	game.state = game.State.PLAYING
	game._place_hp_bar()
	check(game._hp_bar.visible, "the life bar shows while playing")
	var feet: Vector2 = game.camera.unproject_position(hero.global_position)
	var bar: Rect2 = game._hp_bar.get_global_rect()
	check(bar.position.y > feet.y and absf(bar.get_center().x - feet.x) <= 1.0, "the life bar sits under the hero: %s, feet %s" % [bar, feet])
	check(bar.size.is_equal_approx(game.HP_BAR_SIZE), "the life bar keeps its size: %s" % bar.size)
	for line in elog._lines.get_children():
		check((line as RichTextLabel).get_theme_font_size("normal_font_size") == EventLog.FONT_SIZE, "small type")
		break
