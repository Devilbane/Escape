class_name EventLog
extends PanelContainer
## The event log at the left edge of the screen: what the hero finds (loot),
## what the people around say and every message shown over the hero's head
## (to read again later), newest at the bottom, in small type.
## The box has one fixed size and place, so a new line never moves or
## resizes anything else on screen: older lines slide up and out at its top.
## Only the text shows over the world: the dark box behind it fades in while
## the player clicks on it or scrolls it, and fades out again a little after
## (FRAME_STAY). The text dims when nothing new came for a while and lights
## up again with the next line. It stays hidden until the first line comes.
## The mouse wheel or a drag over the box scrolls back through the last KEEP
## lines. Its width is the player's: a slider in the pull-out menu sets it
## between MIN_WIDTH and MAX_WIDTH, kept in the settings file. The height
## stays, so the first-steps card below it never moves.
## A slim scroll bar is drawn in the box's right margin (so it takes no room
## from the text or the box): it shows while the dark box shows and as long as
## the log is scrolled back, and its handle can be dragged.

## Where the box sits: below the status block at the top left, and well
## above the message line at the bottom (see Game.MESSAGE_BOTTOM).
const LEFT := 16.0
const TOP := 188.0
const HEIGHT := 200.0
## The width the player can pick with the slider, and the step it moves in.
## At MAX_WIDTH the box still keeps clear of the message line (Game.MESSAGE_MARGIN).
const MIN_WIDTH := 160.0
const MAX_WIDTH := 300.0
const DEFAULT_WIDTH := 240.0
const WIDTH_STEP := 20.0
const SETTINGS_FILE := Sfx.SETTINGS_FILE
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
## Seconds the dark box stays after the last click or scroll before it fades
## out, and how fast it fades in and out (share of full per second).
const FRAME_STAY := 2.5
const FRAME_FADE := 4.0
## The dark box at full strength: its background and its border.
const FRAME_BG := Color(0.04, 0.03, 0.08, 0.55)
const FRAME_BORDER := Color(0.85, 0.66, 0.32, 0.35)
## The same line from the same speaker again within this many seconds (the
## hero bumping into someone twice) is written once.
const REPEAT_TIME := 6.0
## The scroll bar: its drawn width, its distance from the box's right edge, the
## width of the strip that grabs it, and the shortest handle.
const BAR_WIDTH := 5.0
const BAR_INSET := 3.0
const BAR_GRAB := 18.0
const BAR_MIN_HANDLE := 20.0
## How strongly the bar shows while the log is scrolled back but the dark box
## has faded.
const BAR_HELD := 0.6

const LOOT_COLOR := Color(0.75, 0.9, 1.0)
const SPEECH_COLOR := Color(0.93, 0.91, 0.86)
const NAME_COLOR := Color(1.0, 0.82, 0.4)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")

var _lines: VBoxContainer
var _clip: Control
var _idle := 0.0
## How strongly the dark box shows (0: only the text), and the seconds since
## the player last clicked on the box or scrolled it.
var _frame := 0.0
var _since_touch := INF
var _style: StyleBoxFlat
## How far the player scrolled back up, in pixels (0: the newest line at
## the bottom shows).
var _scroll := 0.0
var _last := ""
var _bar_drag := false

## The width the player picked (see set_width), shared by every log.
static var width := DEFAULT_WIDTH


## Reads the width from the settings file (DEFAULT_WIDTH when none is kept).
static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		width = _clamped(float(cfg.get_value("protokoll", "breite", DEFAULT_WIDTH)))


static func _clamped(value: float) -> float:
	return clampf(snappedf(value, WIDTH_STEP), MIN_WIDTH, MAX_WIDTH)


func _init() -> void:
	# The box takes the wheel and drags to scroll; nothing else.
	mouse_filter = MOUSE_FILTER_STOP
	position = Vector2(LEFT, TOP)
	_apply_width()
	var style := StyleBoxFlat.new()
	_style = style
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_show_frame(0.0)
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


## Sets the width of the box (within MIN_WIDTH and MAX_WIDTH) and keeps it in
## the settings file. The dark box shows for a moment, so the player sees the
## new size while moving the slider, even before the first line came.
func set_width(value: float) -> void:
	width = _clamped(value)
	_apply_width()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("protokoll", "breite", width)
	cfg.save(SETTINGS_FILE)
	visible = true
	_since_touch = 0.0
	if _scroll > 0.0:
		# Narrower lines wrap into more rows: keep the scroll within them.
		scroll_to.call_deferred(_scroll)


## Takes the width read by load_settings (the box is made before it is read).
func use_saved_width() -> void:
	_apply_width()


func _apply_width() -> void:
	custom_minimum_size = Vector2(width, HEIGHT)
	size = custom_minimum_size


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
	line.add_theme_constant_override("outline_size", 3)
	# Without the dark box behind it the text stands on the world: an outline
	# and a shadow keep it readable there (as Game._make_label does).
	line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	line.add_theme_constant_override("shadow_offset_y", 2)
	line.add_theme_constant_override("shadow_offset_x", 1)
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
	queue_redraw.call_deferred()


func _keep_view(line: Control) -> void:
	if is_instance_valid(line):
		scroll_to(_scroll + line.size.y + GAP)


## Scrolls back `pixels` from the newest line, within what there is.
func scroll_to(pixels: float) -> void:
	var most := maxf(0.0, _lines.get_combined_minimum_size().y - _clip.size.y)
	_scroll = clampf(pixels, 0.0, most)
	_lines.offset_top = _scroll
	_lines.offset_bottom = _scroll
	queue_redraw()


## How far back the log is scrolled, in pixels (for tests).
func scrolled() -> float:
	return _scroll


## The room the lines can scroll back through, in pixels.
func _scroll_range() -> float:
	return maxf(0.0, _lines.get_combined_minimum_size().y - _clip.size.y)


## The bar's track: the strip in the right margin, as long as the text area.
func _bar_track() -> Rect2:
	var top := _clip.position.y
	return Rect2(size.x - BAR_INSET - BAR_WIDTH, top, BAR_WIDTH, _clip.size.y)


## The handle inside the track (empty when there is nothing to scroll).
func _bar_handle() -> Rect2:
	var track := _bar_track()
	var most := _scroll_range()
	if most <= 0.0:
		return Rect2()
	var total := most + _clip.size.y
	var h := clampf(track.size.y * _clip.size.y / total, BAR_MIN_HANDLE, track.size.y)
	var y := track.position.y + (track.size.y - h) * (1.0 - clampf(_scroll / most, 0.0, 1.0))
	return Rect2(track.position.x, y, track.size.x, h)


## The handle's rectangle in the box's own coordinates (for tests).
func bar_handle() -> Rect2:
	return _bar_handle()


func _bar_strength() -> float:
	return maxf(_frame, BAR_HELD if _scroll > 0.0 or _bar_drag else 0.0)


func _draw() -> void:
	var handle := _bar_handle()
	var strength := _bar_strength()
	if handle.size == Vector2.ZERO or strength <= 0.0:
		return
	var track := _bar_track()
	draw_rect(track, Color(0, 0, 0, 0.3 * strength))
	var alpha := (1.0 if _bar_drag else 0.7) * strength
	draw_rect(handle, Color(UiKit.GOLD, alpha))


## Scrolls so the handle's middle sits at `y` (box coordinates).
func _scroll_to_bar(y: float) -> void:
	var track := _bar_track()
	var handle := _bar_handle()
	var room := track.size.y - handle.size.y
	if room <= 0.0:
		return
	var share := clampf((y - handle.size.y / 2.0 - track.position.y) / room, 0.0, 1.0)
	scroll_to((1.0 - share) * _scroll_range())


func _gui_input(event: InputEvent) -> void:
	# The bar's strip takes a press and a drag along it.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.x >= size.x - BAR_GRAB and _scroll_range() > 0.0:
			_bar_drag = true
			_since_touch = 0.0
			_scroll_to_bar(event.position.y)
			accept_event()
			return
		if not event.pressed and _bar_drag:
			_bar_drag = false
			queue_redraw()
			accept_event()
			return
	elif event is InputEventMouseMotion and _bar_drag:
		_since_touch = 0.0
		_scroll_to_bar(event.position.y)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed:
		# A click on the box or a turn of the wheel shows the dark box.
		_since_touch = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_to(_scroll + WHEEL_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_to(_scroll - WHEEL_STEP)
			accept_event()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		# Dragging the text down shows older lines, as on a phone.
		_since_touch = 0.0
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


## How strongly the dark box behind the text shows now (0 to 1, for tests).
func frame_strength() -> float:
	return _frame


func _show_frame(strength: float) -> void:
	_frame = strength
	_style.bg_color = Color(FRAME_BG, FRAME_BG.a * strength)
	_style.border_color = Color(FRAME_BORDER, FRAME_BORDER.a * strength)
	queue_redraw()


func _process(delta: float) -> void:
	_idle += delta
	_since_touch += delta
	modulate.a = move_toward(modulate.a, DIM if _idle > DIM_AFTER else 1.0, delta * 2.0)
	var want := 1.0 if _since_touch < FRAME_STAY else 0.0
	if _frame != want:
		_show_frame(move_toward(_frame, want, delta * FRAME_FADE))
	elif want == 0.0 and _lines.get_child_count() == 0:
		# Shown only to preview its width (set_width): hidden again until the
		# first line comes.
		visible = false
