extends SceneTree
## Headless test: the event log shows only its text over the world. Its dark
## box fades in while the player clicks on it or scrolls it, and fades out
## again a little after; it never moves or resizes the log.
## Run with: godot --headless --fixed-fps 60 -s tests/event_log_frame.gd

var failures := 0
var elog: EventLog


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	elog = EventLog.new()
	root.add_child(elog)


func _wait(seconds: float) -> void:
	elog._process(seconds)


func _wheel() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	elog._gui_input(e)


func _process(_delta: float) -> bool:
	for i in 20:
		elog.add_loot("Fund Nummer %d" % i)
	var rect := elog.get_global_rect()
	var style: StyleBoxFlat = elog.get_theme_stylebox("panel")
	check(elog.frame_strength() == 0.0, "at first only the text shows")
	check(style.bg_color.a == 0.0 and style.border_color.a == 0.0, "no box behind the text: %s" % style.bg_color)
	# A turn of the wheel brings the box in, and scrolls.
	_wheel()
	for i in 10:
		_wait(0.05)
	check(elog.frame_strength() == 1.0, "scrolling shows the box: %s" % elog.frame_strength())
	check(is_equal_approx(style.bg_color.a, EventLog.FRAME_BG.a), "at its full darkness: %s" % style.bg_color)
	check(elog.scrolled() > 0.0, "and scrolls back")
	# It stays while the player keeps at it, then fades out.
	_wait(EventLog.FRAME_STAY - 1.0)
	check(elog.frame_strength() == 1.0, "the box stays a moment after the scroll")
	for i in 40:
		_wait(0.05)
	check(elog.frame_strength() == 0.0, "then it fades out: %s" % elog.frame_strength())
	# A click brings it back too; hovering alone does not.
	var hover := InputEventMouseMotion.new()
	elog._gui_input(hover)
	_wait(0.5)
	check(elog.frame_strength() == 0.0, "the pointer passing over does not show the box")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	elog._gui_input(click)
	_wait(0.1)
	check(elog.frame_strength() > 0.0, "a click shows the box")
	# Dragging the text (touch or mouse) counts as scrolling.
	for i in 60:
		_wait(0.05)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 10)
	elog._gui_input(drag)
	_wait(0.1)
	check(elog.frame_strength() > 0.0, "dragging shows the box")
	check(elog.get_global_rect() == rect, "the log keeps its place and size: %s" % elog.get_global_rect())
	var line: RichTextLabel = elog._lines.get_child(0)
	check(line.get_theme_constant("outline_size") >= 3 and line.get_theme_color("font_shadow_color").a > 0.0, "the text has an outline and a shadow to stand on the world")
	if failures == 0:
		print("PASS: event log frame")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true
