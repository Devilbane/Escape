extends SceneTree
## Headless test: messages float just over the hero's head and are written
## into the event log as well.
## - A message shows centred over the hero, its lower edge above the name
##   over the head, and the name keeps clear of it.
## - Every message lands in the event log too, in its own colour.
## - Unread messages stack upwards over the head, never on the name.
## - Words rising from the hero's head (damage, experience) never run
##   through the message lines; the lines go back down once nothing shows.
## - Without a hero on screen (the title) the message sits low in the middle.
## - The message and event log text is a quarter smaller than it was; the
##   name over the head keeps its size.
## Run with: godot --headless --fixed-fps 60 -s tests/message_over_head.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var stage_frames := 0
var hero: Player
var name_box := Rect2()
var crossed := false
var lifted := 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	if failures == 0:
		print("PASS: message over head")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The name over the hero's head on screen (its letters, roughly).
func _name_rect() -> Rect2:
	var cam: Camera3D = game.camera
	var tag: Label3D = hero.name_tag
	var at := tag.global_position
	var half_w := tag.font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size).x * tag.pixel_size * 0.5
	var half_h := tag.font_size * tag.pixel_size * 0.5
	var rect := Rect2(cam.unproject_position(at), Vector2.ZERO)
	for corner in [Vector3(half_w, half_h, 0), Vector3(-half_w, half_h, 0), Vector3(half_w, -half_h, 0), Vector3(-half_w, -half_h, 0)]:
		rect = rect.expand(cam.unproject_position(at + cam.global_basis * corner))
	return rect


func _shown_lines() -> Array:
	return game.message_lines().filter(func(l): return l.modulate.a > 0.05 and l.text != "")


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	stage_frames += 1
	match stage:
		0:
			_title_check()
			hero = game.player
			game.state = game.State.PLAYING
			hero.set_display_name("Testheld")
			game.camera.global_position = hero.global_position + game._camera_offset()
			_next()
		1:
			if stage_frames == 1:
				game.show_message("Die Tür öffnet sich knarrend...", 3.0)
			elif stage_frames == 30:
				_over_head_check()
				_next()
		2:
			if stage_frames == 1:
				game.show_message("Eine zweite Nachricht kommt, bevor die erste gelesen ist.", 3.0)
			elif stage_frames == 20:
				_stack_check()
				_next()
		3:
			if stage_frames == 1:
				for line in game.message_lines():
					line.modulate.a = 0.0
				game._message_tween.kill()
				game.place_message()
				game.show_message("Die Klinge trifft dich!", 3.0)
				Effects.head_text(game.level, hero, 2.2, "-3", Color(1, 0.3, 0.3))
				Effects.float_text(game.level, hero.global_position + Vector3(0, 2.4, 0), "+40 EP", game.XP_COLOR)
				Effects.head_text(game.level, hero, 2.2, "-2", Color(1, 0.3, 0.3))
			else:
				_words_check()
			if stage_frames == 150:
				check(not crossed, "no rising word runs through a message line")
				check(lifted > 0.0, "the lines moved up out of the words' way")
				_next()
		4:
			if stage_frames == 400:
				check(game._message_lift == 0.0, "the lines go back down once nothing shows: %s" % game._message_lift)
				_finish()
				return true
	return false


func _next() -> void:
	stage += 1
	stage_frames = 0


func _title_check() -> void:
	check(game.state != game.State.PLAYING, "the game starts at the title")
	game.show_message("Willkommen", 2.0)
	var box: Rect2 = game._message_box.get_global_rect()
	var screen: Vector2 = game._hud.get_viewport().get_visible_rect().size
	check(absf(box.end.y - (screen.y - game.MESSAGE_BOTTOM)) <= 1.0, "without a hero the message sits low: %s" % box)
	check(absf(box.get_center().x - screen.x / 2.0) <= 1.0, "and centred: %s" % box)
	check(game.event_log.entries().has("Willkommen"), "the message is in the event log")


func _over_head_check() -> void:
	var cam: Camera3D = game.camera
	var line: Label = game._message
	var rect := line.get_global_rect()
	name_box = _name_rect()
	var feet := cam.unproject_position(hero.global_position)
	check(rect.end.y <= name_box.position.y, "the message is over the name: %s vs %s" % [rect, name_box])
	check(name_box.position.y - rect.end.y <= 40.0, "just over it, not far off: %s vs %s" % [rect, name_box])
	check(absf(rect.get_center().x - feet.x) <= 2.0, "centred over the hero: %s, feet %s" % [rect, feet])
	check(rect.size.x <= game.MESSAGE_WIDTH + 1.0, "no wider than the message column: %s" % rect)
	check(not rect.intersects(game.event_log.get_global_rect()), "clear of the event log: %s" % rect)
	var entries: Array[String] = game.event_log.entries()
	check(entries.back() == "Die Tür öffnet sich knarrend...", "the message is in the event log: %s" % [entries])
	var logged: RichTextLabel = game.event_log._lines.get_child(game.event_log._lines.get_child_count() - 1)
	check(logged.get_theme_color("default_color").is_equal_approx(Color.WHITE), "in its own colour")
	game.show_message("Gefahr!", 2.0, Color(1.0, 0.45, 0.25))
	logged = game.event_log._lines.get_child(game.event_log._lines.get_child_count() - 1)
	check(logged.get_theme_color("default_color").is_equal_approx(Color(1.0, 0.45, 0.25)), "a coloured message keeps its colour in the log")
	# A quarter smaller than before (24 and 15); the name keeps its 30.
	check(game.MESSAGE_FONT_SIZE == 18, "the message text is a quarter smaller")
	check(EventLog.FONT_SIZE == 11, "the event log text is a quarter smaller")
	check(hero.name_tag.font_size == 30, "the name over the head keeps its size")
	check(hero.name_tag.position.y > 3.0, "the name sits higher than before")


func _stack_check() -> void:
	var lines := _shown_lines()
	check(lines.size() >= 2, "the unread message stays above the new one (%d lines)" % lines.size())
	var name_now := _name_rect()
	for i in lines.size():
		var r: Rect2 = lines[i].get_global_rect()
		check(not r.grow(-1).intersects(name_now), "\"%s\" keeps off the name" % lines[i].text)
		for j in range(i + 1, lines.size()):
			check(not r.grow(-1).intersects(lines[j].get_global_rect().grow(-1)), "message lines do not overlap")


func _words_check() -> void:
	lifted = maxf(lifted, game._message_lift)
	var cam: Camera3D = game.camera
	for n in DamageNumber.all():
		if n.modulate.a < 0.1 or n._age < DamageNumber.POP_TIME or cam.is_position_behind(n.global_position):
			continue
		var word: Rect2 = n.screen_rect(cam)
		for line in _shown_lines():
			if line.get_global_rect().grow(-1).intersects(word.grow(-1)) and not crossed:
				crossed = true
				print("  \"%s\" runs through \"%s\": %s vs %s" % [n.text, line.text, word, line.get_global_rect()])
