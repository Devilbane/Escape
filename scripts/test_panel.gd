class_name TestPanel
extends Control
## The testing panel in the bottom left corner (for testing, like the chat commands it reuses):
## buttons that change the time of day and the season, travel to the main areas, and switch
## godmode (see Godmode). It is closed by default so normal play stays clear: a small "Test" tab
## (or F3) opens it, and the tab stays put.
##
## The box has FOUR groups, one tab each (time, season, travel, hero). Only one group shows at
## a time inside a fixed-size area, so switching groups never reshapes the box or anything
## around it. The panel only reports what was pressed (`picked`); Game does the work with the
## same code the chat commands use (SkyCommand, Teleport.teleport_to, Godmode).
##
## ENABLED is the one switch to gate it, like Godmode.ENABLED.
##
## Every text is German and has an English entry in scripts/lang/test_panel.gd.

const ENABLED := true
signal picked(kind: String, arg: Variant)

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## Distance from the screen's left edge and bottom (above the keys' help text at the very bottom).
const LEFT := 16.0
const BOTTOM := 96.0
const BUTTON := Vector2(116, 34)
const GAP := 6
const FONT_SIZE := 14
## The fixed area under the group tabs: two columns, three rows (the biggest group, travel).
const AREA := Vector2(BUTTON.x * 2 + GAP, BUTTON.y * 3 + GAP * 2)
const OPEN_KEY := KEY_F3

## Time of day: label, hour (see SkyCommand.TIMES).
const TIMES := [["Morgen", 6.0], ["Mittag", 12.0], ["Abend", 19.5], ["Nacht", 23.0]]
## The seasons: label, season (see Weather).
const SEASONS := [["Frühling", Weather.SPRING], ["Sommer", Weather.SUMMER], ["Herbst", Weather.AUTUMN], ["Winter", Weather.WINTER]]
## Places: label, level file, where on the open-air map ("" the level's entrance, "square", "farm", "silver").
const PLACES := [
	["Dorf", "11_die_freiheit.txt", "square"],
	["Felder", "11_die_freiheit.txt", "farm"],
	["Startverlies", "01_die_zelle.txt", ""],
	["Lager des Alten", "26_das_lager_des_grossen_alten.txt", ""],
	["Minen", "18_die_bergschenke.txt", ""],
	["Silbergrube", "11_die_freiheit.txt", "silver"],
]
## Group tab names (the hero tab reuses the title screen's "Held").
const GROUPS := ["Zeit", "Jahreszeit", "Reisen", "Held"]

var open := false
var god_button: Button
var _box: PanelContainer
var _pages: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = LEFT
	offset_bottom = -BOTTOM
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", GAP)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(column)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", _frame())
	_box.visible = false
	column.add_child(_box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", GAP)
	_box.add_child(inner)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP)
	inner.add_child(tabs)
	var holder := Control.new()
	holder.custom_minimum_size = AREA
	inner.add_child(holder)
	var group := ButtonGroup.new()
	for i in GROUPS.size():
		var tab := _button(Lang.t(String(GROUPS[i])), _show_page.bind(i))
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2((AREA.x - GAP * 3) / 4.0, 28)
		tab.button_pressed = i == 0
		tabs.add_child(tab)
		var page := GridContainer.new()
		page.columns = 2
		page.add_theme_constant_override("h_separation", GAP)
		page.add_theme_constant_override("v_separation", GAP)
		page.visible = i == 0
		holder.add_child(page)
		_pages.append(page)

	for t in TIMES:
		_add(0, Lang.t(String(t[0])).capitalize(), "time", t[1])
	for s in SEASONS:
		_add(1, Lang.t(String(s[0])).capitalize(), "season", s[1])
	for i in PLACES.size():
		_add(2, Lang.t(String(PLACES[i][0])), "travel", i)
	god_button = _button(Lang.t("Gottmodus"), func() -> void: picked.emit("god", null))
	god_button.toggle_mode = true
	god_button.tooltip_text = Lang.t("Unverwundbar und fünffaches Tempo.")
	_pages[3].add_child(god_button)
	_pages[3].add_child(_button(Lang.t("Kletterwand"), func() -> void: picked.emit("wall", null)))

	var tab_button := _button(Lang.t("Test"), toggle)
	tab_button.custom_minimum_size = Vector2(66, 28)
	tab_button.tooltip_text = Lang.t("Testfeld ein- und ausblenden (F3)")
	column.add_child(tab_button)


func toggle() -> void:
	open = not open
	_box.visible = open


## Shows whether godmode is on (the button looks pressed).
func set_god(on: bool) -> void:
	god_button.set_pressed_no_signal(on)


func _input(event: InputEvent) -> void:
	if ENABLED and visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == OPEN_KEY:
		toggle()
		get_viewport().set_input_as_handled()


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _add(page: int, text: String, kind: String, arg: Variant) -> void:
	_pages[page].add_child(_button(text, func() -> void: picked.emit(kind, arg)))


func _button(text: String, action: Callable) -> Button:
	var b := UiKit.button(text, action)
	b.custom_minimum_size = BUTTON
	b.add_theme_font_size_override("font_size", UiKit.sized(FONT_SIZE))
	return b


func _frame() -> StyleBox:
	var box := UiKit.frame_style(Color(0.085, 0.062, 0.045, 0.92), UiKit.BRONZE, 3, 6)
	box.set_content_margin_all(10)
	return box
