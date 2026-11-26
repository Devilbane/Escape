class_name SettingsWindow
extends RefCounted
## The settings window (Menus kind "einstellungen"): the screen, the picture and the sound in one place,
## in four tabs.
##
## - Display: the window mode and monitor (see Monitor), vertical sync, the frame rate cap and the width of
##   the event log.
## - Graphics: a preset (see Graphics) and, on top of it, edge smoothing, render scale, texture sharpness,
##   shadow quality, how many lamps cast shadows, how strong the surfaces' relief is, and bloom.
## - Colour: brightness, contrast and saturation of the whole picture (the same on every preset).
## - Sound: the volume of the effects and of the music, and whether each is on.
##
## The window never changes its size: it has one fixed size (Menus.WINDOW_SIZES) and every tab fills the same
## body area, which scrolls when a tab holds more. A choice changes the game at once and is remembered in
## the settings file; the rows update in place, so nothing moves under the pointer and a slider is never
## rebuilt while it is dragged.

const KIND := "einstellungen"
## The window's fixed content size, and the body that every tab fills.
const SIZE := Vector2(900, 690)
const BODY := Vector2(852, 450)
const LABEL_WIDTH := 220.0
const VALUE_WIDTH := 76.0
const TABS := [["anzeige", "Anzeige"], ["grafik", "Grafik"], ["farbe", "Farbe"], ["ton", "Ton"], ["profile", "Profile"]]
## The tab that was open last (kept while the game runs).
static var tab := "anzeige"

var _menus: Menus
var _game: Node
var _body: VBoxContainer
## Callables that bring every row up to date with the settings (see _refresh).
var _refreshers: Array[Callable] = []
## The line under the body, and the place whose Save or Delete button waits for a second click ("save3", "delete3").
var _status: Label
var _asked := ""


static func build(menus: Menus) -> void:
	SettingsWindow.new().show(menus)


func show(menus: Menus) -> void:
	_menus = menus
	_game = menus.game
	menus._add_label(Lang.t("Einstellungen"), 38, _game.GOLD, _game.TITLE_FONT)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	menus._box.add_child(tabs)
	for t in TABS:
		var b: Button = _game._make_button(Lang.t(t[1]), _switch.bind(t[0]))
		b.custom_minimum_size = Vector2(130, 44)
		b.add_theme_font_size_override("font_size", UiKit.sized(18))
		_set_picked(b, t[0] == tab)
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = BODY
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menus._box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	match tab:
		"grafik":
			_build_graphics()
		"farbe":
			_build_colour()
		"ton":
			_build_sound()
		"profile":
			_build_profiles()
		_:
			_build_display()
	# A hint line that is always there, so the window does not grow when a tooltip-sized note shows.
	var note := menus._add_label(Lang.t("Änderungen gelten sofort und bleiben gespeichert."), 16, Menus.ABOUT_COLOR)
	note.custom_minimum_size = Vector2(0, 26)
	_status = note
	_refresh()


func _switch(which: String) -> void:
	tab = which
	_menus._rebuild()


func _refresh() -> void:
	for r in _refreshers:
		r.call()


# --- Tabs ---------------------------------------------------------------------

func _build_display() -> void:
	var window := _game.get_window()
	var modes: Array = []
	for m: String in Monitor.MODES:
		modes.append([m, Lang.t(Monitor.NAMES[m]), Lang.t(Monitor.HINTS[m])])
	_choice("Fenstermodus", "Wie das Spiel auf dem Bildschirm gezeigt wird.", modes, 3,
		func(): return Monitor.mode, func(v): Monitor.choose_mode(v, window))
	var screens := DisplayServer.get_screen_count()
	var monitors: Array = []
	for i in screens:
		monitors.append([i + 1, str(i + 1), ""])
	_choice("Monitor", "Auf welchem Bildschirm das Spiel läuft.", monitors, maxi(screens, 1),
		func(): return Monitor.pick(Monitor.monitor, screens) + 1, func(v): Monitor.choose_monitor(v, window), screens > 1)
	_choice("V-Sync", "Hält das Bild im Takt des Bildschirms. Aus ist schneller, kann aber reißen.", [
		["off", Lang.t("Aus"), ""], ["on", Lang.t("An"), ""], ["adaptive", Lang.t("Adaptiv"), Lang.t("Adaptiv: V-Sync nur, solange das Spiel schnell genug ist.")]], 3,
		func(): return Graphics.vsync, func(v): Graphics.choose_vsync(v))
	var caps: Array = []
	for c: int in Graphics.FPS_CAPS:
		caps.append([c, str(c) if c > 0 else Lang.t("Unbegrenzt"), ""])
	_choice("Bildrate", "Wie viele Bilder pro Sekunde das Spiel höchstens zeichnet. Weniger schont die Grafikkarte.", caps, 4,
		func(): return Graphics.fps_cap, func(v): Graphics.choose_fps(v))
	_slider("Protokoll", "Breite des Ereignisprotokolls links.", EventLog.MIN_WIDTH, EventLog.MAX_WIDTH, EventLog.WIDTH_STEP,
		func(): return EventLog.width, func(v): _game.event_log.set_width(v), func(v): return "%d" % v)


func _build_graphics() -> void:
	var view := _game.get_viewport()
	var presets: Array = []
	for p: String in Graphics.PRESETS:
		presets.append([p, Lang.t(Graphics.NAMES[p]), Lang.t(Graphics.HINTS[p])])
	_choice("Voreinstellung", "Stellt alles unten auf einmal ein. Danach kannst du einzelnes ändern.", presets, 3,
		func(): return "" if Graphics.is_custom() else Graphics.preset, func(v): Graphics.choose(v, view))
	var based := _note()
	_refreshers.append(func():
		based.text = Lang.t("Eigene Einstellungen, ausgehend von: %s") % Lang.t(Graphics.NAMES[Graphics.preset]) if Graphics.is_custom() else "")
	var edges: Array = []
	for m: String in Graphics.aa_modes():
		edges.append([m, Lang.t(AA_NAMES[m]), Lang.t(AA_HINTS[m])])
	_choice("Kantenglättung", "Glättet gezackte Kanten und beruhigt flimmernde Flächen. TAA ist am ruhigsten, kann aber leicht verwischen.", edges, 5,
		func(): return Graphics.value("aa"), func(v): Graphics.choose_option("aa", v, view))
	_slider("Auflösung", "Wie groß die Welt gezeichnet wird, im Verhältnis zum Fenster. Mehr glättet alles, weniger schont die Grafikkarte.",
		Graphics.SCALE_RANGE.x, Graphics.SCALE_RANGE.y, 0.05,
		func(): return Graphics.value("scale"), func(v): Graphics.choose_option("scale", snappedf(v, 0.05), view), func(v): return "%d %%" % roundi(v * 100.0), Graphics.modern())
	var sharp: Array = []
	for i in Graphics.SHARP_LEVELS.size():
		sharp.append([Graphics.SHARP_LEVELS[i], Lang.t("Aus") if i == 0 else "%d×" % (1 << i), ""])
	_choice("Texturschärfe", "Wie scharf Böden und Wände in der Ferne bleiben. Höher kostet kaum etwas.", sharp, 5,
		func(): return Graphics.value("sharp"), func(v): Graphics.choose_option("sharp", v, view))
	var shadows: Array = []
	for s: String in Graphics.SHADOW_LEVELS:
		shadows.append([s, Lang.t(SHADOW_NAMES[s]), ""])
	_choice("Schatten", "Wie fein und weich die Schatten der Sonne und der Lampen sind.", shadows, 4,
		func(): return Graphics.value("shadows"), func(v): Graphics.choose_option("shadows", v, view))
	_slider("Lampenschatten", "Wie viele Lampen gleichzeitig Schatten an die Wände werfen. Weniger entlastet den Prozessor.", 0.0, float(Graphics.MAX_LAMPS), 1.0,
		func(): return Graphics.value("lamps"), func(v): Graphics.choose_option("lamps", int(v), view), func(v): return "%d" % v)
	_slider("Relief", "Wie stark Stein, Holz und Erde ihre Oberfläche zeigen. Weniger beruhigt Glitzern und Flimmern im Sonnenlicht.",
		Graphics.BUMP_RANGE.x, Graphics.BUMP_RANGE.y, 0.05,
		func(): return Graphics.value("bump"), func(v): Graphics.choose_option("bump", snappedf(v, 0.05), view), func(v): return "%d %%" % roundi(v * 100.0))
	_choice("Bloom", "Der Schein um helle Lichter, Feuer und Fenster.", [[true, Lang.t("An"), ""], [false, Lang.t("Aus"), ""]], 2,
		func(): return Graphics.value("glow"), func(v): Graphics.choose_option("glow", v, view))


func _build_colour() -> void:
	_slider("Helligkeit", "Hellt das ganze Bild auf oder dunkelt es ab.", Graphics.TONES.brightness.x, Graphics.TONES.brightness.z, 0.05,
		func(): return Graphics.tone.brightness, func(v): Graphics.choose_tone("brightness", snappedf(v, 0.05)), func(v): return "%d %%" % roundi(v * 100.0))
	_slider("Kontrast", "Wie stark sich Hell und Dunkel voneinander abheben.", Graphics.TONES.contrast.x, Graphics.TONES.contrast.z, 0.02,
		func(): return Graphics.tone.contrast, func(v): Graphics.choose_tone("contrast", snappedf(v, 0.02)), func(v): return "%d %%" % roundi(v * 100.0))
	_slider("Sättigung", "Wie kräftig die Farben sind. Ganz links ist das Bild schwarzweiß.", Graphics.TONES.saturation.x, Graphics.TONES.saturation.z, 0.05,
		func(): return Graphics.tone.saturation, func(v): Graphics.choose_tone("saturation", snappedf(v, 0.05)), func(v): return "%d %%" % roundi(v * 100.0))
	var reset: Button = _game._make_button(Lang.t("Farben zurücksetzen"), func():
		for key: String in Graphics.TONES:
			Graphics.choose_tone(key, Graphics.TONES[key].y)
		_refresh())
	reset.custom_minimum_size = Vector2(260, 44)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.add_theme_font_size_override("font_size", UiKit.sized(16))
	_body.add_child(reset)


func _build_sound() -> void:
	_slider("Effekte", "Lautstärke der Geräusche", 0.0, 1.0, 0.05,
		func(): return Sfx.volume, func(v): _game._on_effects_volume_changed(v), func(v): return "%d %%" % roundi(v * 100.0))
	_slider("Musik", "Lautstärke der Musik", 0.0, 1.0, 0.05,
		func(): return Music.volume, func(v): _game._on_music_volume_changed(v), func(v): return "%d %%" % roundi(v * 100.0))
	_choice("Ton", "Schaltet alle Geräusche ein oder aus (Taste M).", [[true, Lang.t("An"), ""], [false, Lang.t("Aus"), ""]], 2,
		func(): return not Sfx.muted, func(v): if v == Sfx.muted: _game._toggle_sound())
	_choice("Musik", "Schaltet die Musik ein oder aus.", [[true, Lang.t("An"), ""], [false, Lang.t("Aus"), ""]], 2,
		func(): return not Music.muted, func(v): if v == Music.muted: _game._toggle_music())


## Eight places for named sets of picture settings (see SettingsProfiles). Each row has its name, which can be
## typed, and Save, Load and Delete. Overwriting and deleting ask for a second click on the same button.
func _build_profiles() -> void:
	var view := _game.get_viewport()
	var hint := _note()
	hint.text = Lang.t("Ein Profil merkt sich Grafik, Farbe, V-Sync und Bildrate. Fenstermodus, Monitor und Ton bleiben.")
	for slot in range(1, SettingsProfiles.SLOTS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_edit := LineEdit.new()
		name_edit.max_length = SettingsProfiles.NAME_LENGTH
		name_edit.custom_minimum_size = Vector2(280, 40)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.add_theme_font_override("font", _game.TEXT_FONT)
		name_edit.add_theme_font_size_override("font_size", UiKit.sized(18))
		name_edit.tooltip_text = Lang.t("Der Name des Profils. Zum Ändern anklicken und tippen.")
		name_edit.add_theme_stylebox_override("normal", _menus.panel_style(Color(0.85, 0.66, 0.32, 0.8)))
		name_edit.add_theme_stylebox_override("focus", _menus.panel_style(_game.GOLD))
		for style in ["normal", "focus"]:
			name_edit.get_theme_stylebox(style).set_content_margin_all(6)
		row.add_child(name_edit)
		var save: Button = _small_button("Speichern", 130)
		var load_button: Button = _small_button("Laden", 110)
		var delete: Button = _small_button("Löschen", 120)
		row.add_child(save)
		row.add_child(load_button)
		row.add_child(delete)
		_body.add_child(row)
		save.pressed.connect(func():
			if not SettingsProfiles.get_slot(slot).is_empty() and _asked != "save%d" % slot:
				_asked = "save%d" % slot
			else:
				SettingsProfiles.save_slot(slot, name_edit.text)
				_asked = ""
				_status.text = Lang.t("Gespeichert: %s") % SettingsProfiles.get_slot(slot).name
			_refresh())
		load_button.pressed.connect(func():
			_asked = ""
			if SettingsProfiles.load_slot(slot, view):
				_status.text = Lang.t("Geladen: %s") % SettingsProfiles.get_slot(slot).name
			_refresh())
		delete.pressed.connect(func():
			if _asked != "delete%d" % slot:
				_asked = "delete%d" % slot
			else:
				SettingsProfiles.delete_slot(slot)
				_asked = ""
				name_edit.text = ""
				_status.text = Lang.t("Gelöscht.")
			_refresh())
		_refreshers.append(func():
			var profile := SettingsProfiles.get_slot(slot)
			var used := not profile.is_empty()
			if used and not name_edit.has_focus():
				name_edit.text = str(profile.name)
			name_edit.placeholder_text = Lang.t("Profil %d") % slot
			save.text = Lang.t("Überschreiben?") if _asked == "save%d" % slot else Lang.t("Speichern")
			delete.text = Lang.t("Wirklich?") if _asked == "delete%d" % slot else Lang.t("Löschen")
			load_button.disabled = not used
			delete.disabled = not used
			_set_picked(load_button, used and SettingsProfiles.is_current(slot)))


func _small_button(text: String, width: float) -> Button:
	var b: Button = _game._make_button(Lang.t(text), func(): pass)
	b.custom_minimum_size = Vector2(width, 40)
	b.add_theme_font_size_override("font_size", UiKit.sized(16))
	b.clip_text = true
	return b


# --- Rows ----------------------------------------------------------------------

const AA_NAMES := {"off": "Aus", "fxaa": "FXAA", "smaa": "SMAA", "taa": "TAA", "msaa2": "MSAA 2×", "msaa4": "MSAA 4×", "msaa8": "MSAA 8×"}
const AA_HINTS := {
	"off": "Keine Glättung: am schnellsten, mit gezackten Kanten.",
	"fxaa": "FXAA: glättet das fertige Bild in einem billigen Schritt.",
	"smaa": "SMAA: schärfere Glättung der Kanten, wenig Last.",
	"taa": "TAA: nutzt die letzten Bilder und beruhigt flimmernde Flächen am besten.",
	"msaa2": "MSAA 2×: Kanten werden zweimal abgetastet.",
	"msaa4": "MSAA 4×: Kanten werden viermal abgetastet.",
	"msaa8": "MSAA 8×: Kanten werden achtmal abgetastet. Kostet viel.",
}
const SHADOW_NAMES := {"low": "Niedrig", "medium": "Mittel", "high": "Hoch", "ultra": "Ultra"}


## A row's caption, in the pull-out menu's gold; every caption has the same width, so the controls line up.
func _caption(title: String, hint: String) -> Label:
	var label := Label.new()
	label.text = Lang.t(title)
	label.add_theme_font_override("font", _game.TEXT_FONT)
	label.add_theme_font_size_override("font_size", UiKit.sized(18))
	label.add_theme_color_override("font_color", _game.GOLD)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 40)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = Lang.t(hint)
	return label


func _note() -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _game.TEXT_FONT)
	l.add_theme_font_size_override("font_size", UiKit.sized(16))
	l.add_theme_color_override("font_color", Menus.ABOUT_COLOR)
	l.custom_minimum_size = Vector2(0, 24)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_body.add_child(l)
	return l


## A row of buttons, one per option, the picked one framed in gold. `options`: [value, text, tooltip]; `current`
## says which value is picked, `pick` takes a choice. The row updates itself on every refresh.
func _choice(title: String, hint: String, options: Array, columns: int, current: Callable, pick: Callable, enabled := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_caption(title, hint))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	var buttons: Array = []
	for o in options:
		var b: Button = _game._make_button(str(o[1]), func():
			pick.call(o[0])
			_refresh())
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiKit.sized(16))
		b.clip_text = true
		b.tooltip_text = str(o[2]) if str(o[2]) != "" else Lang.t(hint)
		b.disabled = not enabled
		grid.add_child(b)
		buttons.append(b)
	_body.add_child(row)
	_refreshers.append(func():
		var now: Variant = current.call()
		for i in buttons.size():
			_set_picked(buttons[i], options[i][0] == now))


## A row with a slider and its value. `shown` turns a value into the text beside the slider.
func _slider(title: String, hint: String, low: float, high: float, step: float, current: Callable, apply: Callable, shown: Callable, enabled := true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_caption(title, hint))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.editable = enabled
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	slider.tooltip_text = Lang.t(hint)
	row.add_child(slider)
	var value := Label.new()
	value.add_theme_font_override("font", _game.TEXT_FONT)
	value.add_theme_font_size_override("font_size", UiKit.sized(18))
	value.add_theme_color_override("font_color", Color.WHITE)
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 40)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	_body.add_child(row)
	slider.value = float(current.call())
	value.text = shown.call(slider.value)
	slider.value_changed.connect(func(v: float):
		apply.call(v)
		value.text = shown.call(v)
		# Other rows (the preset, say) follow, but this slider keeps its own place.
		_refresh())
	_refreshers.append(func():
		var now := float(current.call())
		if not is_equal_approx(slider.value, now):
			slider.set_value_no_signal(now)
		value.text = shown.call(now))


## Frames `b` in gold while `on`, as a picked row elsewhere (see Menus._mark_picked); the plain look comes back
## when it is off. The button keeps its size and its text its place.
func _set_picked(b: Button, on: bool) -> void:
	if not b.has_meta("plain"):
		b.set_meta("plain", {"normal": b.get_theme_stylebox("normal"), "hover": b.get_theme_stylebox("hover")})
	var plain: Dictionary = b.get_meta("plain")
	for state: String in ["normal", "hover"]:
		var style: StyleBox = plain[state]
		if on:
			var picked: BronzeStyle = style.duplicate()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				picked.set_content_margin(side, picked.get_margin(side))
			picked.bg_color = Color(0.2, 0.14, 0.1, 1.0)
			picked.border_color = Color(1.0, 0.9, 0.62)
			picked.shadow_color = Color(1.0, 0.8, 0.4, 0.55)
			picked.shadow_size = 5
			style = picked
		b.add_theme_stylebox_override(state, style)
