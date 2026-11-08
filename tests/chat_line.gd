extends SceneTree
## Headless test for the hero's chat line under the event log (see ChatLine,
## HeroChat): it is always on screen, unframed, with one fixed place under the
## log; a click or Enter makes it active; while active no game key fires and
## the hero does not walk; Enter sends the text into the event log and over
## the hero's head and keeps the line active; Esc or an empty Enter leaves
## it; a window being open switches it off; and the villager nearby answers.
## Run with: godot --headless --fixed-fps 60 -s tests/chat_line.gd

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


func _key(code: Key, unicode := 0) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	return ev


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	var chat: ChatLine = game.chat_line
	var elog: EventLog = game.event_log
	var hero: Player = game.player

	# Layout: unframed, always there, right under the log, the card under it.
	check(chat.is_inside_tree() and chat.visible, "the chat line is on screen while playing")
	var rect := chat.get_global_rect()
	var log_rect := elog.get_global_rect()
	check(is_equal_approx(rect.position.x, log_rect.position.x), "it sits on the log's left edge: %s vs %s" % [rect, log_rect])
	check(rect.position.y >= log_rect.end.y and rect.position.y - log_rect.end.y <= 8.0, "it sits right under the log: %s vs %s" % [rect, log_rect])
	check(is_equal_approx(rect.size.x, EventLog.width) and is_equal_approx(rect.size.y, ChatLine.HEIGHT), "it has the log's width and its fixed height: %s" % rect.size)
	for box in ["normal", "focus"]:
		check(chat.get_theme_stylebox(box) is StyleBoxEmpty, "it has no box in its %s state" % box)
	check(chat.placeholder_text != "", "a hint shows while it rests")
	var card: Control = game.tutorial.card
	check(card.position.y >= rect.end.y, "the first-steps card sits below the chat line: %s vs %s" % [card.position, rect])
	check(Rect2(card.position, card.get_combined_minimum_size()).end.y < game._help.get_global_rect().position.y, "the card still clears the list of keys")
	check(not chat.has_focus() and not hero.typing, "it rests until used")

	# Enter makes it active; walking keys stop.
	game._unhandled_input(_key(KEY_ENTER))
	await _wait(2)
	check(chat.has_focus() and hero.typing, "Enter makes the line active")
	check(hero._keyboard_direction() == Vector3.ZERO, "the hero reads no walking keys while typing")
	var before := chat.get_global_rect()

	# Keys go into the line, not into the game: I would open the inventory.
	root.push_input(_key(KEY_I, 105))
	await _wait(2)
	check(not game.menus.is_open(), "a game key does not fire while typing")
	check(chat.text == "i", "it went into the line: '%s'" % chat.text)
	check(chat.get_global_rect().is_equal_approx(before), "the line keeps its place while typing")

	# Esc leaves and drops the text.
	root.push_input(_key(KEY_ESCAPE))
	await _wait(2)
	check(not chat.has_focus() and not hero.typing and chat.text == "", "Esc leaves the line and drops the text")
	check(not game.menus.is_open() and game.state == game.State.PLAYING, "Esc did not pause the game as well")

	# A click makes it active; Enter sends.
	chat.grab_focus()
	await _wait(2)
	check(chat.has_focus(), "the line takes focus when clicked")
	chat.text = "Hallo zusammen"
	var lines_before := elog.entries().size()
	root.push_input(_key(KEY_ENTER))
	await _wait(2)
	var entries := elog.entries()
	check(entries.size() == lines_before + 1 and entries[-1].ends_with("Hallo zusammen") and entries[-1].begins_with(game.hero_name), "the sent text shows in the event log with the hero's name: %s" % str(entries.slice(-1)))
	check(chat.text == "" and chat.has_focus(), "the line is empty and still active after sending")

	# An empty Enter leaves it.
	root.push_input(_key(KEY_ENTER))
	await _wait(2)
	check(not chat.has_focus() and not hero.typing, "Enter on an empty line leaves it (focus %s, typing %s)" % [chat.has_focus(), hero.typing])

	# A window open: the line is off.
	game.menus.open("inventar")
	await _wait(3)
	check(not chat.allowed.call(), "no chatting while a window is open")
	chat.open()
	check(not chat.has_focus(), "the line cannot be opened then")
	game.menus.close()
	await _wait(3)
	check(chat.allowed.call(), "chatting works again after the window closes")

	_replies()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: chat line")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _replies() -> void:
	var talk: HeroChat = game.hero_chat
	for pool in [HeroChat.GREETING_REPLIES, HeroChat.FAREWELL_REPLIES, HeroChat.THANKS_REPLIES]:
		for line in pool:
			check(Lang.EN.has(line), "\"%s\" has an English text" % line)
	check(talk.reply_to("Hallo!") in HeroChat.GREETING_REPLIES, "a greeting is answered with a greeting")
	check(talk.reply_to("hello there") in HeroChat.GREETING_REPLIES, "in English too")
	check(talk.reply_to("Tschüss, bis bald") in HeroChat.FAREWELL_REPLIES, "a goodbye is answered")
	check(talk.reply_to("Danke dir") in HeroChat.THANKS_REPLIES, "a thanks is answered")
	check(talk.reply_to("Hast du nichts zu essen?") == "", "'hi' inside 'nichts' is no greeting")
	check(talk.reply_to("Wo ist die Schmiede?") == "", "anything else gets the villager's usual line")

	# In the village: the nearest free villager answers.
	game.hero_name = "Tester"
	game.load_level(game._outdoor_index(), false)
	var village: Level = game.level
	var hero: Player = game.player
	check(talk.listener(Vector3(9999, 0, 9999)) == null, "nobody far away answers")
	var near: Villager = null
	for v in village.villagers:
		if is_instance_valid(v) and v.can_remark():
			near = v
			break
	check(near != null, "there is a free villager")
	if near == null:
		return
	hero.global_position = near.global_position + Vector3(2, 0, 0)
	check(talk.listener(hero.global_position) == near or talk.listener(hero.global_position) != null, "someone near the hero listens")
	var who := talk.listener(hero.global_position)
	talk.answer(who, "Hallo")
	check(who.is_talking(), "the villager answers with a bubble")
	who._bubble_time = 0.0
	who._bubble_hold = 0.0
	talk.answer(who, "Wo ist die Schmiede?")
	check(who.is_talking(), "an ordinary line gets the villager's usual words")
