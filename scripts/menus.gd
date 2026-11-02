class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := 16
const BLUE := Color(0.65, 0.85, 1.0)
## The colour of everything about the villagers' goodwill (see Reputation).
const REPUTATION_COLOR := Color(0.78, 0.65, 1.0)
## The quieter colour of what a villager wants and who they are tied to,
## under their standing on the reputation page.
const ABOUT_COLOR := Color(0.78, 0.8, 0.86)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett", "laden",
## "kompendium", "charakter", "beenden", "plan" (the day planned for the
## time away) or "rueckkehr" (what the hero did while the player was away).
var current := ""
var _holder: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
## Whether the next fit may choose a new scale (see _fit).
var _rescale := true
var _fit_queued := false
## Width of the wrapped lines in the "Welcome back" window.
const RETURN_TEXT_WIDTH := 700
var _selected := -1
var _note := ""
## True while the player moves through the window with the keys (see _input).
var _keys := false
## The craft of the workbench whose window is open (see CraftingSquare).
var bench := ""
## The master whose wish window is open (see Wishes), by role letter.
var wish_master := ""
## The style window was opened from the wish window: choosing goes back there.
var _style_from_wishes := false
## The saved game whose delete button was clicked once; a second click deletes.
var _delete_asked := ""
## Which page of the compendium shows: "wissen" (controls and everything
## learned), "auftraege" (the villagers' tasks), "ruf" (the villagers'
## opinion of the hero) or "rezepte" (the recipes found and the ingredient pouch).
var compendium_page := "wissen"
## The inventory's open tab: "tasche" (the bag) or "beutel" (the ingredient pouch).
var inventory_tab := "tasche"
## Which page of the map window shows: "karte" (the map) or "tagebuch" (the
## journal), and which level's map.
var map_page := "karte"
var _map_file := ""
## The fixed size of both pages of the map window.
const MAP_PAGE_SIZE := Vector2(980, 450)
## The moon line at the top of the journal: its colour and the height kept
## for it (two lines of text).
const MOON_COLOR := Color(0.78, 0.84, 1.0)
const MOON_LINE_HEIGHT := 52.0
## How many saved games the load window shows before the list scrolls.
const LOAD_ROWS_SHOWN := 5
## Shows the stats of the item under the mouse (or last tapped).
var _info: Label
const INFO_HINT := "Zeig auf einen Gegenstand, um seine Werte zu sehen."
## The windows built as a TradeWindow.
const TRADE_WINDOWS := ["haendler", "wanderhaendler", "schmied", "steinmetz", "barbier"]
## The compact trading window of every merchant (see TradeWindow).
var trade := TradeWindow.new()
## Every control, for the compendium: action and keys.
const SHORTCUTS := [
	["Gehen", "WASD / Pfeiltasten oder Klick auf den Boden"],
	["Rennen", "Maustaste auf dem Boden halten oder Umschalt: in 2 Sekunden bis 250 % so schnell wie Gehen, so viele Sekunden wie Konstitution x 2, kommt mit Konstitution / 10 pro Sekunde zurück; leer erst wieder ab halbvoll. Wer im Lauf binnen 2 Sekunden mehr als 10 % seiner Leben verliert, stürzt zu Boden und steht wieder auf"],
	["Springen", "Leertaste, Rechtsklick im Lauf"],
	["Nahkampf", "F oder J, gegen das Skelett laufen oder es anklicken"],
	["Wurfmesser", "R oder K, Rechtsklick im Stehen"],
	["Schleichen", "C oder Doppelklick"],
	["Benutzen, durchsuchen, Fackel", "Dagegenlaufen"],
	["Inventar", "I"],
	["Kompendium", "H"],
	["Charakter", "P"],
	["Karte und Tagebuch", "N"],
	["Spielstand laden", "L"],
	["Ton an/aus", "M"],
	["Steinblock abstellen", "B, oder „Abstellen“ im Inventar"],
	["Steinblock verschieben", "Block mit der linken Maustaste greifen, ziehen und loslassen (Rechtsklick dabei dreht ihn)"],
	["Steinblock aufheben", "E neben dem Block, oder ihn kurz anklicken"],
	["Schwere Steinblöcke schieben", "E neben dem Block, oder ihn kurz anklicken; ziehen lässt ihn geradeaus rutschen"],
	["Zoom", "+ und −, Mausrad"],
	["Spiel beenden", "Esc"],
	["In Fenstern wählen", "Pfeiltasten oder Tab, Eingabe drückt den Knopf, Esc schließt"],
]


func setup(owner_game: Node, hud: CanvasLayer) -> void:
	game = owner_game
	# The centring container keeps the window in the middle whatever its size.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(center)
	# A plain holder between the two: a container would undo the window's
	# scale (see _fit), the holder takes the scaled size so it stays centred.
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.visible = false
	center.add_child(_holder)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style(Color(0.85, 0.66, 0.32, 0.7)))
	_holder.add_child(_panel)
	_panel.minimum_size_changed.connect(_place_panel)
	# Everything in the window sits in a scroll region. It is exactly as big as
	# the content while that fits the screen; on a smaller screen the window
	# first shrinks a little, then scrolls, so nothing is ever off-screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_box.minimum_size_changed.connect(_queue_fit)
	hud.get_viewport().size_changed.connect(func():
		_rescale = true
		_queue_fit())
	trade.game = game
	trade.rebuild = _rebuild


static func panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.9)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(26)
	return style


## Gap between a window and the edge of the screen.
const SCREEN_MARGIN := 12.0
## A window too big for the screen is shrunk down to this much at most;
## beyond that it scrolls instead, so its text stays readable.
const MIN_SCALE := 0.8


## Makes the open window fit the screen: shrinks it (not below MIN_SCALE)
## when it is too big, and lets its content scroll when even that is not
## enough. The scale is chosen when the window opens and when the screen
## changes size, not on every click inside, so the window does not change
## its size while the player works in it; content that grows later scrolls.
func _fit() -> void:
	_fit_queued = false
	if current == "":
		return
	var screen: Vector2 = _panel.get_viewport_rect().size - Vector2.ONE * 2.0 * SCREEN_MARGIN
	var frame: Vector2 = _panel.get_theme_stylebox("panel").get_minimum_size()
	var content: Vector2 = _box.get_combined_minimum_size()
	if _rescale:
		_rescale = false
		var need := content + frame
		var s := minf(1.0, minf(screen.x / need.x, screen.y / need.y))
		_panel.scale = Vector2.ONE * maxf(s, MIN_SCALE)
	var room: Vector2 = screen / _panel.scale.x - frame
	var view := content
	if view.y > room.y:
		view.y = room.y
		view.x += _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	if view.x > room.x:
		view.x = room.x
		view.y = minf(view.y + _scroll.get_h_scroll_bar().get_combined_minimum_size().y, room.y)
	_scroll.custom_minimum_size = view.floor()
	_place_panel()


## Sizes the window to its content and tells the holder its scaled size.
func _place_panel() -> void:
	_panel.reset_size()
	_holder.custom_minimum_size = (_panel.size * _panel.scale.x).ceil()


func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit.call_deferred()


func is_open() -> bool:
	return current != ""


func open(kind: String) -> void:
	current = kind
	_forge_tab = "waffen"
	inventory_tab = "tasche"
	_map_file = ""
	_shop_page = "kaufen"
	trade.reset()
	_selected = -1
	_note = ""
	_use_keys(false)
	game.set_world_paused(true)
	_holder.visible = true
	_rescale = true
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0
	_rebuild()


func close() -> void:
	if current == "":
		return
	current = ""
	game.trader_role = ""
	_holder.visible = false
	game.set_world_paused(false)
	game._update_hud()
	if game.state == game.State.TITLE:
		game.load_window_closed()


func _rebuild() -> void:
	var focused := _focus_index()
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	# The inventory holds the most, so its rows sit a little closer together.
	_box.add_theme_constant_override("separation", 6 if current == "inventar" or current in TRADE_WINDOWS else 10)
	match current:
		"inventar":
			_build_inventory()
		"lager":
			_build_storage()
		"bank":
			_build_bank()
		"barbier":
			_build_barber()
		"steinmetz":
			_build_stonemason()
		"ausbau":
			_build_upgrades()
		"hauswerkbank":
			_build_workbench()
		"trophaeen":
			_build_trophies()
		"aushang":
			_build_bounty_board()
		"schmied":
			_build_smithy()
		"werkbank":
			_build_bench()
		"kampfstil":
			_build_style()
		"wunsch":
			_build_wishes()
		"tresor":
			_build_vault()
		"haendler":
			_build_shop()
		"wanderhaendler":
			_build_wanderer()
		"bett":
			_build_bed()
		"laden":
			_build_load()
		"kompendium":
			_build_compendium()
		"karte":
			_build_map()
		"charakter":
			_build_character()
		"beenden":
			_build_quit()
		"plan":
			_build_plan()
		"rueckkehr":
			_build_return()
		"hoehle":
			_build_lair_won()
	if current in ["lager", "tresor"]:
		_info = _add_label(Lang.t(INFO_HINT), 16, BLUE)
		_info.custom_minimum_size.y = 26
	if _note != "" or current in TRADE_WINDOWS or current in ["werkbank", "inventar"]:
		# The trading windows and the inventory keep a line for the note, so a
		# purchase or a dropped item does not make the window grow.
		var note := _add_label(_note, 16, Color(1.0, 0.75, 0.5))
		note.custom_minimum_size.y = 26
		if current in TRADE_WINDOWS or current == "inventar":
			# One line at most, never wider than the window.
			note.clip_text = true
			note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			note.custom_minimum_size.x = INVENTORY_WIDTH if current == "inventar" else TradeWindow.BODY_WIDTH
	# The inventory has its own "Back to game" button at the top instead.
	if not current in ["inventar", "bett", "laden", "beenden", "plan", "rueckkehr", "hoehle"]:
		var close_button: Button = game._make_button(Lang.t("Schließen"), close)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_button.custom_minimum_size = Vector2(180, 44 if current in TRADE_WINDOWS else 52)
		_box.add_child(close_button)
	if _keys:
		_set_focusable(true)
		if focused >= 0:
			_focus_at(focused)
	_queue_fit()


# --- Keyboard and controller ------------------------------------------------
#
# The arrow keys (or the pad's cross, or Tab) move a focus over the open
# window's buttons, and Enter (or the pad's A button) presses the focused one.
# The focus shows only once the player uses those keys: the first arrow key
# in a window puts it on the first button, and a mouse click takes it away
# again, so a player with the mouse never sees a stray outline. A window
# never opens with a button already focused: Space is also the jump key, and
# a jump by habit must not buy or sell anything.

## Keys that show the focus when no button has it yet.
const FOCUS_KEYS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]


func _input(event: InputEvent) -> void:
	if current == "":
		return
	if event is InputEventMouseButton:
		# A click (not the wheel, which only scrolls) hides the focus.
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_use_keys(false)
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	if _focus_index() >= 0 or not FOCUS_KEYS.any(func(a): return event.is_action_pressed(a)):
		return
	var focus_owner := _box.get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner.is_visible_in_tree() and not (focus_owner is BaseButton):
		return # a text field keeps its arrow keys
	_use_keys(true)
	_focus_at(0)
	_box.get_viewport().set_input_as_handled()


func _use_keys(on: bool) -> void:
	if _keys == on:
		return
	_keys = on
	_set_focusable(on)


## The window's buttons in reading order, the ones that can be pressed.
func _focusables() -> Array:
	var out := []
	for b in _box.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree() and not b.disabled:
			out.append(b)
	return out


func _set_focusable(on: bool) -> void:
	for b in _box.find_children("*", "BaseButton", true, false):
		if on and b.is_visible_in_tree() and not b.disabled:
			b.focus_mode = Control.FOCUS_ALL
		else:
			if b.has_focus():
				b.release_focus()
			b.focus_mode = Control.FOCUS_NONE


## Where the focus is among the window's buttons, or -1.
func _focus_index() -> int:
	if _box == null:
		return -1
	var focus_owner := _box.get_viewport().gui_get_focus_owner()
	if focus_owner == null or not _box.is_ancestor_of(focus_owner):
		return -1
	return _focusables().find(focus_owner)


func _focus_at(index: int) -> void:
	var list := _focusables()
	if list.is_empty():
		return
	var b: Control = list[clampi(index, 0, list.size() - 1)]
	b.focus_mode = Control.FOCUS_ALL
	b.grab_focus()


# --- Building blocks ------------------------------------------------------

## Text for something finished (a quest done, a trophy won): struck through
## in `color`, styled like game._make_label, wrapped at `width`. `tag` (like
## "done") follows in brackets, not struck through, so the state reads
## without the colour too.
func _done_label(text: String, size: int, color: Color, width: float, tag := "", center := false) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", game.TEXT_FONT)
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_color_override("default_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	var lines := []
	for line in text.split("\n"):
		lines.append("[s]%s[/s]" % line.replace("[", "[lb]"))
	l.text = "\n".join(lines) + ("  (%s)" % tag.replace("[", "[lb]") if tag != "" else "")
	if center:
		l.text = "[center]%s[/center]" % l.text
	return l


func _add_label(text: String, size: int, color := Color.WHITE, font: Font = null) -> Label:
	var l: Label = game._make_label(font if font else game.TEXT_FONT, size, color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	return l


func _item_button(text: String, action: Callable, enabled := true, id := "") -> Button:
	var b: Button = game._make_button(text, action)
	if id != "":
		# Pointing at an item (or tapping it) shows its stats right away.
		b.mouse_entered.connect(_show_info.bind(id))
		b.focus_entered.connect(_show_info.bind(id))
		b.mouse_exited.connect(_show_info.bind(""))
	b.custom_minimum_size = Vector2(160, 54)
	b.add_theme_font_size_override("font_size", 16)
	b.disabled = not enabled
	return b


## A grid of item buttons; empty places up to `size` are shown as dashes.
func _add_item_grid(items: Array, size: int, label_of: Callable, action: Callable, columns := 4, parent: Control = null) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(parent if parent else _box).add_child(grid)
	for i in size:
		if i < items.size():
			var b := _item_button(label_of.call(items[i]), action.bind(i), true, items[i])
			if current == "inventar" and i == _selected:
				b.modulate = Color(0.7, 1.0, 0.7)
			grid.add_child(_inventory_cell(b) if current == "inventar" else b)
		else:
			var empty := _item_button("-", func(): pass, false)
			grid.add_child(_inventory_cell(empty) if current == "inventar" else empty)


func _show_info(id: String) -> void:
	if _info == null or not is_instance_valid(_info):
		return
	if id == "" and current == "inventar" and _selected >= 0 and _selected < game.player.bag.size():
		# Off an item, the inventory shows the picked one again.
		id = game.player.bag[_selected]
	if id == "":
		_info.text = Lang.t(INFO_HINT)
	elif not Items.ALL.has(id) and (Crafting.INGREDIENTS.has(id) or id == "eisen"):
		_info.text = game.crafting.describe_ingredient(id)
	else:
		_info.text = "%s: %s" % [Items.item_name(id), Items.describe(id, game.player.wear.get(id, 0))]


func _stats_text() -> String:
	var p: Player = game.player
	return Lang.t("Leben %d / %d (+%.1f/s)    Kampfkraft %d    Härtung %d    Tempo %d%%    Messer %d    Gold %d") % [
		p.hp, p.max_hp, p.life_regen(), p.power, p.hardening, roundi(p.speed / Player.SPEED * 100.0), p.knives, game.coins]


## The hero's attributes, each with how far it is to the next point.
## `two_lines` splits them in half so the line is not wider than the screen.
func _attributes_text(two_lines := false) -> String:
	var p: Player = game.player
	var parts := []
	for id in Training.ATTRIBUTES:
		var value := p.attribute(id)
		var shown := ("%d%%" % value) if id == "tempo" else str(value)
		var at_cap: bool = value >= Training.ATTRIBUTES[id].max
		parts.append("%s %s%s" % [Lang.t(Training.ATTRIBUTES[id].name), shown,
				Lang.t(" (höchster Wert)") if at_cap else " (%d%%)" % floori(Training.attribute_progress(id, p.xp.get(id, 0.0)) * 100.0)])
	if two_lines and parts.size() > 1:
		var half := ceili(parts.size() / 2.0)
		return "    ".join(parts.slice(0, half)) + "\n" + "    ".join(parts.slice(half))
	return "    ".join(parts)


## Every skill with its level; skills the worn gear does not allow are in brackets.
func _skills_text() -> String:
	var p: Player = game.player
	var parts := []
	for id in Training.SKILLS:
		var text := "%s %d" % [Lang.t(Training.SKILLS[id].name), p.skill(id) if p.skill_enabled(id) else Training.skill_level(p.xp.get(id, 0.0), id)]
		parts.append(text if p.skill_enabled(id) else "(%s)" % text)
	return Lang.t("Fertigkeiten:") + " " + "   ".join(parts) + "\n" + Lang.t("In Klammern: braucht passende Ausrüstung")


# --- Character page -------------------------------------------------------

## The crafts, each with its level, for the character page.
func _crafts_text() -> String:
	var parts := []
	for id in Training.CRAFTS:
		parts.append("%s %d" % [Lang.t(Training.CRAFTS[id].name), Training.skill_level(game.player.xp.get(id, 0.0), id)])
	return Lang.t("Handwerk:") + " " + "   ".join(parts)


## The width of the column beside the character wheel.
const CHARACTER_SIDE := 340
## The details card beside the wheel has a fixed height that fits the longest
## details in both languages, so pointing at another entry moves nothing.
const CHARACTER_CARD_HEIGHT := 262
const CHARACTER_TEXT := Color(0.85, 0.87, 0.92)


## The wheel of attributes and skills (see CharacterPage). Beside it: what
## is not on the wheel (life and the attributes no skill depends on), and a
## card with the details of the entry pointed at, or how a roll works.
func _build_character() -> void:
	var p: Player = game.player
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	var wheel := CharacterPage.new(p, game.TEXT_FONT)
	row.add_child(wheel)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = CHARACTER_SIDE
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	var title: Label = game._make_label(game.TITLE_FONT, 38, game.GOLD)
	title.text = Lang.t("Charakter")
	side.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	side.add_child(grid)
	_character_row(grid, wheel, "", Lang.t("Leben"), "%d / %d   %+.1f/s" % [p.hp, p.max_hp, p.life_regen()], Color(1.0, 0.55, 0.5))
	for id in Training.ATTRIBUTES:
		if not id in Training.MAIN_ATTRIBUTES:
			_character_row(grid, wheel, id, Lang.t(Training.ATTRIBUTES[id].name),
					("%d %%" % p.attribute(id)) if id == "tempo" else str(p.attribute(id)), Color.WHITE)
	# The details card: what the wheel points at, else how a roll works.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CHARACTER_SIDE, CHARACTER_CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", TradeWindow._style(Color(0.07, 0.05, 0.07, 0.97), TradeWindow.BORDER, 8, 12, 2))
	side.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	card.add_child(lines)
	var card_title: Label = game._make_label(game.TITLE_FONT, 20, game.GOLD)
	var card_body: Label = game._make_label(game.TEXT_FONT, 16, CHARACTER_TEXT)
	var card_note: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	for l in [card_title, card_body, card_note]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = CHARACTER_SIDE - 28
		l.add_theme_constant_override("line_spacing", 0)
	for l in [card_title, card_body, card_note]:
		lines.add_child(l)
	var show := func(id: String) -> void:
		var d: Dictionary = wheel.details(id)
		card_title.text = d.title
		card_body.text = "\n".join(d.lines)
		card_note.text = d.note
	show.call("")
	wheel.shown_changed.connect(show)
	for entry in [
		[Lang.t("Innen: Grundfertigkeiten. Außen: fortgeschrittene Fertigkeiten."), CHARACTER_TEXT],
		[_crafts_text(), game.GOLD],
	]:
		var l: Label = game._make_label(game.TEXT_FONT, 16, entry[1])
		l.text = entry[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = CHARACTER_SIDE
		side.add_child(l)


## One line of the list beside the wheel: a name and its value. An attribute's
## line (id not empty) shows its details in the card when pointed at or tapped.
func _character_row(grid: GridContainer, wheel: CharacterPage, id: String, name: String, value: String, color: Color) -> void:
	var name_label: Label = game._make_label(game.TEXT_FONT, 16, CHARACTER_TEXT)
	name_label.text = name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label: Label = game._make_label(game.TEXT_FONT, 16, color)
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l in [name_label, value_label]:
		grid.add_child(l)
		if id == "":
			continue
		# Pass, so the mouse wheel still scrolls the window.
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		l.mouse_entered.connect(wheel.point.bind(id))
		l.mouse_exited.connect(wheel.point.bind(""))
		l.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				wheel.pick(id))


# --- Inventory --------------------------------------------------------------

## The inventory's fixed width: six item cells and the gaps between them.
## Every line and region of the window is this wide, so nothing the player
## picks or points at can make the window wider or narrower.
const INVENTORY_CELL := Vector2(150, 48)
const INVENTORY_WIDTH := 6 * 150 + 5 * 8
## The details of the picked item or the one under the pointer: lines of
## text kept for them, and the font size. Longer texts scroll in that box.
const INVENTORY_DETAIL_LINES := 4
const INVENTORY_TEXT := 15


func _build_inventory() -> void:
	var p: Player = game.player
	_add_inventory_header()
	_add_inventory_line(_stats_text(), BLUE)
	_add_inventory_line(_attributes_text(true), game.GOLD)
	_add_inventory_line(_skills_text(), Color(0.8, 0.85, 0.9))
	_add_worn_heading(p)
	var row := GridContainer.new()
	# Six across keeps all eleven slots in two rows, so the window fits the screen.
	row.columns = 6
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(row)
	for slot in Items.SLOTS:
		var id: String = p.equipped.get(slot, "")
		var text: String = "%s\n%s" % [Lang.t(Items.SLOT_NAMES[slot]), Items.item_name(id) if id != "" else "-"]
		row.add_child(_inventory_cell(_item_button(text, _unequip.bind(slot), id != "", id)))
	# Two tabs share the space below: the bag and the ingredient pouch.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	_box.add_child(tabs)
	var bag_tab := Lang.t("Tasche (%d / %d)    Gewicht %s") % [p.bag.size(), p.bag_size(), Items.weight_text(p.carried_weight())]
	var pouch_tab := Lang.t("Zutatenbeutel (%d)") % _pouch_ids().size()
	for tab in [["tasche", bag_tab], ["beutel", pouch_tab]]:
		var b := _item_button(tab[1], _show_inventory_tab.bind(tab[0]))
		b.custom_minimum_size = Vector2(3 * INVENTORY_CELL.x + 2 * 8, 44)
		b.modulate = Color(1.0, 0.9, 0.6) if inventory_tab == tab[0] else Color(0.75, 0.75, 0.8)
		tabs.add_child(b)
	# The bag's page is always built: it sets the size the pouch's page gets,
	# so switching tabs does not resize the window.
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	_box.add_child(page)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _select, 6, page)
	if inventory_tab == "beutel":
		var room := page.get_combined_minimum_size()
		_box.remove_child(page)
		page.queue_free()
		_box.add_child(_pouch_page(room, 6))
	_box.add_child(_inventory_details())


## A line of the hero's values at the top of the inventory: wrapped at the
## window's width, so a longer value never widens the window.
func _add_inventory_line(text: String, color: Color) -> Label:
	var l := _add_label(text, INVENTORY_TEXT, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = INVENTORY_WIDTH
	return l


## Makes an item button one cell of the inventory's grid: always the same
## size. A long name breaks over two lines, and what does not fit even then
## ends in "…" (the details box shows it in full).
func _inventory_cell(b: Button) -> Button:
	b.custom_minimum_size = INVENTORY_CELL
	if not "\n" in b.text:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", INVENTORY_TEXT)
	return b


## "Worn" with the helmet's show/hide button beside it. The button's place is
## kept when no helmet is worn, so putting one on does not move anything.
func _add_worn_heading(p: Player) -> void:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.custom_minimum_size = Vector2(INVENTORY_WIDTH, 44)
	_box.add_child(heading)
	const SIDE := 2 * 150 + 8
	var balance := Control.new()
	balance.custom_minimum_size.x = SIDE
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(balance)
	var title: Label = game._make_label(game.TEXT_FONT, 16)
	title.text = Lang.t("Angelegt (anklicken zum Ablegen)")
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	if Items.ALL.get(p.equipped.get("kopf", ""), {}).has("hat"):
		# A helmet can stay invisible, so the haircut shows; it protects all the same.
		var shown: bool = p.hair.get("show_helmet", true)
		var toggle := _item_button(Lang.t("Helm verstecken (schützt trotzdem)") if shown else Lang.t("Helm zeigen"), _toggle_helmet)
		toggle.custom_minimum_size = Vector2(SIDE, 44)
		toggle.clip_text = true
		toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		toggle.add_theme_font_size_override("font_size", INVENTORY_TEXT)
		heading.add_child(toggle)
	else:
		var keep := Control.new()
		keep.custom_minimum_size.x = SIDE
		keep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_child(keep)


## Under the bag: a box of fixed size for the details of the item under the
## pointer (or else the picked one), with the picked item's buttons beside
## it. A long description wraps and scrolls inside the box; the box, the
## buttons and the window keep their size whatever is picked.
func _inventory_details() -> Control:
	var p: Player = game.player
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.custom_minimum_size = Vector2(INVENTORY_CELL.x, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info = game._make_label(game.TEXT_FONT, 16, BLUE)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pass, so the mouse wheel scrolls a long description.
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_info)
	var lines := float(INVENTORY_DETAIL_LINES)
	scroll.custom_minimum_size = Vector2(INVENTORY_WIDTH - INVENTORY_CELL.x - 10,
			ceilf(_info.get_line_height() * lines + _info.get_theme_constant("line_spacing") * (lines - 1.0)))
	row.add_child(scroll)
	row.add_child(actions)
	_show_info("")
	if _selected >= 0 and _selected < p.bag.size():
		var id: String = p.bag[_selected]
		var buttons := []
		if Items.is_crate(id):
			buttons.append(_item_button(Lang.t("Abstellen"), _put_down_selected))
		elif Items.is_stone(id):
			buttons.append(_item_button(Lang.t("Abstellen"), _place_stone_selected))
		elif Items.is_quest(id) or Items.is_material(id) or Items.is_food(id) or Items.is_light(id):
			pass # Carried for a task, to the smith, for a fox or for the dark, not worn.
		else:
			buttons.append(_item_button(Lang.t("Anlegen"), _equip_selected))
		buttons.append(_item_button(Lang.t("Wegwerfen"), _drop_selected))
		for b in buttons:
			b.custom_minimum_size = Vector2(INVENTORY_CELL.x, 44)
			actions.add_child(b)
	return row


## The ingredients the hero carries, in the order of the ingredient book,
## with the smith's iron bars last.
func _pouch_ids() -> Array:
	var ids := []
	for id in Crafting.INGREDIENTS:
		if game.crafting.have(id) > 0:
			ids.append(id)
	if game.crafting.have("eisen") > 0:
		ids.append("eisen")
	return ids


## The ingredient pouch: every ingredient carried and how many, in a region
## as big as the bag's page; it scrolls if it ever holds more.
func _pouch_page(room: Vector2, columns: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = room
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var ids := _pouch_ids()
	if ids.is_empty():
		var empty: Label = game._make_label(game.TEXT_FONT, 16, Color(0.85, 0.87, 0.92))
		empty.text = Lang.t("Der Zutatenbeutel ist leer. Zutaten findet dein Fuchs, du angelst sie oder kaufst sie beim Wanderhändler; das Rezeptbuch (H) sagt, wo.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.x = room.x
		list.add_child(empty)
		return scroll
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(grid)
	for id in ids:
		# Ingredients are not worn or dropped: a click shows what the book says.
		var b := _item_button("%s\n× %d" % [Crafting.ingredient_name(id), game.crafting.have(id)], _show_info.bind(id), true, id)
		# Long names end in "…" rather than widen the page; the details box
		# under it shows the full name and what the book says.
		grid.add_child(_inventory_cell(b))
	return scroll


func _show_inventory_tab(tab: String) -> void:
	inventory_tab = tab
	_selected = -1
	_note = ""
	_rebuild()


## The title with a clearly visible "Back to game" button beside it. It sits
## at the top so it stays on screen however tall the window gets.
func _add_inventory_header() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_box.add_child(header)
	var back: Button = game._make_button(Lang.t("Zurück zum Spiel"), close)
	back.custom_minimum_size = Vector2(190, 44)
	back.add_theme_font_size_override("font_size", 16)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = back.get_theme_stylebox("normal").duplicate()
	style.bg_color = Color(0.2, 0.42, 0.18, 0.9)
	style.border_color = game.GOLD
	style.set_border_width_all(3)
	back.add_theme_stylebox_override("normal", style)
	back.add_theme_stylebox_override("hover", style)
	back.add_theme_color_override("font_color", Color.WHITE)
	# An empty box as wide as the button keeps the title in the middle.
	var balance := Control.new()
	balance.custom_minimum_size.x = back.custom_minimum_size.x
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(balance)
	# A little smaller than other windows' titles: the inventory holds the most.
	var title: Label = game._make_label(game.TITLE_FONT, 32, game.GOLD)
	title.text = Lang.t("Inventar")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(back)


func _select(index: int) -> void:
	_selected = index
	_note = ""
	_rebuild()


func _equip_selected() -> void:
	var p: Player = game.player
	var id: String = p.bag[_selected]
	var requires: Dictionary = Items.ALL[id].get("requires", {})
	_note = ""
	if Items.is_book(id):
		_note = Lang.t("Bücher liest dein Held, während du weg bist. Plane es am Bett.")
		_selected = -1
		_rebuild()
		return
	if not p.can_use(requires):
		var attr: String = requires.keys()[0]
		_note = Lang.t("Dafür brauchst du %s %d.") % [Lang.t(Training.ATTRIBUTES[attr].name), requires[attr]]
	elif not p.equip(id):
		_note = Lang.t("In diesen Rucksack passt nicht alles aus deiner Tasche.")
	_selected = -1
	_rebuild()


## Sets the selected crate down in front of the hero and goes back to the
## game, so the crate can be seen where it went.
func _put_down_selected() -> void:
	_selected = -1
	_note = ""
	close()
	var why: String = game.put_down_crate()
	if why != "":
		game.show_message(why, 1.6)


## Sets a stone block down in front of the hero and goes back to the game.
func _place_stone_selected() -> void:
	_selected = -1
	_note = ""
	close()
	var why: String = game.place_stone()
	if why != "":
		game.show_message(why, 1.6)


func _drop_selected() -> void:
	var p: Player = game.player
	_note = Lang.t("%s weggeworfen.") % Items.item_name(p.bag[_selected])
	p.bag.remove_at(_selected)
	_selected = -1
	_rebuild()


func _toggle_helmet() -> void:
	var look: Dictionary = game.player.hair.duplicate()
	look.show_helmet = not look.get("show_helmet", true)
	game.player.set_hair(look)
	_note = ""
	_rebuild()


func _unequip(slot: String) -> void:
	_note = "" if game.player.unequip(slot) else Lang.t("Deine Tasche ist voll.")
	_selected = -1
	_rebuild()


# --- Storage chest ----------------------------------------------------------

func _build_storage() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Lagertruhe"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 16, BLUE)
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag.size(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _store, 6)
	var size := HomeUpgrades.storage_size(game.home_upgrades)
	_add_label(Lang.t("Truhe (%d / %d)") % [game.storage.size(), size], 20)
	_add_item_grid(game.storage, maxi(size, game.storage.size()), Items.item_name, _take, 8 if size > STORAGE_SIZE else 6)


func _store(index: int) -> void:
	if game.storage.size() >= HomeUpgrades.storage_size(game.home_upgrades):
		_note = Lang.t("Die Truhe ist voll.")
	else:
		game.storage.append(game.player.bag[index])
		game.player.bag.remove_at(index)
		_note = ""
	_rebuild()


func _take(index: int) -> void:
	if game.player.bag.size() >= game.player.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(game.storage[index])
		game.storage.remove_at(index)
		_note = ""
	_rebuild()


# --- Workbenches on the crafting square ------------------------------------

## A workbench of the crafting square: what is made there, and the recipes
## the hero knows for its craft. Until the hero knows one, it says how to
## find recipes; the storage chest and Gorm's forge are right beside it.
func _build_bench() -> void:
	Events.teach(CraftingSquare.LEARN)
	var info := CraftingSquare.bench_of(bench)
	if info.is_empty():
		_add_label(Lang.t("Werkbank"), 38, game.GOLD, game.TITLE_FONT)
		return
	var c: Crafting = game.crafting
	_add_label(Lang.t(info.name), 38, game.GOLD, game.TITLE_FONT)
	var craft_name := Lang.t(Training.CRAFTS[bench].name) if Training.CRAFTS.has(bench) else ""
	if craft_name != "":
		_add_label(Lang.t("Dein Handwerk: %s, Stufe %d") % [craft_name, c.craft_level(bench)], 22, game.GOLD)
	else:
		_add_label(Lang.t(info.craft_line), 22)
	_add_label(Lang.t(info.text), 16, BLUE)
	# The recipes scroll in a region of fixed size, so making something (and
	# the note it leaves) never changes the window's frame.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = BENCH_LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var recipes: Array = c.recipes_for(bench)
	if recipes.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16, Color(1.0, 0.75, 0.5))
		none.text = Lang.t("Du kennst noch kein Rezept für diese Werkbank. Rezepte findest du bei Gelehrten, in Truhen und als Belohnung.")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = BENCH_LIST_SIZE.x - 20
		list.add_child(none)
	for id in recipes:
		list.add_child(_bench_row(id))
	_add_label(Lang.t("Deine Truhe und Gorms Esse stehen gleich nebenan."), 16, BLUE)


## The fixed size of the list of recipes at a workbench.
const BENCH_LIST_SIZE := Vector2(780, 300)


## One recipe at a workbench: what it makes and does, each ingredient as
## have / need (with a tick or a cross, not only colour), why it cannot be
## made yet, and the button that makes it.
func _bench_row(id: String) -> Control:
	var c: Crafting = game.crafting
	var r: Dictionary = Crafting.RECIPES[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.custom_minimum_size.x = 560
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title: Label = game._make_label(game.TEXT_FONT, 20, game.GOLD)
	title.text = Lang.t(r.name) + (("  ·  " + Lang.t(r.effect)) if r.has("effect") else "")
	text.add_child(title)
	var parts := []
	for ingredient in r.ingredients:
		var need := int(r.ingredients[ingredient])
		var has := c.have(ingredient)
		parts.append("%s %s %d / %d" % ["✓" if has >= need else "✗", Crafting.ingredient_name(ingredient), mini(has, need), need])
	var needs: Label = game._make_label(game.TEXT_FONT, 16)
	needs.text = "   ".join(parts)
	needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs.custom_minimum_size.x = 560
	text.add_child(needs)
	var why: String = c.why_not(id)
	var state: Label = game._make_label(game.TEXT_FONT, 16, Color(1.0, 0.75, 0.5) if why != "" else Color(0.4, 0.92, 0.4))
	state.text = why if why != "" else Lang.t("Alles da: du kannst es herstellen.")
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.custom_minimum_size.x = 560
	text.add_child(state)
	var button := _item_button(Lang.t("Herstellen"), _make_recipe.bind(id), why == "")
	button.custom_minimum_size = Vector2(170, 54)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return row


func _make_recipe(id: String) -> void:
	var why: String = game.crafting.make(id)
	if why != "":
		_note = why
	else:
		var item: String = Crafting.RECIPES[id].result
		var p: Player = game.player
		var where := Lang.t("in deiner Tasche") if p.bag.has(item) else Lang.t("in deiner Truhe, die Tasche ist voll")
		_note = Lang.t("Hergestellt: %s, %s.") % [Items.item_name(item), where]
		Sfx.play(game, "key", -3.0)
		game.learn(MADE_LEARN)
		game._update_hud()
	_rebuild()


## Explained once in the compendium, the first time the hero makes something.
const MADE_LEARN := "An den Werkbänken auf dem Handwerkerplatz stellst du her, was deine Rezepte verlangen: Lauf gegen die Werkbank des Handwerks, und wenn alle Zutaten im Beutel sind, drück „Herstellen“. Das Stück kommt in deine Tasche, und jedes Mal wirst du in dem Handwerk geübter."


# --- Bank -------------------------------------------------------------------

func _build_bank() -> void:
	var hero: String = game.hero_name
	_add_label(Lang.t("Bank der Krone"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Im Beutel: %d Gold      Auf der Bank: %d Gold") % [game.coins, Bank.gold(hero)], 22)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	for b in [[Lang.t("Alles einzahlen"), func(): _pay_in(game.coins), game.coins > 0],
			[Lang.t("10 einzahlen"), func(): _pay_in(10), game.coins >= 10],
			[Lang.t("10 abheben"), func(): _pay_out(10), Bank.gold(hero) > 0],
			[Lang.t("Alles abheben"), func(): _pay_out(Bank.gold(hero)), Bank.gold(hero) > 0]]:
		row.add_child(_item_button(b[0], b[1], b[2]))
	if Bank.has_vault(hero):
		_add_label(Lang.t("Dein Schließfach im Tresorkeller hat Platz für %d Schätze.") % Bank.VAULT_SIZE, 16, BLUE)
	else:
		_add_label(Lang.t("Ein Schließfach im Tresorkeller kostet einmalig %d Gold (vom Bankkonto).") % Bank.VAULT_PRICE, 16, BLUE)
		var rent := _item_button(Lang.t("Schließfach mieten"), _rent_vault, Bank.gold(hero) >= Bank.VAULT_PRICE)
		rent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rent.custom_minimum_size = Vector2(300, 54)
		_box.add_child(rent)
	var down: Button = game._make_button(Lang.t("In den Tresorkeller gehen"), func():
		close()
		game.go_to_vaults())
	down.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	down.custom_minimum_size = Vector2(320, 54)
	_box.add_child(down)


func _pay_in(amount: int) -> void:
	amount = mini(amount, game.coins)
	game.coins -= amount
	Bank.deposit(game.hero_name, amount)
	Sfx.play(game, "coin")
	_note = ""
	# Bank and saved game must agree, or gold could be had twice.
	game.save_game()
	_rebuild()


func _pay_out(amount: int) -> void:
	game.coins += Bank.withdraw(game.hero_name, amount)
	Sfx.play(game, "coin")
	_note = ""
	# Bank and saved game must agree, or gold could be had twice.
	game.save_game()
	_rebuild()


func _rent_vault() -> void:
	if Bank.withdraw(game.hero_name, Bank.VAULT_PRICE) == Bank.VAULT_PRICE:
		Bank.rent_vault(game.hero_name)
		_note = Lang.t("Das Schließfach gehört dir. Du findest es im Tresorkeller.")
	# Bank and saved game must agree, or gold could be had twice.
	game.save_game()
	_rebuild()


## The hero's own vault in the cellar: like the chest at home.
func _build_vault() -> void:
	var p: Player = game.player
	var hero: String = game.hero_name
	_add_label(Lang.t("Dein Schließfach"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 16, BLUE)
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag.size(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _to_vault, 6)
	var items := Bank.vault_items(hero)
	_add_label(Lang.t("Schließfach (%d / %d)") % [items.size(), Bank.VAULT_SIZE], 20)
	_add_item_grid(items, Bank.VAULT_SIZE, Items.item_name, _from_vault, 6)


func _to_vault(index: int) -> void:
	if Bank.store(game.hero_name, game.player.bag[index]):
		game.player.bag.remove_at(index)
		_note = ""
		game.level.refresh_vaults()
	else:
		_note = Lang.t("Das Schließfach ist voll.")
	# Bank and saved game must agree, or gold could be had twice.
	game.save_game()
	_rebuild()


func _from_vault(index: int) -> void:
	if game.player.bag.size() >= game.player.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(Bank.take(game.hero_name, index))
		_note = ""
		game.level.refresh_vaults()
	# Bank and saved game must agree, or gold could be had twice.
	game.save_game()
	_rebuild()


# --- Reputation -------------------------------------------------------------

## A line in a villager's window: how they think of the hero and the
## discount that gives (nothing for the refuge's merchant).
func _add_standing() -> Label:
	var role: String = game.trader_role
	if role == "":
		return null
	var rep: Reputation = game.reputation
	var lvl := rep.level(role)
	var text := Lang.t("Ruf bei %s: %s") % [Quests.villager_name(role), Reputation.level_name(lvl)]
	var off := roundi(Reputation.LEVELS[lvl].discount * 100.0)
	if off > 0:
		text += Lang.t(" (%d%% Rabatt)") % off
	return _add_label(text, 16, REPUTATION_COLOR)


## Builds a merchant's trading window (see TradeWindow), with the
## villager's goodwill under the gold.
func _trade(gold_text: String, sections: Array, extra: Control = null, hint := "") -> void:
	var standing := _add_standing()
	if standing:
		_box.remove_child(standing)
	trade.build(_box, gold_text, sections, extra, standing, hint)


# --- Merchant ---------------------------------------------------------------

static func sell_price(id: String) -> int:
	return maxi(1, Items.ALL[id].price / 2)


func _build_shop() -> void:
	var p: Player = game.player
	# There are always sausages for a fox (see Pet).
	while game.shop_stock.count(Pet.FOOD) < 2:
		game.shop_stock.push_front(Pet.FOOD)
	# And torches for the pitch-black holes in the wild (see HandTorch).
	while game.shop_stock.count(HandTorch.ITEM) < 3:
		game.shop_stock.push_front(HandTorch.ITEM)
	_add_label(Lang.t("Händler"), 38, game.GOLD, game.TITLE_FONT)
	var gear := []
	var goods := []
	# One row per kind of item, with how many there are: rows are keyed
	# by the item, so buying or selling one never moves the others.
	if _shop_page == "kaufen":
		for id in _kinds(game.shop_stock):
			var entry := _ware_entry("ware:" + id, id, game.trader_price(Items.ALL[id].price), _buy.bind(game.shop_stock.find(id)))
			# Sausages never run out (see Pet), so they show no count.
			entry.count = 1 if id == Pet.FOOD else game.shop_stock.count(id)
			(goods if _is_consumable(id) else gear).append(entry)
	else:
		for id in _kinds(p.bag):
			var entry := {"key": "sell:" + id, "id": id, "name": Items.item_name(id), "price": "+" + Lang.t("%d Gold") % sell_price(id),
					"button": Lang.t("Verkaufen"), "action": _sell.bind(p.bag.find(id)), "count": p.bag.count(id)}
			(goods if _is_consumable(id) else gear).append(entry)
	var gone := Lang.t("Ausverkauft") if _shop_page == "kaufen" else Lang.t("Verkauft")
	var empty := Lang.t("Nichts im Angebot.") if _shop_page == "kaufen" else Lang.t("Nichts davon in deiner Tasche.")
	_trade(Lang.t("Dein Gold: %d") % game.coins, [
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear, "empty": empty, "gone": gone},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods, "empty": empty, "gone": gone},
	], _shop_pages(Lang.t("Verkaufen (%d / %d)") % [p.bag.size(), p.bag_size()]))


## Each item of a list once, in the order it first appears.
static func _kinds(items: Array) -> Array:
	var out := []
	for id in items:
		if not id in out:
			out.append(id)
	return out


## Which page of a merchant's window shows: "kaufen" (his wares) or
## "verkaufen" (the hero's bag).
var _shop_page := "kaufen"


## The two page tabs, Buy and Sell, above a merchant's categories.
func _shop_pages(sell_label := "") -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for page in [["kaufen", Lang.t("Kaufen")], ["verkaufen", sell_label if sell_label != "" else Lang.t("Verkaufen")]]:
		var b := _item_button(page[1], _show_shop_page.bind(page[0]))
		b.custom_minimum_size = Vector2(170, 40)
		if page[0] == _shop_page:
			b.modulate = Color(0.7, 1.0, 0.7)
		tabs.add_child(b)
	return tabs


func _show_shop_page(page: String) -> void:
	_shop_page = page
	trade.reset()
	_note = ""
	_rebuild()


## A row for something on sale: grey when the gold or the bag falls short.
func _ware_entry(key: String, id: String, price: int, action: Callable) -> Dictionary:
	var p: Player = game.player
	return {"key": key, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Gold") % price, "price_ok": game.coins >= price,
			"button": Lang.t("Kaufen"), "action": action, "enabled": game.coins >= price and p.bag.size() < p.bag_size()}


## Books, stone, ore and the like: things that are not worn.
static func _is_consumable(id: String) -> bool:
	var slot: String = Items.ALL[id].slot
	return not slot in Items.SLOTS and slot != "spezial"


func _buy(index: int) -> void:
	var id: String = game.shop_stock[index]
	var price: int = game.trader_price(Items.ALL[id].price)
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	elif game.player.bag.size() >= game.player.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.coins -= price
		Events.bus().traded.emit(game.trader_role)
		game.player.bag.append(id)
		# The shop never runs out of sausages: they stay in stock.
		if id != Pet.FOOD:
			game.shop_stock.remove_at(index)
		_note = Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
		if id == Pet.FOOD and not game.has_fox:
			# Where to take it, short enough for the one note line; the
			# whole hint goes into the compendium.
			_note = Lang.t("Gekauft: Wurst. Füchse leben am Waldteich westlich vom Dorf.")
			Events.teach(Pet.WHERE)
	_rebuild()


func _sell(index: int) -> void:
	var id: String = game.player.bag[index]
	game.coins += sell_price(id)
	game.player.bag.remove_at(index)
	game.shop_stock.append(id)
	_note = Lang.t("Verkauft: %s für %d Gold") % [Items.item_name(id), sell_price(id)]
	_rebuild()


# --- Wandering merchant -------------------------------------------------------

const WANDERER_LEARN := "Wanderhändler Zarek kommt jede dritte Nacht mit seinem Karren ins Dorf und steht bis zum Morgengrauen am Markt. Er bringt Zutaten für Rezepte aus fernen Gegenden mit, dazu etwas einfache Ausrüstung, und jedes Mal andere Waren. Kaufen tut er nichts."


## Zarek sells tonight's wares and buys nothing: ingredients go into the
## pouch, gear into the bag. The window says when he comes back.
func _build_wanderer() -> void:
	Events.teach(WANDERER_LEARN)
	var wares: Array[String] = game.wanderer_wares()
	_add_label(Lang.t("Wanderhändler"), 38, game.GOLD, game.TITLE_FONT)
	var herbs := []
	var gear := []
	var goods := []
	var listed := {}
	for i in wares.size():
		var id: String = wares[i]
		if not Wanderer.is_ingredient(id):
			if listed.has(id):
				continue
			listed[id] = true
			var entry := _ware_entry("ware:" + id, id, Wanderer.price(id), _buy_from_wanderer.bind(i))
			entry.count = wares.count(id)
			(goods if _is_consumable(id) else gear).append(entry)
		elif not listed.has(id):
			# One row per kind of ingredient, bought one piece at a time.
			listed[id] = true
			herbs.append(_ingredient_entry(id, wares.count(id), i))
	var empty := Lang.t("Nichts im Angebot.")
	var note := Lang.t("Zutaten aus fernen Gegenden, nur heute Nacht. Im Morgengrauen zieht Zarek weiter; in %d Nächten kommt er wieder.") % Wanderer.EVERY
	_trade(Lang.t("Dein Gold: %d") % game.coins, [
		{"key": "herbs", "title": Lang.t("Zutaten"), "icon": "kind:ore", "entries": herbs, "empty": empty},
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear, "empty": empty},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods, "empty": empty},
	], null, note)


## A row for one kind of Zarek's ingredients: how many pieces he has left,
## what the ingredient book says about it, and how many are in the pouch.
func _ingredient_entry(id: String, left: int, index: int) -> Dictionary:
	var price := Wanderer.price(id)
	var icon := "kind:ore" if id == "mondsilbererz" else ("kind:stone" if id == "mondstein" else "kind:bag")
	var lines := []
	for line in game.crafting.describe_ingredient(id).split("\n").slice(1):
		lines.append([line, TradeWindow.BLUE])
	return {"key": "herb:%s" % id, "id": id, "icon": icon, "name": Wanderer.ware_name(id),
			"price": Lang.t("%d Gold") % price, "price_ok": game.coins >= price, "action": _buy_from_wanderer.bind(index),
			"enabled": game.coins >= price,
			"detail": {"subtitle": Lang.t("Zutat für Rezepte, noch %d da") % left, "lines": lines},
			"compare": {"title": Lang.t("In deinem Zutatenbeutel"), "name": "%s: %d" % [Wanderer.ware_name(id), game.crafting.have(id)], "icon": icon}}


func _buy_from_wanderer(index: int) -> void:
	var wares: Array[String] = game.wanderer_wares()
	if index >= wares.size():
		return
	var id: String = wares[index]
	var cost := Wanderer.price(id)
	var ingredient := Wanderer.is_ingredient(id)
	if game.coins < cost:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	elif not ingredient and game.player.bag.size() >= game.player.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.coins -= cost
		wares.remove_at(index)
		if ingredient:
			game.crafting.add(id)
			_note = Lang.t("Gekauft: %s. Es kommt in deinen Zutatenbeutel.") % Wanderer.ware_name(id)
		else:
			game.player.bag.append(id)
			_note = Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
		Sfx.play(game, "gear_soft_0", -2.0)
	game._update_hud()
	_rebuild()


# --- Stonemason --------------------------------------------------------------

const STONE := "steinblock"


## The stonemason sells stone blocks, as many as the bag holds, and takes
## them back for half the price.
func _build_stonemason() -> void:
	var p: Player = game.player
	var price: int = game.trader_price(Items.ALL[STONE].price)
	var room: int = p.bag_size() - p.bag.size()
	_add_label(Lang.t("Steinmetz"), 38, game.GOLD, game.TITLE_FONT)
	var all := mini(room, game.coins / price) if price > 0 else room
	var have := p.bag.count(STONE)
	var detail := {"subtitle": TradeWindow.subtitle(STONE), "lines": TradeWindow.stat_lines(STONE) + [
			[Lang.t("Behauene Steinblöcke zum Bauen: Mauern, Stufen, Türme. Abstellen mit B oder im Inventar, verschieben mit der Maus: greifen, ziehen, loslassen."), TradeWindow.BLUE]]}
	var compare := {"title": Lang.t("In deiner Tasche"), "name": Lang.t("Steinblöcke: %d") % have, "icon": STONE,
			"subtitle": Lang.t("Platz für %d weitere") % room}
	_trade(Lang.t("Dein Gold: %d") % game.coins, [
		{"key": "stone", "title": Lang.t("Bausteine"), "icon": "kind:stone", "entries": [
			{"key": "back", "id": STONE, "name": Lang.t("1 zurückgeben"), "price": "+" + Lang.t("%d Gold") % sell_price(STONE),
					"button": Lang.t("Verkaufen"), "action": _sell_stone, "enabled": have > 0, "detail": detail, "compare": compare},
		] if _shop_page == "verkaufen" else [
			{"key": "one", "id": STONE, "name": Lang.t("1 Steinblock"), "price": Lang.t("%d Gold") % price, "price_ok": game.coins >= price,
					"action": _buy_stones.bind(1), "enabled": room > 0 and game.coins >= price, "detail": detail, "compare": compare},
			{"key": "all", "id": STONE, "name": Lang.t("%d Steinblöcke") % maxi(all, 1), "price": Lang.t("%d Gold") % (maxi(all, 1) * price),
					"price_ok": all > 0, "action": _buy_stones.bind(all), "enabled": all > 0, "detail": detail, "compare": compare},
		]},
	], _stonemason_tabs())


func _buy_stones(count: int) -> void:
	var p: Player = game.player
	var price: int = game.trader_price(Items.ALL[STONE].price)
	var bought := 0
	for i in count:
		if game.coins < price or p.bag.size() >= p.bag_size():
			break
		game.coins -= price
		p.bag.append(STONE)
		bought += 1
	if bought > 0:
		Events.bus().traded.emit(game.trader_role)
		_note = Lang.t("Gekauft: %d Steinblöcke") % bought
		Sfx.play(game, "gear_soft_0", -2.0)
	elif p.bag.size() >= p.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	game._update_hud()
	_rebuild()


func _sell_stone() -> void:
	var p: Player = game.player
	if p.bag.has(STONE):
		p.bag.erase(STONE)
		game.coins += sell_price(STONE)
		_note = Lang.t("Verkauft: %s für %d Gold") % [Items.item_name(STONE), sell_price(STONE)]
	game._update_hud()
	_rebuild()


# --- Home upgrades (see HomeUpgrades) ----------------------------------------

## The stonemason's buy and sell tabs, and the way to the house upgrades for
## a hero who has a town house.
func _stonemason_tabs() -> HBoxContainer:
	var tabs := _shop_pages()
	if Homes.house_of(game.hero_name) > 0:
		var b := _item_button(Lang.t("Haus ausbauen"), open.bind("ausbau"))
		b.custom_minimum_size = Vector2(200, 40)
		tabs.add_child(b)
	return tabs


func _add_upgrade_button() -> void:
	var b: Button = game._make_button(Lang.t("Haus ausbauen"), open.bind("ausbau"))
	b.custom_minimum_size = Vector2(300, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(b)


## Hagen builds onto the hero's house: stone blocks and gold for each upgrade.
func _build_upgrades() -> void:
	var p: Player = game.player
	Events.teach(HomeUpgrades.LEARN)
	_add_label(Lang.t("Haus ausbauen"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Dein Gold: %d      Steinblöcke in Tasche und Truhe: %d") % [game.coins, HomeUpgrades.stones_owned(p.bag, game.storage)], 20, game.GOLD)
	_add_label(Lang.t("Steinmetz Hagen baut dir an, was du bezahlst. Steinblöcke verkauft er auch."), 16, BLUE)
	for id in HomeUpgrades.ALL:
		var up: Dictionary = HomeUpgrades.ALL[id]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		_box.add_child(row)
		var text: Label = game._make_label(game.TEXT_FONT, 16, Color.WHITE)
		text.text = Lang.t(up.name) + "\n" + Lang.t(up.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(560, 0)
		row.add_child(text)
		var built := HomeUpgrades.has(game.home_upgrades, id)
		var label := Lang.t("Gebaut") if built else Lang.t("Bauen\n%d Steine, %d Gold") % [up.stones, up.gold]
		var ok := HomeUpgrades.why_not(id, game.home_upgrades, p.bag, game.storage, game.coins) == ""
		var b := _item_button(label, _build_upgrade.bind(id), ok)
		b.custom_minimum_size = Vector2(200, 58)
		row.add_child(b)


func _build_upgrade(id: String) -> void:
	var why: String = game.build_home_upgrade(id)
	if why == "":
		_note = Lang.t("Gebaut: %s. Du findest es in deinem Haus.") % Lang.t(HomeUpgrades.ALL[id].name)
		Sfx.play(game, "gear_soft_0", -2.0)
	else:
		_note = why
	game._update_hud()
	_rebuild()


# --- Bounty board ------------------------------------------------------------

## The bounty board on the village square: today's hunts, each with a
## button to take it on, how far along it is, or to collect the bounty.
func _build_bounty_board() -> void:
	var b: Bounties = game.bounties
	b.refresh(game.day)
	Events.teach(Bounties.HOW_TO)
	_add_label(Lang.t("Aushang: Kopfgelder"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Tag %d. Neue Aushänge gibt es jeden Morgen; was bis dahin nicht erledigt ist, verfällt.") % (game.day + 1), 16, BLUE)
	_add_label(Lang.t("Dein Gold: %d") % game.coins, 20, game.GOLD)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(list)
	for id in b.board_entries():
		var hunt: Dictionary = Bounties.POOL[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var text: Label = game._make_label(game.TEXT_FONT, 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(520, 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.text = Lang.t(hunt.title) + "  ·  " + Lang.t("%d Gold") % hunt.gold + "\n" + Lang.t(hunt.goal)
		row.add_child(text)
		var button: Button
		if b.is_paid(id):
			text.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
			button = _item_button(Lang.t("Abgeholt"), func(): pass, false)
		elif b.is_ready(id):
			text.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
			button = _item_button(Lang.t("Kopfgeld abholen\n+%d Gold") % hunt.gold, _claim_bounty.bind(id))
		elif b.is_taken(id):
			button = _item_button(Lang.t("Auf der Jagd\n%s") % b.progress(id), func(): pass, false)
		else:
			button = _item_button(Lang.t("Jagd annehmen"), _take_bounty.bind(id))
		button.custom_minimum_size = Vector2(190, 54)
		row.add_child(button)


# --- Wishes and fighting style (see Wishes) ---------------------------------

## The villager with this role letter on the current level, or null.
func _villager_of(role: String) -> Villager:
	if game.level == null or not ("villagers" in game.level):
		return null
	for v in game.level.villagers:
		if is_instance_valid(v) and v.role == role:
			return v
	return null


## Ragna asks how the hero likes to face monsters: one button per style.
func _build_style() -> void:
	var w: Wishes = game.wishes
	_add_label(Lang.t("Wie kämpfst du am liebsten?"), 38, game.GOLD, game.TITLE_FONT)
	var about := _add_label(Lang.t("%s will wissen, wie du dich den Monstern stellst. Danach richtet sie ihre Ratschläge.") % Quests.villager_name(Wishes.STYLE_ASKER), 16, BLUE)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 700
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(grid)
	for id in Wishes.STYLES:
		var b: Button = game._make_button(Lang.t(Wishes.STYLES[id].name), _choose_style.bind(id))
		b.custom_minimum_size = Vector2(220, 60)
		b.add_theme_font_size_override("font_size", 18)
		if id == w.style:
			# The style named before: marked by a word too, not only by colour.
			b.text = Lang.t(Wishes.STYLES[id].name) + "  ✓"
			b.modulate = Color(1.0, 0.9, 0.6)
		grid.add_child(b)
	var later := _add_label(Lang.t("Du kannst es dir später bei ihr anders überlegen."), 16, Color(0.75, 0.72, 0.68))
	later.custom_minimum_size.y = 26


func _choose_style(id: String) -> void:
	if not game.wishes.choose_style(id):
		return
	Sfx.play(game, "key", -6.0)
	var v := _villager_of(Wishes.STYLE_ASKER)
	if v != null:
		v.say(Lang.t(Wishes.STYLES[id].say), game.player.global_position)
	game.refresh_quest_marks()
	if _style_from_wishes:
		_style_from_wishes = false
		wish_master = Wishes.STYLE_ASKER
		open("wunsch")
	else:
		close()


## The fixed size of the list of wishes in a master's wish window.
const WISH_LIST_SIZE := Vector2(760, 330)


## A master's wish window: what they offer to help with, best fit first, and
## (at the master who asks it) the hero's fighting style.
func _build_wishes() -> void:
	var w: Wishes = game.wishes
	var role := wish_master
	_add_label(Lang.t("Wünsche"), 38, game.GOLD, game.TITLE_FONT)
	var master := _add_label(Quests.villager_name(role) + ": " + Lang.t("„%s“") % Lang.t(Wishes.MASTERS.get(role, {}).get("ask", "")), 16, BLUE)
	master.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	master.custom_minimum_size.x = 720
	if role == Wishes.STYLE_ASKER:
		var style_row := HBoxContainer.new()
		style_row.alignment = BoxContainer.ALIGNMENT_CENTER
		style_row.add_theme_constant_override("separation", 12)
		_box.add_child(style_row)
		var style_label: Label = game._make_label(game.TEXT_FONT, 18, game.GOLD)
		style_label.text = Lang.t("Dein Kampfstil: %s") % (Lang.t(Wishes.STYLES[w.style].name) if w.style != "" else Lang.t("noch nicht genannt"))
		style_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		style_row.add_child(style_label)
		var change := _item_button(Lang.t("Ändern"), func():
			_style_from_wishes = true
			open("kampfstil"))
		change.custom_minimum_size = Vector2(120, 44)
		style_row.add_child(change)
	# The wishes scroll in a region of fixed size, so the window keeps its
	# frame however many there are.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = WISH_LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var open_wishes: Array = w.open_wishes(role)
	if open_wishes.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16, Color(0.75, 0.72, 0.68))
		none.text = Lang.t("Im Moment weiß sie nichts mehr für dich.")
		list.add_child(none)
	for id in open_wishes:
		var wish: Dictionary = Wishes.ALL[id]
		var quest: Dictionary = Quests.ALL[wish.quest]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)
		var text: Label = game._make_label(game.TEXT_FONT, 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(540, 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var first := Lang.t(wish.wish)
		if w.is_best_fit(id):
			# Marked by words and a star, not by colour alone.
			first = "★ " + first + "  ·  " + Lang.t("passt zu deinem Stil")
			text.add_theme_color_override("font_color", game.GOLD)
		text.text = first + "\n" + Lang.t(quest.goal) + "\n" + Lang.t("Belohnung: %s") % Quests.reward_text(wish.quest)
		row.add_child(text)
		var button := _item_button(Lang.t("Darum bitten"), _ask_wish.bind(id))
		button.custom_minimum_size = Vector2(170, 54)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)


func _ask_wish(id: String) -> void:
	var v := _villager_of(Wishes.ALL[id].master)
	if v == null:
		return
	var why: String = game.wishes.ask(id, v)
	if why != "":
		_note = why
		_rebuild()
		return
	Sfx.play(game, "key", -6.0)
	game.refresh_quest_marks()
	close()


func _take_bounty(id: String) -> void:
	if game.bounties.take(id):
		_note = Lang.t("Neue Jagd: %s") % Lang.t(Bounties.POOL[id].title)
		Sfx.play(game, "key", -6.0)
	_rebuild()


func _claim_bounty(id: String) -> void:
	var gold: int = game.bounties.claim(id)
	if gold > 0:
		game.coins += gold
		Sfx.play_coins(game, gold)
		_note = Lang.t("Kopfgeld erhalten: %d Gold") % gold
	game._update_hud()
	_rebuild()


## The workbench at home: knives from iron, and mending for iron.
func _build_workbench() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Werkbank"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Eisenbarren: %d      Wurfmesser: %d") % [game.iron, p.knives], 20, game.GOLD)
	_add_label(Lang.t("Eisenbarren gibt es bei Schmied Gorm, oder du schmilzt dort alte Ausrüstung ein."), 16, BLUE)
	var make := _item_button(Lang.t("%d Wurfmesser schmieden\n%d Eisenbarren") % [HomeUpgrades.KNIVES_PER_IRON, 1], _make_knives, game.iron >= 1)
	make.custom_minimum_size = Vector2(320, 58)
	make.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(make)
	var worn := Forge.worn_down(p)
	if worn.is_empty():
		_add_label(Lang.t("Nichts ist abgenutzt."), 16)
		return
	_add_label(Lang.t("Abgenutzte Ausrüstung flicken (je %d Eisenbarren):") % HomeUpgrades.MEND_IRON, 16)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	for id in worn:
		row.add_child(_item_button(Items.item_name(id), _mend_at_home.bind(id), game.iron >= HomeUpgrades.MEND_IRON, id))


func _make_knives() -> void:
	if game.iron < 1:
		_note = Lang.t("Dafür brauchst du einen Eisenbarren.")
	else:
		game.iron -= 1
		game.player.knives += HomeUpgrades.KNIVES_PER_IRON
		_note = Lang.t("Geschmiedet: %d Wurfmesser") % HomeUpgrades.KNIVES_PER_IRON
		Sfx.play(game, "gear_metal_0", -2.0)
	game._update_hud()
	_rebuild()


func _mend_at_home(id: String) -> void:
	if game.iron < HomeUpgrades.MEND_IRON:
		_note = Lang.t("Dafür brauchst du einen Eisenbarren.")
	else:
		game.iron -= HomeUpgrades.MEND_IRON
		game.player.wear.erase(id)
		_note = Lang.t("Geflickt: %s") % Items.item_name(id)
		Sfx.play(game, "gear_soft_0", -2.0)
	game._update_hud()
	_rebuild()


## The trophy wall: what the hero has felled, and what is still out there.
func _build_trophies() -> void:
	_add_label(Lang.t("Trophäenwand"), 38, game.GOLD, game.TITLE_FONT)
	var won := HomeUpgrades.trophies_shown(game.trophies)
	_add_label(Lang.t("Jede Trophäe gibt dir +%d Leben. Zusammen: +%d Leben.") % [HomeUpgrades.TROPHY_HP, HomeUpgrades.trophy_hp(game.home_upgrades, game.trophies)], 20, game.GOLD)
	# Every trophy names what wins it; the ones won are struck through in
	# green with the word "won", so colour is never the only cue.
	for kind in HomeUpgrades.TROPHIES:
		var line := Lang.t("%s: %s") % [Lang.t(HomeUpgrades.TROPHIES[kind]), Lang.t(HomeUpgrades.TROPHY_HINTS[kind])]
		if won.has(kind):
			var row := _done_label(line, 18, TradeWindow.GREEN, 700, Lang.t("erbeutet"), true)
			row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_box.add_child(row)
		else:
			_add_label(line, 18)


# --- Smith -------------------------------------------------------------------

## The smith's window shows one of four tabs: "waffen" (buy Gorm's own
## weapons), "schmieden" (forge new gear),
## "einschmelzen" (melt gear down into iron) or "ausbessern" (mend worn gear).
var _forge_tab := "waffen"
const FORGE_ABOUT := {
	"waffen": "Gorms eigene Arbeit: bessere Waffen, die es sonst nirgends gibt. Kriegshammer und Drachenschild schmiedet er nur aus deinem Eisen.",
	"schmieden": "Aus Eisen und etwas Gold schmiedet Gorm dir neue Waffen, Schilde und Rüstungen.",
	"einschmelzen": "Metall aus deiner Tasche wird zu Eisenbarren. Stoff, Leder, Fell und Knochen schmelzen nicht.",
	"ausbessern": "Gorm hämmert Beulen aus: jeder Punkt Haltbarkeit kostet etwas Gold.",
}
const FORGE_TABS := [["waffen", "Waffen kaufen"], ["schmieden", "Schmieden"], ["einschmelzen", "Einschmelzen"], ["ausbessern", "Ausbessern"]]


func _build_smithy() -> void:
	var p: Player = game.player
	Events.teach(Forge.LEARN)
	_add_label(Lang.t("Schmiede"), 38, game.GOLD, game.TITLE_FONT)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for tab in FORGE_TABS:
		var b := _item_button(Lang.t(tab[1]), _show_forge_tab.bind(tab[0]))
		b.custom_minimum_size = Vector2(150, 40)
		if tab[0] == _forge_tab:
			b.modulate = Color(0.7, 1.0, 0.7)
		tabs.add_child(b)
	var room: bool = p.bag.size() < p.bag_size()
	var sections := []
	match _forge_tab:
		"waffen":
			var weapons := []
			var armour := []
			for id in Forge.wares():
				var entry := _ware_entry(id, id, Forge.ware_price(game, id), _buy_ware.bind(id))
				(weapons if Items.ALL[id].slot == "waffe" else armour).append(entry)
			sections = [{"key": "weapons", "title": Lang.t("Waffen"), "icon": "kind:sword", "entries": weapons}]
			# Gorm sells no shield or armour of his own at the moment: then
			# the category is left out rather than shown empty.
			if not armour.is_empty():
				sections.append({"key": "shields", "title": Lang.t("Schilde und Rüstung"), "icon": "kind:shield", "entries": armour})
		"schmieden":
			var forged := []
			for id in Forge.recipes():
				var cost := Forge.forge_cost(id, game)
				var ok: bool = game.iron >= cost.iron and game.coins >= cost.gold
				forged.append({"key": id, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Eisen, %d Gold") % [cost.iron, cost.gold],
						"price_ok": ok, "button": Lang.t("Schmieden"), "action": _forge.bind(id), "enabled": ok and room})
			var iron := []
			for count in [1, 5]:
				var price: int = count * Forge.iron_price(game)
				iron.append({"key": "iron%d" % count, "icon": "kind:iron", "name": Lang.t("%d Eisenbarren") % count, "price": Lang.t("%d Gold") % price,
						"price_ok": game.coins >= price, "action": _buy_iron.bind(count), "enabled": game.coins >= price,
						"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t("Aus Eisen und etwas Gold schmiedet Gorm dir neue Waffen, Schilde und Rüstungen."), TradeWindow.BLUE]]},
						"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("Eisen: %d") % game.iron, "icon": "kind:iron"}})
			sections = [
				{"key": "forge", "title": Lang.t("Schmieden"), "icon": "kind:hammer_anvil", "entries": forged},
				{"key": "iron", "title": Lang.t("Eisenbarren"), "icon": "kind:iron", "entries": iron},
			]
		"einschmelzen":
			var melt := []
			for id in _kinds(p.bag):
				var can := Forge.can_melt(id)
				melt.append({"key": "melt:" + id, "id": id, "name": Items.item_name(id), "price": Lang.t("+%d Eisen") % Forge.melt_yield(id) if can else Lang.t("Schmilzt nicht"), "price_ok": can,
						"button": Lang.t("Einschmelzen"), "action": _melt.bind(p.bag.find(id)), "enabled": can, "count": p.bag.count(id)})
			sections = [{"key": "melt", "title": Lang.t("Einschmelzen"), "icon": "kind:flame", "entries": melt,
					"empty": Lang.t("Deine Tasche ist leer."), "gone": Lang.t("Eingeschmolzen")}]
		"ausbessern":
			var mend := []
			for id in Forge.worn_down(p):
				var durability: int = Items.ALL[id].durability
				var left: int = durability - int(p.wear[id])
				mend.append({"key": id, "id": id, "name": "%s  %d / %d" % [Items.item_name(id), left, durability],
						"price": Lang.t("%d Gold") % Forge.mend_cost(p, id, game), "price_ok": game.coins >= Forge.mend_price(id, game),
						"button": Lang.t("Ausbessern"), "action": _mend.bind(id), "enabled": game.coins >= Forge.mend_price(id, game)})
			sections = [{"key": "mend", "title": Lang.t("Ausbessern"), "icon": "kind:hammer_anvil", "entries": mend, "gone": Lang.t("Wie neu"),
					"empty": Lang.t("Deine Ausrüstung ist heil.")}]
	_trade(Lang.t("Dein Gold: %d    Eisen: %d") % [game.coins, game.iron], sections, tabs, Lang.t(FORGE_ABOUT[_forge_tab]))


func _show_forge_tab(tab: String) -> void:
	_forge_tab = tab
	trade.reset()
	_note = ""
	_rebuild()


func _forge(id: String) -> void:
	var why := Forge.forge(game, id)
	_note = why if why != "" else Lang.t("Geschmiedet: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
		Events.bus().traded.emit(game.trader_role)
		Sfx.play(game, "hit")
	game._update_hud()
	_rebuild()


func _melt(index: int) -> void:
	var id: String = game.player.bag[index]
	var why := Forge.melt(game, index)
	_note = why if why != "" else Lang.t("Eingeschmolzen: %s, +%d Eisen") % [Items.item_name(id), Forge.melt_yield(id)]
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game.player.refresh_stats()
	game._update_hud()
	_rebuild()


func _mend(id: String) -> void:
	var why := Forge.mend(game, id)
	if why == "":
		Events.bus().traded.emit(game.trader_role)
	var p: Player = game.player
	var durability: int = Items.ALL[id].durability
	_note = why if why != "" else Lang.t("Ausgebessert: %s, Haltbarkeit %d / %d") % [Items.item_name(id), durability - int(p.wear.get(id, 0)), durability]
	if why == "":
		Sfx.play(game, "hit")
	game._update_hud()
	_rebuild()


func _buy_ware(id: String) -> void:
	var why := Forge.buy(game, id)
	if why == "":
		Events.bus().traded.emit(game.trader_role)
	_note = why if why != "" else Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _buy_iron(count: int) -> void:
	var why := Forge.buy_iron(game, count)
	if why == "":
		Events.bus().traded.emit(game.trader_role)
	_note = why if why != "" else Lang.t("Gekauft: %d Eisenbarren") % count
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


# --- Barber -----------------------------------------------------------------

## What the barber offers: id, name, price in gold (see HairLook).
const BARBER_STYLES := [["natural", "Natürlich", 5], ["mohawk", "Irokese", 15], ["bald", "Glatze", 10]]
const BARBER_COLORS := [["natural", "Naturfarbe", 5], ["black", "Schwarz", 10], ["blond", "Blond", 10],
		["silver", "Silber", 10], ["red", "Rot", 10], ["green", "Grün", 10], ["blue", "Blau", 10],
		["pink", "Pink", 10], ["purple", "Lila", 10], ["rainbow", "Regenbogen", 25], ["fire", "Feuer", 30]]
const TATTOO_PRICE := 20
const TATTOO_REMOVE_PRICE := 10
## The word the player is typing for a tattoo and its shape, kept while the
## menu rebuilds.
var _tattoo_word := ""
var _tattoo_shape := ""


func _build_barber() -> void:
	var p: Player = game.player
	if _tattoo_word == "":
		_tattoo_word = p.hair.tattoo if p.hair.tattoo != "" else "Pig!"
	if _tattoo_shape == "":
		_tattoo_shape = p.hair.get("tattoo_shape", "straight")
	_add_label(Lang.t("Barbier"), 38, game.GOLD, game.TITLE_FONT)
	var ink: int = game.trader_price(TATTOO_PRICE)
	var remove: int = game.trader_price(TATTOO_REMOVE_PRICE)
	var tattoo := Lang.t("Tätowierung: %s") % p.hair.tattoo if p.hair.tattoo != "" else Lang.t("Keine Tätowierung")
	var ink_detail := {"subtitle": Lang.t("Tätowierung"), "lines": [
			[Lang.t("Tätowierung an der rechten Kopfseite (nur auf geschorenem Kopf zu sehen)"), TradeWindow.BLUE],
			[Lang.t("Wort: %s") % _tattoo_word, Color.WHITE]]}
	var ink_compare := {"title": Lang.t("Derzeit"), "name": tattoo, "icon": "kind:needle", "subtitle": Lang.t("Tätowierung")}
	_trade(Lang.t("Dein Gold: %d") % game.coins, [
		{"key": "style", "title": Lang.t("Frisur"), "icon": "kind:scissors", "entries": _barber_entries(BARBER_STYLES, "style")},
		{"key": "color", "title": Lang.t("Farbe"), "icon": "kind:hair:fire", "entries": _barber_entries(BARBER_COLORS, "color")},
		{"key": "tattoo", "title": Lang.t("Tätowierung"), "icon": "kind:needle", "extra": _tattoo_editor, "entries": [
			{"key": "ink", "icon": "kind:needle", "name": Lang.t("Stechen"), "price": Lang.t("%d Gold") % ink,
					"price_ok": game.coins >= ink, "button": Lang.t("Stechen"), "action": _ink_tattoo,
					"enabled": game.coins >= ink, "detail": ink_detail, "compare": ink_compare},
			{"key": "remove", "icon": "kind:needle", "name": Lang.t("Entfernen"), "price": Lang.t("%d Gold") % remove,
					"price_ok": game.coins >= remove, "button": Lang.t("Entfernen"), "action": _remove_tattoo,
					"enabled": p.hair.tattoo != "" and game.coins >= remove,
					"detail": {"subtitle": Lang.t("Tätowierung"), "lines": [[Lang.t("Die Tätowierung ist weg."), TradeWindow.BLUE]]}, "compare": ink_compare},
		]},
	])


## The word to ink and its shape, above the tattoo rows.
func _tattoo_editor() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var edit := LineEdit.new()
	edit.max_length = HairLook.TATTOO_MAX
	edit.text = _tattoo_word
	edit.placeholder_text = Lang.t("Ein Wort")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(220, 44)
	edit.add_theme_font_override("font", game.TEXT_FONT)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_stylebox_override("normal", panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	edit.add_theme_stylebox_override("focus", panel_style(game.GOLD))
	for style in ["normal", "focus"]:
		edit.get_theme_stylebox(style).set_content_margin_all(8)
	edit.text_changed.connect(func(t): _tattoo_word = t)
	edit.text_submitted.connect(func(_t): _ink_tattoo())
	row.add_child(edit)
	for shape in [["straight", "Gerade"], ["arch", "Im Halbkreis"]]:
		var chosen: bool = _tattoo_shape == shape[0]
		var b := _item_button(Lang.t(shape[1]), _pick_tattoo_shape.bind(shape[0]), not chosen)
		b.custom_minimum_size = Vector2(130, 44)
		if chosen:
			b.modulate = Color(0.7, 1.0, 0.7)
		row.add_child(b)
	return row


## One row per choice; what the hero has now is marked and cannot be bought again.
func _barber_entries(choices: Array, field: String) -> Array:
	var p: Player = game.player
	var now := ""
	for c in choices:
		if p.hair[field] == c[0]:
			now = c[1]
	var kind := Lang.t("Frisur") if field == "style" else Lang.t("Haarfarbe")
	var compare := {"title": Lang.t("Derzeit"), "name": Lang.t(now), "subtitle": kind,
			"icon": "kind:scissors" if field == "style" else "kind:hair:" + String(p.hair.color)}
	var entries := []
	for c in choices:
		var current: bool = p.hair[field] == c[0]
		var price: int = game.trader_price(c[2])
		var line := Lang.t("Sieht man nur ohne Hut.") if field == "style" else Lang.t("Färbt dein Haar.")
		entries.append({"key": field + ":" + c[0], "icon": "kind:scissors" if field == "style" else "kind:hair:" + String(c[0]), "name": Lang.t(c[1]),
				"price": Lang.t("%d Gold") % price, "price_ok": game.coins >= price, "action": _restyle.bind(field, c[0], price),
				"enabled": game.coins >= price, "current": current,
				"detail": {"subtitle": kind, "lines": [[line, TradeWindow.BLUE]]}, "compare": compare})
	return entries


func _restyle(field: String, id: String, price: int) -> void:
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
		_rebuild()
		return
	game.coins -= price
	Events.bus().traded.emit(game.trader_role)
	var look: Dictionary = game.player.hair.duplicate()
	look[field] = id
	game.player.set_hair(look)
	Sfx.play(game, "coin")
	_note = Lang.t("Schnipp, schnapp! Steht dir gut.")
	if field == "style" and id != "natural" and look.tattoo != "":
		_note = Lang.t("Schnipp, schnapp! Jetzt sieht man auch deine Tätowierung.")
	_rebuild()


func _pick_tattoo_shape(shape: String) -> void:
	_tattoo_shape = shape
	_note = ""
	_rebuild()


func _ink_tattoo() -> void:
	var word := _tattoo_word.strip_edges()
	if word == "":
		_note = Lang.t("Sag mir erst, welches Wort ich stechen soll.")
	elif game.coins < game.trader_price(TATTOO_PRICE):
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	else:
		game.coins -= game.trader_price(TATTOO_PRICE)
		Events.bus().traded.emit(game.trader_role)
		var look: Dictionary = game.player.hair.duplicate()
		look.tattoo = word
		look.tattoo_shape = _tattoo_shape
		game.player.set_hair(look)
		Sfx.play(game, "coin")
		_note = Lang.t("Gestochen: %s") % word
		if look.style == "natural":
			_note += " " + Lang.t("Unter deinen Haaren sieht man sie erst, wenn du dir den Kopf scheren lässt.")
	_rebuild()


func _remove_tattoo() -> void:
	if game.coins < game.trader_price(TATTOO_REMOVE_PRICE):
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	else:
		game.coins -= game.trader_price(TATTOO_REMOVE_PRICE)
		var look: Dictionary = game.player.hair.duplicate()
		look.tattoo = ""
		game.player.set_hair(look)
		_note = Lang.t("Die Tätowierung ist weg.")
	_rebuild()


# --- Bed --------------------------------------------------------------------

## Every saved game, one per hero, the one saved last on top. In the middle
## of a run it warns first that the run so far is lost. A saved game can be
## deleted too, after a second click to make sure.
func _build_load() -> void:
	_add_label(Lang.t("Spielstand laden"), 38, game.GOLD, game.TITLE_FONT)
	var saves: Array = game.save_list()
	var playing: bool = game.state == game.State.PLAYING
	if saves.is_empty():
		_add_label(Lang.t("Es gibt noch keinen Spielstand. Gespeichert wird beim Betreten der Zuflucht und in ihrem Bett."), 20)
	elif playing:
		_add_label(Lang.t("Was du seitdem erlebt hast, geht verloren."), 20, Color(1.0, 0.75, 0.5))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for info in saves:
		list.add_child(_save_row(info, playing))
	if saves.size() > LOAD_ROWS_SHOWN:
		# Many heroes: the list scrolls.
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, LOAD_ROWS_SHOWN * 70)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		_box.add_child(scroll)
	elif not saves.is_empty():
		_box.add_child(list)
	if _note != "":
		_add_label(_note, 16, Color(1.0, 0.75, 0.5))
		_note = ""
	var cancel: Button = game._make_button(Lang.t("Abbrechen"), func():
		_delete_asked = ""
		close())
	cancel.custom_minimum_size = Vector2(220, 60)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(cancel)


## One line of the load window: who, where, with how much gold and when,
## then the buttons to load or delete it.
func _save_row(info: Dictionary, playing: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(420, 0)
	row.add_child(text)
	var where: Label = game._make_label(game.TEXT_FONT, 22)
	where.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if info.home:
		where.text = Lang.t("%s zu Hause mit %d Gold.") % [info.name, info.coins]
	elif info.escaped:
		where.text = Lang.t("%s auf dem Friedhof mit %d Gold.") % [info.name, info.coins]
	else:
		where.text = Lang.t("%s auf Ebene %d mit %d Gold.") % [info.name, info.level, info.coins]
	if playing and info.name == game.hero_name:
		where.add_theme_color_override("font_color", game.GOLD)
	text.add_child(where)
	var when: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	when.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	when.text = Lang.t("Gespeichert: %s") % game.save_time_text(info.time)
	text.add_child(when)
	var path: String = info.path
	var load_button: Button = game._make_button(Lang.t("Laden"), func():
		_delete_asked = ""
		if playing:
			close()
			game.load_saved_game(path)
		else:
			# Leaving the title closes the window by itself.
			game.continue_game(path))
	load_button.custom_minimum_size = Vector2(150, 56)
	row.add_child(load_button)
	var asked := _delete_asked == path
	var delete_button: Button = game._make_button(Lang.t("Wirklich?") if asked else Lang.t("Löschen"), func():
		if _delete_asked == path:
			_delete_asked = ""
			game.delete_save(path)
			_note = Lang.t("Spielstand von %s gelöscht.") % info.name
		else:
			_delete_asked = path
		_rebuild())
	delete_button.custom_minimum_size = Vector2(150, 56)
	if asked:
		delete_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	row.add_child(delete_button)
	return row


## Every control on one side, everything the hero has been told on the
## other; a second page holds the villagers' tasks (the quest log).
func _build_compendium() -> void:
	_add_label(Lang.t("Kompendium"), 38, game.GOLD, game.TITLE_FONT)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	_box.add_child(tabs)
	var open_tasks := 0
	for id in Quests.ALL:
		if game.quests.is_active(id):
			open_tasks += 1
	open_tasks += game.bounties.taken.size()
	var tabs_shown := [["wissen", Lang.t("Steuerung und Gelerntes")], ["auftraege", Lang.t("Aufträge (%d offen)") % open_tasks], ["ruf", Lang.t("Ruf")]]
	# The recipes get a page of their own once the first one is found.
	if not game.crafting.entries().is_empty():
		tabs_shown.append(["rezepte", Lang.t("Rezeptbuch (%d)") % game.crafting.entries().size()])
	elif compendium_page == "rezepte":
		compendium_page = "wissen"
	for tab in tabs_shown:
		var b := _item_button(tab[1], func():
			compendium_page = tab[0]
			_rebuild())
		b.custom_minimum_size = Vector2(240, 44)
		if compendium_page == tab[0]:
			b.modulate = Color(1.0, 0.9, 0.6)
		else:
			b.modulate = Color(0.75, 0.75, 0.8)
		tabs.add_child(b)
	if compendium_page == "auftraege":
		_build_quest_log()
		return
	if compendium_page == "rezepte":
		_build_recipes()
		return
	if compendium_page == "ruf":
		_build_reputation_page()
		return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	_box.add_child(columns)

	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 4)
	columns.add_child(keys)
	var keys_title: Label = game._make_label(game.TEXT_FONT, 24, game.GOLD)
	keys_title.text = Lang.t("Steuerung")
	keys.add_child(keys_title)
	# The list of keys is longer than the screen is tall, so it scrolls in a
	# region as high as the one for what was learned beside it.
	var keys_scroll := ScrollContainer.new()
	keys_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	keys_scroll.custom_minimum_size.y = 380
	keys.add_child(keys_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	keys_scroll.add_child(grid)
	for s in SHORTCUTS:
		var what: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		what.text = Lang.t(s[0])
		what.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		# Long names wrap, so the explanations beside them get the room.
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.custom_minimum_size.x = 160
		grid.add_child(what)
		var how: Label = game._make_label(game.TEXT_FONT, 16)
		how.text = Lang.t(s[1])
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size.x = 330
		grid.add_child(how)

	var learned := VBoxContainer.new()
	learned.add_theme_constant_override("separation", 4)
	columns.add_child(learned)
	var learned_title: Label = game._make_label(game.TEXT_FONT, 24, game.GOLD)
	learned_title.text = Lang.t("Gelerntes")
	learned.add_child(learned_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	learned.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	if game.lore.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16)
		none.text = Lang.t("Noch nichts. Hinweise und Erklärungen sammeln sich hier.")
		list.add_child(none)
	# Newest first: the latest hint or explanation sits at the top.
	for i in range(game.lore.size() - 1, -1, -1):
		var entry: String = game.lore[i]
		var l: Label = game._make_label(game.TEXT_FONT, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 410
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry.begins_with("#"):
			var index := int(entry.substr(1))
			var info: Dictionary = game.level_hint(index)
			l.text = Lang.t("Ebene %d: %s") % [index + 1, Lang.t(info.name)] + "\n" + Lang.t(info.hint)
			l.add_theme_color_override("font_color", game.GOLD)
		else:
			l.text = Lang.t(entry)
		list.add_child(l)


## The recipe and ingredient book: every recipe found, its scroll with the
## faded lines still to find out, the ingredients gathered and the craft it
## needs; then every ingredient those recipes name, with where and when it
## is found, what yields it and how many are in the pouch.
func _build_recipes() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	_box.add_child(columns)
	var recipes := _book_column(columns, Lang.t("Rezepte"))
	for id in game.crafting.entries():
		var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
		title.text = Lang.t(Crafting.RECIPES[id].name)
		recipes.add_child(title)
		var text: Label = game._make_label(game.TEXT_FONT, 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = BOOK_COLUMN - 20
		text.text = game.crafting.describe(id)
		recipes.add_child(text)
	var ingredients := _book_column(columns, Lang.t("Zutaten"))
	for ingredient in game.crafting.book_ingredients():
		var entry: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.custom_minimum_size.x = BOOK_COLUMN - 20
		entry.text = game.crafting.describe_ingredient(ingredient)
		ingredients.add_child(entry)


## Width of each of the recipe book's two columns.
const BOOK_COLUMN := 470


## One column of the recipe book: a title over a list that scrolls.
func _book_column(columns: HBoxContainer, title_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	columns.add_child(column)
	var title: Label = game._make_label(game.TEXT_FONT, 24, game.GOLD)
	title.text = title_text
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BOOK_COLUMN, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	return list


## The quest log: every task the hero took on, the open ones first, with who
## gave it, what to do, how far along it is and the reward.
func _build_quest_log() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var entries: Array = game.quests.log_entries()
	var hunts: Array = game.bounties.taken.keys()
	for id in hunts:
		var hunt: Dictionary = Bounties.POOL[id]
		var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
		var status: String = Lang.t("erledigt, am Aushang abholen") if game.bounties.is_ready(id) else game.bounties.progress(id)
		title.text = Lang.t("Kopfgeld: %s") % Lang.t(hunt.title) + "  (%s)" % status
		list.add_child(title)
		var text: Label = game._make_label(game.TEXT_FONT, 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 740
		text.text = Lang.t(hunt.goal) + "\n" + Lang.t("Belohnung: %s") % (Lang.t("%d Gold") % hunt.gold)
		list.add_child(text)
	if entries.is_empty() and hunts.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16)
		none.text = Lang.t("Noch keine Aufträge. Sprich mit den Leuten im Dorf: Manche haben Arbeit für dich.")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 740
		list.add_child(none)
	for id in entries:
		var q: Dictionary = Quests.ALL[id]
		var done: bool = game.quests.is_done(id)
		var goal := Lang.t("Von %s: %s") % [Quests.villager_name(q.giver), Lang.t(q.goal)] + "\n" + Lang.t("Belohnung: %s") % Quests.reward_text(id)
		if done:
			# Finished: struck through in green, and the word "done" as well.
			list.add_child(_done_label(Lang.t(q.title), 21, TradeWindow.GREEN, 740, Lang.t("erledigt")))
			list.add_child(_done_label(goal, 16, TradeWindow.GREEN.darkened(0.25), 740))
			continue
		var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
		var status: String = game.quests.progress(id)
		title.text = Lang.t(q.title) + ("  (%s)" % status if status != "" else "")
		list.add_child(title)
		var text: Label = game._make_label(game.TEXT_FONT, 16, Color.WHITE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 740
		text.text = goal
		list.add_child(text)


## The villagers' goodwill: everyone the hero has met, with their standing,
## how far to the next level, the discount, and the secret recipes learned.
func _build_reputation_page() -> void:
	var rep: Reputation = game.reputation
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var intro: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 740
	intro.text = Lang.t("Hilf den Leuten im Dorf, dann denken sie besser von dir. Freundlich: Rabatt und Neuigkeiten. Vertraut: mehr Rabatt, und wer ein Geheimrezept kennt, verrät es dir. Geehrt: der größte Rabatt.") + " " + Lang.t("Hör zu, wenn die Leute miteinander reden: Dann steht hier, wer mit wem verwandt, befreundet oder verfeindet ist.")
	list.add_child(intro)
	var roles: Array = game.met.keys()
	roles.sort_custom(func(a, b): return rep.points(a) > rep.points(b))
	if roles.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16)
		none.text = Lang.t("Du kennst noch niemanden im Dorf.")
		list.add_child(none)
	for role in roles:
		var lvl := rep.level(role)
		var line := Lang.t("%s: %s") % [Quests.villager_name(role), Reputation.level_name(lvl)]
		var off := roundi(Reputation.LEVELS[lvl].discount * 100.0)
		if off > 0:
			line += Lang.t(" (%d%% Rabatt)") % off
		var next := rep.to_next(role)
		if next > 0:
			line += "  " + Lang.t("noch %d bis %s") % [next, Reputation.level_name(lvl + 1)]
		# One villager's lines together: standing, then what they want and
		# who they are tied to (once overheard, see VillageTalk).
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		list.add_child(group)
		var l: Label = game._make_label(game.TEXT_FONT, 16, REPUTATION_COLOR if lvl > 0 else Color.WHITE)
		l.text = line
		group.add_child(l)
		var about := _villager_about(role)
		if about != "":
			var d: Label = game._make_label(game.TEXT_FONT, 16, ABOUT_COLOR)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 740
			d.text = about
			group.add_child(d)
	var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
	title.text = Lang.t("Geheimrezepte")
	list.add_child(title)
	if rep.recipes.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16, Color(0.7, 0.72, 0.76))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 740
		none.text = Lang.t("Noch keine. Manche Leute im Dorf kennen eines, verraten es aber nur, wem sie vertrauen.")
		list.add_child(none)
	for id in rep.recipes:
		var l: Label = game._make_label(game.TEXT_FONT, 16)
		l.text = Lang.t("%s (von %s), im Tagesplan unter „Handwerk“") % [Lang.t(Offline.RECIPES[id].name), Quests.villager_name(Offline.RECIPES[id].secret)]
		list.add_child(l)


## What a villager wants and, for the ties the hero overheard, who they are
## tied to: "Wants ...  ·  Friends: Hanna  ·  Rivals: Hagen".
func _villager_about(role: String) -> String:
	var parts := []
	if VillageTalk.GOALS.has(role):
		parts.append(Lang.t(VillageTalk.GOALS[role]))
	for tie in game.village_talk.known_ties_of(role):
		parts.append(Lang.t("%s: %s") % tie)
	return "  ·  ".join(parts)


func _build_quit() -> void:
	_add_label(Lang.t("Spiel beenden"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Was seit dem letzten Schlaf im Bett geschah, geht verloren."), 20, Color(1.0, 0.75, 0.5))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var quit: Button = game._make_button(Lang.t("Beenden"), func():
		close()
		game.quit_game())
	quit.custom_minimum_size = Vector2(220, 60)
	row.add_child(quit)
	var cancel: Button = game._make_button(Lang.t("Abbrechen"), close)
	cancel.custom_minimum_size = Vector2(220, 60)
	row.add_child(cancel)


## The dragon has fallen: the lair is won. Says so, counts the fallen
## monsters, and offers the way out or a last look round for gold.
func _build_lair_won() -> void:
	_add_label(Lang.t("Höhle bezwungen!"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Der Drache ist tot, und sein Schatz gehört dir."), 22)
	# A fallen monster sinks away and is gone: only the living still count.
	var monsters: Array = game.level.enemies
	var fallen := monsters.filter(func(e): return not is_instance_valid(e) or e.dead).size()
	_add_label(Lang.t("Besiegte Monster: %d von %d") % [fallen, monsters.size()], 20, BLUE)
	var hint := _add_label(Lang.t("Wo der Drache fiel, leuchtet jetzt ein goldener Ausgang. Tritt hinein, und du stehst wieder vor dem Steinbogen im Wald."), 16, Color(1.0, 0.85, 0.55))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = RETURN_TEXT_WIDTH
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var leave: Button = game._make_button(Lang.t("Höhle verlassen"), func():
		close()
		game.leave_lair())
	leave.custom_minimum_size = Vector2(260, 60)
	row.add_child(leave)
	var stay: Button = game._make_button(Lang.t("Bleiben und Beute sammeln"), close)
	stay.custom_minimum_size = Vector2(300, 60)
	row.add_child(stay)


func _build_bed() -> void:
	_add_label(Lang.t("Ein weiches Bett"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Hier kannst du dich ausruhen. Dein Spiel wird gespeichert\nund du loggst dich aus. Später geht es genau hier weiter."), 20)
	_add_label(Lang.t("Solange du weg bist, lebt dein Held nach seinem Tagesplan:"), 20, BLUE)
	_add_label(_plan_summary(), 16, game.GOLD)
	var plan_button: Button = game._make_button(Lang.t("Tagesplan ändern"), open.bind("plan"))
	plan_button.custom_minimum_size = Vector2(300, 56)
	plan_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(plan_button)
	# Only the hero's own town house can be built onto, not the refuge.
	if game.level.is_home:
		_add_upgrade_button()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var sleep: Button = game._make_button(Lang.t("Schlafen und ausloggen"), func():
		close()
		game.sleep())
	sleep.custom_minimum_size = Vector2(300, 60)
	row.add_child(sleep)
	var cancel: Button = game._make_button(Lang.t("Weiter wach bleiben"), close)
	cancel.custom_minimum_size = Vector2(260, 60)
	row.add_child(cancel)


# --- Time away (see Offline) ------------------------------------------------

## The blocks of the day plan, as shown: block, heading.
const PLAN_ROWS := [["job", "Arbeit"], ["train", "Training"], ["study", "Lernen"], ["craft", "Handwerk"], ["rest", "Ruhe"]]


## One line like "Stadtwache 8 Std. · Training Stärke 4 Std. · Ruhe 8 Std.".
func _plan_summary() -> String:
	var plan := Offline.normalized(game.away_plan, game.away_choices())
	var parts := []
	for row in PLAN_ROWS:
		var hours: int = plan[row[0] + "_hours"]
		if hours > 0:
			var what: String = Lang.t(row[1]) if row[0] == "rest" else _choice_name(row[0], plan[row[0]])
			parts.append(Lang.t("%s %d Std.") % [what, hours])
	if Offline.free_hours(plan) > 0:
		parts.append(Lang.t("%s %d Std.") % [Lang.t("Freizeit"), Offline.free_hours(plan)])
	return "  ·  ".join(parts)


func _choice_name(block: String, id: String) -> String:
	if id == "":
		return Lang.t("nichts")
	match block:
		"job":
			return Lang.t("%s (%d Gold/Std.)") % [Lang.t(Offline.JOBS[id].name), Offline.JOBS[id].gold]
		"train":
			return game._training_name(id)
		"study":
			return "%s (%s)" % [Items.item_name(id), Lang.t(Training.SKILLS[Items.ALL[id].teaches].name)]
		"craft":
			return Lang.t(Offline.RECIPES[id].name)
	return id


func _build_plan() -> void:
	var choices: Dictionary = game.away_choices()
	game.away_plan = Offline.normalized(game.away_plan, choices)
	var plan: Dictionary = game.away_plan
	_add_label(Lang.t("Tagesplan"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Je 10 Minuten, die du weg bist, ist für deinen Helden eine Stunde: ein Tag dauert 4 Stunden.\nDein Held lebt diesen Tag immer wieder, höchstens 8 Tage lang (32 Stunden)."), 16, BLUE)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(grid)
	for row in PLAN_ROWS:
		var block: String = row[0]
		var heading: Label = game._make_label(game.TEXT_FONT, 22, game.GOLD)
		heading.text = Lang.t(row[1])
		heading.custom_minimum_size.x = 150
		grid.add_child(heading)
		if block == "rest":
			var sleep_label: Label = game._make_label(game.TEXT_FONT, 16)
			sleep_label.text = Lang.t("Schlafen und heilen (mindestens 8 Std.)")
			sleep_label.custom_minimum_size.x = 420
			grid.add_child(sleep_label)
		else:
			var options: Array = choices[block]
			var text := _choice_name(block, plan[block]) if not options.is_empty() else _no_choice_text(block)
			var pick: Button = game._make_button(text, _cycle_choice.bind(block))
			pick.custom_minimum_size = Vector2(420, 52)
			pick.disabled = options.is_empty()
			grid.add_child(pick)
		var minus: Button = game._make_button("−", _change_hours.bind(block, -1))
		minus.custom_minimum_size = Vector2(52, 52)
		grid.add_child(minus)
		var hours: Label = game._make_label(game.TEXT_FONT, 22)
		hours.text = Lang.t("%d Std.") % plan[block + "_hours"]
		hours.custom_minimum_size.x = 90
		hours.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(hours)
		var plus: Button = game._make_button("+", _change_hours.bind(block, 1))
		plus.custom_minimum_size = Vector2(52, 52)
		grid.add_child(plus)
	_add_label(Lang.t("Freizeit: %d Std.    Arbeit höchstens %d Std. am Tag") % [Offline.free_hours(plan), Offline.JOB_MAX_HOURS], 20)
	if _note != "":
		_add_label(_note, 16, Color(1.0, 0.75, 0.5))
		_note = ""
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_box.add_child(buttons)
	var sleep: Button = game._make_button(Lang.t("Schlafen und ausloggen"), func():
		close()
		game.sleep())
	sleep.custom_minimum_size = Vector2(300, 60)
	buttons.add_child(sleep)
	var back: Button = game._make_button(Lang.t("Zurück"), open.bind("bett"))
	back.custom_minimum_size = Vector2(200, 60)
	buttons.add_child(back)


func _no_choice_text(block: String) -> String:
	match block:
		"study":
			return Lang.t("Kein Buch dabei (Bücher findest du in Truhen und beim Händler)")
		"train":
			return Lang.t("Nichts mehr zu üben")
	return Lang.t("nichts")


## The next choice for a block, then "nothing", then the first again.
func _cycle_choice(block: String) -> void:
	var options: Array = game.away_choices()[block]
	var plan: Dictionary = game.away_plan
	var i := options.find(plan[block])
	if i + 1 < options.size():
		plan[block] = options[i + 1]
	else:
		plan[block] = ""
		plan[block + "_hours"] = 0
	_rebuild()


func _change_hours(block: String, delta: int) -> void:
	var plan: Dictionary = game.away_plan
	var key := block + "_hours"
	if delta > 0:
		if Offline.free_hours(plan) <= 0:
			_note = Lang.t("Der Tag ist voll: nimm erst woanders Stunden weg.")
		elif block == "job" and plan[key] >= Offline.JOB_MAX_HOURS:
			_note = Lang.t("Mehr als %d Stunden am Tag arbeitet niemand.") % Offline.JOB_MAX_HOURS
		else:
			if block != "rest" and plan[block] == "":
				var options: Array = game.away_choices()[block]
				if options.is_empty():
					_rebuild()
					return
				plan[block] = options[0]
			plan[key] += 1
	else:
		var lowest := Offline.REST_HOURS if block == "rest" else 0
		if plan[key] > lowest:
			plan[key] -= 1
		elif block == "rest":
			_note = Lang.t("Dein Held braucht jeden Tag mindestens %d Stunden Ruhe.") % Offline.REST_HOURS
	_rebuild()


func _build_return() -> void:
	_add_label(Lang.t("Willkommen zurück"), 38, game.GOLD, game.TITLE_FONT)
	var lines: Array[String] = game.away_report
	if lines.size() <= 1:
		lines = lines.duplicate()
		lines.append(Lang.t("Dein Held hat in der Zwischenzeit nichts Besonderes getan."))
	for i in lines.size():
		var l := _add_label(lines[i], 22 if i == 0 else 20, BLUE if i == 0 else Color.WHITE)
		# A fixed width lets long lines wrap instead of stretching the window.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = RETURN_TEXT_WIDTH
	var go: Button = game._make_button(Lang.t("Weiter"), close)
	go.custom_minimum_size = Vector2(220, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(go)


# --- Map and journal --------------------------------------------------------

## The hero's map of a level, with its landmarks and finds listed beside it,
## and the journal on a second page (see Journal and MapView).
func _build_map() -> void:
	var journal: Journal = game.journal
	_add_label(Lang.t("Karte und Tagebuch"), 38, game.GOLD, game.TITLE_FONT)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	_box.add_child(tabs)
	for tab in [["karte", Lang.t("Karte")], ["tagebuch", Lang.t("Tagebuch (%d)") % journal.entries.size()]]:
		var b := _item_button(tab[1], func():
			map_page = tab[0]
			_rebuild())
		b.custom_minimum_size = Vector2(220, 44)
		b.modulate = Color(1.0, 0.9, 0.6) if map_page == tab[0] else Color(0.75, 0.75, 0.8)
		tabs.add_child(b)
	# Both pages fill the same fixed frame, so switching tabs never
	# reshapes the window.
	var page := VBoxContainer.new()
	page.custom_minimum_size = MAP_PAGE_SIZE
	page.add_theme_constant_override("separation", 10)
	_box.add_child(page)
	var outer := _box
	_box = page
	if map_page == "tagebuch":
		_build_journal()
	else:
		_build_map_page(journal)
	_box = outer


func _build_map_page(journal: Journal) -> void:
	var files := journal.mapped_files()
	if files.is_empty():
		_add_label(Lang.t("Noch keine Karte. Sie füllt sich, während du erkundest."), 16)
		return
	var here := journal.current_file()
	if not files.has(_map_file):
		_map_file = here if files.has(here) else files[0]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_box.add_child(row)
	var step := func(d: int):
		_map_file = files[posmod(files.find(_map_file) + d, files.size())]
		_rebuild()
	var back := _item_button("<", step.bind(-1), files.size() > 1)
	back.custom_minimum_size = Vector2(52, 44)
	row.add_child(back)
	var title: Label = game._make_label(game.TEXT_FONT, 22, game.GOLD)
	title.text = journal.level_title(_map_file)
	title.custom_minimum_size.x = 420
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	var next := _item_button(">", step.bind(1), files.size() > 1)
	next.custom_minimum_size = Vector2(52, 44)
	row.add_child(next)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	_box.add_child(columns)
	var view := MapView.new()
	view.name = "MapView"
	view.custom_minimum_size = Vector2(660, 360)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _map_file == here and game.player != null:
		var p: Vector3 = game.player.global_position / Level.TILE
		view.hero_at = Vector2(p.x, p.z)
		var f: Vector3 = game.player.facing()
		view.hero_facing = Vector2(f.x, f.z)
	view.setup(journal, _map_file, game.TEXT_FONT)
	columns.add_child(view)
	view.resized.connect(view.queue_redraw)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_theme_constant_override("separation", 3)
	scroll.add_child(legend)
	var places := view.numbered_places()
	_legend_title(legend, Lang.t("Orte"))
	if places.is_empty():
		_legend_line(legend, Color(0, 0, 0, 0), Lang.t("Noch keine entdeckt."))
	for i in places.size():
		_legend_line(legend, Journal.MARK_COLORS.get(places[i].kind, Color.WHITE), "%d  %s" % [i + 1, journal.place_name(places[i])])
	if not journal.secrets.get(_map_file, []).is_empty():
		_legend_line(legend, Journal.MARK_COLORS.secret, Lang.t("Geheimraum"))
	var finds := journal.finds_on(_map_file)
	if not finds.is_empty():
		_legend_title(legend, Lang.t("Funde"))
		# One line per thing, with how many spots and finds in all.
		var by_name := {}
		var kinds := {}
		for f in finds:
			if not by_name.has(f.name):
				by_name[f.name] = [0, 0]
				kinds[f.name] = f.kind
			by_name[f.name][0] += 1
			by_name[f.name][1] += int(f.count)
		for n in by_name:
			var text := Lang.t(n) + "  ×%d" % by_name[n][1]
			if by_name[n][0] > 1:
				text += "  " + Lang.t("(%d Stellen)") % by_name[n][0]
			_legend_line(legend, Journal.find_color(kinds[n]), text)
	_add_label(Lang.t("Erkundet: %d %%") % _explored_share(journal, _map_file), 16, BLUE)


func _legend_title(box: VBoxContainer, text: String) -> void:
	var l: Label = game._make_label(game.TEXT_FONT, 20, game.GOLD)
	l.text = text
	box.add_child(l)


func _legend_line(box: VBoxContainer, color: Color, text: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(dot)
	var l: Label = game._make_label(game.TEXT_FONT, 16)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 240
	line.add_child(l)
	box.add_child(line)


## How much of the ground of a level (everything but walls and forest) the
## hero has seen, in percent.
func _explored_share(journal: Journal, file: String) -> int:
	var info := journal.map_of(file)
	var ground := 0
	var seen := 0
	for y in info.height:
		for x in info.width:
			var c := Vector2i(x, y)
			if Journal.char_at(info, c) == "#":
				continue
			ground += 1
			if journal.is_explored(file, c):
				seen += 1
	return 0 if ground == 0 else roundi(100.0 * seen / ground)


## The journal: tonight's moon at the top (see Moon), then every new place,
## landmark and find, newest first.
func _build_journal() -> void:
	var journal: Journal = game.journal
	var moon: Label = game._make_label(game.TEXT_FONT, 18, MOON_COLOR)
	moon.text = Lang.t("Mond heute Nacht: %s. %s") % [Lang.t(Moon.word(game.day)), Moon.forecast(game.day)]
	moon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Two lines are kept for it in both languages, so the list below
	# always starts at the same height.
	moon.custom_minimum_size = Vector2(MAP_PAGE_SIZE.x - 20, MOON_LINE_HEIGHT)
	_box.add_child(moon)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = MAP_PAGE_SIZE - Vector2(0, MOON_LINE_HEIGHT + 10)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if journal.entries.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16)
		none.text = Lang.t("Noch leer. Was du entdeckst und findest, schreibt dein Held hier auf.")
		list.add_child(none)
	for i in range(journal.entries.size() - 1, -1, -1):
		var lines := journal.entry_text(journal.entries[i])
		var when: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		when.text = lines[0]
		list.add_child(when)
		var what: Label = game._make_label(game.TEXT_FONT, 16)
		what.text = lines[1]
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.custom_minimum_size.x = MAP_PAGE_SIZE.x - 20
		list.add_child(what)
