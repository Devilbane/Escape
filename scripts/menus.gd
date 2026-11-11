class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := HomeUpgrades.STORAGE_SIZE
## Lines kept for the info line of the storage chest and the vault.
const STORAGE_INFO_LINES := 4
const BLUE := Color(0.65, 0.85, 1.0)
## The colour of everything about the villagers' goodwill (see Reputation).
const REPUTATION_COLOR := Color(0.78, 0.65, 1.0)
## The quieter colour of what a villager wants and who they are tied to,
## under their standing on the reputation page.
const ABOUT_COLOR := Color(0.78, 0.8, 0.86)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett",
## "nachtlager" (the camp with the bedroll, see Camp), "laden",
## "ueberschreiben" (asks before a new game overwrites a slot), "kompendium",
## "charakter", "beenden" (the pause window with the quit button), "plan" (the day planned for the
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
## The load window opened from the bed's "stay awake" right after saving:
## "ok" or "failed", "" when it was opened to load a game.
var saved_now := ""
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
## Shows the stats of the item under the mouse (or last tapped), its name in
## the colour of its rarity (see Rarity).
var _info: RichTextLabel
const INFO_HINT := "Zeig auf einen Gegenstand, um seine Werte zu sehen."
## The windows built as a TradeWindow.
const TRADE_WINDOWS := ["haendler", "wanderhaendler", "schmied", "steinmetz", "barbier", "tempel"]
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
	["Fackel anzünden oder löschen", "V oder die Fackel am rechten Rand, unter dem Haus"],
	["Heiltrank trinken", "1 oder der Trank links neben der Fackel, einmal pro Minute; „Trinken“ im Inventar wählt einen bestimmten"],
	["Entfesselte Kraft (Zauber)", "2 oder der Stern links neben dem Heiltrank, sobald du den Folianten aus Sternhall gelesen hast"],
	["Lager aufschlagen (speichern und schlafen)", "U, der Knopf „Lager“ im Menü, oder die Schlafrolle im Inventar"],
	["Benutzen, durchsuchen, Fackel", "Dagegenlaufen"],
	["Inventar", "I"],
	["Kompendium", "H"],
	["Charakter", "P"],
	["Karte und Tagebuch", "N"],
	["Aufträge", "O"],
	["Nach Hause laufen", "X oder das Haus am rechten Rand, sobald du ein Zuhause hast; jeder eigene Schritt hält an"],
	["Spielstand laden", "L"],
	["Ton an/aus", "M"],
	["Etwas sagen", "Enter oder ein Klick auf die Zeile unter dem Ereignisprotokoll; Enter schickt, Esc oder leere Zeile geht zurück. Wer in der Nähe ist, antwortet"],
	["Steinblock abstellen", "B, oder „Abstellen“ im Inventar"],
	["Steinblock verschieben", "Block mit der linken Maustaste greifen, ziehen und loslassen (Rechtsklick dabei dreht ihn)"],
	["Steinblock aufheben", "E neben dem Block, oder ihn kurz anklicken"],
	["Schwere Steinblöcke schieben", "E neben dem Block, oder ihn kurz anklicken; ziehen setzt ihn ab, bis zu 5 Felder von seinem Platz"],
	["Zoom", "+ und −, Mausrad"],
	["Pause, Spiel beenden", "Esc (noch einmal Esc spielt weiter)"],
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
	# Slim gold scroll bars in every window (chest, bag, trade lists...)
	# instead of the engine's wide grey ones.
	_panel.theme = UiKit.scroll_theme()
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


static func panel_style(border: Color) -> BronzeStyle:
	return UiKit.panel_style(border)


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
	var fixed := fixed_size(current)
	if fixed != Vector2.ZERO:
		# A window the player works in has one size, whatever it holds:
		# its content sits in the middle of it (and would scroll in it).
		content = fixed
	if _rescale:
		_rescale = false
		var need := content + frame
		var s := minf(1.0, minf(screen.x / need.x, screen.y / need.y))
		_panel.scale = Vector2.ONE * maxf(s, MIN_SCALE)
	var room: Vector2 = screen / _panel.scale.x - frame
	var view := content
	if fixed != Vector2.ZERO:
		_scroll.custom_minimum_size = Vector2(minf(view.x, room.x), minf(view.y, room.y)).floor()
		_place_panel()
		return
	if view.y > room.y:
		view.y = room.y
		view.x += _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	if view.x > room.x:
		view.x = room.x
		view.y = minf(view.y + _scroll.get_h_scroll_bar().get_combined_minimum_size().y, room.y)
	_scroll.custom_minimum_size = view.floor()
	_place_panel()


## The fixed size of the content of each window the player works in
## (trading, equipment, chests, workbenches...), by kind; "trade" is every
## merchant's (see TRADE_WINDOWS). These windows never change their size:
## not when the player points at something, picks, folds, switches a tab,
## buys or sells, and not from one visit to the next with more or less in
## the bag. Each is as big as its fullest content in either language
## (`tests/windows_fixed_size.gd` checks that nothing outgrows it). Dialogs
## not listed here (bed, load, quit...) fit their content.
const WINDOW_SIZES := {
	"trade": Vector2(1156, 584),
	"inventar": Vector2(940, 729),
	"lager": Vector2(1256, 774),
	"bodenrucksack": Vector2(1256, 700),
	"metalltruhe": Vector2(880, 580),
	"zutatenbord": Vector2(880, 580),
	"buecherregal": Vector2(880, 580),
	"tresor": Vector2(940, 652),
	"bank": Vector2(780, 460),
	"werkbank": Vector2(780, 536),
	"hauswerkbank": Vector2(560, 420),
	"ausbau": Vector2(780, 540),
	"aushang": Vector2(780, 400),
	"trophaeen": Vector2(560, 360),
	"charakter": Vector2(1024, 642),
	"gefaehrten": Vector2(960, 530),
	"umhangschrank": Vector2(1060, 640),
	"wunsch": Vector2(760, 560),
	"kampfstil": Vector2(700, 330),
	"kompendium": Vector2(990, 600),
	"karte": Vector2(980, 616),
	"auftraege": Vector2(760, 532),
}


## The windows (besides the merchants') that can leave a note after a
## click; they keep its line from the start.
const NOTE_WINDOWS := ["inventar", "lager", "bodenrucksack", "metalltruhe", "zutatenbord", "buecherregal", "tresor", "bank", "werkbank", "hauswerkbank", "ausbau",
	"aushang", "gefaehrten", "wunsch", "umhangschrank"]


## The fixed content size of a kind of window, or zero for one that fits
## its content.
static func fixed_size(kind: String) -> Vector2:
	return WINDOW_SIZES.get("trade" if kind in TRADE_WINDOWS else kind, Vector2.ZERO)


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
	if kind != "laden":
		saved_now = ""
	_forge_tab = "waffen"
	inventory_tab = "tasche"
	_store_scroll = 0
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
	if current == "gefaehrte_name":
		naming = -1
		_naming_back = ""
		_name_edit = null
		if naming_message != "":
			game.show_message.call_deferred(naming_message, 6.0)
			naming_message = ""
	current = ""
	saved_now = ""
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
		"bodenrucksack":
			_build_floor_pack()
		"metalltruhe":
			_build_home_store(HomeStores.METAL)
		"zutatenbord":
			_build_home_store(HomeStores.PANTRY)
		"buecherregal":
			_build_home_store(HomeStores.BOOKS)
		"bank":
			_build_bank()
		"barbier":
			_build_barber()
		"tempel":
			_build_temple()
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
		"nachtlager":
			_build_camp()
		"laden":
			_build_load()
		"ueberschreiben":
			_build_overwrite()
		"kompendium":
			_build_compendium()
		"karte":
			_build_map()
		"auftraege":
			_build_quests()
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
		"beute":
			_build_spoils()
		"gefaehrten":
			_build_companions()
		"umhangschrank":
			_build_wardrobe()
		"gefaehrte_name":
			_build_naming()
	if current in ["lager", "tresor", "bodenrucksack"]:
		# The info line of the chest and the vault has a fixed box as wide as
		# the window: a long description (a torch, say) wraps or scrolls in it
		# instead of widening the window. A window that changed its size on
		# hover moved the item away from the pointer, which reset the line,
		# which shrank the window again: it flickered.
		var info_box := _info_box(STORAGE_INFO_LINES)
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_info.custom_minimum_size.y = info_box.custom_minimum_size.y
		_box.add_child(info_box)
		_show_info("")
	if _note != "" or current in TRADE_WINDOWS or current in NOTE_WINDOWS:
		# Every window the player works in keeps a line for the note, so a
		# purchase or a dropped item does not make the window grow. One line
		# at most, as wide as the window, never wider: a long note ends in "…".
		var note := _add_label(_note, 16, Color(1.0, 0.75, 0.5))
		note.custom_minimum_size = Vector2(0, 26)
		note.clip_text = true
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# The inventory has its own "Back to game" button at the top instead.
	if not current in ["inventar", "bett", "laden", "ueberschreiben", "beenden", "plan", "rueckkehr", "hoehle", "gefaehrte_name"]:
		var close_button: Button = game._make_button(Lang.t("Schließen"), close)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_button.custom_minimum_size = Vector2(180, 44 if current in TRADE_WINDOWS else 52)
		if current == "charakter" and _character_spend != null:
			# The character page's level point button shares the bottom row.
			var bottom := HBoxContainer.new()
			bottom.alignment = BoxContainer.ALIGNMENT_CENTER
			bottom.add_theme_constant_override("separation", 14)
			bottom.add_child(_character_level)
			bottom.add_child(_character_spend)
			bottom.add_child(close_button)
			_box.add_child(bottom)
		else:
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
	l.add_theme_font_size_override("normal_font_size", UiKit.sized(size))
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


## The line that shows an item's details: like a label (see
## Game._make_label), but its item name can have a colour of its own.
func _make_info() -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("normal_font", game.TEXT_FONT)
	l.add_theme_font_size_override("normal_font_size", UiKit.sized(16))
	l.add_theme_color_override("default_color", BLUE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A box of fixed size for the info line (`_info`, made here): `lines` lines
## high, measured on a label of the same font, and `width` wide (0: as wide
## as its container makes it, the text never widens it). A longer text
## scrolls inside, so pointing at an item never resizes the window.
func _info_box(lines: int, width := 0.0) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info = _make_info()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pass, so the mouse wheel scrolls a long description.
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_info)
	var measure: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	scroll.custom_minimum_size = Vector2(width,
			ceilf(measure.get_line_height() * lines + measure.get_theme_constant("line_spacing") * (lines - 1.0)))
	measure.free()
	return scroll


func _item_button(text: String, action: Callable, enabled := true, id := "") -> Button:
	var b: Button = game._make_button(text, action)
	if id != "":
		# An item's name shows in the colour of its rarity (see Rarity).
		var c := Rarity.color(id)
		for state in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, c)
		for state in ["font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(state, Rarity.hover(c))
		# Pointing at an item (or tapping it) shows its stats right away.
		b.mouse_entered.connect(_show_info.bind(id))
		b.focus_entered.connect(_show_info.bind(id))
		b.mouse_exited.connect(_show_info.bind(""))
	b.custom_minimum_size = Vector2(160, 54)
	b.add_theme_font_size_override("font_size", UiKit.sized(16))
	b.disabled = not enabled
	return b


## A grid of item slots (pictures, see _item_slot); empty places up to
## `size` are shown as empty slots. `columns` is kept for the callers; the
## slots always run SLOT_COLUMNS across.
## With `bundle` (the hero's bag) items that bundle (Items.stack_size: torches, jewellery, food)
## share one cell that shows how many, like the ingredient pouch; a click
## acts on one of them.
func _add_item_grid(items: Array, size: int, label_of: Callable, action: Callable, columns := 4, parent: Control = null, bundle := false) -> void:
	var grid := GridContainer.new()
	grid.columns = maxi(columns, SLOT_COLUMNS)
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(parent if parent else _box).add_child(grid)
	var cells: Array = Items.stacks(items) if bundle else []
	if not bundle:
		for i in items.size():
			cells.append({"id": items[i], "count": 1, "indices": [i]})
	for i in size:
		if i < cells.size():
			var cell: Dictionary = cells[i]
			var count: int = cell.count if bundle and Items.stack_size(cell.id) > 1 else 0
			# The last of a bundle is the one taken, so the others keep their places.
			var b := _item_slot(cell.id, label_of.call(cell.id), count, action.bind(cell.indices.back()))
			if current == "inventar" and _selected in cell.indices:
				_mark_picked(b)
			grid.add_child(b)
		else:
			grid.add_child(_item_slot("", "", 0, func(): pass, false))


## The picked cell of the inventory: a bright gold frame on a lighter
## ground, as a picked row in the trade window. A frame rather than a tint,
## so the name keeps the colour of its rarity.
func _mark_picked(b: Button) -> void:
	for state in ["normal", "hover"]:
		var style: BronzeStyle = b.get_theme_stylebox(state).duplicate()
		# The cell keeps its size and its picture its place.
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, style.get_margin(side))
		style.bg_color = Color(0.2, 0.14, 0.1, 1.0)
		style.border_color = Color(1.0, 0.9, 0.62)
		style.shadow_color = Color(1.0, 0.8, 0.4, 0.55)
		style.shadow_size = 5
		b.add_theme_stylebox_override(state, style)


## The ground of an item slot: a dark well under the picture.
const SLOT_WELL := Color(0.075, 0.053, 0.036, 1.0)


## One slot of an item grid: a bronze box with the item's picture, and how
## many in its corner when there are several. The name and the details show
## when the pointer is on it (the tooltip and the details box), so the slot
## needs no text. The rim takes the item's rarity colour (the details name
## the rarity in words, so colour is never the only cue); an empty slot is
## a dim, empty box, or with `ghost` (a kind) a faint picture of what goes there.
func _item_slot(id: String, name: String, count: int, action: Callable, enabled := true, cell := INVENTORY_CELL, ghost := "", compare := true) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	b.custom_minimum_size = cell
	b.set_meta("item", id)
	b.tooltip_text = ("%s  × %d" % [name, count]) if count > 1 else name
	var rim: Color = UiKit.BRONZE
	if id != "" and Rarity.tier(id) != "normal":
		rim = Rarity.color(id)
	var normal: BronzeStyle = UiKit.frame_style(SLOT_WELL, rim, SLOT_RIM, 5)
	var hover: BronzeStyle = normal.duplicate()
	hover.bg_color = Color(0.15, 0.1, 0.06, 1.0)
	hover.border_color = rim.lerp(Color.WHITE, 0.35)
	var disabled: BronzeStyle = normal.duplicate()
	disabled.bg_color = Color(0.06, 0.045, 0.032, 1.0)
	disabled.border_color = Color(UiKit.BRONZE, 0.5)
	var focus := UiKit.Bronze.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.95)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(7)
	focus.set_expand_margin_all(4)
	for state in ["normal", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, normal if state == "normal" else hover)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	var art := ""
	if id != "":
		art = id
	elif ghost != "":
		art = "kind:" + ghost
	if art != "":
		var pad := SLOT_RIM + 6.0
		var icon := ItemIcon.make(art, cell.x - 2.0 * pad, true)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = pad
		icon.offset_top = pad
		icon.offset_right = -pad
		icon.offset_bottom = -pad
		if id == "":
			icon.modulate = Color(1, 1, 1, 0.16)
		b.add_child(icon)
	if count > 1:
		var n: Label = game._make_label(game.TEXT_FONT, 20, Color(1.0, 0.95, 0.81))
		n.text = "×%d" % count
		n.add_theme_constant_override("outline_size", 5)
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		n.offset_right = -SLOT_RIM - 2.0
		n.offset_bottom = -SLOT_RIM + 2.0
		b.add_child(n)
	if id != "":
		# Pointing at an item (or tapping it) shows its stats right away.
		b.mouse_entered.connect(_show_info.bind(id, compare))
		b.focus_entered.connect(_show_info.bind(id, compare))
		b.mouse_exited.connect(_show_info.bind(""))
	b.pressed.connect(action)
	b.disabled = not enabled
	return b


func _show_info(id: String, compare := true) -> void:
	if _info == null or not is_instance_valid(_info):
		return
	if id == "" and current == "inventar" and _selected >= 0 and _selected < game.player.bag.size():
		# Off an item, the inventory shows the picked one again.
		id = game.player.bag[_selected]
	if id == "":
		_info.text = _bb(Lang.t(INFO_HINT))
	elif not Items.ALL.has(id) and (Crafting.INGREDIENTS.has(id) or id == "eisen"):
		_info.text = _bb(game.crafting.describe_ingredient(id))
	else:
		_info.text = info_text(id, game.player.wear.get(id, 0))
		# A bag item shows how it compares with what is worn in its place; a
		# worn item is not compared with itself.
		var versus := TradeWindow.compare_bbcode(game.player, id) if compare else ""
		if versus != "":
			_info.text += "\n" + versus


## An item's details for the info line: its name in the colour of its
## rarity, the rarity in words (so the colour is never the only cue), then
## its values.
static func info_text(id: String, worn := 0) -> String:
	return "%s %s: %s" % [Rarity.bbcode(id), _bb("(%s)" % Rarity.label(id)), _bb(Items.describe(id, worn))]


## Plain text made safe for a RichTextLabel.
static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


func _stats_text() -> String:
	var p: Player = game.player
	return Lang.t("Leben %d / %d (+%.1f/s)    Kampfkraft %d    Härtung %d    Rüstungswert %d%%    Tempo %d%%    Messer %d    Kupfer %d") % [
		p.hp, p.max_hp, p.life_regen(), p.power, p.hardening, p.armour_value, roundi(p.speed / Player.SPEED * 100.0), p.knives, game.coins]


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
				Lang.t(" (höchster Wert)") if at_cap else " (" + Lang.t("%d%% bis +1") % floori(Training.attribute_progress(id, p.xp.get(id, 0.0)) * 100.0) + ")"])
	if two_lines and parts.size() > 1:
		var half := ceili(parts.size() / 2.0)
		return "    ".join(parts.slice(0, half)) + "\n" + "    ".join(parts.slice(half))
	return "    ".join(parts)


## Every skill with its level; skills the worn gear does not allow are in brackets.
func _skills_text() -> String:
	var p: Player = game.player
	var parts := []
	for id in Training.SKILLS:
		var text := "%s %d" % [Lang.t(Training.SKILLS[id].name), p.skill(id) if p.skill_enabled(id) else p.trained_level(id)]
		parts.append(text if p.skill_enabled(id) else "(%s)" % text)
	return Lang.t("Fertigkeiten:") + " " + "   ".join(parts) + "\n" + Lang.t("In Klammern: braucht passende Ausrüstung")


# --- Character page -------------------------------------------------------

## The crafts, each with its level, for the character page: two to a line,
## so four crafts still take two lines in the column beside the wheel.
func _crafts_text() -> String:
	var parts := []
	for id in Training.CRAFTS:
		if id == AshSpire.SPELL and not AshSpire.knows_spell(game.player):
			continue
		parts.append("%s %d" % [Lang.t(Training.CRAFTS[id].name), Training.skill_level(game.player.xp.get(id, 0.0), id)])
	var lines := []
	for i in range(0, parts.size(), 2):
		lines.append("   ".join(parts.slice(i, i + 2)))
	return Lang.t("Handwerk:") + " " + "\n".join(lines)


## The width of the column beside the character wheel.
const CHARACTER_SIDE := 420
## The details card beside the wheel has a fixed height that fits the longest
## details in both languages, so pointing at another entry moves nothing.
const CHARACTER_CARD_HEIGHT := 262
const CHARACTER_TEXT := Color(0.85, 0.87, 0.92)
## The column for the hit and block chances, beside the list of attributes.
const CHARACTER_ODDS_WIDTH := 160
## The button that puts a free level point into the picked main attribute
## (for tests).
var _character_spend: Button = null
var _character_keep := ""
var _character_level: Label = null
## The width kept for the hero level and experience in the bottom row.
const CHARACTER_LEVEL_WIDTH := 200
## The armour set line (for tests).
var _character_set: Label = null


## The wheel of attributes and skills (see CharacterPage). Beside it: what
## is not on the wheel (life and the attributes no skill depends on), and a
## card with the details of the entry pointed at, or how a roll works.
func _build_character() -> void:
	var p: Player = game.player
	_character_spend = null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	var wheel := CharacterPage.new(p, game.TEXT_FONT)
	# A rebuild after spending a point keeps the attribute picked.
	wheel.picked = _character_keep
	_character_keep = ""
	row.add_child(wheel)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = CHARACTER_SIDE
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	var title: Label = game._make_label(game.TITLE_FONT, 38, game.GOLD)
	title.text = Lang.t("Charakter")
	# The blessing sits beside the title, so the window keeps its height
	# whether the hero is blessed or not.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	side.add_child(title_row)
	title_row.add_child(title)
	var blessing_line: Label = game._make_label(game.TEXT_FONT, 16, game.GOLD if p.blessing_god != "" else TradeWindow.GREY)
	blessing_line.text = Blessing.title(p.blessing_god, p.blessing_thirds) if p.blessing_god != "" else Lang.t("Ungesegnet")
	blessing_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	blessing_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blessing_line.clip_text = true
	blessing_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_character_point(blessing_line, wheel, CharacterPage.BLESSING)
	title_row.add_child(blessing_line)
	# The list of what is not on the wheel, and beside it the hero's odds
	# against a person of the same level, as the fight rolls them; pointing
	# at the odds explains them in the card below.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	side.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	top.add_child(grid)
	_character_row(grid, wheel, "", Lang.t("Leben"), "%d / %d   %+.1f/s" % [p.hp, p.max_hp, p.life_regen()], Color(1.0, 0.55, 0.5))
	# The injury a rescue left, always a row so the window keeps its shape.
	_character_row(grid, wheel, CharacterPage.INJURY, Lang.t("Verletzung"),
			Lang.t(Injury.KINDS[p.injury].name) if p.injury != "" else Lang.t("keine"),
			Color(1.0, 0.55, 0.5) if p.injury != "" else TradeWindow.GREY)
	for id in Training.ATTRIBUTES:
		if not id in Training.MAIN_ATTRIBUTES:
			_character_row(grid, wheel, id, Lang.t(Training.ATTRIBUTES[id].name),
					("%d %%" % p.attribute(id)) if id == "tempo" else str(p.attribute(id)), Color.WHITE)
	var odds: Dictionary = wheel.odds()
	var odds_box := VBoxContainer.new()
	odds_box.custom_minimum_size.x = CHARACTER_ODDS_WIDTH
	odds_box.add_theme_constant_override("separation", 6)
	top.add_child(odds_box)
	var odds_title: Label = game._make_label(game.TEXT_FONT, 16, game.GOLD)
	# Above the world's top the yardstick is its strongest (HeroLevel.measured).
	odds_title.text = Lang.t("Gegen Menschen deiner Stufe:") if p.hero_level() <= HeroLevel.WORLD_TOP \
			else Lang.t("Gegen die stärksten Menschen:")
	odds_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds_title.custom_minimum_size.x = CHARACTER_ODDS_WIDTH
	_character_point(odds_title, wheel, CharacterPage.ODDS)
	odds_box.add_child(odds_title)
	var odds_grid := GridContainer.new()
	odds_grid.columns = 2
	odds_grid.add_theme_constant_override("h_separation", 14)
	odds_grid.add_theme_constant_override("v_separation", 6)
	odds_box.add_child(odds_grid)
	_character_row(odds_grid, wheel, CharacterPage.ODDS, Lang.t("Treffer"), CharacterPage.percent(odds.hit), Color.WHITE)
	_character_row(odds_grid, wheel, CharacterPage.ODDS, Lang.t("Block"), CharacterPage.percent(odds.block), Color.WHITE)
	# Below the odds, the two kinds of protection: a flat amount and a share
	# off every hit. Pointing at them explains them in the card.
	var guard_title: Label = game._make_label(game.TEXT_FONT, 16, game.GOLD)
	guard_title.text = Lang.t("Schutz:")
	odds_box.add_child(guard_title)
	var guard_grid := GridContainer.new()
	guard_grid.columns = 2
	guard_grid.add_theme_constant_override("h_separation", 14)
	guard_grid.add_theme_constant_override("v_separation", 6)
	odds_box.add_child(guard_grid)
	_character_row(guard_grid, wheel, CharacterPage.HARDENING, Lang.t("Härtung"), str(p.hardening), Color.WHITE)
	_character_row(guard_grid, wheel, CharacterPage.ARMOUR, Lang.t("Rüstungswert"), "%d %%" % p.armour_value, Color.WHITE)
	# The armour set worn and what it gives, in one line that keeps its
	# height; pointing at it explains sets in the card below.
	var set_kind := ArmourSets.worn(p.equipped)
	var set_line: Label = game._make_label(game.TEXT_FONT, 16, TradeWindow.GREEN if set_kind != "" else TradeWindow.GREY)
	set_line.text = ArmourSets.summary(p.equipped)
	set_line.clip_text = true
	set_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	set_line.custom_minimum_size.x = CHARACTER_SIDE
	_character_point(set_line, wheel, CharacterPage.ARMOUR_SET)
	_character_set = set_line
	side.add_child(set_line)
	# The details card: what the wheel points at, else how a roll works.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CHARACTER_SIDE, CHARACTER_CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", TradeWindow._style(Color(0.1, 0.07, 0.045, 0.97), TradeWindow.BORDER, 8, 12, 2))
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
	show.call(wheel.shown())
	wheel.shown_changed.connect(show)
	# A free level point goes to the main attribute picked in the wheel. The
	# button is always there, beside the close button (see _rebuild), so the
	# window never changes its shape.
	var spend: Button = game._make_button("", func() -> void:
		if p.spend_point(wheel.picked):
			_character_keep = wheel.picked
			Sfx.play(game, "secret", -6.0)
			game._update_hud()
			_rebuild())
	spend.custom_minimum_size = Vector2(CHARACTER_SIDE + 40, 52)
	spend.add_theme_font_size_override("font_size", UiKit.sized(16))
	var label_spend := func(_id: String) -> void:
		var free := p.free_points()
		var id: String = wheel.picked
		if free <= 0:
			spend.text = Lang.t("Kein Punkt frei (jede 3. Heldenstufe)")
		elif id in HeroLevel.POINT_ATTRIBUTES:
			spend.text = Lang.t("+1 %s (%d frei)") % [Lang.t(Training.ATTRIBUTES[id].name), free]
		else:
			spend.text = Lang.t("Punkt frei: wähle Stärke, Geschick oder Intelligenz")
		spend.disabled = free <= 0 or not id in HeroLevel.POINT_ATTRIBUTES
	label_spend.call("")
	wheel.shown_changed.connect(label_spend)
	# The hero's level and experience sit right before it, in the bottom row.
	var step := HeroLevel.progress(p.hero_xp)
	_character_level = game._make_label(game.TEXT_FONT, 18, game.XP_COLOR)
	_character_level.text = Lang.t("Heldenstufe %d") % p.hero_level() + "\n" + \
			((Lang.t("%d / %d EP") % [step.x, step.y]) if step.y > 0 else Lang.t("höchste Stufe"))
	_character_level.custom_minimum_size.x = CHARACTER_LEVEL_WIDTH
	_character_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_character_spend = spend
	for entry in [
		[Lang.t("Innen Grundfertigkeiten, außen fortgeschrittene."), CHARACTER_TEXT],
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
		if id != "":
			_character_point(l, wheel, id)


## Makes a label beside the wheel show `id` in the details card when pointed
## at, and keep it there when clicked or tapped.
func _character_point(l: Label, wheel: CharacterPage, id: String) -> void:
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
const INVENTORY_WIDTH := 6 * 150 + 5 * 8
## An item slot (a picture in a bronze box) and how they are laid out: ten
## across, a little apart, in every item grid (bag, pouch, chest, vault).
const INVENTORY_CELL := Vector2(64, 64)
const SLOT_COLUMNS := 10
const SLOT_GAP := 8
const SLOT_RIM := 5
## The width of a text button beside the grids (tabs, the picked item's actions).
const ACTION_WIDTH := 150.0
## The worn slots: seven across, each with the name of its place under it.
const WORN_COLUMNS := 7
const WORN_CELL := INVENTORY_CELL
const WORN_GAP := floori((SLOT_COLUMNS * INVENTORY_CELL.x + (SLOT_COLUMNS - 1) * SLOT_GAP - WORN_COLUMNS * INVENTORY_CELL.x) / float(WORN_COLUMNS - 1))
## The details of the picked item or the one under the pointer: lines of
## text kept for them, and the font size. Longer texts scroll in that box.
const INVENTORY_DETAIL_LINES := 5
const INVENTORY_TEXT := 15


## The faint picture in an empty worn place: what goes there.
const WORN_GHOSTS := {"kopf": "helmet", "waffe": "sword", "schild": "shield", "umhang": "cloak",
	"ruestung": "armour", "handschuhe": "gloves", "schuhe": "boots", "amulett": "amulet", "ring": "ring",
	"armreif": "bracelet", "spezial_1": "special", "spezial_2": "special", "rucksack": "bag"}


func _build_inventory() -> void:
	var p: Player = game.player
	_add_inventory_header()
	_add_inventory_line(_stats_text(), BLUE)
	_add_inventory_line(_attributes_text(true), game.GOLD)
	_add_inventory_line(_skills_text(), Color(0.8, 0.85, 0.9))
	_add_worn_heading(p)
	var row := GridContainer.new()
	# Seven across keeps all thirteen slots in two rows, as wide as the bag's
	# six cells, so the window fits the screen.
	row.columns = WORN_COLUMNS
	row.add_theme_constant_override("h_separation", WORN_GAP)
	row.add_theme_constant_override("v_separation", SLOT_GAP)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(row)
	for slot in Items.SLOTS:
		var id: String = p.equipped.get(slot, "")
		var place := VBoxContainer.new()
		place.add_theme_constant_override("separation", 2)
		var name := Lang.t(Items.SLOT_NAMES[slot])
		var b := _item_slot(id, ("%s: %s" % [name, Items.item_name(id)]) if id != "" else name, 0, _unequip.bind(slot), id != "", WORN_CELL, WORN_GHOSTS.get(slot, ""), false)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		place.add_child(b)
		var label: Label = game._make_label(game.TEXT_FONT, 13, Color(0.75, 0.65, 0.48))
		label.text = name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = WORN_CELL.x
		place.add_child(label)
		row.add_child(place)
	# Two tabs share the space below: the bag and the ingredient pouch.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	_box.add_child(tabs)
	var bag_tab := Lang.t("Tasche (%d / %d)    Gewicht %s") % [p.bag_used(), p.bag_size(), Items.weight_text(p.carried_weight())]
	var pouch_tab := Lang.t("Zutatenbeutel (%d)") % _pouch_ids().size()
	# The bag is three cells wide, the pouch two, the purse (coins and gems)
	# one: together as wide as the bag's grid.
	for tab in [["tasche", bag_tab, 3], ["beutel", pouch_tab, 2], ["muenzen", Lang.t("Geldbeutel"), 1]]:
		var b := _item_button(tab[1], _show_inventory_tab.bind(tab[0]))
		b.custom_minimum_size = Vector2(tab[2] * ACTION_WIDTH + (tab[2] - 1) * 8, 44)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.modulate = Color(1.0, 0.9, 0.6) if inventory_tab == tab[0] else Color(0.75, 0.75, 0.8)
		tabs.add_child(b)
	# The bag's page is always built: it sets the size the pouch's page gets,
	# so switching tabs does not resize the window.
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	# At least two rows of slots, as a full bag of twenty has, so a small
	# bag still leaves the pouch room for its slots.
	page.custom_minimum_size.y = 2 * INVENTORY_CELL.y + SLOT_GAP
	_box.add_child(page)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _select, SLOT_COLUMNS, page, true)
	if inventory_tab != "tasche":
		var room := page.get_combined_minimum_size()
		_box.remove_child(page)
		page.queue_free()
		_box.add_child(_pouch_page(room, 6) if inventory_tab == "beutel" else _purse_page(room))
	_box.add_child(_inventory_details())


## A line of the hero's values at the top of the inventory: wrapped at the
## window's width, so a longer value never widens the window.
func _add_inventory_line(text: String, color: Color) -> Label:
	var l := _add_label(text, INVENTORY_TEXT, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = INVENTORY_WIDTH
	return l


## "Worn" with the helmet's show/hide button beside it. The button's place is
## kept when no helmet is worn, so putting one on does not move anything.
func _add_worn_heading(p: Player) -> void:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.custom_minimum_size = Vector2(INVENTORY_WIDTH, 44)
	_box.add_child(heading)
	const SIDE := 2 * 150 + 8
	# Bronze rules lead to the heading from both sides (the right one gives
	# way to the helmet's button when a helmet is worn).
	var balance := UiKit.rule()
	balance.custom_minimum_size.x = SIDE
	balance.size_flags_horizontal = Control.SIZE_FILL
	heading.add_child(balance)
	var title: Label = game._make_label(game.TEXT_FONT, 16, game.GOLD)
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
		toggle.add_theme_font_size_override("font_size", UiKit.sized(INVENTORY_TEXT))
		heading.add_child(toggle)
	else:
		var keep := UiKit.rule()
		keep.size_flags_horizontal = Control.SIZE_FILL
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
	actions.custom_minimum_size = Vector2(ACTION_WIDTH, 0)
	var scroll := _info_box(INVENTORY_DETAIL_LINES, INVENTORY_WIDTH - ACTION_WIDTH - 10)
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
		elif Items.is_bedroll(id):
			buttons.append(_item_button(Lang.t("Lager aufschlagen"), func():
				close()
				game.camp_action()))
		elif Items.is_potion(id):
			buttons.append(_item_button(Lang.t("Trinken"), _drink_selected))
		elif Items.is_recipe_scroll(id):
			buttons.append(_item_button(Lang.t("Lesen"), _read_selected))
		elif Items.is_quest(id) or Items.is_material(id) or Items.is_food(id) or Items.is_light(id) or Items.is_ammo(id):
			pass # Carried for a task, to the smith, for a fox, for the dark or as spare knives, not worn.
		else:
			buttons.append(_item_button(Lang.t("Anlegen"), _equip_selected))
		buttons.append(_item_button(Lang.t("Wegwerfen"), _drop_selected))
		for b in buttons:
			b.custom_minimum_size = Vector2(ACTION_WIDTH, 44)
			actions.add_child(b)
	return row


## The ingredients the hero carries, in the order of the ingredient book,
## with the smith's iron bars last. Coins and gems are in the purse, not here.
func _pouch_ids() -> Array:
	var ids := []
	for id in Crafting.INGREDIENTS:
		if game.crafting.have(id) > 0 and not Crafting.in_purse(id):
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
	grid.columns = maxi(columns, SLOT_COLUMNS)
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(grid)
	for id in ids:
		# Ingredients are not worn or dropped: a click shows what the book says.
		# The details box under it shows the name and what the book says.
		grid.add_child(_item_slot(id, Crafting.ingredient_name(id), game.crafting.have(id), _show_info.bind(id)))
	# More kinds than rows in the room: the region scrolls (the grid is
	# narrower than the room, so the scroll bar takes nothing from it).
	return scroll


## How many coins of each metal the coin tab puts down (metal -> count).
var coin_amounts := {}
## The quick amounts on the coin tab ("Alle" is everything carried).
const COIN_STEPS := [1, 10, 100]


## The purse tab: a row per metal the hero carries (copper always), with how
## many, a few quick amounts, a field to type any amount and the button to
## put them down at the hero's feet, where they join a pile of the same
## metal (see CoinPile); below them a row per kind of gem carried, cut and
## uncut, with their weights. Nothing in it takes a place in the bag or the
## pouch (see Crafting.purse). As big as the bag's page; it scrolls if it
## ever holds more.
func _purse_page(room: Vector2) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = room
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var hint: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	hint.text = Lang.t("Münzen einer Art am selben Fleck bilden einen Haufen (bis %d).") % CoinPile.MAX
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(room.x - 12, 26)
	list.add_child(hint)
	# What the coins are worth counted up into silver and gold; the coins stay as they are.
	var held: Dictionary = game._held_coins()
	var worth: Label = game._make_label(game.TEXT_FONT, 18, game.GOLD)
	worth.text = Lang.t("Zusammen wert: %s") % Loot.worth_text(
			int(held.get("kupfermuenze", 0)), int(held.get("silbermuenze", 0)), int(held.get("goldmuenze", 0)))
	worth.clip_text = true
	worth.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worth.custom_minimum_size = Vector2(room.x - 12, 28)
	list.add_child(worth)
	for metal in game.coin_metals():
		list.add_child(_coin_row(metal, room.x - 12))
	for id in Ore.GEMS:
		if game.crafting.have(id) > 0:
			list.add_child(_gem_row(id, room.x - 12))
	return scroll


## One kind of gem in the purse: how many, and the weight and rarity of each
## (oldest first, as Gorm takes them). A click shows what the book says.
func _gem_row(id: String, width: float) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _purse_row_style())
	panel.custom_minimum_size.x = width
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := ItemIcon.make(id, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var carats: Array = game.crafting.gems.get(id, [])
	var title: Label = game._make_label(game.TEXT_FONT, 18, Rarity.color(id))
	title.text = "%s  ×%d" % [Crafting.ingredient_name(id), game.crafting.have(id)]
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(title)
	var each: Label = game._make_label(game.TEXT_FONT, 16, TradeWindow.GREY)
	each.text = ", ".join(carats.map(func(c): return _carat_text(int(c))))
	each.tooltip_text = each.text
	each.clip_text = true
	each.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(each)
	var info := _item_button(Lang.t("Infos"), _show_info.bind(id))
	info.custom_minimum_size = Vector2(150, 44)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	return panel


## The frame of one row on the purse tab.
static func _purse_row_style() -> BronzeStyle:
	var style := BronzeStyle.new()
	style.bg_color = Color(0.12, 0.085, 0.05, 0.85)
	style.border_color = Color(0.85, 0.66, 0.32, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style


func _coin_row(metal: String, width: float) -> Control:
	var info: Dictionary = CoinPile.METALS[metal]
	var held: int = game.coins_held(metal)
	var amount := clampi(int(coin_amounts.get(metal, 1)), 0, held)
	if held > 0 and amount == 0:
		amount = 1
	coin_amounts[metal] = amount
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _purse_row_style())
	panel.custom_minimum_size.x = width
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := ItemIcon.make("kind:coin", 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if metal != CoinPile.GOLD:
		# The coin picture made grey, then coloured like the metal.
		icon.modulate = Color(info.tint.r * 1.15, info.tint.g * 1.25, info.tint.b * 2.2)
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.custom_minimum_size.x = 250
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var title: Label = game._make_label(game.TEXT_FONT, 18, info.tint)
	title.text = Lang.t(info.name)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(title)
	var count: Label = game._make_label(game.TEXT_FONT, 16, TradeWindow.GREY)
	count.text = Lang.t("Dabei: %d") % held if held > 0 else Lang.t("Keine dabei")
	count.clip_text = true
	count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(count)
	for step in COIN_STEPS + [-1]:
		var n: int = held if step < 0 else step
		var b := _item_button(Lang.t("Alle") if step < 0 else str(step), _set_coin_amount.bind(metal, n), held > 0 and (step < 0 or step <= held))
		b.custom_minimum_size = Vector2(64, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if held > 0 and n == amount:
			_mark_picked(b)
		row.add_child(b)
	var edit := LineEdit.new()
	edit.name = "Amount"
	edit.text = str(amount)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.max_length = 5
	edit.editable = held > 0
	edit.custom_minimum_size = Vector2(100, 44)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.tooltip_text = Lang.t("Wie viele Münzen (1 bis %d)") % mini(held, CoinPile.MAX) if held > 0 else ""
	edit.add_theme_font_override("font", game.TEXT_FONT)
	edit.add_theme_font_size_override("font_size", UiKit.sized(18))
	edit.add_theme_color_override("font_color", game.GOLD)
	edit.add_theme_stylebox_override("normal", panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	edit.add_theme_stylebox_override("focus", panel_style(game.GOLD))
	edit.add_theme_stylebox_override("read_only", panel_style(Color(0.5, 0.45, 0.4, 0.5)))
	for st in ["normal", "focus", "read_only"]:
		edit.get_theme_stylebox(st).set_content_margin_all(6)
	# Digits only; the amount is kept as it is typed, and Enter puts them down.
	edit.text_changed.connect(func(t: String):
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			var at := edit.caret_column
			edit.text = digits
			edit.caret_column = mini(at, digits.length())
		coin_amounts[metal] = int(digits) if digits != "" else 0)
	edit.text_submitted.connect(func(_t): _put_coins_down(metal))
	row.add_child(edit)
	var put := _item_button(Lang.t("Ablegen"), _put_coins_down.bind(metal), held > 0)
	put.custom_minimum_size = Vector2(150, 44)
	put.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(put)
	return panel


func _set_coin_amount(metal: String, n: int) -> void:
	coin_amounts[metal] = n
	_note = ""
	_rebuild()


## Puts the chosen number of coins down at the hero's feet (a typed amount
## is kept within what is carried and what one pile holds).
func _put_coins_down(metal: String) -> void:
	var held: int = game.coins_held(metal)
	var n := clampi(int(coin_amounts.get(metal, 0)), 0, mini(held, CoinPile.MAX))
	if n <= 0:
		_note = Lang.t("Keine Münzen zum Ablegen.") if held <= 0 else Lang.t("Gib an, wie viele Münzen du ablegen willst.")
		_rebuild()
		return
	var done: int = game.put_coins_down(metal, n)
	_note = Lang.t("%d %s abgelegt.") % [done, Lang.t(CoinPile.METALS[metal].name)]
	coin_amounts[metal] = mini(n, game.coins_held(metal))
	_rebuild()


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
	back.add_theme_font_size_override("font_size", UiKit.sized(16))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		_note = Lang.t("In diesen Rucksack passt nicht alles aus deiner Tasche.") if Items.ALL[id].slot == "rucksack" else Lang.t("Deine Tasche ist voll.")
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


## Drinks the picked potion (see HealingPotions); during the cooldown the
## note says how long to wait. The rest of the bundle stays picked.
func _drink_selected() -> void:
	var p: Player = game.player
	var id: String = p.bag[_selected]
	var why: String = game.drink_potion(id)
	_note = why if why != "" else Lang.t("%s getrunken.") % Items.item_name(id)
	_selected = -1
	for cell in Items.stacks(p.bag):
		if cell.id == id:
			_selected = cell.indices.back()
			break
	_rebuild()


## Reads the selected recipe scroll: it teaches its recipe and is used up.
func _read_selected() -> void:
	var p: Player = game.player
	var id: String = p.bag[_selected]
	var why: String = game.crafting.read_scroll(id)
	_note = why if why != "" else Lang.t("Du hast das Rezept gelernt: %s.") % Lang.t(Crafting.RECIPES[Items.ALL[id].recipe].name)
	_selected = -1
	_rebuild()


func _drop_selected() -> void:
	var p: Player = game.player
	var id: String = p.bag[_selected]
	if Items.is_backpack(id) and game.pack_spot() == Vector3.INF:
		_note = Lang.t("Hier ist kein Platz für den Rucksack.")
		_rebuild()
		return
	_note = Lang.t("%s abgelegt.") % Items.item_name(id)
	p.bag.remove_at(_selected)
	game.drop_on_floor(id)
	_selected = -1
	# From a bundle (torches) one is dropped and the rest stays picked, so
	# "Drop" can be pressed again for the next.
	for cell in Items.stacks(p.bag):
		if cell.id == id and Items.stack_size(id) > 1:
			_selected = cell.indices.back()
			break
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
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag_used(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _store, 6, null, true)
	var size := HomeUpgrades.storage_size(game.home_upgrades)
	var used := HomeUpgrades.storage_used(game.storage)
	_add_label(Lang.t("Truhe (%d / %d)") % [used, size], 20)
	# Eight across, so the window keeps its width when the chest grows.
	_add_item_grid(game.storage, maxi(size, used), Items.item_name, _take, 8, null, true)


# --- A backpack on the floor (see FloorPack) -----------------------------------

## Like the storage chest: the bag above, the backpack below; a click moves an
## item across. A button takes the backpack back once it is empty.
func _build_floor_pack() -> void:
	var p: Player = game.player
	var pack: FloorPack = game.open_pack
	if pack == null or not is_instance_valid(pack):
		close()
		return
	_add_label(Items.item_name(pack.backpack()), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 16, BLUE)
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag_used(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _pack_store, 6, null, true)
	_add_label(Lang.t("Rucksack (%d / %d)") % [pack.used(), pack.capacity()], 20)
	_add_item_grid(pack.contents(), pack.capacity(), Items.item_name, _pack_take, 8, null, true)
	var take := _item_button(Lang.t("Rucksack aufheben"), _pack_pick_up)
	take.custom_minimum_size = Vector2(220, 44)
	take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(take)


func _pack_store(index: int) -> void:
	var pack: FloorPack = game.open_pack
	var id: String = game.player.bag[index]
	var why := pack.why_not(id)
	if why != "":
		_note = why
	else:
		pack.contents().append(id)
		game.player.bag.remove_at(index)
		_note = ""
	_rebuild()


func _pack_take(index: int) -> void:
	var pack: FloorPack = game.open_pack
	var id: String = pack.contents()[index]
	if not game.player.bag_fits(id):
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(id)
		pack.contents().remove_at(index)
		_note = ""
	_rebuild()


func _pack_pick_up() -> void:
	var pack: FloorPack = game.open_pack
	var why: String = game.take_floor_pack(pack)
	if why != "":
		_note = why
		_rebuild()
		return
	game.open_pack = null
	close()


func _store(index: int) -> void:
	if not HomeUpgrades.storage_fits(game.home_upgrades, game.storage, game.player.bag[index]):
		_note = Lang.t("Die Truhe ist voll.")
	else:
		game.storage.append(game.player.bag[index])
		game.player.bag.remove_at(index)
		_note = ""
	_rebuild()


func _take(index: int) -> void:
	if not game.player.bag_fits(game.storage[index]):
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(game.storage[index])
		game.storage.remove_at(index)
		_note = ""
	_rebuild()


# --- The steel-banded chest and the ingredient board (see HomeStores) -------

## The rows of the two stores' windows: how tall one is, and how many show
## before the list scrolls. The columns: the name, what the hero carries,
## the two buttons that store, the two that take, what lies at home.
const STORE_ROW_HEIGHT := 56.0
const STORE_ROWS := 5
const STORE_NAME_WIDTH := 250.0
const STORE_COUNT_WIDTH := 92.0
const STORE_BUTTON := Vector2(76, 44)
const STORE_WIDTH := 840.0
const STORE_GREY := Color(0.75, 0.72, 0.68)
## Where the list of the open store was scrolled to, kept over rebuilds.
var _store_scroll := 0
var _store_list: ScrollContainer = null


## The window of the steel-banded chest ("metall"), the ingredient board
## ("zutaten") or the bookshelf ("buecher"): one row for every kind the hero
## carries or keeps there, with buttons to store or take one (ten coins) or all
## of it, and two buttons below for everything at once. The bookshelf's window
## says how many books stand on the shelf.
func _build_home_store(store: String) -> void:
	Events.teach(HomeStores.BOOKS_LEARN if store == HomeStores.BOOKS else HomeStores.LEARN)
	if _store_list != null and is_instance_valid(_store_list):
		_store_scroll = _store_list.scroll_vertical
	var metal := store == HomeStores.METAL
	var books := store == HomeStores.BOOKS
	_add_label(Lang.t("Bücherregal") if books else Lang.t("Stahlbeschlagene Truhe") if metal else Lang.t("Zutatenbord"), 38, game.GOLD, game.TITLE_FONT)
	var about_text := Lang.t("Münzen, Barren, Erz und rohe Edelsteine. Sie fasst beliebig viel.") if metal \
			else Lang.t("Kräuter, Pilze, Fische, Phiolen und Tierfutter. Es fasst beliebig viel.")
	if books:
		about_text = Lang.t("Alle Bücher, die du nicht bei dir trägst. Im Regal stehen: %d. Es fasst beliebig viel.") % HomeStores.total(game.home_stores, HomeStores.BOOKS)
	var about := _add_label(about_text, 16, BLUE)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = STORE_WIDTH
	_box.add_child(_store_columns([Lang.t("Bei dir"), Lang.t("Einlagern"), Lang.t("Nehmen"), Lang.t("Im Haus")]))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(STORE_WIDTH, STORE_ROWS * STORE_ROW_HEIGHT + (STORE_ROWS - 1) * 6)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(scroll)
	_store_list = scroll
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var ids := HomeStores.shown(game, store)
	if ids.is_empty():
		var empty: Label = game._make_label(game.TEXT_FONT, 16, STORE_GREY)
		empty.text = Lang.t("Noch nichts davon bei dir oder hier. Münzen, Barren, Erz und Edelsteine kommen hier hinein, sobald du welche hast.") if metal \
				else Lang.t("Noch kein Buch bei dir oder hier. Bücher aus deiner Tasche kommen hier hinein, sobald du welche hast.") if books \
				else Lang.t("Noch nichts davon bei dir oder hier. Zutaten aus deinem Beutel und Tierfutter aus der Tasche kommen hier hinein, sobald du welche hast.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.x = STORE_WIDTH - 40
		list.add_child(empty)
	for id in ids:
		list.add_child(_store_row(id))
	if _store_scroll > 0:
		scroll.set_deferred("scroll_vertical", _store_scroll)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var any_carried := ids.any(func(id): return HomeStores.carried(game, id) > 0)
	var any_stored := ids.any(func(id): return HomeStores.stored(game, id) > 0)
	for b in [[Lang.t("Alles einlagern"), func(): _store_all(store, true), any_carried],
			[Lang.t("Alles nehmen"), func(): _store_all(store, false), any_stored]]:
		var button := _item_button(b[0], b[1], b[2])
		button.custom_minimum_size = Vector2(220, 52)
		row.add_child(button)


## The line over the list naming its columns, laid out as a row is.
func _store_columns(titles: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.custom_minimum_size.x = STORE_WIDTH
	var lead := Control.new()
	lead.custom_minimum_size.x = 6 + 40 + 10 + STORE_NAME_WIDTH
	row.add_child(lead)
	var widths := [STORE_COUNT_WIDTH, STORE_BUTTON.x * 2 + 6, STORE_BUTTON.x * 2 + 6, STORE_COUNT_WIDTH]
	for i in titles.size():
		var l: Label = game._make_label(game.TEXT_FONT, 16, STORE_GREY)
		l.text = titles[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = widths[i]
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
	return row


## One kind in a store's window: picture and name, how many the hero has,
## store one or all, take one or all, how many lie at home.
func _store_row(id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(STORE_WIDTH - 14, STORE_ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", TradeWindow._style(Color(0.09, 0.065, 0.045, 0.95), Color(0.85, 0.66, 0.32, 0.3), 8, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(ItemIcon.make(id, 40))
	var name_label: Label = game._make_label(game.TEXT_FONT, 16, TradeWindow.name_color(id, Color.WHITE))
	name_label.text = store_kind_name(id)
	name_label.custom_minimum_size.x = STORE_NAME_WIDTH
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var have := HomeStores.carried(game, id)
	var kept := HomeStores.stored(game, id)
	row.add_child(_store_count(have))
	var small := str(HomeStores.step(id))
	row.add_child(_store_pair([[small, func(): _store_move(id, HomeStores.step(id), true), have > 0],
			[Lang.t("Alle"), func(): _store_move(id, have, true), have > 0]]))
	row.add_child(_store_pair([[small, func(): _store_move(id, HomeStores.step(id), false), kept > 0],
			[Lang.t("Alle"), func(): _store_move(id, kept, false), kept > 0]]))
	row.add_child(_store_count(kept))
	return panel


func _store_count(n: int) -> Label:
	var l: Label = game._make_label(game.TEXT_FONT, 18, Color.WHITE if n > 0 else STORE_GREY)
	l.text = str(n)
	l.custom_minimum_size.x = STORE_COUNT_WIDTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _store_pair(buttons: Array) -> Control:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	for b in buttons:
		var button := _item_button(b[0], b[1], b[2])
		button.custom_minimum_size = STORE_BUTTON
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(button)
	return pair


## The name of a kind in the stores: coins, bars, ingredients or items.
static func store_kind_name(id: String) -> String:
	if id == HomeStores.COINS:
		return Lang.t("Kupfermünzen")
	if Items.ALL.has(id):
		return Items.item_name(id)
	return Crafting.ingredient_name(id)


## Moves `count` of a kind into its store (`in` true) or out of it.
func _store_move(id: String, count: int, into: bool) -> void:
	var moved := HomeStores.put(game, id, count) if into else HomeStores.take(game, id, count)
	if moved > 0:
		_note = (Lang.t("%d × %s eingelagert.") if into else Lang.t("%d × %s genommen.")) % [moved, store_kind_name(id)]
		if id == HomeStores.COINS:
			Sfx.play(game, "coin")
	elif not into:
		_note = Lang.t("Deine Tasche ist voll.")
	_after_store_move()


func _store_all(store: String, into: bool) -> void:
	var moved := HomeStores.put_all(game, store) if into else HomeStores.take_all(game, store)
	if moved > 0:
		_note = Lang.t("%d Dinge eingelagert.") % moved if into else Lang.t("%d Dinge genommen.") % moved
	elif not into:
		_note = Lang.t("Deine Tasche ist voll.")
	_after_store_move()


func _after_store_move() -> void:
	game.refresh_bookshelf()
	game._update_hud()
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
	# The fine metalwork bench is where the hero forges by hand: every piece
	# Gorm could forge, but with the d100 roll (see Forge.chance).
	if bench == Forge.BENCH_CRAFT:
		var head: Label = game._make_label(game.TEXT_FONT, 22, game.GOLD)
		head.text = Lang.t("Selbst schmieden")
		list.add_child(head)
		var about: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		about.text = Lang.t("Hier schmiedest du von Hand, was deine Schmiedekunst erlaubt. Es kann misslingen: Dann ist die Hälfte der Barren verloren und das Kupfer für die Arbeit ausgegeben. Gorm schmiedet dagegen immer sicher.")
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size.x = BENCH_LIST_SIZE.x - 20
		list.add_child(about)
		for id in Forge.recipes():
			list.add_child(_hand_forge_row(id))
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
	# A long name and effect wrap instead of widening the window.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 560
	text.add_child(title)
	# Each material on a line of its own colour: green when there is enough,
	# red with the number that is missing (see Needs).
	var needs := HFlowContainer.new()
	needs.add_theme_constant_override("h_separation", 18)
	needs.add_theme_constant_override("v_separation", 2)
	needs.custom_minimum_size.x = 560
	text.add_child(needs)
	for ingredient in r.ingredients:
		needs.add_child(Needs.label(game, Crafting.ingredient_name(ingredient), c.have(ingredient), int(r.ingredients[ingredient])))
	if c.craft_level(r.craft) < int(r.craft_level):
		needs.add_child(Needs.label(game, Lang.t("%s Stufe") % Lang.t(Training.CRAFTS[r.craft].name), c.craft_level(r.craft), int(r.craft_level)))
	# A potion says what the hero brews now and when it gets stronger.
	var potency: String = c.potency_line(id)
	if potency != "":
		var brew: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		brew.text = potency
		brew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brew.custom_minimum_size.x = 560
		text.add_child(brew)
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


## One piece the hero can forge by hand at the fine metalwork bench: what it
## takes (have / need), the chance of success, what a failure costs, and the
## button. Rows keep one size whatever the state.
func _hand_forge_row(id: String) -> Control:
	var p: Player = game.player
	var cost := Forge.forge_cost(id, game)
	var level := Forge.craft_level(game, Forge.FORGING)
	var need := Forge.forge_level(id)
	var why := Forge.why_not_by_hand(game, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.custom_minimum_size.x = 560
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title: Label = game._make_label(game.TEXT_FONT, 20, game.GOLD)
	title.text = "%s  ·  %s" % [Items.item_name(id), Items.describe(id)]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 560
	text.add_child(title)
	var needs := HFlowContainer.new()
	needs.add_theme_constant_override("h_separation", 18)
	needs.add_theme_constant_override("v_separation", 2)
	needs.custom_minimum_size.x = 560
	text.add_child(needs)
	if int(cost.iron) > 0:
		needs.add_child(Needs.label(game, Lang.t("Eisen"), game.iron, int(cost.iron)))
	if int(cost.steel) > 0:
		needs.add_child(Needs.label(game, Lang.t("Stahl"), int(game.bars.get(Forge.STEEL, 0)), int(cost.steel)))
	needs.add_child(Needs.label(game, Lang.t("Kupfer"), game.coins, int(cost.gold)))
	if int(cost.ore) > 0:
		needs.add_child(Needs.label(game, Lang.t("Donnererz"), p.bag.count(Forge.THUNDER_ORE), int(cost.ore)))
	if need > 0:
		needs.add_child(Needs.label(game, Lang.t("Schmiedekunst Stufe"), level, need))
	var odds: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	odds.text = Forge.odds_text(game, id)
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.custom_minimum_size.x = 560
	text.add_child(odds)
	var state: Label = game._make_label(game.TEXT_FONT, 16, Color(1.0, 0.75, 0.5) if why != "" else Color(0.4, 0.92, 0.4))
	state.text = why if why != "" else Lang.t("Alles da: du kannst es schmieden.")
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.custom_minimum_size.x = 560
	text.add_child(state)
	var button := _item_button(Lang.t("Schmieden"), _forge_by_hand.bind(id), why == "")
	button.custom_minimum_size = Vector2(170, 54)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return row


func _forge_by_hand(id: String) -> void:
	var why := Forge.forge(game, id)
	if why != "":
		_note = why
	else:
		_note = Forge.result_text(id)
		Sfx.play(game, "hit" if Forge.last.success else "gear_metal_%d" % (randi() % 3))
		game.player.refresh_stats()
	game._update_hud()
	_rebuild()


func _make_recipe(id: String) -> void:
	var why: String = game.crafting.make(id)
	if why != "":
		_note = why
	else:
		var item: String = game.crafting.last_made
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
	_add_label(Lang.t("Im Beutel: %d Kupfer      Auf der Bank: %d Kupfer") % [game.coins, Bank.gold(hero)], 22)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	for b in [[Lang.t("Alles einzahlen"), func(): _pay_in(game.coins), game.coins > 0],
			[Lang.t("10 einzahlen"), func(): _pay_in(10), game.coins >= 10],
			[Lang.t("10 abheben"), func(): _pay_out(10), Bank.gold(hero) > 0],
			[Lang.t("Alles abheben"), func(): _pay_out(Bank.gold(hero)), Bank.gold(hero) > 0]]:
		row.add_child(_item_button(b[0], b[1], b[2]))
	# Silver coins from the pouch, changed into copper (see Loot.COIN_VALUE;
	# new gold coins are never changed).
	var change := HBoxContainer.new()
	change.alignment = BoxContainer.ALIGNMENT_CENTER
	change.add_theme_constant_override("separation", 12)
	_box.add_child(change)
	for coin in Loot.CHANGED:
		var have: int = game.crafting.have(coin)
		var b := _item_button(Lang.t("%d× %s wechseln (je %d Kupfer)") % [have, Crafting.ingredient_name(coin), Loot.COIN_VALUE[coin]], _exchange.bind(coin), have > 0)
		b.custom_minimum_size = Vector2(340, 44)
		change.add_child(b)
	if Bank.has_vault(hero):
		_add_label(Lang.t("Dein Schließfach im Tresorkeller hat Platz für %d Schätze.") % Bank.VAULT_SIZE, 16, BLUE)
	else:
		_add_label(Lang.t("Ein Schließfach im Tresorkeller kostet einmalig %d Kupfer (vom Bankkonto).") % Bank.VAULT_PRICE, 16, BLUE)
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


func _exchange(coin: String) -> void:
	var n: int = game.crafting.have(coin)
	var got := Loot.exchange(game, coin)
	_note = Lang.t("Gewechselt: %d× %s gegen %d Kupfer") % [n, Crafting.ingredient_name(coin), got]
	Sfx.play_coins(game, mini(got, 20))
	game._update_hud()
	# Bank and saved game must agree.
	game.save_game()
	_rebuild()


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
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag_used(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _to_vault, 6, null, true)
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
	if not game.player.bag_fits(Bank.vault_items(game.hero_name)[index]):
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
	# There is always food for the animals that can be won over: sausages,
	# apples and salt licks (see Companions).
	for kind in Companions.ORDER:
		var food: String = Companions.SPECIES[kind].food
		while game.shop_stock.count(food) < 2:
			game.shop_stock.push_front(food)
	# Grain for the hungry chicks in the village nests (see VillageBirds).
	while game.shop_stock.count(VillageBirds.SEEDS) < 2:
		game.shop_stock.push_front(VillageBirds.SEEDS)
	# And torches for the pitch-black holes in the wild (see HandTorch).
	while game.shop_stock.count(HandTorch.ITEM) < 3:
		game.shop_stock.push_front(HandTorch.ITEM)
	# And throwing knives, a full stack topped up after every sale, so the
	# belt can always be filled again (see Player.knives).
	while game.shop_stock.count(Items.KNIFE) < Items.stack_size(Items.KNIFE):
		game.shop_stock.push_front(Items.KNIFE)
	# And a backpack of each kind, so a lost one can always be replaced.
	Items.restock_backpacks(game.shop_stock)
	# And a bedroll for a camp in the wild, for a hero who has none (see Camp).
	if not game.shop_stock.has(Camp.ITEM) and not p.bag.has(Camp.ITEM) and not game.storage.has(Camp.ITEM):
		game.shop_stock.push_front(Camp.ITEM)
	_add_label(Lang.t("Händler"), 38, game.GOLD, game.TITLE_FONT)
	var gear := []
	var goods := []
	# One row per kind of item, with how many there are: rows are keyed
	# by the item, so buying or selling one never moves the others.
	if _shop_page == "kaufen":
		for id in _kinds(game.shop_stock):
			var entry := _ware_entry("ware:" + id, id, game.trader_price(Items.buy_price(id)), _buy.bind(game.shop_stock.find(id)))
			# Animal food and throwing knives never run out (see above), so
			# they show no count.
			entry.count = 1 if Items.is_food(id) or id == Items.KNIFE else game.shop_stock.count(id)
			(goods if _is_consumable(id) else gear).append(entry)
	else:
		for id in _kinds(p.bag):
			var entry := {"key": "sell:" + id, "id": id, "name": Items.item_name(id), "price": "+" + Lang.t("%d Kupfer") % sell_price(id),
					"button": Lang.t("Verkaufen"), "action": _sell.bind(p.bag.find(id)), "count": p.bag.count(id)}
			(goods if _is_consumable(id) else gear).append(entry)
	var gone := Lang.t("Ausverkauft") if _shop_page == "kaufen" else Lang.t("Verkauft")
	var empty := Lang.t("Nichts im Angebot.") if _shop_page == "kaufen" else Lang.t("Nichts davon in deiner Tasche.")
	_trade(Lang.t("Dein Kupfer: %d") % game.coins, [
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear, "empty": empty, "gone": gone},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods, "empty": empty, "gone": gone},
	], _shop_pages(Lang.t("Verkaufen (%d / %d)") % [p.bag_used(), p.bag_size()]))


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
	return {"key": key, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price,
			"button": Lang.t("Kaufen"), "action": action, "enabled": game.coins >= price and p.bag_fits(id)}


## Books, stone, ore and the like: things that are not worn.
static func _is_consumable(id: String) -> bool:
	var slot: String = Items.ALL[id].slot
	return not slot in Items.SLOTS and slot != "spezial"


func _buy(index: int) -> void:
	var id: String = game.shop_stock[index]
	var price: int = game.trader_price(Items.buy_price(id))
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
	elif not game.player.bag_fits(id):
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.coins -= price
		Events.bus().traded.emit(game.trader_role)
		game.player.bag.append(id)
		# The shop never runs out of animal food: it stays in stock.
		if not Items.is_food(id):
			game.shop_stock.remove_at(index)
		_note = Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
		var eater := Companions.eater_of(id)
		if eater != "" and not game.owns_companion(eater):
			# Where to take it, short enough for the one note line; the
			# whole hint goes into the compendium.
			if eater == "fuchs":
				_note = Lang.t("Gekauft: Wurst. Füchse leben am Waldteich westlich vom Dorf.")
				Events.teach(Pet.WHERE)
			else:
				_note = Lang.t("Gekauft: %s. %s äsen auf den Lichtungen zwischen Friedhof und Dorf.") % [Items.item_name(id), Lang.t(Companions.SPECIES[eater].plural)]
				Events.teach(Companions.WHERE_DEER)
		elif id == VillageBirds.SEEDS:
			_note = Lang.t("Gekauft: Körner. Hungrige Küken piepsen in manchen Nestern auf den Dächern.")
			Events.teach(VillageBirds.LEARN)
	_rebuild()


func _sell(index: int) -> void:
	var id: String = game.player.bag[index]
	game.coins += sell_price(id)
	game.player.bag.remove_at(index)
	game.shop_stock.append(id)
	_note = Lang.t("Verkauft: %s für %d Kupfer") % [Items.item_name(id), sell_price(id)]
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
	_trade(Lang.t("Dein Kupfer: %d") % game.coins, [
		{"key": "herbs", "title": Lang.t("Zutaten"), "icon": "kind:ore", "entries": herbs, "empty": empty},
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear, "empty": empty},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods, "empty": empty},
	], null, note)


## A row for one kind of Zarek's ingredients: how many pieces he has left,
## what the ingredient book says about it, and how many are in the pouch.
func _ingredient_entry(id: String, left: int, index: int) -> Dictionary:
	var price := Wanderer.price(id)
	# The ingredient's own picture (see ItemIcon.INGREDIENT_ICONS), never the backpack.
	var icon := id
	var lines := []
	for line in game.crafting.describe_ingredient(id).split("\n").slice(1):
		lines.append([line, TradeWindow.BLUE])
	return {"key": "herb:%s" % id, "id": id, "icon": icon, "name": Wanderer.ware_name(id),
			"price": Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price, "action": _buy_from_wanderer.bind(index),
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
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
	elif not ingredient and not game.player.bag_fits(id):
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
	var price: int = game.trader_price(Items.buy_price(STONE))
	var room: int = p.bag_size() - p.bag_used()
	_add_label(Lang.t("Steinmetz"), 38, game.GOLD, game.TITLE_FONT)
	var header := Lang.t("Dein Kupfer: %d") % game.coins
	var all := mini(room, game.coins / price) if price > 0 else room
	var have := p.bag.count(STONE)
	var detail := {"subtitle": TradeWindow.subtitle(STONE), "lines": TradeWindow.stat_lines(STONE) + [
			[Lang.t("Behauene Steinblöcke zum Bauen: Mauern, Stufen, Türme. Abstellen mit B oder im Inventar, verschieben mit der Maus: greifen, ziehen, loslassen."), TradeWindow.BLUE]]}
	var compare := {"title": Lang.t("In deiner Tasche"), "name": Lang.t("Steinblöcke: %d") % have, "icon": STONE,
			"subtitle": Lang.t("Platz für %d weitere") % room}
	_trade(header, [
		{"key": "stone", "title": Lang.t("Bausteine"), "icon": "kind:stone", "entries": [
			{"key": "back", "id": STONE, "name": Lang.t("1 zurückgeben"), "price": "+" + Lang.t("%d Kupfer") % sell_price(STONE),
					"button": Lang.t("Verkaufen"), "action": _sell_stone, "enabled": have > 0, "detail": detail, "compare": compare},
		] if _shop_page == "verkaufen" else [
			{"key": "one", "id": STONE, "name": Lang.t("1 Steinblock"), "price": Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price,
					"action": _buy_stones.bind(1), "enabled": room > 0 and game.coins >= price, "detail": detail, "compare": compare},
			{"key": "all", "id": STONE, "name": Lang.t("%d Steinblöcke") % maxi(all, 1), "price": Lang.t("%d Kupfer") % (maxi(all, 1) * price),
					"price_ok": all > 0, "action": _buy_stones.bind(all), "enabled": all > 0, "detail": detail, "compare": compare},
		]},
	], _stonemason_tabs())


func _buy_stones(count: int) -> void:
	var p: Player = game.player
	var price: int = game.trader_price(Items.buy_price(STONE))
	var bought := 0
	for i in count:
		if game.coins < price or p.bag_used() >= p.bag_size():
			break
		game.coins -= price
		p.bag.append(STONE)
		bought += 1
	if bought > 0:
		Events.bus().traded.emit(game.trader_role)
		_note = Lang.t("Gekauft: %d Steinblöcke") % bought
		Sfx.play(game, "gear_soft_0", -2.0)
	elif p.bag_used() >= p.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
	game._update_hud()
	_rebuild()


func _sell_stone() -> void:
	var p: Player = game.player
	if p.bag.has(STONE):
		p.bag.erase(STONE)
		game.coins += sell_price(STONE)
		_note = Lang.t("Verkauft: %s für %d Kupfer") % [Items.item_name(STONE), sell_price(STONE)]
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
	_add_label(Lang.t("Dein Kupfer: %d      Steinblöcke in Tasche und Truhe: %d") % [game.coins, HomeUpgrades.stones_owned(p.bag, game.storage)], 20, game.GOLD)
	_add_label(Lang.t("Steinmetz Hagen baut dir an, was du bezahlst. Steinblöcke verkauft er auch."), 16, BLUE)
	# The upgrades scroll in a region of fixed size, so the window keeps its frame however many
	# there are.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = UPGRADE_LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in HomeUpgrades.ALL:
		var up: Dictionary = HomeUpgrades.ALL[id]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var text: Label = game._make_label(game.TEXT_FONT, 16, Color.WHITE)
		text.text = Lang.t(up.name) + "\n" + Lang.t(up.text)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var built := HomeUpgrades.has(game.home_upgrades, id)
		if built:
			text.custom_minimum_size = Vector2(560, 0)
			row.add_child(text)
		else:
			# What it takes, and what is still missing (see Needs).
			var info := VBoxContainer.new()
			info.add_theme_constant_override("separation", 2)
			info.custom_minimum_size = Vector2(560, 0)
			row.add_child(info)
			info.add_child(text)
			var needs := HFlowContainer.new()
			needs.add_theme_constant_override("h_separation", 18)
			info.add_child(needs)
			needs.add_child(Needs.label(game, Lang.t("Steinblöcke"), HomeUpgrades.stones_owned(p.bag, game.storage), int(up.stones)))
			needs.add_child(Needs.label(game, Lang.t("Kupfer"), game.coins, int(up.gold)))
		var label := Lang.t("Gebaut") if built else Lang.t("Bauen\n%d Steine, %d Kupfer") % [up.stones, up.gold]
		var ok := HomeUpgrades.why_not(id, game.home_upgrades, p.bag, game.storage, game.coins) == ""
		var b := _item_button(label, _build_upgrade.bind(id), ok)
		b.custom_minimum_size = Vector2(200, 58)
		row.add_child(b)


## The fixed size of the list of house upgrades.
const UPGRADE_LIST_SIZE := Vector2(770, 330)


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
	_add_label(Lang.t("Dein Kupfer: %d") % game.coins, 20, game.GOLD)
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
		text.text = Lang.t(hunt.title) + "  ·  " + Lang.t("%d Kupfer") % hunt.gold + "\n" + Lang.t(hunt.goal)
		row.add_child(text)
		var button: Button
		if b.is_paid(id):
			text.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
			button = _item_button(Lang.t("Abgeholt"), func(): pass, false)
		elif b.is_ready(id):
			text.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
			button = _item_button(Lang.t("Kopfgeld abholen\n+%d Kupfer") % hunt.gold, _claim_bounty.bind(id))
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
		b.add_theme_font_size_override("font_size", UiKit.sized(18))
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
		_note = Lang.t("Kopfgeld erhalten: %d Kupfer") % gold
	game._update_hud()
	_rebuild()


## The workbench at home: knives from iron, and mending for iron.
func _build_workbench() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Werkbank"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Eisenbarren: %d      Wurfmesser: %d") % [game.iron, p.knives + p.spare_knives()], 20, game.GOLD)
	_add_label(Lang.t("Eisenbarren gibt es bei Schmied Gorm, oder du schmilzt dort alte Ausrüstung ein."), 16, BLUE)
	var make := _item_button(Lang.t("%d Wurfmesser schmieden\n%d Eisenbarren") % [HomeUpgrades.KNIVES_PER_IRON, 1], _make_knives, game.iron >= 1)
	make.custom_minimum_size = Vector2(320, 58)
	make.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(make)
	var knife_need := Needs.label(game, Lang.t("Eisenbarren"), game.iron, 1)
	knife_need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(knife_need)
	var worn := Forge.worn_down(p)
	if worn.is_empty():
		_add_label(Lang.t("Nichts ist abgenutzt."), 16)
		return
	_add_label(Lang.t("Abgenutzte Ausrüstung flicken (je %d Eisenbarren):") % HomeUpgrades.MEND_IRON, 16)
	var mend_need := Needs.label(game, Lang.t("Eisenbarren"), game.iron, HomeUpgrades.MEND_IRON)
	mend_need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(mend_need)
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
		game.give_knives(HomeUpgrades.KNIVES_PER_IRON)
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


# --- Cape wardrobe (see CapeWardrobe, CapeDesigns) ---------------------------------

## Size of one design's card in the cape wardrobe, and of its picture.
const CAPE_CARD := Vector2(236, 372)
const CAPE_PICTURE := Vector2(200, 214)


## The cape wardrobe's window: one card for every design with a picture of the cape's back, its
## name, a line about it and a button to wear it. The design worn now is marked (a green "Worn" tag
## and a gold border, so colour is not the only cue) and its button is dimmed. Every card has the
## same size whatever its state, so picking one moves nothing.
func _build_wardrobe() -> void:
	_add_label(Lang.t("Umhangschrank"), 38, game.GOLD, game.TITLE_FONT)
	var intro := _add_label(Lang.t("Wähle das Bild auf dem Rücken deines Umhangs. Du kannst es jederzeit wechseln."), 18, ABOUT_COLOR)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 4 * CAPE_CARD.x + 3 * 14
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(row)
	for i in CapeDesigns.DESIGNS.size():
		row.add_child(_cape_card(i))


func _cape_card(design: int) -> Control:
	var info: Dictionary = CapeDesigns.DESIGNS[design]
	var worn: bool = game.player.cape_design == design
	var card := PanelContainer.new()
	card.custom_minimum_size = CAPE_CARD
	var style := BronzeStyle.new()
	style.bg_color = Color(0.14, 0.1, 0.06, 0.9)
	style.border_color = game.GOLD if worn else Color(0.4, 0.34, 0.25, 0.6)
	style.set_border_width_all(3 if worn else 2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	# The cape's back: a dark cloth with the picture on it (none on a blank cape).
	var cloth := PanelContainer.new()
	cloth.custom_minimum_size = CAPE_PICTURE
	var cloth_style := StyleBoxFlat.new()
	cloth_style.bg_color = Color(0.2, 0.1, 0.12)
	cloth_style.set_corner_radius_all(6)
	cloth.add_theme_stylebox_override("panel", cloth_style)
	col.add_child(cloth)
	var tex := CapeDesigns.texture(design)
	if tex != null:
		var picture := TextureRect.new()
		picture.texture = tex
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloth.add_child(picture)
	var name_label := _make_wardrobe_label(Lang.t(info.name), 20, game.GOLD)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var text := _make_wardrobe_label(Lang.t(info.text), 16, ABOUT_COLOR)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.y = 70
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(text)
	var button: Button = game._make_button(Lang.t("Getragen") if worn else Lang.t("Tragen"), _wear_cape.bind(design))
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = worn
	col.add_child(button)
	return card


func _make_wardrobe_label(text: String, size: int, color: Color) -> Label:
	var l: Label = game._make_label(game.TEXT_FONT, size, color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _wear_cape(design: int) -> void:
	game.player.set_cape_design(design)
	_note = Lang.t("Du trägst jetzt: %s") % Lang.t(CapeDesigns.DESIGNS[design].name)
	_rebuild()


# --- Companions (see Companions) -------------------------------------------------

## The companion being named (index into game.companions), and the window to
## go back to when the name is given ("" closes).
var naming := -1
var _naming_back := ""
## Told once the name is given (or the naming cancelled), back in the game.
var naming_message := ""
var _name_text := ""
var _name_edit: LineEdit = null
## Sizes of the companions window's rows, so a row never changes size with
## its state or the language.
const COMPANION_ROW := Vector2(900, 92)
const COMPANION_NAME_WIDTH := 250
const COMPANION_PERK_WIDTH := 290
const COMPANION_BUTTON := Vector2(150, 52)


## The companions window, at the straw in the hero's house: one row for
## each kind (fox, doe, stag), with who goes along and who waits here.
## A kind not won over yet says how to win it over, so the window keeps
## its three rows and its size.
func _build_companions() -> void:
	_add_label(Lang.t("Gefährten"), 38, game.GOLD, game.TITLE_FONT)
	var intro := _add_label(Lang.t("Einer geht mit dir und schenkt dir seine Gabe. Die anderen warten hier auf dem Stroh."), 18, ABOUT_COLOR)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = COMPANION_ROW.x
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(rows)
	for kind in Companions.ORDER:
		rows.add_child(_companion_row(kind))
	if game.companions.size() > 1 or game.following < 0:
		var nobody: Button = game._make_button(Lang.t("Alle hierlassen"), _take_companion.bind(-1))
		nobody.custom_minimum_size = Vector2(220, 52)
		nobody.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nobody.disabled = game.following < 0
		_box.add_child(nobody)


func _companion_row(kind: String) -> Control:
	var index := -1
	for i in game.companions.size():
		if game.companions[i].kind == kind:
			index = i
	var tame := index >= 0
	var at_side: bool = tame and index == game.following
	var row := PanelContainer.new()
	var style := BronzeStyle.new()
	style.bg_color = Color(0.14, 0.1, 0.06, 0.9) if tame else Color(0.09, 0.07, 0.05, 0.7)
	style.border_color = game.GOLD if at_side else Color(0.4, 0.34, 0.25, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size = COMPANION_ROW
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(line)
	var icon := ItemIcon.make("kind:paw:" + kind, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = Color.WHITE if tame else Color(1, 1, 1, 0.45)
	line.add_child(icon)
	# Who it is: its name, then its kind and where it is.
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 4)
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.custom_minimum_size.x = COMPANION_NAME_WIDTH
	line.add_child(who)
	var name_label: Label = game._make_label(game.TEXT_FONT, 22, game.GOLD if tame else TradeWindow.GREY)
	name_label.text = game.companions[index].name if tame else Companions.species_name(kind)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = COMPANION_NAME_WIDTH
	who.add_child(name_label)
	var where: Label = game._make_label(game.TEXT_FONT, 16, Color.WHITE if at_side else ABOUT_COLOR)
	if at_side:
		where.text = Lang.t("%s · geht mit dir") % Companions.species_name(kind)
	elif tame:
		where.text = Lang.t("%s · wartet hier") % Companions.species_name(kind)
	else:
		where.text = Lang.t("Noch nicht gezähmt")
	who.add_child(where)
	# What it gives, and for one not won over yet: how.
	var what := VBoxContainer.new()
	what.add_theme_constant_override("separation", 4)
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.custom_minimum_size.x = COMPANION_PERK_WIDTH
	line.add_child(what)
	var perk: Label = game._make_label(game.TEXT_FONT, 16, BLUE if tame else TradeWindow.GREY)
	perk.text = Lang.t("Gabe: %s") % Companions.perk_text(kind)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.custom_minimum_size.x = COMPANION_PERK_WIDTH
	what.add_child(perk)
	if not tame:
		var how: Label = game._make_label(game.TEXT_FONT, 16, Color(1.0, 0.85, 0.55))
		how.text = Lang.t("Zähmen mit: %s (%d / %d)") % [Items.item_name(Companions.SPECIES[kind].food), int(game.trust.get(kind, 0)), Companions.TRUST_NEEDED]
		how.custom_minimum_size.x = COMPANION_PERK_WIDTH
		what.add_child(how)
	# Its buttons, or the same room left empty.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(buttons)
	if tame:
		var take: Button = game._make_button(Lang.t("Hierlassen") if at_side else Lang.t("Mitnehmen"), _take_companion.bind(-1 if at_side else index))
		take.custom_minimum_size = COMPANION_BUTTON
		take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buttons.add_child(take)
		var rename: Button = game._make_button(Lang.t("Umbenennen"), _rename_companion.bind(index))
		rename.custom_minimum_size = COMPANION_BUTTON
		rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buttons.add_child(rename)
	else:
		var room := Control.new()
		room.custom_minimum_size = Vector2(COMPANION_BUTTON.x * 2 + 8, COMPANION_BUTTON.y)
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons.add_child(room)
	return row


func _take_companion(index: int) -> void:
	var before: Dictionary = game.companion()
	game.take_companion(index)
	var now: Dictionary = game.companion()
	if now.is_empty():
		_note = Lang.t("%s bleibt hier auf dem Stroh.") % before.name if not before.is_empty() else ""
	else:
		_note = Lang.t("%s geht jetzt mit dir: %s") % [now.name, Companions.perk_text(now.kind)]
	_rebuild()


func _rename_companion(index: int) -> void:
	naming = index
	_naming_back = "gefaehrten"
	naming_message = ""
	open("gefaehrte_name")


## Names a companion: just won over, or renamed at home. The name field is
## ready for typing; Enter or "Fertig" keeps the name, Esc keeps the old one.
func _build_naming() -> void:
	if naming < 0 or naming >= game.companions.size():
		close()
		return
	var c: Dictionary = game.companions[naming]
	if _name_edit == null or not is_instance_valid(_name_edit) or _name_edit.get_meta("for", -1) != naming:
		_name_text = c.name
	_add_label(Lang.t(Companions.SPECIES[c.kind].ask), 32, game.GOLD, game.TITLE_FONT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	row.add_child(ItemIcon.make("kind:paw:" + c.kind, 56))
	var perk: Label = game._make_label(game.TEXT_FONT, 18, BLUE)
	perk.text = Lang.t("Gabe: %s") % Companions.perk_text(c.kind)
	row.add_child(perk)
	var edit := LineEdit.new()
	edit.max_length = Companions.NAME_MAX
	edit.text = _name_text
	edit.placeholder_text = Companions.species_name(c.kind)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(320, 52)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.add_theme_font_override("font", game.TEXT_FONT)
	edit.add_theme_font_size_override("font_size", UiKit.sized(22))
	edit.add_theme_stylebox_override("normal", panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	edit.add_theme_stylebox_override("focus", panel_style(game.GOLD))
	for style in ["normal", "focus"]:
		edit.get_theme_stylebox(style).set_content_margin_all(8)
	edit.set_meta("for", naming)
	edit.text_changed.connect(func(t): _name_text = t)
	edit.text_submitted.connect(func(_t): _give_name())
	_box.add_child(edit)
	_name_edit = edit
	var hint := _add_label(Lang.t("Bis zu %d Zeichen. Umbenennen kannst du später zu Hause am Stroh.") % Companions.NAME_MAX, 16, ABOUT_COLOR)
	hint.custom_minimum_size.y = 24
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_box.add_child(buttons)
	var done: Button = game._make_button(Lang.t("Fertig"), _give_name)
	done.custom_minimum_size = Vector2(220, 60)
	buttons.add_child(done)
	var cancel: Button = game._make_button(Lang.t("Abbrechen"), _end_naming)
	cancel.custom_minimum_size = Vector2(220, 60)
	buttons.add_child(cancel)
	# Ready to type at once (a text field, not a button: Space only types).
	edit.call_deferred("grab_focus")
	edit.call_deferred("select_all")


func _give_name() -> void:
	var old: String = game.companions[naming].name
	game.rename_companion(naming, _name_text)
	var now: String = game.companions[naming].name
	_end_naming(Lang.t("%s heißt jetzt %s.") % [old, now] if now != old else "")


## Back to the companions window (renaming at home), or back to the game.
func _end_naming(note := "") -> void:
	var back := _naming_back
	if back == "":
		close()
		return
	naming = -1
	_naming_back = ""
	_name_edit = null
	open(back)
	_note = note
	_rebuild()


# --- Smith -------------------------------------------------------------------

## The smith's window shows one of four tabs: "waffen" (buy Gorm's own
## weapons), "schmieden" (forge new gear),
## "einschmelzen" (melt gear down into metal, and sell the fine bars) or
## "ausbessern" (mend worn gear).
var _forge_tab := "waffen"
const FORGE_ABOUT := {
	"waffen": "Gorms eigene Arbeit: bessere Waffen, die es sonst nirgends gibt. Kriegshammer und Drachenschild schmiedet er nur aus deinem Eisen.",
	"schmieden": "Aus Eisen und etwas Kupfer schmiedet Gorm dir neue Waffen, Schilde und Rüstungen. Mit Donnererz vom Gewitter schmiedet er Donnerwaffen, deren Treffer Gegner kurz betäuben können.",
	"einschmelzen": "Waffen und Rüstungen werden zu Eisen, feine Stücke und Schmuck zu Bronze, Silber oder Gold, je seltener, desto edler; Zauberdinge lassen Mondsilber. Je hundert Münzen einer Sorte werden zu einem Barren. Die edlen Barren kauft Gorm dir ab. Stoff, Leder, Fell und Knochen schmelzen nicht.",
	"ausbessern": "Gorm hämmert Beulen aus: jeder Punkt Haltbarkeit kostet etwas Kupfer.",
}
const FORGE_TABS := [["waffen", "Waffen kaufen"], ["schmieden", "Schmieden"], ["einschmelzen", "Einschmelzen"], ["ausbessern", "Ausbessern"]]


func _build_smithy() -> void:
	var p: Player = game.player
	Events.teach(Forge.LEARN)
	Events.teach(Forge.STEEL_LEARN)
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
	var room: bool = p.bag_used() < p.bag_size()
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
				var ok := Forge.can_afford(game, id)
				var entry := {"key": id, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Eisen, %d Kupfer") % [cost.iron, cost.gold],
						"price_ok": game.iron >= cost.iron and game.coins >= cost.gold, "button": Lang.t("Schmieden"), "action": _forge.bind(id), "enabled": ok and room}
				var level := Forge.craft_level(game, Forge.FORGING)
				var need := Forge.forge_level(id)
				if Forge.is_steel(id):
					# Steel gear: steel bars in place of iron, and a level of
					# Schmiedekunst. Until the hero has it, the price line says so.
					entry.price = Lang.t("%d Stahl, %d Kupfer") % [cost.steel, cost.gold] if level >= need else Lang.t("Braucht Schmiedekunst %d") % need
					entry.price_ok = level >= need and int(game.bars.get(Forge.STEEL, 0)) >= int(cost.steel) and game.coins >= cost.gold
				# Every piece lists what it takes and what is still missing, the same
				# lines for all (see Needs).
				var lines := TradeWindow.stat_lines(id)
				if int(cost.iron) > 0:
					lines.append(Needs.line(Lang.t("Eisen"), game.iron, int(cost.iron)))
				if int(cost.steel) > 0:
					lines.append(Needs.line(Lang.t("Stahl"), int(game.bars.get(Forge.STEEL, 0)), int(cost.steel)))
				lines.append(Needs.line(Lang.t("Kupfer"), game.coins, int(cost.gold)))
				if int(cost.ore) > 0:
					lines.append(Needs.line(Lang.t("Donnererz"), p.bag.count(Forge.THUNDER_ORE), int(cost.ore)))
				if need > 0:
					lines.append(Needs.line(Lang.t("Schmiedekunst Stufe"), level, need))
				lines.append([Lang.t("Gorm schmiedet es dir sicher, ohne Fehlschlag."), TradeWindow.BLUE])
				if not room:
					lines.append([Lang.t("✗ Deine Tasche ist voll"), TradeWindow.RED])
				if Forge.in_stock(game, id) > 0:
					lines.append([Lang.t("Gorm hat %d fertig, zum Kaufen unten") % Forge.in_stock(game, id), TradeWindow.BLUE])
				entry.detail = {"subtitle": TradeWindow.subtitle(id), "lines": lines}
				forged.append(entry)
			# The pieces Gorm has finished on his shelf: bought as they are.
			var ready := []
			for id in Forge.recipes():
				var n := Forge.in_stock(game, id)
				if n <= 0:
					continue
				var ready_price := Forge.ware_price(game, id)
				var lines := TradeWindow.stat_lines(id)
				lines.append(Needs.line(Lang.t("Kupfer"), game.coins, ready_price))
				if not room:
					lines.append([Lang.t("✗ Deine Tasche ist voll"), TradeWindow.RED])
				ready.append({"key": "ready:" + id, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Kupfer") % ready_price,
						"price_ok": game.coins >= ready_price, "button": Lang.t("Kaufen"), "action": _buy_finished.bind(id),
						"enabled": game.coins >= ready_price and room, "count": n,
						"detail": {"subtitle": TradeWindow.subtitle(id), "lines": lines}})
			var iron := []
			for count in [1, 5]:
				var price: int = count * Forge.iron_price(game)
				iron.append({"key": "iron%d" % count, "icon": "kind:iron", "name": Lang.t("%d Eisenbarren") % count, "price": Lang.t("%d Kupfer") % price,
						"price_ok": game.coins >= price, "action": _buy_iron.bind(count), "enabled": game.coins >= price,
						"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t("Aus Eisen und etwas Kupfer schmiedet Gorm dir neue Waffen, Schilde und Rüstungen."), TradeWindow.BLUE]]},
						"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("Eisen: %d") % game.iron, "icon": "kind:iron"}})
			sections = [
				{"key": "forge", "title": Lang.t("Schmieden"), "icon": "kind:hammer_anvil", "entries": forged},
				{"key": "ready", "title": Lang.t("Fertig vom Schmied"), "icon": "kind:sword", "entries": ready,
						"empty": Lang.t("Gorm hat gerade nichts Fertiges da. Jeden Morgen legt er ein paar Stücke nach.")},
				{"key": "steel", "title": Lang.t("Stahl"), "icon": "kind:bar_" + Forge.STEEL, "entries": _steel_entries()},
				{"key": "iron", "title": Lang.t("Eisenbarren"), "icon": "kind:iron", "entries": iron},
			]
		"einschmelzen":
			var melt := []
			for id in _kinds(p.bag):
				var can := Forge.can_melt(id)
				melt.append({"key": "melt:" + id, "id": id, "name": Items.item_name(id), "price": Forge.metals_text(Forge.melt_into(id), true) if can else Lang.t("Schmilzt nicht"), "price_ok": can,
						"button": Lang.t("Einschmelzen"), "action": _melt.bind(p.bag.find(id)), "enabled": can, "count": p.bag.count(id)})
			# The fine bars the hero has: Gorm buys them, one bar at a time.
			var fine := []
			for metal in Forge.FINE:
				if not Forge.METALS[metal].has("worth"):
					continue
				var have := int(game.bars.get(metal, 0))
				var worth: int = Forge.METALS[metal].worth
				var entry := {"key": "bar:" + metal, "icon": "kind:bar_" + metal, "name": Lang.t(Forge.METALS[metal].name), "price": "+" + Lang.t("%d Kupfer") % worth,
						"price_ok": have > 0, "button": Lang.t("Verkaufen"), "action": _sell_bar.bind(metal), "enabled": have > 0, "count": have,
						"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t("Aus fein gearbeiteten Stücken und Schmuck geschmolzen. Gorm kauft jeden Barren für %d Kupfer.") % worth, TradeWindow.BLUE]]},
						"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("%s: %d") % [Lang.t(Forge.METALS[metal].name), have], "icon": "kind:bar_" + metal}}
				if have <= 0:
					entry.gone = Lang.t("Keine")
				fine.append(entry)
			# The pouch coins from fallen foes (see Loot.COINS): a hundred of
			# one metal melt into one bar of it.
			var coins := []
			for coin in Loot.COINS:
				var have: int = game.crafting.have(coin)
				var metal: String = Loot.COINS[coin]
				var bar := Lang.t(Forge.METALS[metal].name)
				var icon: String = "kind:iron" if metal == "eisen" else "kind:bar_" + metal
				var ok := have >= Loot.COINS_PER_BAR
				coins.append({"key": "coins:" + coin, "icon": coin, "name": Crafting.ingredient_name(coin), "price": Lang.t("%d Münzen: 1 %s") % [Loot.COINS_PER_BAR, bar],
						"price_ok": ok, "button": Lang.t("Einschmelzen"), "action": _melt_coins.bind(coin), "enabled": ok, "count": have,
						"detail": {"subtitle": Lang.t("Münzen"), "lines": [[Lang.t("Gorm schmilzt je %d Münzen zu einem %s ein.") % [Loot.COINS_PER_BAR, bar], TradeWindow.BLUE],
							[Lang.t("Du hast %d, genug für %d.") % [have, have / Loot.COINS_PER_BAR], TradeWindow.GREEN if ok else TradeWindow.GREY]]},
						"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("%s: %d") % [bar, game.crafting.have(metal)], "icon": icon}})
			# Raw ore from the mountains (see Ore): the oldest lump of each
			# size melts first, into grams of the metals in it.
			var ore := []
			for lump_id in Ore.LUMPS:
				var lumps: Array = game.crafting.ores.get(lump_id, [])
				var next: Dictionary = lumps[0] if not lumps.is_empty() else {}
				var entry := {"key": "ore:" + lump_id, "icon": lump_id, "name": Crafting.ingredient_name(lump_id),
						"price": "%d g" % int(next.grams) if not next.is_empty() else "", "price_ok": not next.is_empty(),
						"button": Lang.t("Einschmelzen"), "action": _melt_ore.bind(lump_id), "enabled": not next.is_empty(), "count": lumps.size(),
						"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Ore.guess(lump_id, next) if not next.is_empty() else Lang.t("Keiner"), TradeWindow.BLUE],
							[Lang.t("Je %d g eines Metalls werden ein Barren.") % Ore.GRAMS_PER_BAR, TradeWindow.GREY]]},
						"compare": {"title": Lang.t("Übrig vom Schmelzen"), "name": Ore.grams_text(game.metal_grams), "icon": "kind:ore"}}
				if next.is_empty():
					entry.gone = Lang.t("Keiner")
				ore.append(entry)
			sections = [{"key": "melt", "title": Lang.t("Einschmelzen"), "icon": "kind:flame", "entries": melt,
					"empty": Lang.t("Deine Tasche ist leer."), "gone": Lang.t("Eingeschmolzen")},
					{"key": "ore", "title": Lang.t("Erz einschmelzen"), "icon": "kind:ore", "entries": ore},
					{"key": "gems", "title": Lang.t("Edelsteine"), "icon": "kind:crystal", "entries": _gem_entries()},
					{"key": "coins", "title": Lang.t("Münzen einschmelzen"), "icon": "kind:coin", "entries": coins},
					{"key": "bars", "title": Lang.t("Barren verkaufen"), "icon": "kind:bar_gold", "entries": fine}]
		"ausbessern":
			var mend := []
			for id in Forge.worn_down(p):
				var durability: int = Items.ALL[id].durability
				var left: int = durability - int(p.wear[id])
				mend.append({"key": id, "id": id, "name": "%s  %d / %d" % [Items.item_name(id), left, durability],
						"price": Lang.t("%d Kupfer") % Forge.mend_cost(p, id, game), "price_ok": game.coins >= Forge.mend_price(id, game),
						"button": Lang.t("Ausbessern"), "action": _mend.bind(id), "enabled": game.coins >= Forge.mend_price(id, game),
						"detail": {"subtitle": TradeWindow.subtitle(id), "lines": TradeWindow.stat_lines(id, int(p.wear[id])) + [Needs.line(Lang.t("Kupfer"), game.coins, Forge.mend_cost(p, id, game))]}})
			sections = [{"key": "mend", "title": Lang.t("Ausbessern"), "icon": "kind:hammer_anvil", "entries": mend, "gone": Lang.t("Wie neu"),
					"empty": Lang.t("Deine Ausrüstung ist heil.")}]
	_trade(Lang.t("Dein Kupfer: %d    Eisen: %d    Stahl: %d") % [game.coins, game.iron, int(game.bars.get(Forge.STEEL, 0))], sections, tabs, Lang.t(FORGE_ABOUT[_forge_tab]))


## The forge's steel rows: make a steel bar (iron, charcoal, limestone, and a
## level of Stahlkochen, see Forge.make_steel), and buy charcoal.
func _steel_entries() -> Array:
	var out := []
	var level := Forge.craft_level(game, Forge.STEEL_MAKING)
	var need := Forge.STEEL_MAKING_LEVEL
	var why := Forge.why_no_steel(game)
	var steel := int(game.bars.get(Forge.STEEL, 0))
	var lines := [[Lang.t("Ein Eisenbarren, mit Holzkohle und Kalkstein gekocht, wird ein Stahlbarren. Stahlrüstung schmiedet Gorm nur aus Stahl."), TradeWindow.BLUE],
			Needs.line(Lang.t("Stahlkochen Stufe"), level, need)]
	for ingredient in Forge.STEEL_RECIPE:
		lines.append(Needs.line(Crafting.ingredient_name(ingredient), game.crafting.have(ingredient), int(Forge.STEEL_RECIPE[ingredient])))
	out.append({"key": "steel:make", "icon": "kind:bar_" + Forge.STEEL, "name": Lang.t("Stahlbarren"), "count": steel,
			"price": Lang.t("1 Eisen, 1 Holzkohle, 1 Kalkstein") if level >= need else Lang.t("Braucht Stahlkochen %d") % need, "price_ok": why == "",
			"button": Lang.t("Kochen"), "action": _make_steel, "enabled": why == "",
			"detail": {"subtitle": Lang.t("Rohstoff"), "lines": lines},
			"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("%s: %d") % [Lang.t("Stahlbarren"), steel], "icon": "kind:bar_" + Forge.STEEL}})
	for count in [1, 5]:
		var price: int = count * Forge.charcoal_price(game)
		out.append({"key": "charcoal%d" % count, "icon": Forge.CHARCOAL, "name": Lang.t("%d Holzkohle") % count, "price": Lang.t("%d Kupfer") % price,
				"price_ok": game.coins >= price, "action": _buy_charcoal.bind(count), "enabled": game.coins >= price,
				"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t(Crafting.INGREDIENTS[Forge.CHARCOAL].where), TradeWindow.BLUE]]},
				"compare": {"title": Lang.t("Dein Vorrat"), "name": Lang.t("%s: %d") % [Crafting.ingredient_name(Forge.CHARCOAL), game.crafting.have(Forge.CHARCOAL)], "icon": Forge.CHARCOAL}})
	return out


func _make_steel() -> void:
	var why := Forge.make_steel(game)
	_note = why if why != "" else Lang.t("Gekocht: 1 Stahlbarren")
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _buy_charcoal(count: int) -> void:
	var why := Forge.buy_charcoal(game, count)
	if why == "":
		Events.bus().traded.emit(game.trader_role)
	_note = why if why != "" else Lang.t("Gekauft: %d Holzkohle") % count
	game._update_hud()
	_rebuild()


func _show_forge_tab(tab: String) -> void:
	_forge_tab = tab
	trade.reset()
	_note = ""
	_rebuild()


func _forge(id: String) -> void:
	var why := Forge.forge(game, id, true)
	if why != "":
		_note = why
	else:
		_note = Lang.t("Geschmiedet: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
		Events.bus().traded.emit(game.trader_role)
		Sfx.play(game, "hit" if Forge.last.success else "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _buy_finished(id: String) -> void:
	var why := Forge.buy_finished(game, id)
	if why == "":
		Events.bus().traded.emit(game.trader_role)
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	_note = why if why != "" else Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	game._update_hud()
	_rebuild()


func _melt(index: int) -> void:
	var id: String = game.player.bag[index]
	var why := Forge.melt(game, index)
	_note = why if why != "" else Lang.t("Eingeschmolzen: %s, %s") % [Items.item_name(id), Forge.metals_text(Forge.melt_into(id), true)]
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game.player.refresh_stats()
	game._update_hud()
	_rebuild()


## The forge's gem rows (see Ore.GEMS): cut the oldest uncut gem, sell the
## oldest cut one. A gem's rarity follows its weight, named in words.
func _gem_entries() -> Array:
	var out := []
	var uncut: Array = game.crafting.gems.get(Ore.UNCUT, [])
	var cut: Array = game.crafting.gems.get(Ore.CUT, [])
	var a := {"key": "gem:cut", "icon": Ore.UNCUT, "name": Crafting.ingredient_name(Ore.UNCUT), "count": uncut.size(),
			"price": _carat_text(int(uncut[0])) if not uncut.is_empty() else "", "price_ok": not uncut.is_empty(),
			"button": Lang.t("Schleifen"), "action": _cut_gem, "enabled": not uncut.is_empty(),
			"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t("Gorm schleift ihn. Dabei verliert er 15 bis 50 Prozent seines Gewichts, und seine Seltenheit richtet sich nach dem, was bleibt."), TradeWindow.BLUE]]}}
	if uncut.is_empty():
		a.gone = Lang.t("Keiner")
	out.append(a)
	var worth := Ore.gem_worth(int(cut[0])) if not cut.is_empty() else 0
	var b := {"key": "gem:sell", "icon": Ore.CUT, "name": Crafting.ingredient_name(Ore.CUT), "count": cut.size(),
			"price": "%s, +%s" % [_carat_text(int(cut[0])), Lang.t("%d Kupfer") % worth] if not cut.is_empty() else "", "price_ok": not cut.is_empty(),
			"button": Lang.t("Verkaufen"), "action": _sell_gem, "enabled": not cut.is_empty(),
			"detail": {"subtitle": Lang.t("Rohstoff"), "lines": [[Lang.t("Je mehr Karat, desto seltener und wertvoller. Gorm kauft geschliffene Edelsteine."), TradeWindow.BLUE]]}}
	if cut.is_empty():
		b.gone = Lang.t("Keiner")
	out.append(b)
	return out


## A gem's weight and rarity in words: "14 ct, Rare".
static func _carat_text(carat: int) -> String:
	return "%d ct, %s" % [carat, Lang.t(Rarity.TIERS[Ore.gem_tier(carat)].name)]


func _cut_gem() -> void:
	var out := Forge.cut_gem(game)
	_note = out.why if out.why != "" else Lang.t("Geschliffen: %d ct werden %d ct (%s)") % [out.from, out.to, Lang.t(Rarity.TIERS[Ore.gem_tier(out.to)].name)]
	if out.why == "":
		Sfx.play(game, "hit")
	_rebuild()


func _sell_gem() -> void:
	var carat := int(game.crafting.gems.get(Ore.CUT, [0])[0])
	var why := Forge.sell_gem(game)
	_note = why if why != "" else Lang.t("Verkauft: %s für %d Kupfer") % [_carat_text(carat), Ore.gem_worth(carat)]
	if why == "":
		Events.bus().traded.emit(game.trader_role)
		Sfx.play_coins(game, Ore.gem_worth(carat))
	game._update_hud()
	_rebuild()


func _melt_ore(id: String) -> void:
	var out := Forge.melt_ore(game, id)
	_note = out.why if out.why != "" else Lang.t("Eingeschmolzen: %s, %d g Schlacke (%d %%), %s") % [Crafting.ingredient_name(id), int(out.slag), int(out.share.get(Ore.SLAG, 0)), Ore.grams_text(out.grams)]
	if out.why == "" and not out.bars.is_empty():
		_note += "  " + Forge.metals_text(out.bars, true)
	if out.why == "" and not out.gems.is_empty():
		_note += "  " + Lang.t("+%d ungeschliffene Edelsteine") % out.gems.size()
	if out.why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _melt_coins(coin: String) -> void:
	var why := Forge.melt_coins(game, coin)
	_note = why if why != "" else Lang.t("Eingeschmolzen: %d× %s, +1 %s") % [Loot.COINS_PER_BAR, Crafting.ingredient_name(coin), Lang.t(Forge.METALS[Loot.COINS[coin]].name)]
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _sell_bar(metal: String) -> void:
	var why := Forge.sell_bars(game, metal, 1)
	_note = why if why != "" else Lang.t("Verkauft: %s für %d Kupfer") % [Lang.t(Forge.METALS[metal].name), int(Forge.METALS[metal].worth)]
	if why == "":
		Events.bus().traded.emit(game.trader_role)
		Sfx.play_coins(game, int(Forge.METALS[metal].worth))
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


# --- Temple -----------------------------------------------------------------

## Priestess Elsbeth's window: the gods of the village and the blessing the
## hero carries (see Blessing). One list, one row per god; the god the hero
## is blessed by shows what is left, and the others wait until it is gone.
func _build_temple() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Tempel"), 38, game.GOLD, game.TITLE_FONT)
	var blessed := p.blessing_god != ""
	var now := {"title": Lang.t("Derzeit"), "name": Lang.t("Kein Segen"), "subtitle": Lang.t("Segen"), "icon": "kind:heal_potion",
			"lines": [[Lang.t("Wähle einen Gott. Der erste Segen ist umsonst."), TradeWindow.GREY]]}
	if blessed:
		var held: Dictionary = Blessing.GODS[p.blessing_god]
		now = {"title": Lang.t("Derzeit"), "name": Lang.t(held.name), "subtitle": Blessing.title(p.blessing_god, p.blessing_thirds),
				"icon": held.icon, "lines": _blessing_lines(p.blessing_god, p.blessing_thirds)}
	var entries := []
	for id in Blessing.ORDER:
		var god: Dictionary = Blessing.GODS[id]
		var mine: bool = p.blessing_god == id
		var price: int = Blessing.price_renew(p.blessing_thirds) if mine else Blessing.price_new(p.blessed_before)
		var detail_lines := [[Lang.t(god.tale), TradeWindow.BLUE]] + _blessing_lines(id, Blessing.FULL)
		detail_lines.append([Lang.t("Jede Rettung nimmt ein Drittel des Segens. Nach drei Rettungen ist er fort."), TradeWindow.GREY])
		var can := false
		var button := Lang.t("Segnen")
		if mine:
			button = Lang.t("Erneuern")
			can = p.blessing_thirds < Blessing.FULL and game.coins >= price
		elif blessed:
			detail_lines.append([Lang.t("Du bist deinem Gott treu, bis sein Segen erlischt."), TradeWindow.ORANGE])
		else:
			can = game.coins >= price
		entries.append({"key": "god:" + id, "icon": god.icon, "name": Lang.t(god.name),
				"price": Lang.t("Umsonst") if price == 0 else Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price,
				"button": button, "action": _bless.bind(id, price), "enabled": can,
				"current": mine and p.blessing_thirds >= Blessing.FULL,
				"detail": {"subtitle": Lang.t(god.title), "lines": detail_lines}, "compare": now})
	_trade(Lang.t("Dein Kupfer: %d") % game.coins, [
		{"key": "gods", "title": Lang.t("Die Götter"), "icon": "kind:heal_potion", "entries": entries},
		{"key": "healing", "title": Lang.t("Heilung"), "icon": "kind:herb", "entries": _healing_entries()},
	], null, Lang.t("Wähle einen Gott und lass dich von Elsbeth segnen. Der Segen schützt dich, solange du ihn hast."))


## The altar of the healing goddess (see Injury): one row, a prayer that
## takes the injury away for an offering (less, with her blessing).
func _healing_entries() -> Array:
	var p: Player = game.player
	var god: Dictionary = Blessing.GODS[Blessing.HEALER]
	var price := Injury.prayer_price(p)
	var lines := [[Lang.t("Mirenna nimmt Verletzungen von dir, auch die, die nie von selbst heilen."), TradeWindow.BLUE]]
	var now := {"title": Lang.t("Derzeit"), "name": Lang.t("Keine Verletzung"), "subtitle": Lang.t("Verletzung"), "icon": "kind:herb", "lines": []}
	var can := false
	var button := Lang.t("Beten")
	if p.injury != "":
		now = {"title": Lang.t("Derzeit"), "name": Injury.title(p.injury, p.injury_severity), "subtitle": Lang.t("Verletzung"), "icon": "kind:herb",
				"lines": [[Injury.effect_text(p.injury, p.injury_severity), TradeWindow.RED], [Injury.how_to_heal(p.injury, p.injury_severity), TradeWindow.GREY]]}
		can = Injury.heals_at_village(p) and game.coins >= price
		if not Injury.heals_at_village(p):
			lines.append([Lang.t("Diese Wunde heilt nur am fernen, vergessenen Schrein."), TradeWindow.ORANGE])
	else:
		lines.append([Lang.t("Du bist unverletzt."), TradeWindow.GREY])
	if Blessing.mercy(p) > 0.0:
		lines.append([Lang.t("Dein Segen macht die Heilung billiger."), TradeWindow.GREEN])
	return [{"key": "heal:prayer", "icon": god.icon, "name": Lang.t("Gebet an Mirenna"),
			"price": Lang.t("Umsonst") if price == 0 else Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price,
			"button": button, "action": _pray_for_healing.bind(price), "enabled": can,
			"detail": {"subtitle": Lang.t(god.title), "lines": lines}, "compare": now}]


func _pray_for_healing(price: int) -> void:
	var p: Player = game.player
	if not Injury.heals_at_village(p):
		return
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
		_rebuild()
		return
	game.coins -= price
	Injury.heal(p)
	Sfx.play(game, "secret", -6.0)
	game._update_hud()
	_note = Lang.t("Du betest zu Mirenna. Deine Verletzung ist verschwunden.")
	game.save_game()
	_rebuild()


## The effect lines of a god at `thirds`, green for what helps, red for what costs.
func _blessing_lines(god: String, thirds: int) -> Array:
	var out := []
	for line in Blessing.lines(god, thirds):
		out.append([line[0], TradeWindow.GREEN if line[1] else TradeWindow.RED])
	return out


func _bless(god: String, price: int) -> void:
	var p: Player = game.player
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
		_rebuild()
		return
	game.coins -= price
	Blessing.bless(p, god)
	Sfx.play(game, "secret", -6.0)
	game._update_hud()
	_note = Lang.t("Elsbeth legt die Hand auf deine Stirn: %s segnet dich.") % Lang.t(Blessing.GODS[god].name)
	Events.tell(Lang.t("Du bist nun gesegnet von %s.") % Lang.t(Blessing.GODS[god].name), game.GOLD)
	Events.teach(Blessing.LORE)
	game.save_game()
	_rebuild()


# --- Barber -----------------------------------------------------------------

## What the barber offers: id, name, price in gold (see HairLook).
const BARBER_STYLES := [["natural", "Natürlich", 5], ["short", "Kurzhaarschnitt", 10], ["spiky", "Stachelkopf", 15],
		["mohawk", "Irokese", 15], ["bald", "Glatze", 10]]
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
	_trade(Lang.t("Dein Kupfer: %d") % game.coins, [
		{"key": "style", "title": Lang.t("Frisur"), "icon": "kind:scissors", "entries": _barber_entries(BARBER_STYLES, "style")},
		{"key": "color", "title": Lang.t("Farbe"), "icon": "kind:hair:fire", "entries": _barber_entries(BARBER_COLORS, "color")},
		{"key": "tattoo", "title": Lang.t("Tätowierung"), "icon": "kind:needle", "extra": _tattoo_editor, "entries": [
			{"key": "ink", "icon": "kind:needle", "name": Lang.t("Stechen"), "price": Lang.t("%d Kupfer") % ink,
					"price_ok": game.coins >= ink, "button": Lang.t("Stechen"), "action": _ink_tattoo,
					"enabled": game.coins >= ink, "detail": ink_detail, "compare": ink_compare},
			{"key": "remove", "icon": "kind:needle", "name": Lang.t("Entfernen"), "price": Lang.t("%d Kupfer") % remove,
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
	edit.add_theme_font_size_override("font_size", UiKit.sized(18))
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
				"price": Lang.t("%d Kupfer") % price, "price_ok": game.coins >= price, "action": _restyle.bind(field, c[0], price),
				"enabled": game.coins >= price, "current": current,
				"detail": {"subtitle": kind, "lines": [[line, TradeWindow.BLUE]]}, "compare": compare})
	return entries


func _restyle(field: String, id: String, price: int) -> void:
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
		_rebuild()
		return
	game.coins -= price
	Events.bus().traded.emit(game.trader_role)
	var look: Dictionary = game.player.hair.duplicate()
	look[field] = id
	game.player.set_hair(look)
	Sfx.play(game, "coin")
	_note = Lang.t("Schnipp, schnapp! Steht dir gut.")
	if field == "style" and HairLook.shows_scalp(id) and look.tattoo != "":
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
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
	else:
		game.coins -= game.trader_price(TATTOO_PRICE)
		Events.bus().traded.emit(game.trader_role)
		var look: Dictionary = game.player.hair.duplicate()
		look.tattoo = word
		look.tattoo_shape = _tattoo_shape
		game.player.set_hair(look)
		Sfx.play(game, "coin")
		_note = Lang.t("Gestochen: %s") % word
		if not HairLook.shows_scalp(look.style):
			_note += " " + Lang.t("Unter deinen Haaren sieht man sie erst, wenn du dir den Kopf scheren lässt.")
	_rebuild()


func _remove_tattoo() -> void:
	if game.coins < game.trader_price(TATTOO_REMOVE_PRICE):
		_note = Lang.t("Dafür reicht dein Kupfer nicht.")
	else:
		game.coins -= game.trader_price(TATTOO_REMOVE_PRICE)
		var look: Dictionary = game.player.hair.duplicate()
		look.tattoo = ""
		game.player.set_hair(look)
		_note = Lang.t("Die Tätowierung ist weg.")
	_rebuild()


# --- Bed --------------------------------------------------------------------

## Every saved game, one per slot, the one saved last on top. In the middle
## of a run it warns first that the run so far is lost. A saved game can be
## deleted too, after a second click to make sure. Opened from the bed right
## after saving, it says the game was saved instead and lets the player carry on.
func _build_load() -> void:
	var after_save := saved_now != ""
	_add_label(Lang.t("Spielstände") if after_save else Lang.t("Spielstand laden"), 38, game.GOLD, game.TITLE_FONT)
	var saves: Array = game.save_list()
	var playing: bool = game.state == game.State.PLAYING
	if saved_now == "ok":
		_add_label(Lang.t("Spiel gespeichert auf Platz %d.") % game.save_slot, 20, Color(0.6, 1.0, 0.6))
	elif saved_now == "failed":
		_add_label(Lang.t("Speichern fehlgeschlagen!"), 20, Color(1.0, 0.5, 0.4))
	elif saves.is_empty():
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
	var cancel: Button = game._make_button(Lang.t("Weiterspielen") if after_save else Lang.t("Abbrechen"), func():
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
	where.text = game.save_summary(info)
	if playing and info.slot == game.save_slot:
		where.add_theme_color_override("font_color", game.GOLD)
	text.add_child(where)
	var when: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	when.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	when.text = Lang.t("Platz %d · gespeichert: %s") % [info.slot, game.save_time_text(info.time)]
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


## A new game is about to take a slot whose hero has come further: says who
## would be lost, and asks before the slot is overwritten. Going back keeps
## the name box as it was, so another slot can be picked.
func _build_overwrite() -> void:
	_add_label(Lang.t("Spielstand überschreiben?"), 38, game.GOLD, game.TITLE_FONT)
	var info: Dictionary = game.save_info(game.save_path(game._new_slot))
	if info.is_empty():
		# The slot was emptied meanwhile: nothing to lose.
		close()
		game.begin_new_game()
		return
	var lead := _add_label(Lang.t("Auf Platz %d ist eine Figur, die weiter gekommen ist als ein neues Spiel:") % info.slot, 20)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size.x = RETURN_TEXT_WIDTH
	var who := _add_label(game.save_summary(info), 22, game.GOLD)
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var when := _add_label(Lang.t("Gespeichert: %s") % game.save_time_text(info.time), 16, BLUE)
	when.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_add_label(Lang.t("Wenn du überschreibst, ist dieser Spielstand für immer verloren."), 20, Color(1.0, 0.75, 0.5))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var overwrite: Button = game._make_button(Lang.t("Überschreiben"), func():
		close()
		game.begin_new_game())
	overwrite.custom_minimum_size = Vector2(220, 60)
	overwrite.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	row.add_child(overwrite)
	var back: Button = game._make_button(Lang.t("Anderen Platz wählen"), close)
	back.custom_minimum_size = Vector2(300, 60)
	row.add_child(back)


## The widest a compendium tab gets, and the gap between tabs.
const COMPENDIUM_TAB := 240.0
const COMPENDIUM_TAB_GAP := 10


## Every control on one side, everything the hero has been told on the
## other; a second page holds the villagers' tasks (the quest log).
func _build_compendium() -> void:
	_add_label(Lang.t("Kompendium"), 38, game.GOLD, game.TITLE_FONT)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", COMPENDIUM_TAB_GAP)
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
	# Monster lore gets its page once the first monster has fallen.
	if not MonsterLore.known_kinds().is_empty():
		tabs_shown.append(["monster", Lang.t("Monsterkunde")])
	elif compendium_page == "monster":
		compendium_page = "wissen"
	# Places get their page once the hero has entered one (every floor
	# counts on the first visit, see Game._announce_level).
	if not _visited_places().is_empty():
		tabs_shown.append(["orte", Lang.t("Orte (%d)") % _visited_places().size()])
	elif compendium_page == "orte":
		compendium_page = "wissen"
	# All tabs share one width, narrower when there are more of them, so the
	# row never grows past the window.
	var tab_width := minf(COMPENDIUM_TAB, floorf((WINDOW_SIZES.kompendium.x - COMPENDIUM_TAB_GAP * (tabs_shown.size() - 1)) / tabs_shown.size()))
	for tab in tabs_shown:
		var b := _item_button(tab[1], func():
			compendium_page = tab[0]
			_rebuild())
		b.custom_minimum_size = Vector2(tab_width, 44)
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
	if compendium_page == "monster":
		_build_monster_lore()
		return
	if compendium_page == "orte":
		_build_places()
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
	# The floors have a page of their own (Places).
	var tips: Array = game.lore.filter(func(entry: String) -> bool: return not entry.begins_with("#"))
	if tips.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 16)
		none.text = Lang.t("Noch nichts. Hinweise und Erklärungen sammeln sich hier.")
		list.add_child(none)
	# Newest first: the latest hint or explanation sits at the top.
	for i in range(tips.size() - 1, -1, -1):
		var l: Label = game._make_label(game.TEXT_FONT, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 410
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = Lang.t(tips[i])
		list.add_child(l)


## The floors and places the hero has entered, by their number in the game.
func _visited_places() -> Array:
	var out := []
	for entry in game.lore:
		if entry.begins_with("#"):
			out.append(int(entry.substr(1)))
	out.sort()
	return out


## The Places page: the description every floor showed on the first visit,
## kept here to read again (the event log also writes it on every entry).
func _build_places() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for index in _visited_places():
		var info: Dictionary = game.level_hint(index)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		list.add_child(card)
		var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
		title.text = Lang.t("Ebene %d: %s") % [index + 1, Lang.t(info.name)]
		card.add_child(title)
		var text: Label = game._make_label(game.TEXT_FONT, 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 740
		text.text = Lang.t(info.hint)
		card.add_child(text)


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
	var worth: Label = game._make_label(game.TITLE_FONT, 21, game.GOLD)
	worth.text = Lang.t("Was sich jetzt lohnt")
	list.add_child(worth)
	var hints := VBoxContainer.new()
	hints.add_theme_constant_override("separation", 4)
	list.add_child(hints)
	for hint in quest_hints():
		var line: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 740
		line.text = "• " + hint
		hints.add_child(line)
	var tasks: Label = game._make_label(game.TITLE_FONT, 21, game.GOLD)
	tasks.text = Lang.t("Deine Aufträge")
	list.add_child(tasks)
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
		text.text = Lang.t(hunt.goal) + "\n" + Lang.t("Belohnung: %s") % (Lang.t("%d Kupfer") % hunt.gold)
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
		var giver_name: String = Quests.villager_name(q.giver) if q.giver != "" else Lang.t(q.get("source", ""))
		var goal := Lang.t("Von %s: %s") % [giver_name, Lang.t(q.goal)] + "\n" + Lang.t("Belohnung: %s") % Quests.reward_text(id)
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


## The quests window (O, or the scroll icon on the right edge): what is
## worth doing next, then every task taken on, as in the compendium.
func _build_quests() -> void:
	_add_label(Lang.t("Aufträge"), 38, game.GOLD, game.TITLE_FONT)
	_build_quest_log()


## Short hints on what is worth doing next, most pressing first: tasks ready
## to hand in, villagers with work, new bounties, places not fully explored,
## and what tonight's moon brings.
func quest_hints() -> Array[String]:
	var hints: Array[String] = []
	var quests: Quests = game.quests
	for id in Quests.ALL:
		if not quests.is_active(id):
			continue
		var q: Dictionary = Quests.ALL[id]
		if q.kind == "potion":
			if quests.missing(id) == 0:
				hints.append(Lang.t("Bring Bruder Orlan einen Heiltrank: %s") % Lang.t(q.title))
		elif q.kind == "deliver":
			if game.player.bag.has(q.item):
				hints.append(Lang.t("Bring es zu %s: %s") % [Quests.villager_name(q.to), Lang.t(q.title)])
		elif quests.missing(id) == 0:
			hints.append(Lang.t("Geschafft, melde dich bei %s: %s") % [Quests.villager_name(q.giver), Lang.t(q.title)])
	for id in game.bounties.taken:
		if game.bounties.is_ready(id):
			hints.append(Lang.t("Hol dein Kopfgeld am Aushang ab: %s") % Lang.t(Bounties.POOL[id].title))
	var askers: Array[String] = []
	for role in Villager.ROLES:
		if quests.mark(role) == "!" or game.crafting.mark(role) == "!" or game.wishes.mark(role) == "!":
			var who := Quests.villager_name(role)
			if who != "" and not who in askers:
				askers.append(who)
	if not askers.is_empty():
		hints.append(Lang.t("Im Dorf hat jemand etwas für dich (achte auf das „!“): %s") % ", ".join(askers))
	for id in game.bounties.posted:
		if game.bounties.is_open(id):
			hints.append(Lang.t("Am Aushang im Dorf hängen Kopfgelder, die noch niemand jagt."))
			break
	var journal: Journal = game.journal
	var unexplored := []
	for file in journal.mapped_files():
		if journal.is_full(file):
			continue
		var share := floori(100.0 * journal.explored_share(file))
		if share < 100:
			unexplored.append([share, file])
	unexplored.sort_custom(func(a, b): return a[0] < b[0])
	for entry in unexplored.slice(0, 3):
		hints.append(Lang.t("%s ist erst zu %d %% erkundet: Dort gibt es noch mehr zu finden.") % [journal.level_title(entry[1]), entry[0]])
	if Moon.is_full(game.day) or Moon.is_new(game.day):
		hints.append(Lang.t("Heute Nacht: %s") % Moon.forecast(game.day))
	if hints.is_empty():
		hints.append(Lang.t("Gerade wartet nichts Bestimmtes. Erkunde neue Ebenen oder sprich mit den Leuten im Dorf."))
	return hints


## The villagers' goodwill: everyone the hero has met, with their standing,
## how far to the next level, the discount, and the secret recipes learned.
## The columns of the monster lore table: name, kills, rank, vital hit
## chance, next rank. Numbers are right-aligned so they line up.
const LORE_COLUMNS := [220, 80, 130, 110, 160]


## Monster lore: every kind of monster the hero has slain, with how many,
## the rank of knowledge, the chance of a vital hit and the kills to the
## next rank (see MonsterLore). A fixed region that scrolls.
func _build_monster_lore() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var intro: Label = game._make_label(game.TEXT_FONT, 16, BLUE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 740
	intro.text = Lang.t("Je mehr Monster einer Art du besiegst, desto öfter triffst du eine Schwachstelle (höchstens 50 %). Ein Treffer in die Schwachstelle macht doppelt so viel wie dein härtester Schlag und lässt das Monster manchmal bluten oder für den Rest des Kampfes langsamer angreifen.")
	list.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = LORE_COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	list.add_child(grid)
	var heads := [Lang.t("Monster"), Lang.t("Besiegt"), Lang.t("Stufe"), Lang.t("Schwachstelle"), Lang.t("Nächste Stufe")]
	for i in heads.size():
		grid.add_child(_lore_cell(heads[i], i, game.GOLD))
	for kind in MonsterLore.known_kinds():
		var rank := MonsterLore.rank_of(kind)
		var next := MonsterLore.kills_to_next(kind)
		var chance := roundi(MonsterLore.vital_chance(kind) * 100.0)
		grid.add_child(_lore_cell(Lang.t(MonsterLore.monster_name(kind)), 0, Color.WHITE))
		grid.add_child(_lore_cell(str(MonsterLore.kill_count(kind)), 1, Color.WHITE))
		grid.add_child(_lore_cell(Lang.t(MonsterLore.rank_name(rank)), 2, MonsterLore.VITAL_COLOR if rank > 0 else Color(0.75, 0.72, 0.68)))
		grid.add_child(_lore_cell("%d %%" % chance, 3, MonsterLore.VITAL_COLOR if chance > 0 else Color(0.75, 0.72, 0.68)))
		var to_next := Lang.t("noch %d bis %s") % [next, Lang.t(MonsterLore.rank_name(rank + 1))] if next > 0 else Lang.t("Höchste Stufe")
		grid.add_child(_lore_cell(to_next, 4, Color(0.75, 0.72, 0.68)))


## One cell of the monster lore table: fixed width, long text shortened.
func _lore_cell(text: String, column: int, color: Color) -> Label:
	var l: Label = game._make_label(game.TEXT_FONT, 16, color)
	l.text = text
	l.custom_minimum_size.x = LORE_COLUMNS[column]
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if column in [1, 3]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


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
	_add_label(Lang.t("Pause"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Die Welt steht still, bis du weiterspielst."), 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	# Going on is the main way out of a pause, so it comes first; Esc does
	# the same.
	var resume: Button = game._make_button(Lang.t("Weiterspielen"), close)
	resume.custom_minimum_size = Vector2(220, 60)
	row.add_child(resume)
	var quit: Button = game._make_button(Lang.t("Spiel beenden"), func():
		close()
		game.quit_game())
	quit.custom_minimum_size = Vector2(220, 60)
	row.add_child(quit)
	# What quitting costs sits right under the buttons.
	_add_label(Lang.t("Was seit dem letzten Schlaf im Bett geschah, geht verloren."), 16, Color(1.0, 0.75, 0.5))


## The dragon has fallen: the lair is won. Says so, counts the fallen
## monsters, and offers the way out or a last look round for gold.
func _build_lair_won() -> void:
	_add_label(Lang.t("Höhle bezwungen!"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Der Drache ist tot, und sein Schatz gehört dir."), 22)
	# A fallen monster may already have rotted away: only the living still count.
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


## The spoils of the won lair (see DragonLair.spoils): gold, bars,
## ingredients and gear, each with its picture, in a list of fixed size
## that scrolls when it is long, so the window keeps one size.
const SPOILS_LIST := Vector2(660, 252)
const SPOILS_CELL := 318


func _build_spoils() -> void:
	var s: Dictionary = game.lair_spoils
	_add_label(Lang.t("Glutschlunds Hort"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Das hast du aus der Drachenhöhle getragen:"), 20)
	var entries := []
	if int(s.get("gold", 0)) > 0:
		entries.append(["kind:coin", Lang.t("%d Kupfer") % int(s.gold), game.GOLD])
	var bars: Dictionary = s.get("bars", {})
	for metal in Forge.METALS:
		if int(bars.get(metal, 0)) > 0:
			var icon: String = "kind:iron" if metal == "eisen" else ("kind:ore" if metal == "mondsilbererz" else "kind:bar_" + metal)
			entries.append([icon, "%d× %s" % [int(bars[metal]), Lang.t(Forge.METALS[metal].name)], Forge.METALS[metal].color])
	var found: Dictionary = s.get("ingredients", {})
	for id in found:
		entries.append([id, "%d× %s" % [int(found[id]), Crafting.ingredient_name(id)], Rarity.color(id)])
	var items: Dictionary = s.get("items", {})
	for id in items:
		var label: String = Items.item_name(id) if int(items[id]) == 1 else "%d× %s" % [int(items[id]), Items.item_name(id)]
		entries.append([id, label, Rarity.color(id)])
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = SPOILS_LIST
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	if entries.is_empty():
		var none := _add_label(Lang.t("Nichts. Der Drache ist tot, aber sein Gold liegt noch unten."), 18, BLUE)
		none.reparent(grid)
	for e in entries:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = SPOILS_CELL
		row.add_theme_constant_override("separation", 10)
		row.add_child(ItemIcon.make(e[0], 40.0))
		var l: Label = game._make_label(game.TEXT_FONT, 18, e[2])
		l.text = e[1]
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		grid.add_child(row)
	_add_label(Lang.t("Aus Drachenschuppe, Drachenblut und Glutherz machst du am Feinschmiedetisch Drachenschmuck."), 16, Color(1.0, 0.85, 0.55))


func _build_bed() -> void:
	rest_window = "bett"
	_add_label(Lang.t("Ein weiches Bett"), 38, game.GOLD, game.TITLE_FONT)
	if game.level.inn:
		# An inn on the way: rest till morning and carry on, or log out here.
		_add_label(Lang.t("Ruh dich bis zum Morgen aus: Danach hast du volles Leben,\nGift und Flüche sind fort, und dein Spiel ist gespeichert."), 20)
		var rest: Button = game._make_button(Lang.t("Bis zum Morgen ausruhen"), func():
			close()
			game.rest_at_inn())
		rest.custom_minimum_size = Vector2(300, 60)
		rest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(rest)
		_add_label(Lang.t("Oder schlaf hier und logg dich aus. Beim nächsten Mal\nwachst du in diesem Bett auf, ausgeruht."), 20)
	else:
		# Sleep through to the next morning and carry on, or log out.
		_add_label(Lang.t("Schlaf bis zum Morgen und mach gleich weiter: Du hast volles Leben,\ndie Uhr springt auf 7 Uhr früh, und dein Spiel ist gespeichert."), 20)
		var till_morning: Button = game._make_button(Lang.t("Bis zum Morgen schlafen"), func():
			close()
			game.rest_till_morning())
		till_morning.custom_minimum_size = Vector2(300, 60)
		till_morning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(till_morning)
		_add_label(Lang.t("Oder schlaf hier und logg dich aus. Dein Spiel wird gespeichert,\nspäter geht es genau hier weiter."), 20)
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
	# Staying up saves the game here as well and shows the saved games, so
	# the player sees it went through and can keep playing straight away.
	var awake: Button = game._make_button(Lang.t("Wach bleiben und speichern"), game.stay_awake)
	awake.custom_minimum_size = Vector2(300, 60)
	row.add_child(awake)


## The camp's window (see Camp): sleep by the fire and log out, or stay
## awake and save, laid out like the bed's.
func _build_camp() -> void:
	rest_window = "nachtlager"
	_add_label(Lang.t("Dein Lager"), 38, game.GOLD, game.TITLE_FONT)
	if Camp.can_rest(game.level):
		# Down in the dungeon: rest a while by the fire and carry on, at the
		# risk of an ambush, laid out like the inn's rest till morning.
		_add_label(Lang.t("Ruh dich am Feuer aus: Danach hast du volles Leben, und dein Spiel ist gespeichert.\nAuch nach einer Ohnmacht wachst du dann an diesem Lager auf."), 20)
		_add_label(camp_risk_text(), 20, Color(1.0, 0.75, 0.5))
		var rest: Button = game._make_button(Lang.t("Am Feuer ausruhen"), func():
			close()
			game.rest_at_camp())
		rest.custom_minimum_size = Vector2(300, 60)
		rest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(rest)
	_add_label(Lang.t("Das Feuer knistert, die Schlafrolle liegt bereit. Schlaf hier und logg dich aus:\nBeim nächsten Mal wachst du an diesem Lager auf. Gehst du weg, packst du es wieder ein."), 20)
	_add_label(Lang.t("Solange du weg bist, lebt dein Held nach seinem Tagesplan:"), 20, BLUE)
	_add_label(_plan_summary(), 16, game.GOLD)
	var plan_button: Button = game._make_button(Lang.t("Tagesplan ändern"), open.bind("plan"))
	plan_button.custom_minimum_size = Vector2(300, 56)
	plan_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(plan_button)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var sleep: Button = game._make_button(Lang.t("Schlafen und ausloggen"), func():
		close()
		game.sleep(true))
	sleep.custom_minimum_size = Vector2(300, 60)
	row.add_child(sleep)
	var awake: Button = game._make_button(Lang.t("Wach bleiben und speichern"), game.stay_awake)
	awake.custom_minimum_size = Vector2(300, 60)
	row.add_child(awake)


## The camp window's line on the danger of resting by the fire: the chance
## of an ambush, and who keeps watch (see Camp.GUARDS).
func camp_risk_text() -> String:
	var guard: String = game.camp_guard()
	var chance := Camp.ambush_chance(game.level, guard)
	var percent := roundi(chance * 100.0)
	if Camp.ambush_kinds(game.level).is_empty():
		return Lang.t("Hier ist es ruhig: Kein Ungeheuer wird dich stören.")
	if guard == "":
		return Lang.t("Gefahr eines Hinterhalts: %d %%. Ein Gefährte an deiner Seite würde Wache halten.") % percent
	var who: String = game.companion().get("name", Companions.species_name(guard))
	if percent <= 0:
		return Lang.t("%s hält Wache: Kein Ungeheuer wagt sich heran.") % who
	return Lang.t("%s hält Wache: Gefahr eines Hinterhalts nur %d %%.") % [who, percent]


# --- Time away (see Offline) ------------------------------------------------

## The window the day plan was opened from, and goes back to: the bed
## ("bett") or the camp ("nachtlager").
var rest_window := "bett"

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
			return Lang.t("%s (%d Kupfer/Std.)") % [Lang.t(Offline.JOBS[id].name), Offline.JOBS[id].gold]
		"train":
			return game._training_name(id)
		"study":
			return Lang.t("%s (%s, noch %d Std.)") % [Items.item_name(id), Lang.t(Training.SKILLS[Items.ALL[id].teaches].name), ceili(Offline.book_left(game.book_hours, id))]
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
	var at_camp := rest_window == "nachtlager"
	var sleep: Button = game._make_button(Lang.t("Schlafen und ausloggen"), func():
		close()
		game.sleep(at_camp))
	sleep.custom_minimum_size = Vector2(300, 60)
	buttons.add_child(sleep)
	var back: Button = game._make_button(Lang.t("Zurück"), open.bind(rest_window))
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
	if not view.lost_packs().is_empty():
		_legend_line(legend, MapView.PACK_COLOR, Lang.t("Verlorener Rucksack"))
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
	# How much is seen, by the same measure that makes a map fully explored
	# (see Journal.note_full_map): rounded down, so 95 % is really reached.
	var explored := Lang.t("Erkundet: %d %%") % floori(100.0 * journal.explored_share(_map_file))
	if journal.is_full(_map_file):
		explored += " " + Lang.t("(vollständig)")
	_add_label(explored, 16, BLUE)


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
