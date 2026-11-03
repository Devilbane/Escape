class_name LevelEditor
extends Control
## The map workshop: makes and changes the maps of the dungeon (the levels,
## the floors inside buildings, homes and mines) in the very format of the
## files in levels/, so a map made here plays in the game as it is.
##
## On the left the tiles, in groups; in the middle the map, painted with the
## mouse (see EditorCanvas); on the right three pages of one size: the map's
## settings, its own creations (see EditorCreations) and the checks (see
## LevelMap.validate), which run after every change. "Test" plays the map
## at once with a new hero (see Game.PLAYTEST_FLAG) and comes back here.
##
## Maps are saved in user://karten/ (Creations.USER_DIR); run from the Godot
## editor, the workshop can also save straight into levels/. On the web,
## where there is no folder to open, a map goes to and comes from the
## clipboard as text.

const MAIN_SCENE := "res://scenes/main.tscn"
## The map and its file, kept while the map is being tested.
const STATE_FLAG := &"escape_editor_state"
const TEST_FILE := Creations.USER_DIR + "_test.txt"
const GAME_DIR := "res://levels/"
const PALETTE_WIDTH := 290
const SIDE_WIDTH := 400
const UNDO_STEPS := 100
const PAGES := ["Karte", "Geschöpfe", "Prüfung"]

var map: LevelMap
var file_path := ""
var dirty := false
var issues: Array = []
var canvas: EditorCanvas
var creations_page: EditorCreations
var _undo: Array = []
var _redo: Array = []
var _page := 0
var _page_buttons: Array[Button] = []
var _page_boxes: Array[VBoxContainer] = []
var _page_scroll: ScrollContainer
var _tile_buttons := {}
var _tool_buttons: Array[Button] = []
var _tile_name: Label
var _tile_note: Label
var _file_label: Label
var _hover_label: Label
var _message: Label
var _summary: Label
var _palette_groups: VBoxContainer
## Which tiles the palette shows: 0 the dungeon's, 1 the open air's, -1 none yet.
var _palette_outdoor := -1
var _dialog: Control
var _message_time := 0.0


func _ready() -> void:
	Lang.setup()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://scripts/game.gd")._tooltip_theme()
	DirAccess.make_dir_recursive_absolute(Creations.USER_DIR)
	map = LevelMap.blank()
	if Engine.has_meta(STATE_FLAG):
		var state: Dictionary = Engine.get_meta(STATE_FLAG)
		Engine.remove_meta(STATE_FLAG)
		map = LevelMap.parse(state.text)
		file_path = state.file
		dirty = state.dirty
	_build()
	_after_load()


# --- Layout -----------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := EditorUi.vbox(10)
	margin.add_child(column)
	column.add_child(_build_top_bar())
	var main := EditorUi.hbox(12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(main)
	main.add_child(_build_palette())
	var middle := PanelContainer.new()
	var frame := Menus.panel_style(EditorUi.BORDER)
	frame.set_content_margin_all(4)
	frame.set_corner_radius_all(8)
	middle.add_theme_stylebox_override("panel", frame)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(middle)
	canvas = EditorCanvas.new()
	canvas.painted.connect(_on_painted)
	canvas.hovered.connect(_on_hovered)
	canvas.stroke_started.connect(_remember)
	middle.add_child(canvas)
	main.add_child(_build_side())
	column.add_child(_build_status_bar())


func _build_top_bar() -> Control:
	var bar := EditorUi.hbox(10)
	var title: Label = preload("res://scripts/game.gd")._make_label(EditorUi.TITLE_FONT, 28, EditorUi.GOLD)
	title.text = Lang.t("Karten-Werkstatt")
	bar.add_child(title)
	_file_label = EditorUi.label("", 16, EditorUi.DIM)
	_file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_label.clip_text = true
	_file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_file_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_file_label)
	for entry in [["Neu", _ask_new], ["Öffnen", _open_dialog], ["Speichern", _save_dialog], ["Testen", playtest], ["Hauptmenü", _ask_leave]]:
		bar.add_child(EditorUi.button(Lang.t(entry[0]), entry[1], Vector2(124, 52)))
	return bar


func _panel(width: int) -> PanelContainer:
	var p := PanelContainer.new()
	var style := Menus.panel_style(EditorUi.BORDER)
	style.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = Vector2(width, 0)
	return p


func _build_palette() -> Control:
	var panel := _panel(PALETTE_WIDTH)
	var box := EditorUi.vbox(EditorUi.ROW_GAP)
	panel.add_child(box)
	box.add_child(EditorUi.label(Lang.t("Werkzeug"), 18, EditorUi.GOLD))
	var tools := EditorUi.hbox(8)
	for entry in [["Pinsel", EditorCanvas.Tool.BRUSH], ["Fläche", EditorCanvas.Tool.RECT], ["Füllen", EditorCanvas.Tool.FILL]]:
		var b := EditorUi.toggle(Lang.t(entry[0]), set_tool.bind(entry[1]), Vector2(80, 44))
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(b)
		_tool_buttons.append(b)
	box.add_child(tools)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_palette_groups = EditorUi.vbox(EditorUi.ROW_GAP)
	_palette_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette_groups)
	# The picked tile: a box of fixed height, so a long note never moves the list.
	var details := EditorUi.vbox(4)
	details.custom_minimum_size = Vector2(0, 116)
	_tile_name = EditorUi.label("", 18, EditorUi.GOLD)
	_tile_name.clip_text = true
	_tile_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tile_note = EditorUi.label("", 16, EditorUi.DIM)
	_tile_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tile_note.custom_minimum_size = Vector2(0, 84)
	_tile_note.max_lines_visible = 4
	details.add_child(_tile_name)
	details.add_child(_tile_note)
	box.add_child(details)
	return panel


## The tiles of this kind of map: the dungeon's, or those of the open air.
func _fill_palette() -> void:
	var outdoor := map.is_outdoor()
	if _palette_outdoor == int(outdoor):
		return
	_palette_outdoor = int(outdoor)
	for child in _palette_groups.get_children():
		_palette_groups.remove_child(child)
		child.queue_free()
	_tile_buttons.clear()
	var all := EditorPalette.groups(outdoor)
	for g in all.size():
		if g > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, EditorUi.GROUP_GAP - EditorUi.ROW_GAP)
			_palette_groups.add_child(gap)
		_palette_groups.add_child(EditorUi.label(Lang.t(all[g][0]), 16, EditorUi.GOLD))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_palette_groups.add_child(grid)
		for letter in all[g][1]:
			grid.add_child(_tile_button(letter, outdoor))
	if not map.table().has(canvas.letter):
		canvas.letter = "."


func _tile_button(letter: String, outdoor := false) -> Button:
	var b := EditorUi.toggle(letter, pick_letter.bind(letter), Vector2(46, 46))
	b.add_theme_font_size_override("font_size", 18)
	var swatch := ColorRect.new()
	swatch.color = EditorPalette.color_of(letter, outdoor)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	swatch.offset_left = 8
	swatch.offset_right = -8
	swatch.offset_top = -10
	swatch.offset_bottom = -5
	b.add_child(swatch)
	_tile_buttons[letter] = b
	return b


func _build_side() -> Control:
	var panel := _panel(SIDE_WIDTH)
	var box := EditorUi.vbox(10)
	panel.add_child(box)
	var tabs := EditorUi.hbox(8)
	for i in PAGES.size():
		var b := EditorUi.toggle(Lang.t(PAGES[i]), show_page.bind(i), Vector2(0, 48))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_page_buttons.append(b)
	box.add_child(tabs)
	# One scroll region for all three pages: switching never resizes anything.
	_page_scroll = ScrollContainer.new()
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Never wider than the panel, whatever a page holds.
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(_page_scroll)
	var holder := EditorUi.vbox(0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(holder)
	for i in PAGES.size():
		var page := EditorUi.vbox(EditorUi.ROW_GAP)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(page)
		_page_boxes.append(page)
	creations_page = EditorCreations.new(self)
	return panel


func _build_status_bar() -> Control:
	var bar := EditorUi.hbox(14)
	bar.custom_minimum_size = Vector2(0, 30)
	_hover_label = EditorUi.label("", 16, EditorUi.DIM)
	_hover_label.custom_minimum_size = Vector2(380, 0)
	_hover_label.clip_text = true
	bar.add_child(_hover_label)
	_message = EditorUi.label("", 16, EditorUi.TEXT)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.clip_text = true
	bar.add_child(_message)
	_summary = EditorUi.label("", 16, EditorUi.TEXT)
	_summary.custom_minimum_size = Vector2(260, 0)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_summary)
	return bar


# --- Pages ------------------------------------------------------------------

func show_page(i: int) -> void:
	_page = i
	for k in _page_boxes.size():
		_page_boxes[k].visible = k == i
		_page_buttons[k].button_pressed = k == i
	_page_scroll.scroll_vertical = 0


func _build_map_page() -> void:
	var box := _page_boxes[0]
	for child in box.get_children():
		child.queue_free()
	box.add_child(EditorUi.row(Lang.t("Name"), EditorUi.line_edit(map.get_header("name"), func(t): _set_header("name", t.strip_edges()), 60)))
	var hint := EditorUi.line_edit(map.get_header("hint"), func(t): _set_header("hint", t.strip_edges()))
	hint.placeholder_text = Lang.t("Was der Spieler beim Betreten liest")
	box.add_child(EditorUi.row(Lang.t("Hinweis"), hint))
	var size_row := EditorUi.hbox(8)
	var w := EditorUi.spin(map.width(), 3, map.max_size().x, 1, func(v): _resize(int(v), map.height()))
	var h := EditorUi.spin(map.height(), 3, map.max_size().y, 1, func(v): _resize(map.width(), int(v)))
	w.custom_minimum_size.x = 84
	h.custom_minimum_size.x = 84
	size_row.add_child(w)
	size_row.add_child(EditorUi.label("×", 18))
	size_row.add_child(h)
	box.add_child(EditorUi.row(Lang.t("Größe"), size_row))
	if map.is_outdoor():
		box.add_child(_gap())
		var about := EditorUi.label(Lang.t("Die Karte im Freien: Dorf, Wald, Pass und Berge. Gebäude sind Rechtecke aus einem Zeichen; Fallen, Geheimräume und eigene Geschöpfe gibt es hier nicht."), 16, EditorUi.DIM)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(about)
		_add_other_headers(box, ["name", "hint", "outdoor"])
		return
	var tiers := Level.TIERS.keys().map(func(k): return [k, Lang.t(Level.TIERS[k].name)])
	box.add_child(EditorUi.row(Lang.t("Geheimraum"), EditorUi.choice(tiers, Level.TIER_ALIASES.get(map.get_header("secret", "normal"), map.get_header("secret", "normal")), func(k): _set_header("secret", k))))
	box.add_child(_gap())
	box.add_child(EditorUi.label(Lang.t("Art der Karte"), 16, EditorUi.GOLD))
	for entry in [["elite", "Starke Skelette (Elite)"], ["dark", "Stockdunkel"], ["safe", "Sicherer Raum, ohne Monster"]]:
		var key: String = entry[0]
		box.add_child(EditorUi.check(Lang.t(entry[1]), map.has_header(key), func(on):
			map.set_flag(key, on)
			_changed()))
	box.add_child(_gap())
	box.add_child(EditorUi.label(Lang.t("Verborgene Fallen"), 16, EditorUi.GOLD))
	var trap := Traps.parse_header(map.get_header("traps"))
	var kinds: Array = trap.get("kinds", [])
	var count := EditorUi.spin(trap.get("count", 0), 0, Traps.MAX_HEADER_TRAPS, 1, func(_v): _store_traps())
	count.set_meta("traps", "count")
	box.add_child(EditorUi.row(Lang.t("Anzahl"), count))
	for kind in Traps.ALL_KINDS:
		var c := EditorUi.check(Lang.t(Traps.KINDS[kind].name), kind in kinds, func(_on): _store_traps())
		c.set_meta("traps", kind)
		box.add_child(c)
	box.add_child(_gap())
	box.add_child(EditorUi.label(Lang.t("Wandinschrift"), 16, EditorUi.GOLD))
	var writing := map.get_header("writing").split("|", true, 1)
	var word := EditorUi.line_edit(writing[0].strip_edges(), func(_t): _store_writing(), 20)
	word.placeholder_text = Lang.t("HOFFNUNG")
	word.set_meta("writing", "word")
	box.add_child(EditorUi.row(Lang.t("Wort"), word))
	var text := EditorUi.line_edit(writing[1].strip_edges() if writing.size() > 1 else "", func(_t): _store_writing(), 200)
	text.placeholder_text = Lang.t("Was der Held liest")
	text.set_meta("writing", "text")
	box.add_child(EditorUi.row(Lang.t("Text"), text))
	var note := EditorUi.label(Lang.t("Ohne eigene Inschrift wählt das Spiel eine nach der Tiefe."), 16, EditorUi.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_add_other_headers(box, ["name", "hint", "secret", "elite", "dark", "safe", "traps", "writing", "custom"])


## The header lines this page does not edit, shown so nobody wonders where
## they went: they are kept as they are.
func _add_other_headers(box: VBoxContainer, shown: Array) -> void:
	var others: Array = map.headers.filter(func(hd): return not hd[0] in shown)
	if not others.is_empty():
		box.add_child(_gap())
		box.add_child(EditorUi.label(Lang.t("Weitere Angaben (bleiben erhalten)"), 16, EditorUi.GOLD))
		for hd in others:
			var l := EditorUi.label("%s: %s" % hd, 16, EditorUi.DIM)
			l.clip_text = true
			box.add_child(l)


func _gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, EditorUi.GROUP_GAP - EditorUi.ROW_GAP)
	return gap


func _set_header(key: String, value: String) -> void:
	map.set_header(key, value)
	_changed()


func _store_traps() -> void:
	var count := 0
	var kinds: Array = []
	for child in _page_boxes[0].find_children("*", "", true, false):
		if not child.has_meta("traps"):
			continue
		if child is SpinBox:
			count = int(child.value)
		elif child is CheckBox and child.button_pressed:
			kinds.append(child.get_meta("traps"))
	map.set_header("traps", "%d %s" % [count, ", ".join(kinds)] if count > 0 else "")
	_changed()


func _store_writing() -> void:
	var parts := {}
	for child in _page_boxes[0].find_children("*", "LineEdit", true, false):
		if child.has_meta("writing"):
			parts[child.get_meta("writing")] = child.text.strip_edges().replace("|", "/")
	var word: String = parts.get("word", "")
	var text: String = parts.get("text", "")
	map.set_header("writing", "%s | %s" % [word, text] if word != "" and text != "" else "")
	_changed()


func _build_checks_page() -> void:
	var box := _page_boxes[2]
	for child in box.get_children():
		child.queue_free()
	if issues.is_empty():
		var ok := EditorUi.label(Lang.t("Alles in Ordnung: die Karte ist spielbar."), 16)
		ok.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(ok)
		return
	for issue in issues:
		var sign := Lang.t("Fehler") if issue.error else Lang.t("Hinweis")
		var b := EditorUi.button("%s: %s" % [sign, LevelMap.describe(issue)], mark_issue.bind(issue), Vector2(0, 0))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if issue.error else EditorUi.GOLD)
		EditorUi.pad(b)
		box.add_child(b)


func mark_issue(issue: Dictionary) -> void:
	canvas.marked = issue.cell
	canvas.queue_redraw()


# --- Editing ----------------------------------------------------------------

func pick_letter(letter: String) -> void:
	canvas.letter = letter
	for l in _tile_buttons:
		_tile_buttons[l].button_pressed = l == letter
	_update_tile_info()


func set_tool(tool: EditorCanvas.Tool) -> void:
	canvas.tool = tool
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = i == int(tool)


func set_creation(letter: String, spec: Dictionary) -> void:
	map.set_creation(letter, spec)
	_update_custom_tiles()
	_update_tile_info()
	_changed()


func _update_tile_info() -> void:
	var made := map.creations()
	var letter := canvas.letter
	var outdoor := map.is_outdoor()
	_tile_name.text = "%s  %s" % [letter, EditorPalette.name_of(letter, made, outdoor)]
	_tile_note.text = EditorPalette.note_of(letter, outdoor)
	if not outdoor and Creations.LETTERS.contains(letter) and not made.has(letter):
		_tile_note.text = Lang.t("Lege das Geschöpf auf der Seite „Geschöpfe“ an.")


func _update_custom_tiles() -> void:
	var outdoor := map.is_outdoor()
	var made := map.creations() if not outdoor else {}
	for letter in _tile_buttons:
		var b: Button = _tile_buttons[letter]
		b.tooltip_text = EditorPalette.name_of(letter, made, outdoor)
		if not outdoor and Creations.LETTERS.contains(letter):
			b.modulate = Color.WHITE if made.has(letter) else Color(1, 1, 1, 0.55)


## Keeps the grid as it was before a stroke, for undo.
func _remember() -> void:
	_undo.append(map.grid.duplicate())
	if _undo.size() > UNDO_STEPS:
		_undo.pop_front()
	_redo.clear()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(map.grid.duplicate())
	map.grid = _undo.pop_back()
	_grid_replaced()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(map.grid.duplicate())
	map.grid = _redo.pop_back()
	_grid_replaced()


func _grid_replaced() -> void:
	canvas.queue_redraw()
	_build_map_page()
	_changed()


func _resize(w: int, h: int) -> void:
	if w == map.width() and h == map.height():
		return
	_remember()
	map.resize(w, h)
	canvas.queue_redraw()
	_changed()


func _on_painted() -> void:
	_changed()


func _changed() -> void:
	dirty = true
	_validate()
	_update_file_label()


func _validate() -> void:
	issues = map.validate()
	var errors := issues.filter(func(i): return i.error).size()
	var hints := issues.size() - errors
	if issues.is_empty():
		_summary.text = Lang.t("Spielbar")
	elif errors == 0:
		_summary.text = Lang.t("Spielbar, %d Hinweise") % hints
	else:
		_summary.text = Lang.t("%d Fehler, %d Hinweise") % [errors, hints]
	_summary.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if errors > 0 else EditorUi.TEXT)
	if canvas.marked.x >= 0 and not issues.any(func(i): return i.cell == canvas.marked):
		canvas.marked = Vector2i(-1, -1)
		canvas.queue_redraw()
	_build_checks_page()


func _on_hovered(c: Vector2i) -> void:
	if not map.in_bounds(c):
		_hover_label.text = ""
		return
	var ch := map.cell(c)
	var outdoor := map.is_outdoor()
	_hover_label.text = "%d, %d   %s  %s" % [c.x, c.y, ch, EditorPalette.name_of(ch, {} if outdoor else map.creations(), outdoor)]


func _update_file_label() -> void:
	var where := file_path.get_file() if file_path != "" else Lang.t("noch nicht gespeichert")
	_file_label.text = "%s  ·  %s%s" % [map.get_header("name", Lang.t("Ohne Namen")), where, "  ·  " + Lang.t("geändert") if dirty else ""]


func say(text: String) -> void:
	_message.text = text
	_message_time = 5.0


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


## Shows a freshly opened (or new) map.
func _after_load() -> void:
	_undo.clear()
	_redo.clear()
	canvas.map = map
	canvas.marked = Vector2i(-1, -1)
	_fill_palette()
	_build_map_page()
	creations_page.build(_page_boxes[1])
	show_page(_page)
	pick_letter(canvas.letter)
	set_tool(canvas.tool)
	_update_custom_tiles()
	_validate()
	_update_file_label()
	# The canvas has its size only after the first layout.
	canvas.fit.call_deferred()


# --- Keys -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _dialog != null:
		if event.physical_keycode == KEY_ESCAPE:
			close_dialog()
			get_viewport().set_input_as_handled()
		return
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed
	match event.physical_keycode:
		KEY_Z when ctrl and event.shift_pressed:
			redo()
		KEY_Z when ctrl:
			undo()
		KEY_Y when ctrl:
			redo()
		KEY_S when ctrl:
			_save_dialog()
		KEY_O when ctrl:
			_open_dialog()
		KEY_F5:
			playtest()
		KEY_ESCAPE:
			_ask_leave()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Dialogs ----------------------------------------------------------------

## A window over the workshop: the rest stays dimmed and cannot be clicked
## until it closes (with its buttons or Esc).
func _open_window(title: String) -> VBoxContainer:
	close_dialog()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_dialog = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Menus.panel_style(EditorUi.GOLD))
	center.add_child(panel)
	var box := EditorUi.vbox(10)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	var head: Label = preload("res://scripts/game.gd")._make_label(EditorUi.TITLE_FONT, 26, EditorUi.GOLD)
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	return box


func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _confirm(text: String, yes: String, action: Callable) -> void:
	var box := _open_window(Lang.t("Bist du sicher?"))
	var l := EditorUi.label(text, 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row := EditorUi.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(EditorUi.button(yes, func():
		close_dialog()
		action.call(), Vector2(220, 60)))
	row.add_child(EditorUi.button(Lang.t("Abbrechen"), close_dialog, Vector2(220, 60)))
	box.add_child(row)


## Asks first when there are changes that would be lost.
func _unless_lost(action: Callable) -> void:
	if dirty:
		_confirm(Lang.t("Die Änderungen an dieser Karte sind nicht gespeichert und gehen verloren."), Lang.t("Verwerfen"), action)
	else:
		action.call()


func _ask_new() -> void:
	_unless_lost(new_map)


func new_map() -> void:
	map = LevelMap.blank()
	file_path = ""
	dirty = false
	_after_load()
	say(Lang.t("Eine neue Karte."))


func _ask_leave() -> void:
	_unless_lost(func(): get_tree().change_scene_to_file(MAIN_SCENE))


## The maps there are to open: [path, name], the game's own first.
static func map_files() -> Array:
	var out: Array = []
	for dir in [GAME_DIR, Creations.USER_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for f in files:
			if not f.ends_with(".txt") or dir + f == TEST_FILE:
				continue
			out.append([dir + f, LevelMap.load_file(dir + f).get_header("name", f)])
	return out


func _open_dialog() -> void:
	var box := _open_window(Lang.t("Karte öffnen"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := EditorUi.vbox(EditorUi.ROW_GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var section := ""
	for entry in map_files():
		var here: String = Lang.t("Karten des Spiels") if entry[0].begins_with(GAME_DIR) else Lang.t("Meine Karten")
		if here != section:
			section = here
			list.add_child(EditorUi.label(here, 16, EditorUi.GOLD))
		var b := EditorUi.button("%s   (%s)" % [Lang.t(entry[1]), entry[0].get_file()], func(): _unless_lost(open_file.bind(entry[0])), Vector2(0, 48))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		list.add_child(b)
	var row := EditorUi.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(EditorUi.button(Lang.t("Aus der Zwischenablage"), func(): _unless_lost(paste_map), Vector2(260, 60)))
	row.add_child(EditorUi.button(Lang.t("Abbrechen"), close_dialog, Vector2(220, 60)))
	box.add_child(row)


func open_file(path: String) -> void:
	close_dialog()
	map = LevelMap.load_file(path)
	file_path = path
	dirty = false
	_after_load()
	say(Lang.t("Geöffnet: %s") % path.get_file())


func paste_map() -> void:
	close_dialog()
	var text := DisplayServer.clipboard_get()
	var pasted := LevelMap.parse(text)
	if pasted.grid.is_empty():
		say(Lang.t("In der Zwischenablage ist keine Karte."))
		return
	map = pasted
	file_path = ""
	dirty = true
	_after_load()
	say(Lang.t("Karte aus der Zwischenablage eingefügt."))


## A file name from the map's name: plain lower-case letters.
static func file_name_for(map_name: String) -> String:
	var id := Creations.item_id(map_name).trim_prefix("eigen_")
	return id if id != "" else "karte"


func _save_dialog() -> void:
	var box := _open_window(Lang.t("Karte speichern"))
	var start := file_path.get_file().get_basename() if file_path != "" else file_name_for(map.get_header("name"))
	var name_edit := EditorUi.line_edit(start, func(_t): pass, 60)
	box.add_child(EditorUi.row(Lang.t("Dateiname"), name_edit))
	# A line kept free for what is in the way, so the buttons never move.
	var note := EditorUi.label("", 16, EditorUi.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(0, 48)
	if LevelMap.has_errors(issues):
		note.text = Lang.t("Die Karte hat noch Fehler (siehe Prüfung). Speichern geht trotzdem.")
	box.add_child(note)
	var targets := [[Creations.USER_DIR, Lang.t("In meinen Karten speichern")]]
	if OS.has_feature("editor"):
		targets.append([GAME_DIR, Lang.t("Ins Spiel speichern (levels/)")])
	for t in targets:
		box.add_child(EditorUi.button(t[1], func(): _save_to(t[0], name_edit.text), Vector2(0, 56)))
	var row := EditorUi.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(EditorUi.button(Lang.t("In die Zwischenablage"), copy_map, Vector2(260, 60)))
	row.add_child(EditorUi.button(Lang.t("Abbrechen"), close_dialog, Vector2(220, 60)))
	box.add_child(row)


func _save_to(dir: String, file_name: String) -> void:
	var base := file_name.strip_edges().trim_suffix(".txt")
	if base == "" or not base.is_valid_filename():
		base = file_name_for(map.get_header("name"))
	var path := dir + base + ".txt"
	if FileAccess.file_exists(path) and path != file_path:
		_confirm(Lang.t("Es gibt schon eine Karte %s. Soll sie ersetzt werden?") % path.get_file(), Lang.t("Ersetzen"), save_as.bind(path))
		return
	save_as(path)


func save_as(path: String) -> bool:
	close_dialog()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		say(Lang.t("Speichern fehlgeschlagen!"))
		return false
	f.store_string(map.to_text())
	f.close()
	file_path = path
	dirty = false
	for spec in map.creations().values():
		Creations.register(spec)
	_update_file_label()
	say(Lang.t("Gespeichert: %s") % path.get_file())
	return true


func copy_map() -> void:
	close_dialog()
	DisplayServer.clipboard_set(map.to_text())
	say(Lang.t("Die Karte ist als Text in der Zwischenablage."))


# --- Testing ----------------------------------------------------------------

## Plays the map at once (see Game.PLAYTEST_FLAG). A map with errors is not
## played: the checks say what to fix first.
func playtest() -> void:
	if LevelMap.has_errors(issues):
		show_page(2)
		say(Lang.t("Behebe erst die Fehler, dann geht es los."))
		return
	DirAccess.make_dir_recursive_absolute(Creations.USER_DIR)
	var f := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	if f == null:
		say(Lang.t("Speichern fehlgeschlagen!"))
		return
	f.store_string(map.to_text())
	f.close()
	Engine.set_meta(STATE_FLAG, {"text": map.to_text(), "file": file_path, "dirty": dirty})
	Engine.set_meta(preload("res://scripts/game.gd").PLAYTEST_FLAG, TEST_FILE)
	get_tree().change_scene_to_file(MAIN_SCENE)
