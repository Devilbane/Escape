class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := 16
const BLUE := Color(0.65, 0.85, 1.0)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett", "laden",
## "kompendium", "beenden", "plan" (the day planned for the time away) or
## "rueckkehr" (what the hero did while the player was away).
var current := ""
var _panel: PanelContainer
var _box: VBoxContainer
var _selected := -1
var _note := ""
## Shows the stats of the item under the mouse (or last tapped).
var _info: Label
const INFO_HINT := "Zeig auf einen Gegenstand, um seine Werte zu sehen."
## Every control, for the compendium: action and keys.
const SHORTCUTS := [
	["Laufen", "WASD / Pfeiltasten, Klick oder Halten auf den Boden"],
	["Springen", "Leertaste, Rechtsklick im Lauf"],
	["Nahkampf", "F oder J, gegen das Skelett laufen oder es anklicken"],
	["Wurfmesser", "R oder K, Rechtsklick im Stehen"],
	["Schleichen", "C oder Doppelklick"],
	["Benutzen, durchsuchen, Fackel", "Dagegenlaufen"],
	["Inventar", "I"],
	["Kompendium", "H"],
	["Spielstand laden", "L"],
	["Ton an/aus", "M"],
	["Zoom", "+ und −, Mausrad"],
	["Spiel beenden", "Esc"],
]


func setup(owner_game: Node, hud: CanvasLayer) -> void:
	game = owner_game
	# The centring container keeps the window in the middle whatever its size.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style(Color(0.85, 0.66, 0.32, 0.7)))
	_panel.visible = false
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)


static func panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.9)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(26)
	return style


func is_open() -> bool:
	return current != ""


func open(kind: String) -> void:
	current = kind
	_selected = -1
	_note = ""
	game.set_world_paused(true)
	_panel.visible = true
	_rebuild()


func close() -> void:
	if current == "":
		return
	current = ""
	_panel.visible = false
	game.set_world_paused(false)
	game._update_hud()


func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	match current:
		"inventar":
			_build_inventory()
		"lager":
			_build_storage()
		"haendler":
			_build_shop()
		"bett":
			_build_bed()
		"laden":
			_build_load()
		"kompendium":
			_build_compendium()
		"beenden":
			_build_quit()
		"plan":
			_build_plan()
		"rueckkehr":
			_build_return()
	if current in ["inventar", "lager", "haendler"]:
		_info = _add_label(Lang.t(INFO_HINT), 18, BLUE)
		_info.custom_minimum_size.y = 26
	if _note != "":
		_add_label(_note, 18, Color(1.0, 0.75, 0.5))
	if not current in ["bett", "laden", "beenden", "plan", "rueckkehr"]:
		var close_button: Button = game._make_button(Lang.t("Schließen"), close)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_button.custom_minimum_size = Vector2(180, 52)
		_box.add_child(close_button)


# --- Building blocks ------------------------------------------------------

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
	if not enabled:
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
	return b


## A grid of item buttons; empty places up to `size` are shown as dashes.
func _add_item_grid(items: Array, size: int, label_of: Callable, action: Callable, columns := 4) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(grid)
	for i in size:
		if i < items.size():
			var b := _item_button(label_of.call(items[i]), action.bind(i), true, items[i])
			if current == "inventar" and i == _selected:
				b.modulate = Color(0.7, 1.0, 0.7)
			grid.add_child(b)
		else:
			grid.add_child(_item_button("-", func(): pass, false))


func _show_info(id: String) -> void:
	if _info == null or not is_instance_valid(_info):
		return
	if id == "":
		_info.text = Lang.t(INFO_HINT)
	else:
		_info.text = "%s: %s" % [Items.item_name(id), Items.describe(id, game.player.wear.get(id, 0))]


func _stats_text() -> String:
	var p: Player = game.player
	return Lang.t("Leben %d / %d    Kampfkraft %d    Härtung %d    Tempo %d%%    Messer %d    Gold %d") % [
		p.hp, p.max_hp, p.power, p.hardening, roundi(p.speed / Player.SPEED * 100.0), p.knives, game.coins]


## The hero's attributes, each with how far it is to the next point.
func _attributes_text() -> String:
	var p: Player = game.player
	var parts := []
	for id in Training.ATTRIBUTES:
		var value := p.attribute(id)
		var shown := ("%d%%" % value) if id == "tempo" else str(value)
		var at_cap: bool = value >= Training.ATTRIBUTES[id].max
		parts.append("%s %s%s" % [Lang.t(Training.ATTRIBUTES[id].name), shown,
				Lang.t(" (höchster Wert)") if at_cap else " (%d%%)" % floori(Training.attribute_progress(id, p.xp.get(id, 0.0)) * 100.0)])
	return "    ".join(parts)


## Every skill with its level; skills the worn gear does not allow are in brackets.
func _skills_text() -> String:
	var p: Player = game.player
	var parts := []
	for id in Training.SKILLS:
		var text := "%s %d" % [Lang.t(Training.SKILLS[id].name), p.skill(id) if p.skill_enabled(id) else Training.skill_level(p.xp.get(id, 0.0))]
		parts.append(text if p.skill_enabled(id) else "(%s)" % text)
	return Lang.t("Fertigkeiten:") + " " + "   ".join(parts) + "\n" + Lang.t("In Klammern: braucht passende Ausrüstung")


# --- Inventory --------------------------------------------------------------

func _build_inventory() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Inventar"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(_stats_text(), 18, BLUE)
	_add_label(_attributes_text(), 18, game.GOLD)
	_add_label(_skills_text(), 16, Color(0.8, 0.85, 0.9))
	_add_label(Lang.t("Angelegt (anklicken zum Ablegen)"), 20)
	var row := GridContainer.new()
	row.columns = 5
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(row)
	for slot in Items.SLOTS:
		var id: String = p.equipped.get(slot, "")
		var text: String = "%s\n%s" % [Lang.t(Items.SLOT_NAMES[slot]), Items.item_name(id) if id != "" else "-"]
		row.add_child(_item_button(text, _unequip.bind(slot), id != "", id))
	_add_label(Lang.t("Tasche (%d / %d)    Gewicht %s") % [p.bag.size(), Items.BAG_SIZE, Items.weight_text(p.carried_weight())], 20)
	_add_item_grid(p.bag, Items.BAG_SIZE, Items.item_name, _select)
	if _selected >= 0 and _selected < p.bag.size():
		var id: String = p.bag[_selected]
		_add_label("%s: %s" % [Items.item_name(id), Items.describe(id, p.wear.get(id, 0))], 18, BLUE)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 8)
		_box.add_child(actions)
		actions.add_child(_item_button(Lang.t("Anlegen"), _equip_selected))
		actions.add_child(_item_button(Lang.t("Wegwerfen"), _drop_selected))


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
	p.equip(id)
	_selected = -1
	_rebuild()


func _drop_selected() -> void:
	var p: Player = game.player
	_note = Lang.t("%s weggeworfen.") % Items.item_name(p.bag[_selected])
	p.bag.remove_at(_selected)
	_selected = -1
	_rebuild()


func _unequip(slot: String) -> void:
	_note = "" if game.player.unequip(slot) else Lang.t("Deine Tasche ist voll.")
	_selected = -1
	_rebuild()


# --- Storage chest ----------------------------------------------------------

func _build_storage() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Lagertruhe"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 18, BLUE)
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag.size(), Items.BAG_SIZE], 20)
	_add_item_grid(p.bag, Items.BAG_SIZE, Items.item_name, _store, 6)
	_add_label(Lang.t("Truhe (%d / %d)") % [game.storage.size(), STORAGE_SIZE], 20)
	_add_item_grid(game.storage, STORAGE_SIZE, Items.item_name, _take, 6)


func _store(index: int) -> void:
	if game.storage.size() >= STORAGE_SIZE:
		_note = Lang.t("Die Truhe ist voll.")
	else:
		game.storage.append(game.player.bag[index])
		game.player.bag.remove_at(index)
		_note = ""
	_rebuild()


func _take(index: int) -> void:
	if game.player.bag.size() >= Items.BAG_SIZE:
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(game.storage[index])
		game.storage.remove_at(index)
		_note = ""
	_rebuild()


# --- Merchant ---------------------------------------------------------------

static func sell_price(id: String) -> int:
	return maxi(1, Items.ALL[id].price / 2)


func _build_shop() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Händler"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Dein Gold: %d") % game.coins, 20, game.GOLD)
	_add_label(Lang.t("Kaufen"), 20)
	_add_item_grid(game.shop_stock, maxi(4, game.shop_stock.size()), func(id): return Lang.t("%s\n%d Gold") % [Items.item_name(id), Items.ALL[id].price], _buy)
	_add_label(Lang.t("Verkaufen"), 20)
	_add_item_grid(p.bag, Items.BAG_SIZE, func(id): return Lang.t("%s\n%d Gold") % [Items.item_name(id), sell_price(id)], _sell)


func _buy(index: int) -> void:
	var id: String = game.shop_stock[index]
	if game.coins < Items.ALL[id].price:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	elif game.player.bag.size() >= Items.BAG_SIZE:
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.coins -= Items.ALL[id].price
		game.player.bag.append(id)
		game.shop_stock.remove_at(index)
		_note = Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	_rebuild()


func _sell(index: int) -> void:
	var id: String = game.player.bag[index]
	game.coins += sell_price(id)
	game.player.bag.remove_at(index)
	game.shop_stock.append(id)
	_note = Lang.t("Verkauft: %s für %d Gold") % [Items.item_name(id), sell_price(id)]
	_rebuild()


# --- Bed --------------------------------------------------------------------

## Asks before loading the saved game in the middle of a run.
func _build_load() -> void:
	_add_label(Lang.t("Spielstand laden"), 38, game.GOLD, game.TITLE_FONT)
	var info: Dictionary = game.save_info()
	if info.is_empty():
		_add_label(Lang.t("Es gibt noch keinen Spielstand. Gespeichert wird beim Betreten der Zuflucht und in ihrem Bett."), 20)
	else:
		_add_label(Lang.t("%s auf Ebene %d mit %d Gold.") % [info.name, info.level, info.coins], 22)
		_add_label(Lang.t("Was du seitdem erlebt hast, geht verloren."), 20, Color(1.0, 0.75, 0.5))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	if not info.is_empty():
		var load_button: Button = game._make_button(Lang.t("Laden"), func():
			close()
			game.load_saved_game())
		load_button.custom_minimum_size = Vector2(220, 60)
		row.add_child(load_button)
	var cancel: Button = game._make_button(Lang.t("Abbrechen"), close)
	cancel.custom_minimum_size = Vector2(220, 60)
	row.add_child(cancel)


## Every control on one side, everything the hero has been told on the other.
func _build_compendium() -> void:
	_add_label(Lang.t("Kompendium"), 38, game.GOLD, game.TITLE_FONT)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	_box.add_child(columns)

	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 4)
	columns.add_child(keys)
	var keys_title: Label = game._make_label(game.TEXT_FONT, 24, game.GOLD)
	keys_title.text = Lang.t("Steuerung")
	keys.add_child(keys_title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	keys.add_child(grid)
	for s in SHORTCUTS:
		var what: Label = game._make_label(game.TEXT_FONT, 17, BLUE)
		what.text = Lang.t(s[0])
		what.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(what)
		var how: Label = game._make_label(game.TEXT_FONT, 17)
		how.text = Lang.t(s[1])
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size.x = 260
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
		var none: Label = game._make_label(game.TEXT_FONT, 18)
		none.text = Lang.t("Noch nichts. Hinweise und Erklärungen sammeln sich hier.")
		list.add_child(none)
	for entry in game.lore:
		var l: Label = game._make_label(game.TEXT_FONT, 17)
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


func _build_bed() -> void:
	_add_label(Lang.t("Ein weiches Bett"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Hier kannst du dich ausruhen. Dein Spiel wird gespeichert\nund du loggst dich aus. Später geht es genau hier weiter."), 20)
	_add_label(Lang.t("Solange du weg bist, lebt dein Held nach seinem Tagesplan:"), 20, BLUE)
	_add_label(_plan_summary(), 18, game.GOLD)
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
	_add_label(Lang.t("Je 10 Minuten, die du weg bist, ist für deinen Helden eine Stunde: ein Tag dauert 4 Stunden.\nDein Held lebt diesen Tag immer wieder, höchstens 8 Tage lang (32 Stunden)."), 18, BLUE)
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
			var sleep_label: Label = game._make_label(game.TEXT_FONT, 18)
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
		_add_label(_note, 18, Color(1.0, 0.75, 0.5))
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
		_add_label(lines[i], 22 if i == 0 else 20, BLUE if i == 0 else Color.WHITE)
	var go: Button = game._make_button(Lang.t("Weiter"), close)
	go.custom_minimum_size = Vector2(220, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(go)
