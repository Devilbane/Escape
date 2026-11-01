class_name TradeWindow
extends RefCounted
## The compact trading window every merchant uses (Mira, Gorm, Hagen, Benno
## and Zarek): the gold at the top, categories that fold open and shut, and
## in each a grid of small rows (picture, name, price, button) that scrolls
## when it holds more than fits. Clicking a row picks it: the list narrows to
## one column and two cards appear beside it, one with the picked thing's
## values and its price, one with what the hero wears in that place now and
## how the two compare (green is better, red is worse). Pointing at another
## row while the cards are open shows that one instead.
##
## A section is {key, title, icon, entries, extra (optional Callable that
## returns a Control shown above the rows), empty (text when it has none)}.
## An entry is {key, id (item id or ""), icon, name, price, price_ok, button,
## action, enabled, current (what the hero has now: no button),
## detail (optional {subtitle, lines}), compare (optional {title, name,
## subtitle, icon, lines, diffs, empty})}. Lines are [text, colour] pairs,
## diffs [better, text] pairs (a third value false leaves a diff out of
## the "better" badge).

const LIST_HEIGHT := 400.0
const ROW_WIDTH := 350.0
const ROW_HEIGHT := 60.0
const CARD_WIDTH := 290.0
const BORDER := Color(0.85, 0.66, 0.32, 0.55)
const BLUE := Color(0.55, 0.75, 1.0)
const ORANGE := Color(1.0, 0.6, 0.25)
const GREY := Color(0.75, 0.72, 0.68)
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
var _detail_box: VBoxContainer
var _compare_box: VBoxContainer
var _badge_box: Control


func reset() -> void:
	collapsed.clear()
	selected = ""
	_selected_id = ""
	_hovered = ""


## Builds the window into `box`: the gold line, `extra` (e.g. Gorm's tabs),
## then the categories and, with a row picked, its cards.
func build(box: VBoxContainer, gold_text: String, sections: Array, extra: Control = null, under_gold: Control = null) -> void:
	_entries.clear()
	for section in sections:
		for entry in section.entries:
			_entries[entry.key] = entry
	_keep_selection()
	_hovered = ""
	var gold := HBoxContainer.new()
	gold.alignment = BoxContainer.ALIGNMENT_CENTER
	gold.add_theme_constant_override("separation", 8)
	gold.add_child(ItemIcon.make("kind:coin", 22, true))
	gold.add_child(_label(gold_text, 22, game.GOLD))
	box.add_child(gold)
	if under_gold:
		box.add_child(under_gold)
	if extra:
		box.add_child(extra)
	var picked := selected != ""
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 12)
	box.add_child(body)
	var columns := 1 if picked else 2
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var height := 0.0
	for section in sections:
		height += _add_section(list, section, columns)
	var width := ROW_WIDTH * columns + 8.0 * (columns - 1) + 14.0
	scroll.custom_minimum_size = Vector2(width, minf(height, LIST_HEIGHT))
	body.add_child(scroll)
	if picked:
		var middle := VBoxContainer.new()
		middle.add_theme_constant_override("separation", 4)
		_badge_box = Control.new()
		_badge_box.custom_minimum_size = Vector2(CARD_WIDTH, 26)
		middle.add_child(_badge_box)
		_detail_box = VBoxContainer.new()
		middle.add_child(_detail_box)
		body.add_child(middle)
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 4)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(CARD_WIDTH, 26)
		right.add_child(spacer)
		_compare_box = VBoxContainer.new()
		right.add_child(_compare_box)
		body.add_child(right)
		_show_cards(selected)
	else:
		_detail_box = null
		_compare_box = null
		_badge_box = null


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


## One category: its header (click to fold) and its rows. Returns its height.
func _add_section(list: VBoxContainer, section: Dictionary, columns: int) -> float:
	var folded: bool = collapsed.get(section.key, false)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _style(Color(0.1, 0.08, 0.1, 0.95), BORDER, 8, 6))
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
	var height := 46.0
	if folded:
		return height
	if section.has("extra"):
		var extra: Control = section.extra.call()
		list.add_child(extra)
		height += extra.get_combined_minimum_size().y + 6.0
	if section.entries.is_empty():
		list.add_child(_label(section.get("empty", Lang.t("Nichts im Angebot.")), 16, GREY))
		return height + 30.0
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for entry in section.entries:
		grid.add_child(_row(entry))
	list.add_child(grid)
	var rows := ceili(section.entries.size() / float(columns))
	return height + rows * (ROW_HEIGHT + 6.0) + 6.0


func _row(entry: Dictionary) -> Control:
	var picked: bool = entry.key == selected
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.1, 0.95) if picked else Color(0.07, 0.06, 0.08, 0.95),
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
	var name_label := _label(entry.name, 16, Color.WHITE)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 150
	text.add_child(name_label)
	if entry.get("price", "") != "":
		text.add_child(_price_line(entry.price, entry.get("price_ok", true), 14))
	row.add_child(text)
	if entry.get("current", false):
		var now := _label(Lang.t("Jetzt"), 15, GREEN)
		now.custom_minimum_size = Vector2(80, 0)
		now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		now.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(now)
	elif entry.has("action"):
		var b := _button(entry.get("button", Lang.t("Kaufen")), entry.action, entry.get("enabled", true), Vector2(76, 36), 15)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_entered.connect(_on_row_hover.bind(entry.key))
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
	if _detail_box == null or not is_instance_valid(_detail_box):
		return
	_hovered = key
	_show_cards(key if key != "" else selected)


# --- The two cards --------------------------------------------------------

func _show_cards(key: String) -> void:
	if not _entries.has(key):
		key = selected
	if not _entries.has(key):
		return
	var entry: Dictionary = _entries[key]
	for b in [_detail_box, _compare_box, _badge_box]:
		for child in b.get_children():
			b.remove_child(child)
			child.queue_free()
	var compare: Dictionary = entry.get("compare", compare_with_worn(game.player, entry.get("id", "")))
	_detail_box.add_child(_detail_card(entry))
	_compare_box.add_child(_compare_card(compare))
	if is_upgrade(compare):
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _style(Color(0.05, 0.2, 0.06, 0.95), GREEN, 8, 3))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(ItemIcon.make("kind:up", 12, true))
		row.add_child(_label(Lang.t("Besser"), 15, GREEN))
		badge.add_child(row)
		badge.position = Vector2(CARD_WIDTH - 110, 0)
		_badge_box.add_child(badge)


func _detail_card(entry: Dictionary) -> Control:
	var id: String = entry.get("id", "")
	var detail: Dictionary = entry.get("detail", {})
	var card := _card(true)
	var box: VBoxContainer = card.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(ItemIcon.make(entry.get("icon", id), 58))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label(entry.name, 20, game.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	names.add_child(_label(detail.get("subtitle", subtitle(id)), 15, ORANGE))
	head.add_child(names)
	box.add_child(head)
	box.add_child(HSeparator.new())
	var lines: Array = detail.get("lines", stat_lines(id, game.player.wear.get(id, 0) if game.player.equipped.values().has(id) else 0))
	for line in lines:
		box.add_child(_wrapped(line[0], 16, line[1]))
	if lines.is_empty():
		box.add_child(_wrapped(Lang.t("Keine besonderen Werte."), 16, GREY))
	if entry.has("action") and not entry.get("current", false):
		box.add_child(HSeparator.new())
		if entry.get("price", "") != "":
			var cost := _price_line(Lang.t("Kosten: %s") % entry.price, entry.get("price_ok", true), 17)
			cost.alignment = BoxContainer.ALIGNMENT_CENTER
			box.add_child(cost)
		var b := _button(entry.get("button", Lang.t("Kaufen")), entry.action, entry.get("enabled", true), Vector2(170, 46), 20)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
		var text := _wrapped(compare.empty, 16, GREY)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
		return card
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(ItemIcon.make(compare.get("icon", ""), 46))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(compare.get("name", ""), 17, Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(name_label)
	if compare.get("subtitle", "") != "":
		names.add_child(_label(compare.subtitle, 14, GREY))
	head.add_child(names)
	box.add_child(head)
	var lines: Array = compare.get("lines", [])
	if not lines.is_empty():
		box.add_child(HSeparator.new())
		for line in lines:
			box.add_child(_wrapped(line[0], 15, line[1]))
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
			row.add_child(_label(diff[1], 15, GREEN if diff[0] else RED))
			box.add_child(row)
	return card


# --- What items say ----------------------------------------------------------

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
	if item.get("speed", 0.0) != 0.0:
		lines.append([Lang.t("%+d%% Tempo") % roundi(item.speed * 100.0), BLUE])
	if item.has("bag"):
		lines.append([Lang.t("Platz für %d Dinge") % item.bag, BLUE])
	if item.has("uses"):
		lines.append([Lang.t("Fertigkeit: %s") % Lang.t(Training.SKILLS[item.uses].name), BLUE])
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
				"lines": [[Lang.t("Tasche: %d / %d") % [p.bag.size(), p.bag_size()], GREY]]}
	var worn_slot := slot
	if slot == "spezial":
		# A free place for a special makes it a new thing; else it would take
		# the first one's place.
		if not p.equipped.has("spezial_1") or not p.equipped.has("spezial_2"):
			return {"title": Lang.t("Nichts angelegt"), "empty": Lang.t("Das ist ein neuer Gegenstand (für diesen Platz).")}
		worn_slot = "spezial_1"
	if not p.equipped.has(worn_slot):
		return {"title": Lang.t("Nichts angelegt"), "empty": Lang.t("Das ist ein neuer Gegenstand (für diesen Platz).")}
	var worn: String = p.equipped[worn_slot]
	return {"title": Lang.t("Derzeit angelegt"), "name": Items.item_name(worn), "icon": worn,
			"subtitle": subtitle(worn), "lines": stat_lines(worn, p.wear.get(worn, 0)), "diffs": diffs(id, worn)}


## What changes when `id` is worn instead of `worn`, e.g. [true, "+1 Power"].
static func diffs(id: String, worn: String) -> Array:
	var a: Dictionary = Items.ALL[id]
	var b: Dictionary = Items.ALL[worn]
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


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CARD_WIDTH - 40
	return l


func _price_line(text: String, ok: bool, size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var coin := ItemIcon.make("kind:coin", size - 2, true)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	row.add_child(_label(text, size, game.GOLD if ok else RED))
	return row


func _button(text: String, action: Callable, enabled: bool, min_size: Vector2, font_size: int) -> Button:
	var b: Button = game._make_button(text, action)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.disabled = not enabled
	if not enabled:
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
	return b


func _card(glow: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var style := _style(Color(0.07, 0.05, 0.07, 0.97), game.GOLD if glow else BORDER, 10, 16, 2)
	if glow:
		style.shadow_color = Color(1.0, 0.7, 0.25, 0.35)
		style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	return card


static func _style(bg: Color, border: Color, radius: int, margin: int, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
