class_name WallWorkshop
extends Control
## The climbing wall workshop: draws the templates of climbing walls (see WallMap), shows the 3D wall built
## from one (WallBuild) and lets you climb it to try it (WallStage). Open it from the testing panel (F3, tab
## "Held", button "Kletterwand") or run scenes/wall_workshop.tscn.
##
## Left: the tools (hold, arrows, gap, surface, erase), the malus of a new hold, and the surface. In the
## middle, one of three pages of one size: the template, the wall seen in 3D, and the climbing test. On the
## right: files (a list of the shipped walls in walls/ and your own in user://waende/, saving, copying the text
## and pasting a text back), the wall's settings (name, level, size, summit) and what the wall under the
## pointer and the likeliest route mean for a climber of a given skill. Changes are checked at once.
##
## A wall is saved as a text file in user://waende/ (WallPlacements.USER_DIR), the same format as walls/*.txt.
## The summit setting says where the top of the wall leads, "level file:place", for example the village square
## "11_die_freiheit.txt:square" (see WallPlacements).

signal closed

const SAVE_DIR := "user://waende/"
const SHIPPED_DIR := "res://walls/"
const LEFT_WIDTH := 262
const RIGHT_WIDTH := 330
const UNDO_STEPS := 60
const PAGES := ["Vorlage", "Wandansicht", "Kletterprobe"]
const TOOLS := [["Griff", "Malt Griffe mit dem gewählten Malus. Rechtsklick löscht."],
		["Pfeile", "Ein Klick nahe einer Kante schaltet die Richtung dieses Griffs um."],
		["Spalte", "Ziehe ein Rechteck auf: das ist eine Spalte (Riss) in der Wand. Rechtsklick entfernt sie."],
		["Belag", "Malt Eis, loses Gestein oder nasses Moos. Rechtsklick löscht."],
		["Ziel", "Setzt ein Ziel oder Ereignis auf ein Feld (Garten, Höhle, Nest, Grabkammer, toter Kletterer). Rechtsklick löscht es."],
		["Radierer", "Löscht Griff, Belag, Spalte und Ziel."]]

var map: WallMap
var canvas: WallCanvas
var stage: WallStage
var _page := 0
var _stage_stale := true
var _undo: Array[String] = []
var _redo: Array[String] = []
var _page_buttons: Array[Button] = []
var _tool_buttons: Array[Button] = []
var _malus_buttons: Array[Button] = []
var _surface_buttons: Array[Button] = []
var _page_holder: Control
var _files: OptionButton
var _file_paths: Array[String] = []
var _name_edit: LineEdit
var _level_spin: SpinBox
var _width_spin: SpinBox
var _height_spin: SpinBox
var _summit_edit: LineEdit
var _skill_spin: SpinBox
var _con_spin: SpinBox
var _attr_spins: Array[SpinBox] = []
var _link_box: CheckBox
var _info: Label
var _message: Label
var _recheck := Timer.new()
var _hover_cell := Vector2i(-1, -1)
var _loading := false
var _weather := WallWeather.CLEAR
## How much chance rules the climbing test: random weather, falling stones and lightning (0..1, see WallStage.chaos).
var _chaos := 0.5
## The share of squares the random wall fills with holds, in percent.
var _fill := 60


func _ready() -> void:
	Lang.setup()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://scripts/game.gd")._tooltip_theme()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	map = WallMap.load_file(SHIPPED_DIR + "sample_three_paths.txt")
	if map == null:
		map = WallMap.blank()
	_build()
	_recheck.one_shot = true
	_recheck.wait_time = 0.3
	_recheck.timeout.connect(_analyse)
	add_child(_recheck)
	_refresh_files()
	_after_change(false)


func _build() -> void:
	var back := ColorRect.new()
	back.color = UiKit.PANEL_BG
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	row.add_child(_left_column())
	row.add_child(_middle())
	row.add_child(_right_column())


func _label(text: String, size := 14, colour := Color(0.9, 0.85, 0.75), wrap := true) -> Label:
	var l := Label.new()
	l.text = Lang.t(text)
	l.add_theme_font_override("font", UiKit.TEXT_FONT)
	l.add_theme_font_size_override("font_size", UiKit.sized(size))
	l.add_theme_color_override("font_color", colour)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Wolfram climbs the wall by himself on the test page (his skill and attributes are the ones in the form).
func _watch_wolfram() -> void:
	_stage_stale = true
	_show_page(2)
	stage.start_auto()


func _button(text: String, action: Callable, toggle := false) -> Button:
	var b := UiKit.button(Lang.t(text), action)
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiKit.sized(14))
	b.toggle_mode = toggle
	return b


func _column(width: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 6)
	return col


func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	return g


func _left_column() -> Control:
	var col := _column(LEFT_WIDTH)
	col.add_child(_label("Kletterwand-Werkstatt", 18, UiKit.GOLD))
	col.add_child(_label("Werkzeug", 13, UiKit.BRONZE))
	var tools := _grid(2)
	var group := ButtonGroup.new()
	for i in TOOLS.size():
		var b := _button(String(TOOLS[i][0]), _pick_tool.bind(i), true)
		b.button_group = group
		b.tooltip_text = Lang.t(String(TOOLS[i][1]))
		b.button_pressed = i == 0
		tools.add_child(b)
		_tool_buttons.append(b)
	col.add_child(tools)
	col.add_child(_label("Malus des Griffs (0 leicht, 9 schwer)", 13, UiKit.BRONZE))
	var malus := _grid(5)
	var mgroup := ButtonGroup.new()
	for m in WallMap.MAX_MALUS + 1:
		var b := _button(str(m), _pick_malus.bind(m), true)
		b.button_group = mgroup
		b.button_pressed = m == 2
		malus.add_child(b)
		_malus_buttons.append(b)
	col.add_child(malus)
	_link_box = CheckBox.new()
	_link_box.text = Lang.t("Mit Nachbargriffen verbinden")
	_link_box.button_pressed = true
	_link_box.tooltip_text = Lang.t("Ein neuer Griff bekommt Pfeile zu den Griffen neben sich (und sie zu ihm). So malst du einen Weg in einem Zug.")
	_link_box.add_theme_font_size_override("font_size", UiKit.sized(13))
	_link_box.toggled.connect(func(on: bool) -> void: canvas.link = on)
	col.add_child(_link_box)
	col.add_child(_label("Belag", 13, UiKit.BRONZE))
	var surfaces := _grid(3)
	var sgroup := ButtonGroup.new()
	for kind: int in WallRules.SURFACES:
		var b := _button(String(WallRules.SURFACES[kind].name), _pick_surface.bind(kind), true)
		b.button_group = sgroup
		b.button_pressed = kind == WallMap.ICE
		b.tooltip_text = Lang.t("Bleibt immer mit mindestens %d%% Sturzrisiko, wie geschickt der Kletterer auch ist.") % int(round(WallRules.risk(kind) * 100.0))
		b.add_theme_font_size_override("font_size", UiKit.sized(11))
		surfaces.add_child(b)
		_surface_buttons.append(b)
	col.add_child(surfaces)
	col.add_child(_label("Ziel / Ereignis", 13, UiKit.BRONZE))
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", UiKit.sized(14))
	for kind: String in WallMap.MARKERS:
		picker.add_item(Lang.t(String(WallMap.MARKERS[kind].name)))
		picker.set_item_metadata(picker.item_count - 1, kind)
	picker.item_selected.connect(func(i: int) -> void:
		canvas.marker = String(picker.get_item_metadata(i)))
	col.add_child(picker)
	var undo_row := _grid(2)
	undo_row.add_child(_button("Rückgängig", _undo_step))
	undo_row.add_child(_button("Wiederholen", _redo_step))
	col.add_child(undo_row)
	col.add_child(_label("Fuß der Wand unten (gold), Gipfel oben (blau). Ein Griff in der untersten Reihe ist ein Einstieg, einer in der obersten ein Ausstieg.", 12))
	return col


func _middle() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var b := _button(String(PAGES[i]), _show_page.bind(i), true)
		b.button_group = group
		b.button_pressed = i == 0
		b.custom_minimum_size = Vector2(150, 34)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tabs.add_child(b)
		_page_buttons.append(b)
	col.add_child(tabs)
	_page_holder = Control.new()
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.clip_contents = true
	col.add_child(_page_holder)
	canvas = WallCanvas.new()
	canvas.map = map
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.stroke_started.connect(_push_undo)
	canvas.changed.connect(_on_canvas_changed)
	canvas.hovered.connect(_on_hover)
	_page_holder.add_child(canvas)
	stage = WallStage.new()
	stage.visible = false
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.changed.connect(_on_stage_changed)
	_page_holder.add_child(stage)
	return col


func _right_column() -> Control:
	var col := _column(RIGHT_WIDTH)
	col.add_child(_label("Dateien", 13, UiKit.BRONZE))
	_files = OptionButton.new()
	_files.add_theme_font_size_override("font_size", UiKit.sized(14))
	col.add_child(_files)
	var file_row := _grid(3)
	file_row.add_child(_button("Laden", _load_selected))
	file_row.add_child(_button("Speichern", _save))
	file_row.add_child(_button("Neu", _new_wall))
	file_row.add_child(_button("Text kopieren", _copy_text))
	file_row.add_child(_button("Text einfügen", _paste_text))
	file_row.add_child(_button("Zurück zum Spiel", _close))
	col.add_child(file_row)
	var random_row := HBoxContainer.new()
	random_row.add_theme_constant_override("separation", 6)
	random_row.add_child(_label("Füllung", 13, Color(0.9, 0.85, 0.75), false))
	var fill_spin := _spin(0, 100, _fill, func(v: float) -> void: _fill = int(v))
	fill_spin.suffix = " %"
	fill_spin.tooltip_text = Lang.t("Wie viele Felder der Zufallswand einen Griff bekommen: 100 % füllt jedes Feld.")
	random_row.add_child(fill_spin)
	var random_button := _button("Zufallswand", _random_wall)
	random_button.tooltip_text = Lang.t("Würfelt eine neue Wand in der gewählten Größe, mit einer Route zum Gipfel. Mit Rückgängig kommt die alte zurück.")
	random_row.add_child(random_button)
	col.add_child(random_row)
	var watch := _button("Wolfram klettert (zuschauen)", _watch_wolfram)
	watch.tooltip_text = Lang.t("Wolfram steigt die Wand allein hinauf, mit den Werten rechts: er schaut sich jede Spalte an, rastet und flucht.")
	col.add_child(watch)
	col.add_child(_label("Wand", 13, UiKit.BRONZE))
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 6)
	form.add_theme_constant_override("v_separation", 4)
	form.add_child(_label("Name", 13, Color(0.9, 0.85, 0.75), false))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String) -> void:
		if not _loading:
			map.wall_name = t)
	form.add_child(_name_edit)
	form.add_child(_label("Grundstufe", 13, Color(0.9, 0.85, 0.75), false))
	_level_spin = _spin(1, 60, 3, func(v: float) -> void:
		map.level = int(v)
		_after_change(true))
	_level_spin.tooltip_text = Lang.t("Das Klettern-Niveau, das einen Griff mit Malus 0 gerade schafft.")
	form.add_child(_level_spin)
	form.add_child(_label("Breite", 13, Color(0.9, 0.85, 0.75), false))
	_width_spin = _spin(WallMap.MIN_SIZE, WallMap.MAX_SIZE, map.width, func(v: float) -> void: _resize(int(v), map.height))
	form.add_child(_width_spin)
	form.add_child(_label("Höhe", 13, Color(0.9, 0.85, 0.75), false))
	_height_spin = _spin(WallMap.MIN_SIZE, WallMap.MAX_SIZE, map.height, func(v: float) -> void: _resize(map.width, int(v)))
	form.add_child(_height_spin)
	form.add_child(_label("Gipfelziel", 13, Color(0.9, 0.85, 0.75), false))
	_summit_edit = LineEdit.new()
	_summit_edit.placeholder_text = "11_die_freiheit.txt:square"
	_summit_edit.tooltip_text = Lang.t("Wohin der Gipfel führt: Karte und Ort, zum Beispiel 11_die_freiheit.txt:square. Leer: nirgendwohin.")
	_summit_edit.text_changed.connect(func(t: String) -> void:
		if not _loading:
			map.summit = t.strip_edges())
	form.add_child(_summit_edit)
	form.add_child(_label("Können", 13, Color(0.9, 0.85, 0.75), false))
	_skill_spin = _spin(1, 60, 6, func(_v: float) -> void: _after_change(true))
	_skill_spin.tooltip_text = Lang.t("Das Klettern-Niveau, für das die Chancen und die beste Route gerechnet werden (und der Kletterer der Probe).")
	form.add_child(_skill_spin)
	form.add_child(_label("Konstitution", 13, Color(0.9, 0.85, 0.75), false))
	_con_spin = _spin(1, 60, 10, func(_v: float) -> void: _stage_stale = true)
	_con_spin.tooltip_text = Lang.t("Die Konstitution des Kletterers der Probe: sie bestimmt, wie lange der Atem (die Rennleiste) beim Klettern reicht.")
	form.add_child(_con_spin)
	form.add_child(_label("Geschick, Intuition, Weisheit", 13, Color(0.9, 0.85, 0.75), true))
	var attrs := HBoxContainer.new()
	attrs.add_theme_constant_override("separation", 2)
	for k in 3:
		var sp := _spin(1, 30, 10, func(_v: float) -> void: _stage_stale = true)
		sp.tooltip_text = Lang.t("Geschick und Intuition verbessern Sprünge, Weisheit und Intuition das Abschätzen einer Spalte (Start 10, höchstens 30).")
		attrs.add_child(sp)
		_attr_spins.append(sp)
	form.add_child(attrs)
	form.add_child(_label("Wetter", 13, Color(0.9, 0.85, 0.75), false))
	var sky := OptionButton.new()
	sky.add_theme_font_size_override("font_size", UiKit.sized(14))
	for w: String in WallWeather.ORDER:
		sky.add_item(Lang.t(String(WallWeather.DATA[w].name)))
		sky.set_item_metadata(sky.item_count - 1, w)
	sky.tooltip_text = Lang.t("Das Wetter der Probe und der Rechnung: Regen und Sturm machen Griffe schwerer, Wind die Sprünge, Schnee legt Eis auf die Wand, Sturm lässt Steine fallen.")
	sky.item_selected.connect(func(i: int) -> void:
		_weather = String(sky.get_item_metadata(i))
		if not stage.map == null:
			stage.set_weather(_weather)
		_after_change(false))
	form.add_child(sky)
	form.add_child(_label("Zufall", 13, Color(0.9, 0.85, 0.75), false))
	var chaos_row := HBoxContainer.new()
	chaos_row.add_theme_constant_override("separation", 8)
	var chaos_slider := HSlider.new()
	chaos_slider.min_value = 0.0
	chaos_slider.max_value = 1.0
	chaos_slider.step = 0.1
	chaos_slider.value = _chaos
	chaos_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chaos_slider.custom_minimum_size = Vector2(0, 28)
	chaos_slider.tooltip_text = Lang.t("Wie sehr der Zufall die Kletterprobe regiert: wechselndes Wetter, fallende Steine und Blitze. 0 % ist ruhig, 100 % wild.")
	var chaos_value := _label("%d %%" % int(round(_chaos * 100.0)), 13, UiKit.GOLD, false)
	chaos_value.custom_minimum_size = Vector2(48, 0)
	chaos_slider.value_changed.connect(func(v: float) -> void:
		_chaos = v
		chaos_value.text = "%d %%" % int(round(v * 100.0))
		if stage.map != null:
			stage.chaos = v)
	chaos_row.add_child(chaos_slider)
	chaos_row.add_child(chaos_value)
	form.add_child(chaos_row)
	col.add_child(form)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info = _label("", 13)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_info)
	col.add_child(scroll)
	_message = _label("", 13, UiKit.GOLD)
	_message.custom_minimum_size = Vector2(0, 40)
	col.add_child(_message)
	return col


func _spin(lo: int, hi: int, value: int, on_change: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		if not _loading:
			on_change.call(v))
	return s


# --- tools and pages -------------------------------------------------------------------------------------

func _pick_tool(i: int) -> void:
	canvas.tool = i as WallCanvas.Tool


func _pick_malus(m: int) -> void:
	canvas.malus = m


func _pick_surface(kind: int) -> void:
	canvas.surface = kind


func _show_page(i: int) -> void:
	_page = i
	canvas.visible = i == 0
	stage.visible = i != 0
	if i != 0:
		if _stage_stale or stage.map == null:
			stage.setup(map, int(_skill_spin.value), i == 2, _weather, int(_con_spin.value))
			stage.chaos = _chaos
			stage.climb.dexterity = int(_attr_spins[0].value)
			stage.climb.intuition = int(_attr_spins[1].value)
			stage.climb.wisdom = int(_attr_spins[2].value)
			_stage_stale = false
		else:
			stage.interactive = i == 2
			stage.follow = i == 2
	canvas.show_climber = i == 2
	_recheck.start()
	_analyse()


func _on_canvas_changed() -> void:
	_stage_stale = true
	_recheck.start()


func _on_stage_changed() -> void:
	canvas.climber = stage.climb.cell if stage.climb != null else WallClimb.NOWHERE
	canvas.queue_redraw()


func _on_hover(cell: Vector2i) -> void:
	_hover_cell = cell
	_analyse()


# --- undo ------------------------------------------------------------------------------------------------

func _push_undo() -> void:
	_undo.append(map.to_text())
	if _undo.size() > UNDO_STEPS:
		_undo.pop_front()
	_redo.clear()


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(map.to_text())
	_set_map(WallMap.parse(_undo.pop_back()))


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(map.to_text())
	_set_map(WallMap.parse(_redo.pop_back()))


func _set_map(m: WallMap) -> void:
	map = m
	canvas.map = m
	_loading = true
	_name_edit.text = m.wall_name
	_level_spin.value = m.level
	_width_spin.value = m.width
	_height_spin.value = m.height
	_summit_edit.text = m.summit
	_loading = false
	_stage_stale = true
	if _page != 0:
		_show_page(_page)
	_after_change(false)


func _resize(w: int, h: int) -> void:
	_push_undo()
	_set_map(map.resized(w, h))


func _after_change(stale: bool) -> void:
	if stale:
		_stage_stale = true
	canvas.queue_redraw()
	_analyse()


# --- files -----------------------------------------------------------------------------------------------

func _refresh_files() -> void:
	_files.clear()
	_file_paths.clear()
	for dir in [SHIPPED_DIR, SAVE_DIR]:
		var names := DirAccess.get_files_at(dir)
		names.sort()
		for f in names:
			if f.ends_with(".txt"):
				_file_paths.append(dir + f)
				_files.add_item(("%s%s" % [f.get_basename(), Lang.t(" (Beispiel)") if dir == SHIPPED_DIR else ""]))


func _load_selected() -> void:
	var i := _files.selected
	if i < 0 or i >= _file_paths.size():
		return
	var m := WallMap.load_file(_file_paths[i])
	if m == null:
		_say("Die Datei lässt sich nicht lesen.")
		return
	_push_undo()
	_set_map(m)
	_say(Lang.t("Geladen: %s") % m.wall_name, true)
	if not m.parse_errors.is_empty():
		_say(Lang.t("Beim Lesen fiel auf: ") + Lang.t(m.parse_errors[0]), true)


## The file name for a wall: its name in lower case with only letters, digits and underscores.
static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	out = out.strip_edges()
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "wand"


func _save() -> void:
	var path := SAVE_DIR + slug(map.wall_name) + ".txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_say("Speichern ist fehlgeschlagen.")
		return
	f.store_string(map.to_text())
	f.close()
	_refresh_files()
	_files.select(_file_paths.find(path))
	_say(Lang.t("Gespeichert: %s") % ProjectSettings.globalize_path(path), true)


func _new_wall() -> void:
	_push_undo()
	_set_map(WallMap.blank())
	_say("Eine neue, leere Wand.")


func _random_wall() -> void:
	_push_undo()
	_set_map(WallGenerator.generate(map, _fill / 100.0, randi()))
	_say(Lang.t("Eine Zufallswand mit %d %% Griffen.") % _fill, true)


func _copy_text() -> void:
	DisplayServer.clipboard_set(map.to_text())
	_say("Der Text der Wand liegt in der Zwischenablage.")


func _paste_text() -> void:
	var text := DisplayServer.clipboard_get()
	if text.strip_edges() == "" or not text.contains("[holds]"):
		_say("In der Zwischenablage liegt keine Wand.")
		return
	_push_undo()
	_set_map(WallMap.parse(text))
	_say("Die Wand wurde aus der Zwischenablage gelesen.")


func _close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		closed.emit()


func _say(text: String, translated := false) -> void:
	_message.text = text if translated else Lang.t(text)


# --- what the wall means for a climber -------------------------------------------------------------------

func _analyse() -> void:
	if map == null or _info == null:
		return
	var skill := int(_skill_spin.value)
	var lines := PackedStringArray()
	lines.append(_cell_text(_hover_cell if map.inside(_hover_cell.x, _hover_cell.y) else canvas.selected, skill))
	lines.append("")
	var route := WallRoutes.easiest(map, skill, _weather)
	canvas.route = route
	if route.is_empty():
		var any := WallRoutes.easiest(map, 99)
		if any.is_empty():
			lines.append(Lang.t("Kein Weg vom Fuß zum Gipfel."))
		else:
			lines.append(Lang.t("Für Klettern %d gibt es keinen Weg: eine Spalte ist zu breit. Es geht ab Klettern %d.") % [skill, _needed_skill(any)])
	else:
		var d := WallRoutes.describe(map, route)
		lines.append(Lang.t("Beste Route für Klettern %d: %d Züge, schwerster Griff %d, %d Beläge, %d Sprünge.") % [skill, d.steps, d.hardest, d.hazards, d.jumps])
		lines.append(Lang.t("Schwächster Zug: %d%% Chance.") % int(round(WallRoutes.weakest(map, route, skill, _weather) * 100.0)))
	lines.append("")
	for issue: Dictionary in map.validate():
		var mark := "✖ " if issue.level == "error" else "• "
		var where := ""
		if issue.cell != null:
			where = " (%d, %d)" % [issue.cell.x + 1, issue.cell.y + 1]
		lines.append(mark + Lang.t(String(issue.text)) + where)
	for e in map.parse_errors:
		lines.append("• " + Lang.t(e))
	_info.text = "\n".join(lines)
	canvas.queue_redraw()


## The least Klettern level at which a route to the top exists (jumps need level).
func _needed_skill(_any: Array) -> int:
	for s in range(1, 100):
		if not WallRoutes.easiest(map, s).is_empty():
			return s
	return 99


func _cell_text(cell: Vector2i, skill: int) -> String:
	if not map.inside(cell.x, cell.y):
		return Lang.t("Fahre mit der Maus über ein Feld, um zu sehen, was es bedeutet.")
	var out := Lang.t("Feld %d, %d") % [cell.x + 1, cell.y + 1]
	var gi := map.gap_at(cell.x, cell.y)
	if gi >= 0:
		return out + ": " + Lang.t("Spalte, %d m² groß, %d m breit. Der Sprung braucht Klettern %d.") % [int(map.gap_area(gi)), int(map.gap_span(gi)), WallRules.jump_required(map, gi)]
	if not map.has_hold(cell.x, cell.y):
		out += ": " + Lang.t("glatter Fels, kein Halt.")
	else:
		var dirs := ""
		for letter: String in WallMap.DIR_LETTERS:
			if map.dirs_at(cell.x, cell.y) & int(WallMap.DIR_LETTERS[letter]) != 0:
				dirs += letter.to_upper()
		out += ": " + Lang.t("Griff, Malus %d, braucht Klettern %d. Chance für Klettern %d: %d%%. Wege hinaus: %s") % [
				map.malus_at(cell.x, cell.y), WallRules.required(map, cell.x, cell.y, _weather), skill,
				int(round(WallRules.step_chance(map, cell.x, cell.y, skill, _weather) * 100.0)), dirs if dirs != "" else "-"]
	var kind := map.hazard_at(cell.x, cell.y)
	if kind != WallMap.NONE:
		out += "\n" + Lang.t(String(WallRules.SURFACES[kind].name)) + ": " + Lang.t("mindestens %d%% Sturzrisiko, auch für Meister.") % int(round(WallRules.risk(kind) * 100.0))
	return out
