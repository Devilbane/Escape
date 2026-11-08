class_name ChatLine
extends LineEdit
## The hero's chat line, right under the event log: always on screen, with no
## box around it, only text over the world in the log's own type. A click on
## it, or Enter, makes it active (the caret shows and the text lights up);
## Enter sends what was written and keeps it active, so a talk can go on;
## Escape, or Enter on an empty line, leaves it again.
##
## While it is active the game's keys and the hero's walking keys must not
## fire: the line takes every key press before the game sees it, and the
## hero stops reading WASD and Shift (Player.typing, set by Game from
## `opened` and `closed`). It has one fixed size and place, so nothing around
## it moves when it is used. The game turns it off (allowed) while a window is
## open or the hero cannot act: then it is dim and cannot be clicked.

## What the hero wrote and sent.
signal said(text: String)
## The line became active / was left.
signal opened
signal closed

## Under the log, with a small gap; the first-steps card sits below it
## (see Tutorial.setup).
const GAP := 2.0
const HEIGHT := 32.0
## The line below the log: where it sits, so the card under it can follow.
const BOTTOM := EventLog.TOP + EventLog.HEIGHT + GAP + HEIGHT
## The most characters one line holds: a bubble over the hero has to stay
## readable.
const MAX_CHARS := 80
const FONT_SIZE := 15
## Resting (the hint) and active (the text being typed) colours.
const HINT_COLOR := Color(0.93, 0.91, 0.86, 0.6)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const CARET_COLOR := EventLog.NAME_COLOR

## Whether the line is on screen at all (while the game is played), and
## whether the game lets the hero chat now (no window is open); set by the game.
var shown: Callable = func() -> bool: return true
var allowed: Callable = func() -> bool: return true


func _init() -> void:
	position = Vector2(EventLog.LEFT, EventLog.TOP + EventLog.HEIGHT + GAP)
	_apply_width()
	max_length = MAX_CHARS
	# A click makes it active; Tab and the arrow keys never land here by chance.
	focus_mode = Control.FOCUS_CLICK
	context_menu_enabled = false
	caret_blink = true
	# Enter sends and the line stays active (the next Enter sends again).
	keep_editing_on_text_submit = true
	# Unframed: no box in any state, only the text on the world.
	for box in ["normal", "focus", "read_only"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 2
		empty.content_margin_right = 2
		add_theme_stylebox_override(box, empty)
	add_theme_font_override("font", EventLog.FONT)
	add_theme_font_size_override("font_size", UiKit.sized(FONT_SIZE))
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_placeholder_color", HINT_COLOR)
	add_theme_color_override("caret_color", CARET_COLOR)
	add_theme_color_override("font_selected_color", TEXT_COLOR)
	# The same outline the log's text has: readable over any scene.
	add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	add_theme_constant_override("outline_size", 3)
	focus_entered.connect(opened.emit)
	focus_exited.connect(closed.emit)
	text_submitted.connect(_on_submitted)
	gui_input.connect(_on_gui_input)


## The hint shown while the line rests, in the current language (the game
## calls it where it builds the HUD).
func set_hint() -> void:
	placeholder_text = Lang.t("Enter: Reden")
	tooltip_text = Lang.t("Klicke hier oder drücke Enter, um etwas zu sagen. Enter schickt, Esc geht zurück.")


## Makes the line active, if the game allows it.
func open() -> void:
	if allowed.call():
		grab_focus()


## Leaves the line and drops what was typed but not sent.
func leave() -> void:
	clear()
	release_focus()


## Whether the hero is typing now.
func is_typing() -> bool:
	return has_focus()


func _apply_width() -> void:
	custom_minimum_size = Vector2(EventLog.width, HEIGHT)
	size = custom_minimum_size


func _on_submitted(line: String) -> void:
	line = line.strip_edges()
	clear()
	if line == "":
		# Let go after this key press is dealt with: else the same Enter, seen
		# again by the game, would open the line anew.
		release_focus.call_deferred()
		return
	said.emit(line)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		leave()
		accept_event()


func _process(_delta: float) -> void:
	visible = shown.call()
	var ok: bool = visible and allowed.call()
	if not ok and has_focus():
		leave()
	# Off while a window is open: dim and out of the pointer's way.
	focus_mode = Control.FOCUS_CLICK if ok else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if ok else Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0 if ok else 0.4
	if custom_minimum_size.x != EventLog.width:
		_apply_width()
