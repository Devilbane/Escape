class_name Menus
extends Node
## The windows that pause the dungeon: inventory, storage chest, merchant and bed.
## Each window is rebuilt from scratch whenever something in it changes.

const STORAGE_SIZE := 16
const BLUE := Color(0.65, 0.85, 1.0)
## The colour of everything about the villagers' goodwill (see Reputation).
const REPUTATION_COLOR := Color(0.78, 0.65, 1.0)

var game: Node
## The open window: "", "inventar", "lager", "haendler", "bett", "laden",
## "kompendium", "charakter", "beenden", "plan" (the day planned for the
## time away) or "rueckkehr" (what the hero did while the player was away).
var current := ""
var _panel: PanelContainer
var _box: VBoxContainer
## Width of the wrapped lines in the "Welcome back" window.
const RETURN_TEXT_WIDTH := 700
var _selected := -1
var _note := ""
## The craft of the workbench whose window is open (see CraftingSquare).
var bench := ""
## The saved game whose delete button was clicked once; a second click deletes.
var _delete_asked := ""
## Which page of the compendium shows: "wissen" (controls and everything
## learned), "auftraege" (the villagers' tasks), "ruf" (the villagers'
## opinion of the hero) or "rezepte" (the recipes found and the ingredient pouch).
var compendium_page := "wissen"
## How many saved games the load window shows before the list scrolls.
const LOAD_ROWS_SHOWN := 5
## Shows the stats of the item under the mouse (or last tapped).
var _info: Label
const INFO_HINT := "Zeig auf einen Gegenstand, um seine Werte zu sehen."
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
	["Spielstand laden", "L"],
	["Ton an/aus", "M"],
	["Steinblock abstellen", "B, oder „Abstellen“ im Inventar"],
	["Steinblock verschieben", "Block mit der linken Maustaste greifen, ziehen und loslassen (Rechtsklick dabei dreht ihn)"],
	["Steinblock aufheben", "E neben dem Block, oder ihn kurz anklicken"],
	["Schwere Steinblöcke schieben", "E neben dem Block, oder ihn kurz anklicken; ziehen lässt ihn geradeaus rutschen"],
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


func is_open() -> bool:
	return current != ""


func open(kind: String) -> void:
	current = kind
	_forge_tab = "waffen"
	trade.reset()
	_selected = -1
	_note = ""
	game.set_world_paused(true)
	_panel.visible = true
	_rebuild()


func close() -> void:
	if current == "":
		return
	current = ""
	game.trader_role = ""
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
		"werkbank":
			_build_bench()
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
	if current in ["inventar", "lager", "tresor"]:
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

## The crafts, each with its level, for the character page.
func _crafts_text() -> String:
	var parts := []
	for id in Training.CRAFTS:
		parts.append("%s %d" % [Lang.t(Training.CRAFTS[id].name), Training.skill_level(game.player.xp.get(id, 0.0), id)])
	return Lang.t("Handwerk:") + " " + "   ".join(parts)


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
		[_crafts_text(), game.GOLD],
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
		elif Items.is_quest(id) or Items.is_material(id):
			pass # Carried for a task or to the smith, not worn.
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


# --- Workbenches on the crafting square ------------------------------------

## A workbench of the crafting square: what is made there, and the recipes
## the hero knows for its craft. Until the hero knows one, it says how to
## find recipes; the storage chest and Gorm's forge are right beside it.
func _build_bench() -> void:
	game.learn(CraftingSquare.LEARN)
	var info := CraftingSquare.bench_of(bench)
	if info.is_empty():
		_add_label(Lang.t("Werkbank"), 38, game.GOLD, game.TITLE_FONT)
		return
	_add_label(Lang.t(info.name), 38, game.GOLD, game.TITLE_FONT)
	_add_label(Lang.t(info.craft_line), 22)
	_add_label(Lang.t(info.text), 18, BLUE)
	_add_label(Lang.t("Hier stellst du her, was ein Rezept für dieses Handwerk verlangt."), 18)
	_add_label(Lang.t("Du kennst noch kein Rezept für diese Werkbank. Rezepte findest du bei Gelehrten, in Truhen und als Belohnung."), 18, Color(1.0, 0.75, 0.5))
	_add_label(Lang.t("Deine Truhe und Gorms Esse stehen gleich nebenan."), 16, BLUE)


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
	return _add_label(text, 17, REPUTATION_COLOR)


## Builds a merchant's trading window (see TradeWindow), with the
## villager's goodwill under the gold.
func _trade(gold_text: String, sections: Array, extra: Control = null) -> void:
	var standing := _add_standing()
	if standing:
		_box.remove_child(standing)
	trade.build(_box, gold_text, sections, extra, standing)


# --- Merchant ---------------------------------------------------------------

static func sell_price(id: String) -> int:
	return maxi(1, Items.ALL[id].price / 2)


func _build_shop() -> void:
	var p: Player = game.player
	_add_label(Lang.t("Händler"), 38, game.GOLD, game.TITLE_FONT)
	var gear := []
	var goods := []
	for i in game.shop_stock.size():
		var id: String = game.shop_stock[i]
		var entry := _ware_entry("buy:%d" % i, id, game.trader_price(Items.ALL[id].price), _buy.bind(i))
		(goods if _is_consumable(id) else gear).append(entry)
	var selling := []
	for i in p.bag.size():
		var id: String = p.bag[i]
		selling.append({"key": "sell:%d" % i, "id": id, "name": Items.item_name(id), "price": Lang.t("%d Gold") % sell_price(id),
				"button": Lang.t("Verkaufen"), "action": _sell.bind(i)})
	_trade(Lang.t("Dein Gold: %d") % game.coins, [
		{"key": "gear", "title": Lang.t("Ausrüstung"), "icon": "kind:helmet", "entries": gear},
		{"key": "goods", "title": Lang.t("Verbrauchsgüter"), "icon": "kind:potion", "entries": goods},
		{"key": "sell", "title": Lang.t("Verkaufen (%d / %d)") % [p.bag.size(), p.bag_size()], "icon": "kind:coin", "entries": selling,
				"empty": Lang.t("Deine Tasche ist leer.")},
	])


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
		game.traded()
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
			{"key": "one", "id": STONE, "name": Lang.t("1 Steinblock"), "price": Lang.t("%d Gold") % price, "price_ok": game.coins >= price,
					"action": _buy_stones.bind(1), "enabled": room > 0 and game.coins >= price, "detail": detail, "compare": compare},
			{"key": "all", "id": STONE, "name": Lang.t("%d Steinblöcke") % maxi(all, 1), "price": Lang.t("%d Gold") % (maxi(all, 1) * price),
					"price_ok": all > 0, "action": _buy_stones.bind(all), "enabled": all > 0, "detail": detail, "compare": compare},
			{"key": "back", "id": STONE, "name": Lang.t("1 zurückgeben"), "price": "+" + Lang.t("%d Gold") % sell_price(STONE),
					"button": Lang.t("Verkaufen"), "action": _sell_stone, "enabled": have > 0, "detail": detail, "compare": compare},
		]},
	])


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
		game.traded()
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

## The smith's window shows one of four tabs: "waffen" (buy Gorm's own
## weapons), "schmieden" (forge new gear),
## "einschmelzen" (melt gear down into iron) or "ausbessern" (mend worn gear).
var _forge_tab := "waffen"
const FORGE_ABOUT := {
	"waffen": "Gorms eigene Arbeit: bessere Waffen und ein Drachenschild, die es sonst nirgends gibt.",
	"schmieden": "Aus Eisen und etwas Gold schmiedet Gorm dir neue Waffen, Schilde und Rüstungen.",
	"einschmelzen": "Metall aus deiner Tasche wird zu Eisenbarren. Stoff, Leder, Fell und Knochen schmelzen nicht.",
	"ausbessern": "Gorm hämmert Beulen aus: jeder Punkt Haltbarkeit kostet etwas Gold.",
}
const FORGE_TABS := [["waffen", "Waffen kaufen"], ["schmieden", "Schmieden"], ["einschmelzen", "Einschmelzen"], ["ausbessern", "Ausbessern"]]


func _build_smithy() -> void:
	var p: Player = game.player
	game.learn(Forge.LEARN)
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
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.add_child(tabs)
	var about := _add_label(Lang.t(FORGE_ABOUT[_forge_tab]), 16, BLUE)
	_box.remove_child(about)
	header.add_child(about)
	var room: bool = p.bag.size() < p.bag_size()
	var sections := []
	match _forge_tab:
		"waffen":
			var weapons := []
			var armour := []
			for id in Forge.wares():
				var entry := _ware_entry(id, id, Forge.ware_price(game, id), _buy_ware.bind(id))
				(weapons if Items.ALL[id].slot == "waffe" else armour).append(entry)
			sections = [
				{"key": "weapons", "title": Lang.t("Waffen"), "icon": "kind:sword", "entries": weapons},
				{"key": "shields", "title": Lang.t("Schilde und Rüstung"), "icon": "kind:shield", "entries": armour},
			]
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
			for i in p.bag.size():
				var id: String = p.bag[i]
				var can := Forge.can_melt(id)
				melt.append({"key": "melt:%d" % i, "id": id, "name": Items.item_name(id), "price": Lang.t("+%d Eisen") % Forge.melt_yield(id) if can else Lang.t("Schmilzt nicht"), "price_ok": can,
						"button": Lang.t("Einschmelzen"), "action": _melt.bind(i), "enabled": can})
			sections = [{"key": "melt", "title": Lang.t("Einschmelzen"), "icon": "kind:flame", "entries": melt,
					"empty": Lang.t("Deine Tasche ist leer.")}]
		"ausbessern":
			var mend := []
			for id in Forge.worn_down(p):
				var durability: int = Items.ALL[id].durability
				var left: int = durability - int(p.wear[id])
				mend.append({"key": id, "id": id, "name": "%s  %d / %d" % [Items.item_name(id), left, durability],
						"price": Lang.t("%d Gold") % Forge.mend_cost(p, id, game), "price_ok": game.coins >= Forge.mend_price(id, game),
						"button": Lang.t("Ausbessern"), "action": _mend.bind(id), "enabled": game.coins >= Forge.mend_price(id, game)})
			sections = [{"key": "mend", "title": Lang.t("Ausbessern"), "icon": "kind:hammer_anvil", "entries": mend,
					"empty": Lang.t("Deine Ausrüstung ist heil.")}]
	_trade(Lang.t("Dein Gold: %d    Eisen: %d") % [game.coins, game.iron], sections, header)


func _show_forge_tab(tab: String) -> void:
	_forge_tab = tab
	trade.reset()
	_note = ""
	_rebuild()


func _forge(id: String) -> void:
	var why := Forge.forge(game, id)
	_note = why if why != "" else Lang.t("Geschmiedet: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
		game.traded()
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
		game.traded()
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
		game.traded()
	_note = why if why != "" else Lang.t("Gekauft: %s (%s)") % [Items.item_name(id), Items.describe(id)]
	if why == "":
		Sfx.play(game, "gear_metal_%d" % (randi() % 3))
	game._update_hud()
	_rebuild()


func _buy_iron(count: int) -> void:
	var why := Forge.buy_iron(game, count)
	if why == "":
		game.traded()
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
	game.traded()
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
		game.traded()
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
		var text: Label = game._make_label(game.TEXT_FONT, 17)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = BOOK_COLUMN - 20
		text.text = game.crafting.describe(id)
		recipes.add_child(text)
	var ingredients := _book_column(columns, Lang.t("Zutaten"))
	for ingredient in game.crafting.book_ingredients():
		var entry: Label = game._make_label(game.TEXT_FONT, 17, BLUE)
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
	if entries.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 18)
		none.text = Lang.t("Noch keine Aufträge. Sprich mit den Leuten im Dorf: Manche haben Arbeit für dich.")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 740
		list.add_child(none)
	for id in entries:
		var q: Dictionary = Quests.ALL[id]
		var done: bool = game.quests.is_done(id)
		var title: Label = game._make_label(game.TEXT_FONT, 21, Color(0.6, 0.62, 0.66) if done else game.GOLD)
		var status: String = Lang.t("erledigt") if done else game.quests.progress(id)
		title.text = Lang.t(q.title) + ("  (%s)" % status if status != "" else "")
		list.add_child(title)
		var text: Label = game._make_label(game.TEXT_FONT, 17, Color(0.55, 0.57, 0.6) if done else Color.WHITE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 740
		text.text = Lang.t("Von %s: %s") % [Quests.villager_name(q.giver), Lang.t(q.goal)] + "\n" + Lang.t("Belohnung: %s") % Quests.reward_text(id)
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
	intro.text = Lang.t("Hilf den Leuten im Dorf, dann denken sie besser von dir. Freundlich: Rabatt und Neuigkeiten. Vertraut: mehr Rabatt, und wer ein Geheimrezept kennt, verrät es dir. Geehrt: der größte Rabatt.")
	list.add_child(intro)
	var roles: Array = game.met.keys()
	roles.sort_custom(func(a, b): return rep.points(a) > rep.points(b))
	if roles.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 18)
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
		var l: Label = game._make_label(game.TEXT_FONT, 18, REPUTATION_COLOR if lvl > 0 else Color.WHITE)
		l.text = line
		list.add_child(l)
	var title: Label = game._make_label(game.TEXT_FONT, 21, game.GOLD)
	title.text = Lang.t("Geheimrezepte")
	list.add_child(title)
	if rep.recipes.is_empty():
		var none: Label = game._make_label(game.TEXT_FONT, 17, Color(0.7, 0.72, 0.76))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 740
		none.text = Lang.t("Noch keine. Manche Leute im Dorf kennen eines, verraten es aber nur, wem sie vertrauen.")
		list.add_child(none)
	for id in rep.recipes:
		var l: Label = game._make_label(game.TEXT_FONT, 17)
		l.text = Lang.t("%s (von %s), im Tagesplan unter „Handwerk“") % [Lang.t(Offline.RECIPES[id].name), Quests.villager_name(Offline.RECIPES[id].secret)]
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
		var l := _add_label(lines[i], 22 if i == 0 else 20, BLUE if i == 0 else Color.WHITE)
		# A fixed width lets long lines wrap instead of stretching the window.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = RETURN_TEXT_WIDTH
	var go: Button = game._make_button(Lang.t("Weiter"), close)
	go.custom_minimum_size = Vector2(220, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(go)
