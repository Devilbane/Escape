class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := 16
const BLUE := Color(0.65, 0.85, 1.0)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett", "laden",
## "kompendium", "charakter", "beenden", "plan" (the day planned for the
## time away) or "rueckkehr" (what the hero did while the player was away).
var current := ""
var _panel: PanelContainer
var _box: VBoxContainer
var _selected := -1
var _note := ""
## The saved game whose delete button was clicked once; a second click deletes.
var _delete_asked := ""
## How many saved games the load window shows before the list scrolls.
const LOAD_ROWS_SHOWN := 5
## Shows the stats of the item under the mouse (or last tapped).
var _info: Label
const INFO_HINT := "Zeig auf einen Gegenstand, um seine Werte zu sehen."
## Every control, for the compendium: action and keys.
const SHORTCUTS := [
	["Gehen", "WASD / Pfeiltasten oder Klick auf den Boden"],
	["Rennen", "Maustaste auf dem Boden halten oder Umschalt: in 3 Sekunden bis 250 % so schnell wie Gehen, so viele Sekunden wie Konstitution x 2, kommt mit Konstitution / 10 pro Sekunde zurück; leer erst wieder ab halbvoll. Wer im Lauf binnen 2 Sekunden mehr als 10 % seiner Leben verliert, stürzt zu Boden und steht wieder auf"],
	["Springen", "Leertaste, Rechtsklick im Lauf"],
	["Nahkampf", "F oder J, gegen das Skelett laufen oder es anklicken"],
	["Wurfmesser", "R oder K, Rechtsklick im Stehen"],
	["Schleichen", "C oder Doppelklick"],
	["Benutzen, durchsuchen, Fackel", "Dagegenlaufen"],
	["Inventar", "I"],
	["Kompendium", "H"],
	["Charakter", "P"],
	["Spielstand laden", "L"],
	["Ton an/aus", "M"],
	["Steinblock abstellen", "B, oder „Abstellen“ im Inventar"],
	["Steinblock verschieben", "Block mit der linken Maustaste greifen, ziehen und loslassen (Rechtsklick dabei dreht ihn)"],
	["Steinblock aufheben", "E neben dem Block, oder ihn kurz anklicken"],
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
	_forge_tab = "schmieden"
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
	if game.state == game.State.TITLE:
		game.load_window_closed()


func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	# The inventory holds the most, so its rows sit a little closer together.
	_box.add_theme_constant_override("separation", 6 if current == "inventar" else 10)
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
		"schmied":
			_build_smithy()
		"tresor":
			_build_vault()
		"haendler":
			_build_shop()
		"bett":
			_build_bed()
		"laden":
			_build_load()
		"kompendium":
			_build_compendium()
		"charakter":
			_build_character()
		"beenden":
			_build_quit()
		"plan":
			_build_plan()
		"rueckkehr":
			_build_return()
	if current in ["inventar", "lager", "haendler", "tresor", "schmied"]:
		_info = _add_label(Lang.t(INFO_HINT), 18, BLUE)
		_info.custom_minimum_size.y = 26
	if _note != "":
		_add_label(_note, 18, Color(1.0, 0.75, 0.5))
	# The inventory has its own "Back to game" button at the top instead.
	if not current in ["inventar", "bett", "laden", "beenden", "plan", "rueckkehr"]:
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

## The wheel of attributes and skills, with how a roll on a skill works.
func _build_character() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	row.add_child(CharacterPage.new(game.player, game.TEXT_FONT))
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.custom_minimum_size.x = 300
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	var title: Label = game._make_label(game.TITLE_FONT, 34, game.GOLD)
	title.text = Lang.t("Charakter")
	side.add_child(title)
	for entry in [
		[Lang.t("Jede Fertigkeit liegt im Feld der Eigenschaften, die sie bestimmen."), Color(0.85, 0.87, 0.92)],
		[Lang.t("Probe auf eine Fertigkeit:\nW100 ≤ (Summe der Eigenschaften / ihre Anzahl) × (Stufe + 1)"), game.GOLD],
		[Lang.t("Beispiel: Klingen 2, Stärke 12, Geschick 10: (12 + 10) / 2 × 3 = 33 %"), BLUE],
		[Lang.t("Ein Wuchttreffer (+1 Schaden) ist eine Probe auf die Waffen-Fertigkeit."), Color(0.85, 0.87, 0.92)],
		[Lang.t("Innen: Grundfertigkeiten. Außen: fortgeschrittene Fertigkeiten, die auf einer Grundfertigkeit aufbauen (Novize, Fortgeschritten, Meister: je 3 Stufen)."), Color(0.85, 0.87, 0.92)],
		[Lang.t("Gedimmt: braucht passende Ausrüstung"), Color(0.75, 0.75, 0.8)],
	]:
		var l: Label = game._make_label(game.TEXT_FONT, 16, entry[1])
		l.text = entry[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
		side.add_child(l)


# --- Inventory --------------------------------------------------------------

func _build_inventory() -> void:
	var p: Player = game.player
	_add_inventory_header()
	_add_label(_stats_text(), 18, BLUE)
	_add_label(_attributes_text(true), 18, game.GOLD)
	_add_label(_skills_text(), 16, Color(0.8, 0.85, 0.9))
	_add_label(Lang.t("Angelegt (anklicken zum Ablegen)"), 20)
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
		row.add_child(_item_button(text, _unequip.bind(slot), id != "", id))
	if Items.ALL.get(p.equipped.get("kopf", ""), {}).has("hat"):
		# A helmet can stay invisible, so the haircut shows; it protects all the same.
		var shown: bool = p.hair.get("show_helmet", true)
		var toggle := _item_button(Lang.t("Helm verstecken (schützt trotzdem)") if shown else Lang.t("Helm zeigen"), _toggle_helmet)
		toggle.custom_minimum_size = Vector2(300, 46)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(toggle)
	_add_label(Lang.t("Tasche (%d / %d)    Gewicht %s") % [p.bag.size(), p.bag_size(), Items.weight_text(p.carried_weight())], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _select, 4 if p.bag_size() <= 8 else 6)
	if _selected >= 0 and _selected < p.bag.size():
		var id: String = p.bag[_selected]
		_add_label("%s: %s" % [Items.item_name(id), Items.describe(id, p.wear.get(id, 0))], 18, BLUE)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 8)
		_box.add_child(actions)
		if Items.is_crate(id):
			actions.add_child(_item_button(Lang.t("Abstellen"), _put_down_selected))
		elif Items.is_stone(id):
			actions.add_child(_item_button(Lang.t("Abstellen"), _place_stone_selected))
		else:
			actions.add_child(_item_button(Lang.t("Anlegen"), _equip_selected))
		actions.add_child(_item_button(Lang.t("Wegwerfen"), _drop_selected))


## The title with a clearly visible "Back to game" button beside it. It sits
## at the top so it stays on screen however tall the window gets.
func _add_inventory_header() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_box.add_child(header)
	var back: Button = game._make_button(Lang.t("Zurück zum Spiel"), close)
	back.custom_minimum_size = Vector2(190, 52)
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
	var title: Label = game._make_label(game.TITLE_FONT, 38, game.GOLD)
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
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 18, BLUE)
	_add_label(Lang.t("Tasche (%d / %d)") % [p.bag.size(), p.bag_size()], 20)
	_add_item_grid(p.bag, p.bag_size(), Items.item_name, _store, 6)
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
	if game.player.bag.size() >= game.player.bag_size():
		_note = Lang.t("Deine Tasche ist voll.")
	else:
		game.player.bag.append(game.storage[index])
		game.storage.remove_at(index)
		_note = ""
	_rebuild()


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
		_add_label(Lang.t("Dein Schließfach im Tresorkeller hat Platz für %d Schätze.") % Bank.VAULT_SIZE, 18, BLUE)
	else:
		_add_label(Lang.t("Ein Schließfach im Tresorkeller kostet einmalig %d Gold (vom Bankkonto).") % Bank.VAULT_PRICE, 18, BLUE)
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
	_add_label(Lang.t("Klicke einen Gegenstand an, um ihn zu verschieben."), 18, BLUE)
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
	_add_item_grid(p.bag, p.bag_size(), func(id): return Lang.t("%s\n%d Gold") % [Items.item_name(id), sell_price(id)], _sell)


func _buy(index: int) -> void:
	var id: String = game.shop_stock[index]
	if game.coins < Items.ALL[id].price:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	elif game.player.bag.size() >= game.player.bag_size():
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


# --- Stonemason --------------------------------------------------------------

const STONE := "steinblock"


## The stonemason sells stone blocks, as many as the bag holds, and takes
## them back for half the price.
func _build_stonemason() -> void:
	var p: Player = game.player
	var price: int = Items.ALL[STONE].price
	var room: int = p.bag_size() - p.bag.size()
	_add_label(Lang.t("Steinmetz"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Dein Gold: %d") % game.coins, 20, game.GOLD)
	_add_label(Lang.t("Steinblöcke in deiner Tasche: %d    Platz für %d weitere") % [p.bag.count(STONE), room], 20)
	_add_label(Lang.t("Behauene Steinblöcke zum Bauen: Mauern, Stufen, Türme. Abstellen mit B oder im Inventar, verschieben mit der Maus: greifen, ziehen, loslassen."), 16, BLUE)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	var all := mini(room, game.coins / price) if price > 0 else room
	row.add_child(_item_button(Lang.t("1 Steinblock\n%d Gold") % price, _buy_stones.bind(1), room > 0 and game.coins >= price, STONE))
	row.add_child(_item_button(Lang.t("%d Steinblöcke\n%d Gold") % [maxi(all, 1), maxi(all, 1) * price], _buy_stones.bind(all), all > 0, STONE))
	row.add_child(_item_button(Lang.t("1 zurückgeben\n+%d Gold") % sell_price(STONE), _sell_stone, p.bag.has(STONE), STONE))


func _buy_stones(count: int) -> void:
	var p: Player = game.player
	var price: int = Items.ALL[STONE].price
	var bought := 0
	for i in count:
		if game.coins < price or p.bag.size() >= p.bag_size():
			break
		game.coins -= price
		p.bag.append(STONE)
		bought += 1
	if bought > 0:
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


# --- Smith -------------------------------------------------------------------

## The smith's window shows one of three tabs: "schmieden" (forge new gear),
## "einschmelzen" (melt gear down into iron) or "ausbessern" (mend worn gear).
var _forge_tab := "schmieden"
const FORGE_TABS := [["schmieden", "Schmieden"], ["einschmelzen", "Einschmelzen"], ["ausbessern", "Ausbessern"]]


func _build_smithy() -> void:
	var p: Player = game.player
	game.learn(Forge.LEARN)
	_add_label(Lang.t("Schmiede"), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t("Dein Gold: %d    Eisen: %d") % [game.coins, game.iron], 20, game.GOLD)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	_box.add_child(tabs)
	for tab in FORGE_TABS:
		var b := _item_button(Lang.t(tab[1]), _show_forge_tab.bind(tab[0]))
		if tab[0] == _forge_tab:
			b.modulate = Color(0.7, 1.0, 0.7)
		tabs.add_child(b)
	match _forge_tab:
		"schmieden":
			_add_label(Lang.t("Aus Eisen und etwas Gold schmiedet Gorm dir neue Waffen, Schilde und Rüstungen."), 16, BLUE)
			var grid := _forge_grid()
			for id in Forge.recipes():
				var cost := Forge.forge_cost(id)
				var ok: bool = game.iron >= cost.iron and game.coins >= cost.gold and p.bag.size() < p.bag_size()
				grid.add_child(_item_button(Lang.t("%s\n%d Eisen, %d Gold") % [Items.item_name(id), cost.iron, cost.gold], _forge.bind(id), ok, id))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			_box.add_child(row)
			row.add_child(_item_button(Lang.t("1 Eisenbarren\n%d Gold") % Forge.IRON_PRICE, _buy_iron.bind(1), game.coins >= Forge.IRON_PRICE))
			row.add_child(_item_button(Lang.t("%d Eisenbarren\n%d Gold") % [5, 5 * Forge.IRON_PRICE], _buy_iron.bind(5), game.coins >= 5 * Forge.IRON_PRICE))
		"einschmelzen":
			_add_label(Lang.t("Metall aus deiner Tasche wird zu Eisenbarren. Stoff, Leder, Fell und Knochen schmelzen nicht."), 16, BLUE)
			var grid := _forge_grid()
			for i in p.bag_size():
				if i < p.bag.size():
					var id: String = p.bag[i]
					var text := Lang.t("%s\n+%d Eisen") % [Items.item_name(id), Forge.melt_yield(id)] if Forge.can_melt(id) else Items.item_name(id)
					grid.add_child(_item_button(text, _melt.bind(i), Forge.can_melt(id), id))
				else:
					grid.add_child(_item_button("-", func(): pass, false))
		"ausbessern":
			_add_label(Lang.t("Gorm hämmert Beulen aus: jeder Punkt Haltbarkeit kostet etwas Gold."), 16, BLUE)
			var worn := Forge.worn_down(p)
			if worn.is_empty():
				_add_label(Lang.t("Deine Ausrüstung ist heil."), 20)
			var grid := _forge_grid()
			for id in worn:
				var durability: int = Items.ALL[id].durability
				var left: int = durability - int(p.wear[id])
				grid.add_child(_item_button(Lang.t("%s %d / %d\n%d Gold") % [Items.item_name(id), left, durability, Forge.mend_cost(p, id)], _mend.bind(id), game.coins >= Forge.mend_price(id), id))


func _forge_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(grid)
	return grid


func _show_forge_tab(tab: String) -> void:
	_forge_tab = tab
	_note = ""
	_rebuild()


func _forge(id: String) -> void:
	var why := Forge.forge(game, id)
	_note = why if why != "" else Lang.t("Geschmiedet: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
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
	var p: Player = game.player
	var durability: int = Items.ALL[id].durability
	_note = why if why != "" else Lang.t("Ausgebessert: %s, Haltbarkeit %d / %d") % [Items.item_name(id), durability - int(p.wear.get(id, 0)), durability]
	if why == "":
		Sfx.play(game, "hit")
	game._update_hud()
	_rebuild()


func _buy_iron(count: int) -> void:
	var why := Forge.buy_iron(game, count)
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
	_add_label(Lang.t("Dein Gold: %d") % game.coins, 20, game.GOLD)
	_add_label(Lang.t("Frisur"), 20)
	_add_barber_row(BARBER_STYLES, "style")
	_add_label(Lang.t("Farbe"), 20)
	_add_barber_row(BARBER_COLORS.slice(0, 6), "color")
	_add_barber_row(BARBER_COLORS.slice(6), "color")
	_add_label(Lang.t("Tätowierung an der rechten Kopfseite (nur auf geschorenem Kopf zu sehen)"), 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var edit := LineEdit.new()
	edit.max_length = HairLook.TATTOO_MAX
	edit.text = _tattoo_word
	edit.placeholder_text = Lang.t("Ein Wort")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(260, 54)
	edit.add_theme_font_override("font", game.TEXT_FONT)
	edit.add_theme_font_size_override("font_size", 22)
	edit.add_theme_stylebox_override("normal", panel_style(Color(0.85, 0.66, 0.32, 0.8)))
	edit.add_theme_stylebox_override("focus", panel_style(game.GOLD))
	edit.text_changed.connect(func(t): _tattoo_word = t)
	edit.text_submitted.connect(func(_t): _ink_tattoo())
	row.add_child(edit)
	for shape in [["straight", "Gerade"], ["arch", "Im Halbkreis"]]:
		var chosen: bool = _tattoo_shape == shape[0]
		var b := _item_button(Lang.t("Jetzt: %s") % Lang.t(shape[1]) if chosen else Lang.t(shape[1]), _pick_tattoo_shape.bind(shape[0]), not chosen)
		b.custom_minimum_size = Vector2(150, 54)
		row.add_child(b)
	row.add_child(_item_button(Lang.t("Stechen\n%d Gold") % TATTOO_PRICE, _ink_tattoo, game.coins >= TATTOO_PRICE))
	row.add_child(_item_button(Lang.t("Entfernen\n%d Gold") % TATTOO_REMOVE_PRICE, _remove_tattoo,
			p.hair.tattoo != "" and game.coins >= TATTOO_REMOVE_PRICE))


## One row of choices; what the hero has now is marked and cannot be bought again.
func _add_barber_row(choices: Array, field: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for c in choices:
		var current: bool = game.player.hair[field] == c[0]
		var text := Lang.t("Jetzt: %s") % Lang.t(c[1]) if current else Lang.t("%s\n%d Gold") % [Lang.t(c[1]), c[2]]
		var b := _item_button(text, _restyle.bind(field, c[0], c[2]), not current and game.coins >= c[2])
		b.custom_minimum_size = Vector2(150, 54)
		row.add_child(b)


func _restyle(field: String, id: String, price: int) -> void:
	if game.coins < price:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
		_rebuild()
		return
	game.coins -= price
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
	elif game.coins < TATTOO_PRICE:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	else:
		game.coins -= TATTOO_PRICE
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
	if game.coins < TATTOO_REMOVE_PRICE:
		_note = Lang.t("Dafür reicht dein Gold nicht.")
	else:
		game.coins -= TATTOO_REMOVE_PRICE
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
		_add_label(_note, 18, Color(1.0, 0.75, 0.5))
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
	if info.escaped:
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
	# Newest first: the latest hint or explanation sits at the top.
	for i in range(game.lore.size() - 1, -1, -1):
		var entry: String = game.lore[i]
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
