class_name TradeWindow
extends RefCounted
## The compact trading window every merchant uses (Mira, Gorm, Hagen, Benno
## and Zarek): the gold at the top, categories that fold open and shut, and
## in each a grid of small rows (picture, name, price, button) that scrolls
## when it holds more than fits. Beside the list, always in the same place,
## a panel shows the row under the mouse (or the picked one, after a click):
## its values and price, and what the hero wears in that place now and how
## the two compare (green is better, red is worse).
##
## The window keeps one size and one layout whatever happens in it: folding
## a category, pointing at or picking a row only changes what is inside the
## list and the panel, so the eye always finds things where they were.
## Buying and selling do not move anything either: rows keep their order
## from when the window opened, a row whose last piece is gone stays as a
## dimmed "sold out" row until the window closes, a stack of the same
## item is one row with a count, and the list keeps its scroll position.
## For that, row keys must name the thing (e.g. "ware:schwert"), never its
## place in a list.
##
## A section is {key, title, icon, entries, extra (optional Callable that
## returns a Control shown above the rows), empty (text when it has none)}.
## An entry is {key, id (item id or ""), icon, name, price, price_ok, button,
## action, enabled, current (what the hero has now: no button),
## detail (optional {subtitle, lines}), compare (optional {title, name,
## subtitle, icon, lines, diffs, empty})}. Lines are [text, colour] pairs,
## diffs [better, text] pairs (a third value false leaves a diff out of
## the "better" badge).

const LIST_HEIGHT := 380.0
const ROW_WIDTH := 300.0
## The list: two columns of rows and room for the scroll bar.
const LIST_WIDTH := ROW_WIDTH * 2 + 8.0 + 14.0
const ROW_HEIGHT := 60.0
## The button in a row (Buy, Sell, Melt down...): wide enough for the
## longest word in both languages ("Einschmelzen").
const ROW_BUTTON_WIDTH := 100.0
const CARD_WIDTH := 255.0
## Everything under the gold line: the list and the two cards beside it.
const BODY_WIDTH := LIST_WIDTH + 2.0 * (CARD_WIDTH + 12.0)
## The row of tabs (Buy / Sell, Gorm's work) under the gold line.
const TABS_HEIGHT := 40.0
const BORDER := Color(0.88, 0.66, 0.36, 0.9)
const BLUE := Color(0.55, 0.75, 1.0)
const ORANGE := Color(1.0, 0.6, 0.25)
const GREY := Color(0.75, 0.72, 0.68)
const GOLD_HEX := "ffd166"
const GREEN := Color(0.4, 0.92, 0.4)
const RED := Color(1.0, 0.38, 0.32)

var game: Node
## Asks the owner to build the window again (after a click).
var rebuild: Callable
## Folded-up categories, by section key.
var collapsed := {}
## The picked row (its key and item), and the row the mouse is over.
var selected := ""
var _selected_id := ""
var _hovered := ""

var _entries := {}
## Every row key shown since the window (or tab) opened, by section, in the
## order they first appeared; and the last look of each row, to show a
## dimmed copy once it is gone.
var _seen := {}
var _last := {}
## How far the list is scrolled down, kept over rebuilds.
var _scroll := 0
## The two card places beside the list: the item's values, and how it
## compares with what the hero wears.
var _detail_slot: Control
var _compare_slot: Control
## What the empty item card says (e.g. what one of Gorm's tabs is for).
var _hint := ""


func reset() -> void:
	collapsed.clear()
	selected = ""
	_selected_id = ""
	_hovered = ""
	_seen.clear()
	_last.clear()
	_scroll = 0


## The section's rows in a fixed order: the ones seen before keep their
## places (gone ones as dimmed copies), new ones come at the end.
func _steady(section: Dictionary) -> Array:
	var order: Array = _seen.get(section.key, [])
	var now := {}
	for entry in section.entries:
		now[entry.key] = entry
	for entry in section.entries:
		if not entry.key in order:
			order.append(entry.key)
	_seen[section.key] = order
	var rows := []
	for key in order:
		if now.has(key):
			_last[key] = now[key]
			rows.append(now[key])
		elif _last.has(key):
			var gone: Dictionary = _last[key].duplicate()
			gone.gone = section.get("gone", Lang.t("Ausverkauft"))
			gone.enabled = false
			gone.erase("count")
			rows.append(gone)
	return rows


## Builds the window into `box`: the gold line, `extra` (e.g. Gorm's tabs),
## then the categories and, with a row picked, its cards.
## `standing` (the villager's goodwill) goes on the gold line; `hint` is
## what the item card says while no row is pointed at or picked.
func build(box: VBoxContainer, gold_text: String, sections: Array, extra: Control = null, standing: Control = null, hint := "") -> void:
	_hint = hint
	_entries.clear()
	var steady := []
	for section in sections:
		var shown: Dictionary = section.duplicate()
		shown.entries = _steady(section)
		steady.append(shown)
		for entry in shown.entries:
			_entries[entry.key] = entry
	sections = steady
	_keep_selection()
	var gold := HBoxContainer.new()
	gold.alignment = BoxContainer.ALIGNMENT_CENTER
	gold.add_theme_constant_override("separation", 8)
	gold.add_child(ItemIcon.make("kind:coin", 22, true))
	# Room for the widest value, so a purchase does not shift the line.
	var gold_label := _label(gold_text, 22, game.GOLD)
	gold_label.custom_minimum_size.x = 300
	gold.add_child(gold_label)
	if standing:
		gold.add_child(_label("·", 22, GREY))
		standing.custom_minimum_size.x = 420
		gold.add_child(standing)
	box.add_child(gold)
	# The tabs' row is there in every merchant's window, empty where he has
	# no tabs, so all of them share one size and one layout.
	if extra == null:
		extra = Control.new()
		extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.custom_minimum_size.y = maxf(extra.custom_minimum_size.y, TABS_HEIGHT)
	box.add_child(extra)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 12)
	box.add_child(body)
	# The list and the panel always keep the same size, so nothing jumps
	# when a category folds or a row is picked.
	var scroll := ScrollContainer.new()
	# Never scrolled sideways, and never widened by a row either.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, LIST_HEIGHT)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size.x = LIST_WIDTH - 14.0
	scroll.add_child(list)
	for section in sections:
		_add_section(list, section)
	body.add_child(scroll)
	# Back to where the list was scrolled before the rebuild, once it has
	# its size (containers sort themselves first, at the end of the frame).
	scroll.get_v_scroll_bar().value_changed.connect(func(v): _scroll = int(v))
	scroll.set_deferred("scroll_vertical", _scroll)
	_detail_slot = _slot()
	body.add_child(_detail_slot)
	_compare_slot = _slot()
	body.add_child(_compare_slot)
	# The row under the mouse stays shown: a purchase does not blank the cards.
	_show_cards(_hovered if _entries.has(_hovered) else selected)


## A picked row stays picked while its thing is still on offer; when it was
## bought, another row with the same item takes its place, if there is one.
func _keep_selection() -> void:
	if selected == "":
		return
	if _entries.has(selected) and _entries[selected].get("id", "") == _selected_id:
		return
	for key in _entries:
		if _selected_id != "" and _entries[key].get("id", "") == _selected_id:
			selected = key
			return
	selected = ""
	_selected_id = ""


## One category: its header (click to fold) and its rows in two columns.
func _add_section(list: VBoxContainer, section: Dictionary) -> void:
	var folded: bool = collapsed.get(section.key, false)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _style(Color(0.13, 0.09, 0.055, 0.95), BORDER, 8, 6))
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.gui_input.connect(_on_header_input.bind(section.key))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(ItemIcon.make(section.get("icon", "kind:helmet"), 26, true))
	var title := _label(section.title, 20, game.GOLD, game.TITLE_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var count := _label("%d" % section.entries.size(), 15, GREY)
	row.add_child(count)
	row.add_child(ItemIcon.make("kind:chev_down" if folded else "kind:chev_up", 18, true))
	header.add_child(row)
	list.add_child(header)
	if folded:
		return
	if section.has("extra"):
		list.add_child(section.extra.call())
	if section.entries.is_empty():
		# An empty category keeps the shape of a row, so it lines up with the rest.
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(0, ROW_HEIGHT * 0.7)
		empty.add_theme_stylebox_override("panel", _style(Color(0.09, 0.065, 0.045, 0.6), Color(0.85, 0.66, 0.32, 0.15), 8, 6))
		var text := _label(section.get("empty", Lang.t("Nichts im Angebot.")), 15, GREY)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(text)
		list.add_child(empty)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for entry in section.entries:
		grid.add_child(_row(entry))
	list.add_child(grid)


func _row(entry: Dictionary) -> Control:
	var picked: bool = entry.key == selected
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", _style(Color(0.17, 0.115, 0.06, 0.95) if picked else Color(0.09, 0.065, 0.045, 0.95),
			game.GOLD if picked else Color(0.85, 0.66, 0.32, 0.3), 8, 6, 2 if picked else 1))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_row_input.bind(entry.key))
	panel.mouse_entered.connect(_on_row_hover.bind(entry.key))
	panel.mouse_exited.connect(_on_row_hover.bind(""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(ItemIcon.make(entry.get("icon", entry.get("id", "")), 46))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(entry.name, 16, name_color(entry.get("id", ""), Color.WHITE))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 120
	text.add_child(name_label)
	if entry.get("price", "") != "":
		var price := _price_line(entry.price, entry.get("price_ok", true), 16)
		if entry.get("count", 1) > 1:
			# A stack of the same thing: one row with how many there are.
			price.add_child(_label("×%d" % entry.count, 16, GREY))
		text.add_child(price)
	row.add_child(text)
	if entry.has("gone"):
		# Bought or sold out while the window is open: the row stays in its
		# place, dimmed, until the window closes.
		panel.modulate = Color(1, 1, 1, 0.45)
		var gone := _label(entry.gone, 15, GREY)
		gone.custom_minimum_size = Vector2(80, 0)
		gone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(gone)
	elif entry.get("current", false):
		var now := _label(Lang.t("Jetzt"), 16, GREEN)
		now.custom_minimum_size = Vector2(80, 0)
		now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		now.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(now)
	elif entry.has("action"):
		var b := _button(entry.get("button", Lang.t("Kaufen")), entry.action, entry.get("enabled", true), Vector2(ROW_BUTTON_WIDTH, 36), 16)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# A long word ("Einschmelzen") ends in "…" rather than widen the row;
		# the card beside the list shows it in full.
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.mouse_entered.connect(_on_row_hover.bind(entry.key))
		# With the keys, the focus on a row's button shows that row's cards.
		b.focus_entered.connect(_on_row_hover.bind(entry.key))
		row.add_child(b)
	return panel


func _on_header_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collapsed[key] = not collapsed.get(key, false)
		rebuild.call()


func _on_row_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pick(key)


## Picks a row (or puts it down again when it was picked already).
func pick(key: String) -> void:
	if selected == key or not _entries.has(key):
		selected = ""
		_selected_id = ""
	else:
		selected = key
		_selected_id = _entries[key].get("id", "")
	rebuild.call()


func _on_row_hover(key: String) -> void:
	if _detail_slot == null or not is_instance_valid(_detail_slot):
		return
	_hovered = key
	_show_cards(key if key != "" else selected)


# --- The two cards --------------------------------------------------------

## A fixed place for a card beside the list: always there, always the same
## size, so only what it shows changes.
func _slot() -> Control:
	var slot := ScrollContainer.new()
	# A card never widens its place (its lines wrap, see _wrapped).
	slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	slot.custom_minimum_size = Vector2(CARD_WIDTH, LIST_HEIGHT)
	return slot


func _fill(slot: Control, card: Control) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	slot.add_child(card)


## Fills the two card places with a row's cards, or with quiet empty cards
## while no row is pointed at or picked.
func _show_cards(key: String) -> void:
	if not _entries.has(key):
		key = selected
	if not _entries.has(key):
		var text := (_hint + "\n\n" if _hint != "" else "") + Lang.t("Zeig auf einen Gegenstand, um seine Werte zu sehen. Ein Klick hält ihn hier fest.")
		_fill(_detail_slot, _empty_card(Lang.t("Gegenstand"), text))
		_fill(_compare_slot, _empty_card(Lang.t("Vergleich"), Lang.t("Hier steht, was du an dieser Stelle trägst, und was besser oder schlechter wäre.")))
		return
	var entry: Dictionary = _entries[key]
	var compare: Dictionary = entry.get("compare", compare_with_worn(game.player, entry.get("id", "")))
	_fill(_detail_slot, _detail_card(entry, is_upgrade(compare)))
	_fill(_compare_slot, _compare_card(compare))


func _empty_card(title: String, text: String) -> Control:
	var card := _card(false)
	var box: VBoxContainer = card.get_child(0)
	var head := _label(title, 16, game.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	box.add_child(HSeparator.new())
	var hint := _wrapped(text, 15, GREY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return card


func _detail_card(entry: Dictionary, upgrade := false) -> Control:
	var id: String = entry.get("id", "")
	var detail: Dictionary = entry.get("detail", {})
	var card := _card(true)
	var box: VBoxContainer = card.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(ItemIcon.make(entry.get("icon", id), 50))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label(entry.name, 18, name_color(id, game.GOLD))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	# Under the name, the rarity in words beside the kind of thing ("Rare ·
	# Shield"), in the rarity's colour, so the colour is never the only cue.
	var kind: String = detail.get("subtitle", subtitle(id))
	if Items.ALL.has(id) and not detail.has("subtitle"):
		names.add_child(_beside(_label("%s · %s" % [Rarity.label(id), kind], 16, Rarity.color(id))))
	else:
		names.add_child(_beside(_label(kind, 16, ORANGE)))
	head.add_child(names)
	box.add_child(head)
	if upgrade:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _style(Color(0.05, 0.2, 0.06, 0.95), GREEN, 8, 3))
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(ItemIcon.make("kind:up", 12, true))
		row.add_child(_label(Lang.t("Besser"), 16, GREEN))
		badge.add_child(row)
		box.add_child(badge)
	box.add_child(HSeparator.new())
	var lines: Array = detail.get("lines", stat_lines(id, game.player.wear.get(id, 0) if game.player.equipped.values().has(id) else 0))
	if not detail.has("lines") and Items.is_book(id):
		lines = lines + book_lines(id, game.book_hours)
	for line in lines:
		box.add_child(_wrapped(line[0], 16, line[1]))
	if lines.is_empty():
		box.add_child(_wrapped(Lang.t("Keine besonderen Werte."), 15, GREY))
	# The price and the button sit at the bottom of the card, always there.
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(push)
	if entry.has("action") and not entry.get("current", false):
		box.add_child(HSeparator.new())
		if entry.get("price", "") != "":
			var cost := _price_line(Lang.t("Kosten: %s") % entry.price, entry.get("price_ok", true), 17, true)
			cost.alignment = BoxContainer.ALIGNMENT_CENTER
			box.add_child(cost)
		var b := _button(entry.get("gone", entry.get("button", Lang.t("Kaufen"))), entry.action, entry.get("enabled", true), Vector2(150, 42), 18)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(b)
	elif entry.get("current", false):
		box.add_child(HSeparator.new())
		box.add_child(_wrapped(Lang.t("Das hast du schon."), 16, GREEN))
	return card


func _compare_card(compare: Dictionary) -> Control:
	var card := _card(false)
	var box: VBoxContainer = card.get_child(0)
	var title := _label(compare.get("title", Lang.t("Derzeit angelegt")), 16, game.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HSeparator.new())
	if compare.has("empty"):
		var plus := ItemIcon.make("kind:plus", 70)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(plus)
		var text := _wrapped(compare.empty, 15, GREY)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
		return card
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(ItemIcon.make(compare.get("icon", ""), 46))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(compare.get("name", ""), 17, name_color(compare.get("icon", ""), Color.WHITE))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(name_label)
	if compare.get("subtitle", "") != "":
		names.add_child(_beside(_label(compare.subtitle, 15, GREY)))
	head.add_child(names)
	box.add_child(head)
	# With a comparison the differences say it all; the worn item's own
	# values would only make the panel longer.
	var lines: Array = [] if compare.has("diffs") else compare.get("lines", [])
	if not lines.is_empty():
		box.add_child(HSeparator.new())
		for line in lines:
			box.add_child(_wrapped(line[0], 16, line[1]))
	if compare.has("diffs"):
		var heading := _label(Lang.t("Vergleich"), 16, game.GOLD)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(HSeparator.new())
		box.add_child(heading)
		if compare.diffs.is_empty():
			box.add_child(_wrapped(Lang.t("Gleiche Werte"), 15, GREY))
		for diff in compare.diffs:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var arrow := ItemIcon.make("kind:up" if diff[0] else "kind:down", 13, true)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(arrow)
			row.add_child(_beside(_label(diff[1], 16, GREEN if diff[0] else RED)))
			box.add_child(row)
	return card


# --- What items say ----------------------------------------------------------

## The colour of a thing's name: an item's or an ingredient's is the colour
## of its rarity (see Rarity); anything else (a service, a hair style, iron
## bars) keeps `other`.
static func name_color(id: String, other: Color) -> Color:
	if Items.ALL.has(id) or Crafting.INGREDIENTS.has(id):
		return Rarity.color(id)
	return other


## What kind of thing an item is, e.g. "Shield" or "Gorm's work: weapon".
static func subtitle(id: String) -> String:
	if not Items.ALL.has(id):
		return ""
	var item: Dictionary = Items.ALL[id]
	var kind := Lang.t(Items.SLOT_NAMES.get(item.slot, ""))
	match item.slot:
		"spezial":
			kind = Lang.t("Besonderes")
		"buch":
			kind = Lang.t("Buch")
		"stein":
			kind = Lang.t("Baustein")
		"erz":
			kind = Lang.t("Rohstoff")
		"kiste":
			kind = Lang.t("Kiste")
		"auftrag":
			kind = Lang.t("Für einen Auftrag")
		"futter":
			kind = Lang.t("Futter")
	if item.get("unique", false):
		return Lang.t("Einzigartig: %s") % kind
	if item.get("smith", false):
		return Lang.t("Gorms Arbeit: %s") % kind
	if item.get("wanderer", false):
		return Lang.t("Von weit her: %s") % kind
	return kind


## How much reading a book still holds (see Offline.BOOK_HOURS), as detail
## lines: the hours left in blue, a warning in red once it is used up.
static func book_lines(id: String, read: Dictionary) -> Array:
	if Offline.book_used_up(read, id):
		return [[Lang.t("✗ Ausgelesen: du kannst nichts mehr daraus lernen"), RED]]
	return [[Lang.t("Lesestoff: noch %d von %d Std.") % [ceili(Offline.book_left(read, id)), Offline.BOOK_HOURS], BLUE]]


## An item's values, one per line: plain numbers in white, skills and
## other gains in blue, needs in orange (red when the hero falls short),
## the special effect in gold, the weight in grey.
static func stat_lines(id: String, worn := 0) -> Array:
	if not Items.ALL.has(id):
		return []
	var item: Dictionary = Items.ALL[id]
	var lines := []
	if item.get("power", 0) != 0:
		lines.append([Lang.t("Kampfkraft: %+d") % item.power, Color.WHITE])
	if item.get("hp", 0) != 0:
		lines.append([Lang.t("Leben: %+d") % item.hp, Color.WHITE])
	if item.get("armor", 0) != 0:
		lines.append([Lang.t("Härtung: %+d") % item.armor, Color.WHITE])
	if item.get("block", 0.0) > 0.0:
		lines.append([Lang.t("Blockchance: %d%%") % roundi(item.block * 100.0), Color.WHITE])
	if item.has("durability"):
		lines.append([Lang.t("Haltbarkeit: %d / %d") % [item.durability - worn, item.durability], Color.WHITE])
		if worn >= item.durability:
			lines.append([Lang.t("Zerstört: nur noch einzuschmelzen"), Color(0.95, 0.5, 0.45)])
	if item.get("speed", 0.0) != 0.0:
		lines.append([Lang.t("%+d%% Tempo") % roundi(item.speed * 100.0), BLUE])
	if item.has("bag"):
		lines.append([Lang.t("Platz für %d Dinge") % item.bag, BLUE])
	if item.has("uses"):
		lines.append([Lang.t("Fertigkeit: %s") % Lang.t(Training.SKILLS[item.uses].name), BLUE])
	if item.get("shock", 0.0) > 0.0:
		lines.append([Lang.t("%d%% Blitzschlag: betäubt den Gegner kurz") % roundi(item.shock * 100.0), BLUE])
	for skill_id in item.get("skills", {}):
		lines.append([Lang.t("+%d %s") % [item.skills[skill_id], Lang.t(Training.SKILLS[skill_id].name)], BLUE])
	if item.has("teaches"):
		lines.append([Lang.t("lehrt %s (beim Lernen im Bett planen)") % Lang.t(Training.SKILLS[item.teaches].name), BLUE])
	for attr in item.get("requires", {}):
		lines.append([Lang.t("braucht %s %d") % [Lang.t(Training.ATTRIBUTES[attr].name), item.requires[attr]], ORANGE])
	if item.has("effect"):
		lines.append([Lang.t(item.effect), Color(1.0, 0.85, 0.45)])
	if item.get("weight", 0.0) > 0.0:
		lines.append([Lang.t("Gewicht %s") % Items.weight_text(item.weight), GREY])
	return lines


## The number values compared between two items: [key, name, scale, unit,
## more is better].
const COMPARED := [
	["power", "Kampfkraft", 1.0, "", true],
	["hp", "Leben", 1.0, "", true],
	["armor", "Härtung", 1.0, "", true],
	["block", "Blockchance", 100.0, "%", true],
	["shock", "Blitzschlag", 100.0, "%", true],
	["speed", "Tempo", 100.0, "%", true],
	["durability", "Haltbarkeit", 1.0, "", true],
	["bag", "Taschenplätze", 1.0, "", true],
]


## How `id` compares with what the hero wears in its place. The card says
## "nothing worn here" when the place is free, and for things that are not
## worn (books, stone, ore) how many the bag holds.
static func compare_with_worn(p: Player, id: String) -> Dictionary:
	if not Items.ALL.has(id):
		return {"title": Lang.t("Derzeit angelegt"), "empty": Lang.t("Hier gibt es nichts zu vergleichen.")}
	var slot: String = Items.ALL[id].slot
	if not slot in Items.SLOTS and slot != "spezial":
		var have := p.bag.count(id)
		return {"title": Lang.t("In deiner Tasche"), "name": Items.item_name(id), "icon": id,
				"subtitle": Lang.t("%d Stück") % have,
				"lines": [[Lang.t("Tasche: %d / %d") % [p.bag_used(), p.bag_size()], GREY]]}
	var worn_slot := slot
	if slot == "spezial":
		# A free place for a special makes it a new thing; else it would take
		# the first one's place.
		if not p.equipped.has("spezial_1") or not p.equipped.has("spezial_2"):
			return {"title": Lang.t("Nichts angelegt"), "empty": Lang.t("Das ist ein neuer Gegenstand (für diesen Platz)."), "gains": gains(id)}
		worn_slot = "spezial_1"
	if not p.equipped.has(worn_slot):
		return {"title": Lang.t("Nichts angelegt"), "empty": Lang.t("Das ist ein neuer Gegenstand (für diesen Platz)."), "gains": gains(id)}
	var worn: String = p.equipped[worn_slot]
	return {"title": Lang.t("Derzeit angelegt"), "name": Items.item_name(worn), "icon": worn,
			"subtitle": subtitle(worn), "lines": stat_lines(worn, p.wear.get(worn, 0)), "diffs": diffs(id, worn)}


## What changes when `id` is worn instead of `worn`, e.g. [true, "+1 Power"].
static func diffs(id: String, worn: String) -> Array:
	return _diffs_between(Items.ALL[id], Items.ALL[worn])


## What `id` brings into a free place: every value it has, as a gain (the
## weight aside, which is no gain).
static func gains(id: String) -> Array:
	return _diffs_between(Items.ALL[id], {}).filter(func(d): return d.size() < 3)


static func _diffs_between(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for c in COMPARED:
		var d: float = (float(a.get(c[0], 0)) - float(b.get(c[0], 0))) * c[2]
		var n := roundi(d)
		if n != 0:
			out.append([(n > 0) == c[4], "%+d%s %s" % [n, c[3], Lang.t(c[1])]])
	var skills := {}
	for s in a.get("skills", {}):
		skills[s] = int(a.skills[s])
	for s in b.get("skills", {}):
		skills[s] = int(skills.get(s, 0)) - int(b.skills[s])
	for s in skills:
		if skills[s] != 0:
			out.append([skills[s] > 0, "%+d %s" % [skills[s], Lang.t(Training.SKILLS[s].name)]])
	var weight := float(a.get("weight", 0.0)) - float(b.get("weight", 0.0))
	if not is_zero_approx(weight):
		# The third value says it does not count towards "better".
		out.append([weight < 0.0, ("+" if weight > 0.0 else "-") + Lang.t("%s Gewicht") % Items.weight_text(absf(weight)), false])
	return out


## The comparison of `id` with the worn item in its place as one line of
## BBCode for the details box of an inventory: green numbers where `id` is
## better, red where it is worse (each with its sign, so colour is never the
## only cue), plain words when equal. Empty for things that are not worn.
static func compare_bbcode(p: Player, id: String) -> String:
	var compare := compare_with_worn(p, id)
	var diffs: Array
	var head: String
	if compare.has("diffs"):
		diffs = compare.diffs
		head = Lang.t("Statt %s:") % compare.name
	elif compare.has("gains"):
		diffs = compare.gains
		head = Lang.t("Nichts angelegt:")
	else:
		return ""
	var parts := ["[color=#%s]%s[/color]" % [GOLD_HEX, head.replace("[", "[lb]")]]
	if diffs.is_empty():
		parts.append(Lang.t("Gleiche Werte").replace("[", "[lb]"))
	for d in diffs:
		parts.append("[color=#%s]%s[/color]" % [(GREEN if d[0] else RED).to_html(false), d[1]])
	return " ".join(parts)


## Better in something and worse in nothing (the weight aside).
static func is_upgrade(compare: Dictionary) -> bool:
	if not compare.has("diffs") or compare.diffs.is_empty():
		return false
	var better := false
	for d in compare.diffs:
		if d.size() > 2 and not d[2]:
			continue
		if not d[0]:
			return false
		better = true
	return better


# --- Building blocks ------------------------------------------------------

func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l: Label = game._make_label(font if font else game.TEXT_FONT, size, color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.text = text
	return l


## A label beside an icon in a card: it breaks over lines in the room left,
## so a long kind or comparison never widens the card.
func _beside(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CARD_WIDTH - 36
	return l


## A price with its coin. It never widens its row or card: in a row a long
## price ("12 Iron, 300 Gold") ends in "…", in a card (`wrap`) it breaks
## over two lines.
func _price_line(text: String, ok: bool, size: int, wrap := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var coin := ItemIcon.make("kind:coin", size - 2, true)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var l := _label(text, size, game.GOLD if ok else RED)
	if wrap:
		var width := minf(l.get_minimum_size().x, CARD_WIDTH - 60.0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
	else:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _button(text: String, action: Callable, enabled: bool, min_size: Vector2, font_size: int) -> Button:
	var b: Button = game._make_button(text, action)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", UiKit.sized(font_size))
	b.disabled = not enabled
	return b


func _card(glow: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, LIST_HEIGHT)
	var style := _style(Color(0.1, 0.07, 0.045, 0.97), game.GOLD if glow else BORDER, 10, 12, 2)
	if glow:
		style.shadow_color = Color(1.0, 0.7, 0.25, 0.35)
		style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	return card


static func _style(bg: Color, border: Color, radius: int, margin: int, width := 1) -> BronzeStyle:
	var style := BronzeStyle.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
