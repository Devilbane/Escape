class_name EventLog
extends PanelContainer
## The event log at the left edge of the screen: what the hero finds (loot),
## what the people around say and every message shown over the hero's head
## (to read again later), newest at the bottom, in small type.
## The box has one fixed size and place, so a new line never moves or
## resizes anything else on screen: older lines slide up and out at its top.
## It dims when nothing new came for a while and lights up again with the
## next line. It stays hidden until the first line comes. The mouse wheel or
## a drag over the box scrolls back through the last KEEP lines.

## Where the box sits: below the status block at the top left, and well
## above the message line at the bottom (see Game.MESSAGE_BOTTOM).
const LEFT := 24.0
const TOP := 196.0
const WIDTH := 300.0
const HEIGHT := 200.0
## Small type for a list the player can glance at (fine print in the ux-ui
## guide's sizes; nothing the player must read to decide is only here).
const FONT_SIZE := 15
## Space between two lines, in pixels.
const GAP := 4
## Lines kept to scroll back through (the mouse wheel or a drag over the
## box); a hundred short labels cost next to nothing.
const KEEP := 100
## Pixels one turn of the mouse wheel scrolls.
const WHEEL_STEP := 40.0
## Seconds without a new line before the box dims, and how far.
const DIM_AFTER := 10.0
const DIM := 0.55
## The same line from the same speaker again within this many seconds (the
## hero bumping into someone twice) is written once.
const REPEAT_TIME := 6.0

const LOOT_COLOR := Color(0.75, 0.9, 1.0)
const SPEECH_COLOR := Color(0.93, 0.91, 0.86)
const NAME_COLOR := Color(1.0, 0.82, 0.4)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

var _lines: VBoxContainer
var _clip: Control
var _idle := 0.0
## How far the player scrolled back up, in pixels (0: the newest line at
## the bottom shows).
var _scroll := 0.0
var _last := ""


func _init() -> void:
	# The box takes the wheel and drags to scroll; nothing else.
	mouse_filter = MOUSE_FILTER_STOP
	position = Vector2(LEFT, TOP)
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.55)
	style.border_color = Color(0.85, 0.66, 0.32, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	# The lines hang from the bottom of a clipped area and grow upwards.
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(clip)
	_clip = clip
	_lines = VBoxContainer.new()
	_lines.mouse_filter = MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", GAP)
	_lines.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_lines.grow_vertical = GROW_DIRECTION_BEGIN
	clip.add_child(_lines)
	visible = false


## Something the hero found, already translated.
func add_loot(text: String, color := LOOT_COLOR) -> void:
	_add("", text, color)


## A message shown over the hero's head, already translated, in its colour.
func add_message(text: String, color := Color.WHITE) -> void:
	_add("", text, color)


## A line someone said, already translated; `speaker` is their name.
func add_speech(speaker: String, text: String) -> void:
	_add(speaker, text, SPEECH_COLOR)


func _add(speaker: String, text: String, color: Color) -> void:
	text = text.strip_edges().replace("\n", " ")
	if text == "":
		return
	var key := speaker + "|" + text
	if key == _last and _idle < REPEAT_TIME:
		return
	_last = key
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_theme_font_override("normal_font", FONT)
	line.add_theme_font_size_override("normal_font_size", UiKit.sized(FONT_SIZE))
	line.add_theme_color_override("default_color", color)
	line.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	line.add_theme_constant_override("outline_size", 2)
	# Item names marked by Rarity.marked show in the colour of their rarity.
	var body := Rarity.to_bbcode(_escape(text))
	if speaker != "":
		body = "[color=#%s]%s:[/color] %s" % [NAME_COLOR.to_html(false), _escape(speaker), body]
	line.text = body
	_lines.add_child(line)
	while _lines.get_child_count() > KEEP:
		var old := _lines.get_child(0)
		_lines.remove_child(old)
		old.queue_free()
	# Scrolled back to read: the new line must not push the text away under
	# the reader's eyes, so the view moves up with it.
	if _scroll > 0.0:
		_keep_view.call_deferred(line)
	visible = true
	_idle = 0.0
	modulate.a = 1.0


func _keep_view(line: Control) -> void:
	if is_instance_valid(line):
		scroll_to(_scroll + line.size.y + GAP)


## Scrolls back `pixels` from the newest line, within what there is.
func scroll_to(pixels: float) -> void:
	var most := maxf(0.0, _lines.get_combined_minimum_size().y - _clip.size.y)
	_scroll = clampf(pixels, 0.0, most)
	_lines.offset_top = _scroll
	_lines.offset_bottom = _scroll


## How far back the log is scrolled, in pixels (for tests).
func scrolled() -> float:
	return _scroll


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_to(_scroll + WHEEL_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_to(_scroll - WHEEL_STEP)
			accept_event()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# Dragging the text down shows older lines, as on a phone.
		scroll_to(_scroll + event.relative.y)
		accept_event()
	if event is InputEventMouse or event is InputEventScreenDrag:
		_idle = 0.0


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


## The lines in the log, oldest first, as plain text (for tests).
func entries() -> Array[String]:
	var out: Array[String] = []
	for line in _lines.get_children():
		out.append((line as RichTextLabel).get_parsed_text())
	return out


func _process(delta: float) -> void:
	_idle += delta
	modulate.a = move_toward(modulate.a, DIM if _idle > DIM_AFTER else 1.0, delta * 2.0)
