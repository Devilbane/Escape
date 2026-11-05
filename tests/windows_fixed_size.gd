extends SceneTree
## Headless test: every window the player works in (trading, equipment,
## chests, workbenches, the barber...) keeps one fixed size. Each window is
## opened twice, once nearly empty (no gold, an empty bag, nothing learned)
## and once full to the brim (rich, a full bag of the longest names, every
## recipe), in both languages. In each, the test points at everything that
## shows details on hover, picks rows, folds categories, switches tabs, buys
## and sells. The window's frame must stay exactly where it was in all of it,
## and be the same in both openings: its size never follows its content.
## The merchants' windows all share one size.
## Run with: godot --headless -s tests/windows_fixed_size.gd
## With AUDIT=1 it prints every size it sees; with SHOTS=<folder> and a
## display it saves a screenshot of each window, full, in English.

var failures := 0
var game: Node
var frames := 0
var audit := OS.get_environment("AUDIT") != ""
var shots := OS.get_environment("SHOTS")

## The windows and the villager each belongs to (for the goodwill line).
const KINDS := {
	"inventar": "", "lager": "", "metalltruhe": "", "zutatenbord": "", "tresor": "", "bank": "", "haendler": "6", "schmied": "1",
	"steinmetz": "S", "barbier": "Z", "wanderhaendler": "", "werkbank": "", "hauswerkbank": "",
	"ausbau": "", "aushang": "", "trophaeen": "", "charakter": "", "gefaehrten": "", "wunsch": "",
	"kampfstil": "", "kompendium": "", "karte": "", "auftraege": "",
}

## The size of each window, by kind (and of every merchant's, under "trade").
var _sizes := {}
## What was being done when a window changed size, to say in the failure.
var _step := ""


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _rect() -> Rect2:
	var menus: Menus = game.menus
	return menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)


func _test() -> void:
	game.hero_name = "Window size test"
	game.load_level(game._outdoor_index(), false)
	await _wait()
	root.size = Vector2i(1280, 720)
	for lang in ["de", "en"]:
		Lang.language = lang
		Lang._apply()
		_sizes.clear()
		for full in [false, true]:
			_fill(full)
			for kind in KINDS:
				await _window(kind, "%s, %s" % [lang, "full" if full else "empty"])
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: every window keeps one size")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## Nearly nothing (`full` false), or as much as the game allows, with the
## longest names first.
func _fill(full: bool) -> void:
	var p: Player = game.player
	p.bag.clear()
	p.equipped.clear()
	p.wear.clear()
	game.storage.clear()
	game.crafting.pouch.clear()
	game.coins = 99999 if full else 0
	game.iron = 999 if full else 0
	game.menus.bench = CraftingSquare.BENCHES.values()[0].craft
	game.menus.wish_master = Wishes.STYLE_ASKER
	game.companions = []
	game.home_upgrades = {"truhe": true} if full else {}
	game.home_stores = HomeStores.empty()
	game.bars = {}
	if not full:
		return
	p.equipped["rucksack"] = "reiserucksack"
	var names := Items.ALL.keys()
	names.sort_custom(func(a, b): return Items.item_name(a).length() > Items.item_name(b).length())
	for slot in Items.SLOTS:
		for id in names:
			if not p.equipped.has(slot) and Items.ALL[id].get("slot", "") == slot:
				p.equipped[slot] = id
				if Items.ALL[id].has("durability"):
					p.wear[id] = 1
	for i in p.bag_size():
		p.bag.append(names[i % names.size()])
	for i in 12:
		game.storage.append(names[i])
	for id in Crafting.RECIPES:
		game.crafting.learn_recipe(id)
	for ingredient in Crafting.INGREDIENTS:
		game.crafting.add(ingredient, 7)
	# Both stores full of every kind they take, a long count at home too.
	for metal in Forge.FINE:
		game.bars[metal] = 99
	for store in [HomeStores.METAL, HomeStores.PANTRY]:
		for kind in HomeStores.kinds(store):
			game.home_stores[store][kind] = 99999
	for id in Quests.ALL:
		if not Quests.ALL[id].get("wish", false):
			game.quests.state[id] = {"state": "active", "count": 0}
	game.companions = Companions.ORDER.map(func(k): return Companions.make(k, "Wwwwwwwwwwwwwwwwww"))
	game.following = 0


## Opens one window, works in it and checks its frame after every step.
func _window(kind: String, where: String) -> void:
	var menus: Menus = game.menus
	game.trader_role = KINDS[kind]
	menus.open(kind)
	game.trader_role = KINDS[kind]
	menus._rebuild()
	await _wait()
	var group: String = "trade" if kind in Menus.TRADE_WINDOWS else kind
	if not _sizes.has(group):
		_sizes[group] = _rect()
	_step = "opening"
	await _same(kind, where)
	if shots != "" and where == "en, full":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join(kind + ".png"))
	for tab in _tabs(kind):
		_step = "tab " + tab
		_switch(kind, tab)
		await _same(kind, where)
		await _work(kind, where)
	menus.close()
	await _wait(1)


## The tabs of a window (or [""] for one without).
func _tabs(kind: String) -> Array:
	match kind:
		"inventar":
			return ["tasche", "beutel", "muenzen"]
		"haendler", "steinmetz":
			return ["kaufen", "verkaufen"]
		"schmied":
			return Menus.FORGE_TABS.map(func(t): return t[0])
		"kompendium":
			return ["wissen", "auftraege", "ruf", "rezepte"]
		"karte":
			return ["karte", "tagebuch"]
	return [""]


func _switch(kind: String, tab: String) -> void:
	var menus: Menus = game.menus
	match kind:
		"inventar":
			menus._show_inventory_tab(tab)
		"haendler", "steinmetz":
			menus._show_shop_page(tab)
		"schmied":
			menus._show_forge_tab(tab)
		"kompendium":
			menus.compendium_page = tab
			menus._rebuild()
		"karte":
			menus.map_page = tab
			menus._rebuild()


## Points at, picks and folds everything in the open window, then buys or
## moves something, checking the frame each time.
func _work(kind: String, where: String) -> void:
	var menus: Menus = game.menus
	var trade: TradeWindow = menus.trade
	if kind in Menus.TRADE_WINDOWS:
		for key in trade._entries.keys():
			_step = "pointing at " + key
			trade._on_row_hover(key)
			await _same(kind, where)
			_step = "picking " + key
			trade.pick(key)
			await _same(kind, where)
		trade._on_row_hover("")
		for key in trade.collapsed.keys() + _section_keys():
			_step = "folding " + key
			trade.collapsed[key] = not trade.collapsed.get(key, false)
			menus._rebuild()
			await _same(kind, where)
			trade.collapsed[key] = false
			menus._rebuild()
		# Buying (or selling) the first thing on offer, with its note.
		for key in trade._entries.keys():
			var entry: Dictionary = trade._entries[key]
			if entry.get("enabled", true) and entry.has("action") and not entry.has("gone"):
				_step = "trading " + key
				entry.action.call()
				await _same(kind, where)
				break
		_step = "a long note"  # every merchant can leave one
		menus._note = Items.describe(_longest_description()) + " " + Items.describe(_longest_description())
		menus._rebuild()
		await _same(kind, where)
		menus._note = ""
		menus._rebuild()
		return
	# Everything that shows details when pointed at.
	for c in menus._box.find_children("*", "Control", true, false):
		if c is Control and is_instance_valid(c) and c.mouse_entered.get_connections().size() > 0:
			_step = "pointing at " + (c.text.replace("\n", " ") if c is Button else c.name)
			c.mouse_entered.emit()
			await _same(kind, where)
			if is_instance_valid(c):
				c.mouse_exited.emit()
	match kind:
		"inventar":
			if game.player.bag.size() > 0:
				_step = "picking"
				menus._select(0)
				await _same(kind, where)
				_step = "dropping"
				menus._drop_selected()
				await _same(kind, where)
		"lager":
			if game.player.bag.size() > 0:
				_step = "storing"
				menus._store(0)
				await _same(kind, where)
			if game.storage.size() > 0:
				_step = "taking"
				menus._take(0)
				await _same(kind, where)
		"metalltruhe", "zutatenbord":
			var store := HomeStores.METAL if kind == "metalltruhe" else HomeStores.PANTRY
			var ids := HomeStores.shown(game, store)
			if not ids.is_empty():
				_step = "storing one"
				menus._store_move(ids[0], 1, true)
				await _same(kind, where)
				_step = "taking all"
				menus._store_move(ids[0], HomeStores.stored(game, ids[0]), false)
				await _same(kind, where)
				_step = "storing everything"
				menus._store_all(store, true)
				await _same(kind, where)
		"tresor":
			if game.player.bag.size() > 0:
				_step = "storing"
				menus._to_vault(0)
				await _same(kind, where)
	if kind in Menus.NOTE_WINDOWS:
		_step = "a long note"
		menus._note = Items.describe(_longest_description()) + " " + Items.describe(_longest_description())
		menus._rebuild()
		await _same(kind, where)
		menus._note = ""
		menus._rebuild()


func _section_keys() -> Array:
	var keys := []
	for key in game.menus.trade._seen:
		keys.append(key)
	return keys


func _longest_description() -> String:
	var best := ""
	for id in Items.ALL:
		if best == "" or Items.describe(id).length() > Items.describe(best).length():
			best = id
	return best


## The window's frame is where it was when this kind (or the first
## merchant's window) first opened.
func _same(kind: String, where: String) -> void:
	await _wait()
	var group: String = "trade" if kind in Menus.TRADE_WINDOWS else kind
	var now := _rect()
	if audit:
		print("%-16s %-10s %-40s %s content %s scale %.3f" % [kind, where, _step.left(40), now, game.menus._box.get_combined_minimum_size(), game.menus._panel.scale.x])
	check(now == _sizes[group], "%s (%s): %s changes the window to %s, was %s" % [kind, where, _step, now, _sizes[group]])
	# Nothing outgrows the fixed size: no window hides part of itself
	# behind a scroll bar it did not have before.
	var content: Vector2 = game.menus._box.get_combined_minimum_size()
	var fixed := Menus.fixed_size(kind)
	check(fixed != Vector2.ZERO, "%s has a fixed size" % kind)
	check(content.x <= fixed.x and content.y <= fixed.y, "%s (%s): %s needs %s, more than its fixed size %s" % [kind, where, _step, content, fixed])
	# The merchants' cards and rows wrap or shorten their text: none is cut
	# off at the edge of its place.
	if kind in Menus.TRADE_WINDOWS:
		var trade: TradeWindow = game.menus.trade
		for slot in [trade._detail_slot, trade._compare_slot]:
			for card in slot.get_children():
				check(card.get_combined_minimum_size().x <= TradeWindow.CARD_WIDTH, "%s (%s): %s widens a card to %s" % [kind, where, _step, card.get_combined_minimum_size()])
		for grid in game.menus._box.find_children("*", "GridContainer", true, false):
			for row in grid.get_children():
				check(row.get_combined_minimum_size().x <= TradeWindow.ROW_WIDTH, "%s (%s): %s widens a row to %s" % [kind, where, _step, row.get_combined_minimum_size()])
