class_name EventLog
extends PanelContainer
## The event log at the left edge of the screen: what the hero finds (loot)
## and what the people around say, newest at the bottom, in small type.
## The box has one fixed size and place, so a new line never moves or
## resizes anything else on screen: older lines slide up and out at its top.
## It dims when nothing new came for a while and lights up again with the
## next line. It stays hidden until the first line comes.

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
## Lines kept; older ones are long gone above the top edge anyway.
const KEEP := 40
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
var _idle := 0.0
var _last := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
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
	line.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	line.add_theme_color_override("default_color", color)
	line.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	line.add_theme_constant_override("outline_size", 3)
	var body := _escape(text)
	if speaker != "":
		body = "[color=#%s]%s:[/color] %s" % [NAME_COLOR.to_html(false), _escape(speaker), body]
	line.text = body
	_lines.add_child(line)
	while _lines.get_child_count() > KEEP:
		var old := _lines.get_child(0)
		_lines.remove_child(old)
		old.queue_free()
	visible = true
	_idle = 0.0
	modulate.a = 1.0


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
