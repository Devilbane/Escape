class_name EditorUi
extends RefCounted
## The controls of the map workshop (see LevelEditor) in the game's house
## style: the game's own buttons and labels (Game._make_button,
## Game._make_label, Menus.panel_style), and fields, number boxes, lists and
## ticks styled to match. Every text is at least 16 px.

const GAME := preload("res://scripts/game.gd")
const GOLD := Color(1.0, 0.82, 0.4)
const TEXT := Color(1, 0.95, 0.85)
const DIM := Color(1, 0.95, 0.85, 0.7)
const BORDER := Color(0.85, 0.66, 0.32, 0.8)
const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const ROW_GAP := 6
const GROUP_GAP := 12
const LABEL_WIDTH := 124


static func label(text: String, size := 16, color := TEXT) -> Label:
	var l: Label = GAME._make_label(FONT, size, color)
	l.text = text
	return l


static func button(text: String, action: Callable, min_size := Vector2(140, 52)) -> Button:
	var b: Button = GAME._make_button(text, action)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	return b


## A button that stays pressed while it is the chosen one (tools, tabs, tiles).
static func toggle(text: String, action: Callable, min_size := Vector2(44, 44)) -> Button:
	var b := button(text, action, min_size)
	b.toggle_mode = true
	return b


## Room between a button's border and its text, for buttons whose text wraps.
static func pad(b: Button, margin := 12) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBox = b.get_theme_stylebox(state).duplicate()
		style.content_margin_left = margin
		style.content_margin_right = margin
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, style)


static var _ticks := {}


## The box of a tick, drawn in the game's gold: empty, or filled when ticked;
## dimmed when it cannot be used.
static func tick_icon(on: bool, enabled := true) -> Texture2D:
	var key := "%s%s" % [on, enabled]
	if _ticks.has(key):
		return _ticks[key]
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := GOLD if enabled else Color(GOLD, 0.35)
	for y in n:
		for x in n:
			var border := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			if border:
				img.set_pixel(x, y, edge)
			elif on and x >= 6 and y >= 6 and x < n - 6 and y < n - 6:
				img.set_pixel(x, y, edge)
			else:
				img.set_pixel(x, y, Color(0.08, 0.05, 0.1, 0.9))
	_ticks[key] = ImageTexture.create_from_image(img)
	return _ticks[key]


static func field_style(border := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.05, 0.1, 0.9)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func line_edit(text: String, changed: Callable, max_length := 0) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.max_length = max_length
	e.custom_minimum_size = Vector2(0, 44)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(e)
	e.add_theme_stylebox_override("normal", field_style())
	e.add_theme_stylebox_override("focus", field_style(GOLD))
	e.text_changed.connect(changed)
	return e


static func spin(value: float, low: float, high: float, step: float, changed: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(110, 44)
	s.custom_arrow_step = step
	var e := s.get_line_edit()
	_style(e)
	e.add_theme_stylebox_override("normal", field_style())
	e.add_theme_stylebox_override("focus", field_style(GOLD))
	s.value_changed.connect(changed)
	return s


## A list to choose from: [[id, label], ...]; an id of "" is a heading.
static func choice(options: Array, current: String, chosen: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0, 44)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Never wider than its place: a long item is cut, the list shows it whole.
	o.fit_to_longest_item = false
	o.clip_text = true
	_style(o)
	for s in ["normal", "hover", "pressed", "focus"]:
		o.add_theme_stylebox_override(s, field_style(GOLD if s != "normal" else BORDER))
	var popup := o.get_popup()
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_font_override("font_separator", FONT)
	popup.add_theme_font_size_override("font_separator_size", 16)
	popup.add_theme_color_override("font_separator_color", GOLD)
	# An option with an empty key is a heading: a separator with its name,
	# so a long list falls into groups.
	for option in options:
		if option[0] == "":
			o.add_separator(option[1])
			continue
		o.add_item(option[1])
		var i := o.item_count - 1
		o.set_item_metadata(i, option[0])
		if option[0] == current:
			o.select(i)
	o.item_selected.connect(func(i): chosen.call(o.get_item_metadata(i)))
	return o


static func check(text: String, on: bool, toggled: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 44)
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(c)
	c.add_theme_color_override("font_hover_color", GOLD)
	c.add_theme_color_override("font_disabled_color", Color(1, 0.95, 0.85, 0.4))
	c.add_theme_constant_override("h_separation", 10)
	c.add_theme_icon_override("checked", tick_icon(true))
	c.add_theme_icon_override("unchecked", tick_icon(false))
	c.add_theme_icon_override("checked_disabled", tick_icon(true, false))
	c.add_theme_icon_override("unchecked_disabled", tick_icon(false, false))
	c.add_theme_color_override("font_pressed_color", TEXT)
	c.toggled.connect(toggled)
	return c


static func color_button(color: Color, changed: Callable) -> ColorPickerButton:
	var b := ColorPickerButton.new()
	b.color = color
	b.edit_alpha = false
	b.custom_minimum_size = Vector2(64, 44)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.color_changed.connect(changed)
	return b


## A label in front of a control, the label column LABEL_WIDTH wide.
static func row(text: String, control: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	var l := label(text)
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(l)
	r.add_child(control)
	return r


static func vbox(gap := ROW_GAP) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	return b


static func hbox(gap := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	return b


static func _style(c: Control) -> void:
	c.add_theme_font_override("font", FONT)
	c.add_theme_font_size_override("font_size", 16)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_placeholder_color", Color(1, 0.95, 0.85, 0.45))
