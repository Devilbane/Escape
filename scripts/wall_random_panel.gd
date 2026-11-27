class_name WallRandomPanel
extends Control
## The options of the random wall (see WallGenerator), laid over the wall workshop as a window of a fixed size:
## how hard the holds are, and for every special feature (danger zones, cracks, loot, resting places, doors,
## goals) a fixed number and a chance. The rows sit in a scroll region of a fixed height, so nothing around it
## moves. Closing keeps the values; "Würfeln" rolls the wall and closes.

signal roll
signal closed

const WINDOW_WIDTH := 620
const LIST_HEIGHT := 360
const NAME_WIDTH := 200
const SPIN_WIDTH := 92

## The options being edited (WallGenerator.default_options() layout); the workshop reads them when it rolls.
var options := WallGenerator.default_options()
var _spins := {}
var _sliders := {}
var _hardness: HSlider


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	var frame := UiKit.panel_style(UiKit.BRONZE)
	frame.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", frame)
	panel.custom_minimum_size = Vector2(WINDOW_WIDTH, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_label("Zufallswand: Optionen", 18, UiKit.GOLD))
	col.add_child(_label("Jedes Merkmal hat eine feste Anzahl und eine Chance auf mehr: die Chance wird für je 6 Reihen der Wand einmal gewürfelt.", 13, Color(0.85, 0.8, 0.7)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme = UiKit.scroll_theme()
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	list.add_child(_heading("Wand"))
	_hardness = _slider_row(list, "Schwere Griffe", float(options.hardness), "Wie schwer die Griffe im Schnitt sind: 0 % lauter leichte, 100 % viele schwere.", func(v: float) -> void:
		options.hardness = v)
	var group := ""
	for f: Dictionary in WallGenerator.FEATURES:
		if f.group != group:
			group = String(f.group)
			list.add_child(_heading(group))
		_feature_row(list, f)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_button("Zurücksetzen", reset))
	row.add_child(_button("Würfeln", func() -> void:
		visible = false
		roll.emit()))
	row.add_child(_button("Schließen", close))


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Back to no special features and the usual hardness.
func reset() -> void:
	var fresh := WallGenerator.default_options()
	options.hardness = fresh.hardness
	options.features = fresh.features
	_hardness.value = float(options.hardness)
	for key: String in _spins:
		(_spins[key] as SpinBox).value = 0
		(_sliders[key] as HSlider).value = 0.0


func _label(text: String, size := 14, colour := Color(0.9, 0.85, 0.75)) -> Label:
	var l := Label.new()
	l.text = Lang.t(text)
	l.add_theme_font_override("font", UiKit.TEXT_FONT)
	l.add_theme_font_size_override("font_size", UiKit.sized(size))
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _heading(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var l := _label(text, 14, UiKit.BRONZE)
	box.add_child(l)
	box.add_child(UiKit.rule())
	return box


func _button(text: String, action: Callable) -> Button:
	var b := UiKit.button(Lang.t(text), action)
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiKit.sized(14))
	return b


## A slider 0..100 % with its value beside it.
func _slider_row(parent: Control, name: String, value: float, tip: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := _label(name, 14, Color(0.9, 0.85, 0.75))
	l.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 32)
	slider.tooltip_text = Lang.t(tip)
	var shown := _label("%d %%" % int(round(value * 100.0)), 13, UiKit.GOLD)
	shown.custom_minimum_size = Vector2(52, 0)
	slider.value_changed.connect(func(v: float) -> void:
		shown.text = "%d %%" % int(round(v * 100.0))
		on_change.call(v))
	row.add_child(slider)
	row.add_child(shown)
	parent.add_child(row)
	return slider


## A feature: its name, a fixed number and a chance for more.
func _feature_row(parent: Control, f: Dictionary) -> void:
	var key := String(f.key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := String(f.name) if f.has("name") else String(WallMap.MARKERS[key].name)
	var l := _label(name, 14, Color(0.9, 0.85, 0.75))
	l.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = int(f.max)
	spin.custom_minimum_size = Vector2(SPIN_WIDTH, 32)
	spin.tooltip_text = Lang.t("Anzahl")
	spin.value_changed.connect(func(v: float) -> void:
		options.features[key].count = int(v))
	row.add_child(spin)
	_spins[key] = spin
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 32)
	slider.tooltip_text = Lang.t("Chance auf eines mehr, für je 6 Reihen der Wand einmal gewürfelt. 100 % gibt eines je 6 Reihen.")
	var shown := _label("0 %", 13, UiKit.GOLD)
	shown.custom_minimum_size = Vector2(52, 0)
	slider.value_changed.connect(func(v: float) -> void:
		shown.text = "%d %%" % int(round(v * 100.0))
		options.features[key].chance = v)
	row.add_child(slider)
	row.add_child(shown)
	_sliders[key] = slider
	parent.add_child(row)
