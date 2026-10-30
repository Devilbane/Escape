class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := 16
const BLUE := Color(0.65, 0.85, 1.0)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett", "laden" or "beenden".
var current := ""
var _panel: PanelContainer
var _box: VBoxContainer
var _selected := -1
var _note := ""


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
		"beenden":
			_build_quit()
	if _note != "":
		_add_label(_note, 18, Color(1.0, 0.75, 0.5))
	if not current in ["bett", "laden", "beenden"]:
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


func _item_button(text: String, action: Callable, enabled := true) -> Button:
	var b: Button = game._make_button(text, action)
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
			var b := _item_button(label_of.call(items[i]), action.bind(i))
			if current == "inventar" and i == _selected:
				b.modulate = Color(0.7, 1.0, 0.7)
			grid.add_child(b)
		else:
			grid.add_child(_item_button("-", func(): pass, false))


func _stats_text() -> String:
	var p: Player = game.player
	return Lang.t("Leben %d / %d    Kampfkraft %d    Härtung %d / %d    Tempo %d%%    Messer %d    Gold %d") % [
		p.hp, p.max_hp, p.power, p.armor_points, p.hardening, roundi(p.speed / Player.SPEED * 100.0), p.knives, game.coins]


# --- Inventory --------------------------------------------------------------

func _build_inventory() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Inventar"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(_stats_text(), 18, BLUE)
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
		row.add_child(_item_button(text, _unequip.bind(slot), id != ""))
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag.size(), Items.BAG_SIZE], 20)
	_add_item_grid(p.bag, Items.BAG_SIZE, Items.item_name, _select)
	if _selected >= 0 and _selected < p.bag.size():
		var id: String = p.bag[_selected]
		_add_label("%s: %s" % [Items.item_name(id), Items.describe(id)], 18, BLUE)
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
	p.equip(p.bag[_selected])
	_selected = -1
	_note = ""
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
		_add_label(Lang.t("Es gibt noch keinen Spielstand. Gespeichert wird im Bett der Zuflucht."), 20)
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
