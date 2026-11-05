extends SceneTree
## Headless test for the event log's width slider in the pull-out menu (see
## EventLog.set_width): the slider sets the box's width between MIN_WIDTH and
## MAX_WIDTH, its place and height stay (so the first-steps card below it
## never moves), the width is kept in the settings file and comes back on the
## next start, and the slider lines up with the volume sliders above it.
## Run with: godot --headless --fixed-fps 60 -s tests/event_log_width.gd

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


func _saved_width() -> float:
	var cfg := ConfigFile.new()
	cfg.load(EventLog.SETTINGS_FILE)
	return float(cfg.get_value("protokoll", "breite", -1.0))


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	var kept := EventLog.width
	var elog: EventLog = game.event_log
	var slider: HSlider = game._log_width_slider

	check(EventLog.DEFAULT_WIDTH < EventLog.MAX_WIDTH, "the default is narrower than the old fixed width")
	check(slider != null and game._drawer.is_ancestor_of(slider), "the width slider is in the pull-out menu")
	check(is_equal_approx(slider.min_value, EventLog.MIN_WIDTH) and is_equal_approx(slider.max_value, EventLog.MAX_WIDTH), "the slider runs from the narrowest to the widest log")
	check(is_equal_approx(slider.value, EventLog.width), "the slider shows the log's width")
	check(slider.tooltip_text != "", "the slider explains itself on hover")

	# Moving the slider: only the width changes, the box stays in place.
	var before := elog.get_global_rect()
	var card_before: Vector2 = game.tutorial.card.position
	slider.value = EventLog.MIN_WIDTH
	await _wait(3)
	var narrow := elog.get_global_rect()
	check(is_equal_approx(narrow.size.x, EventLog.MIN_WIDTH), "the slider makes the log narrower: %s" % narrow.size)
	check(is_equal_approx(narrow.size.y, EventLog.HEIGHT), "its height stays: %s" % narrow.size)
	check(narrow.position.is_equal_approx(before.position), "its place stays: %s vs %s" % [narrow.position, before.position])
	check(game.tutorial.card.position.is_equal_approx(card_before), "the first-steps card below stays where it was")
	check(elog.visible and elog.frame_strength() > 0.0, "the box shows while the slider moves, to see its size")
	check(is_equal_approx(_saved_width(), EventLog.MIN_WIDTH), "the width is saved")

	slider.value = EventLog.MAX_WIDTH
	await _wait(3)
	var wide := elog.get_global_rect()
	check(is_equal_approx(wide.size.x, EventLog.MAX_WIDTH), "the slider makes the log wider: %s" % wide.size)
	check(not wide.intersects(game._message_box.get_global_rect()), "at its widest the log keeps clear of the message line")

	# Lines wrap to the new width.
	for i in 6:
		elog.add_message("Eine recht lange Zeile, die im schmalen Protokoll in mehrere Reihen umbrechen muss %d" % i)
	await _wait(3)
	var line: Control = elog._lines.get_child(elog._lines.get_child_count() - 1)
	var tall_wide := line.size.y
	slider.value = EventLog.MIN_WIDTH
	await _wait(3)
	check(line.size.x <= EventLog.MIN_WIDTH, "a line takes the narrower width: %s" % line.size)
	check(line.size.y > tall_wide, "and wraps into more rows: %s vs %s" % [line.size.y, tall_wide])

	# The saved width comes back on the next start, within the slider's range.
	EventLog.width = EventLog.DEFAULT_WIDTH
	EventLog.load_settings()
	check(is_equal_approx(EventLog.width, EventLog.MIN_WIDTH), "the width is loaded again")
	var cfg := ConfigFile.new()
	cfg.load(EventLog.SETTINGS_FILE)
	cfg.set_value("protokoll", "breite", 9999.0)
	cfg.save(EventLog.SETTINGS_FILE)
	EventLog.load_settings()
	check(is_equal_approx(EventLog.width, EventLog.MAX_WIDTH), "a width out of range is held to the slider's range")

	# The three sliders of the menu line up: their labels share one width,
	# which fits the longest label in both languages.
	var font: Font = game.TEXT_FONT
	var font_size := UiKit.sized(18)
	for text in ["Musik", "Effekte", "Protokoll"]:
		for shown in [text, Lang.EN.get(text, text)]:
			var w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			check(w <= game.SLIDER_LABEL_WIDTH, "\"%s\" fits in front of its slider: %s" % [shown, w])
	var left: float = slider.get_global_rect().position.x
	for other in [game._music_slider, game._effects_slider]:
		check(is_equal_approx(other.get_global_rect().position.x, left), "the sliders start on one line")
		check(is_equal_approx(other.get_global_rect().size.x, slider.get_global_rect().size.x), "and have one length")

	elog.set_width(kept)
	if failures == 0:
		print("PASS: event log width")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
