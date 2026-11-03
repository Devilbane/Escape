extends SceneTree
## Headless test for the colour code of item rarity (see Rarity): every tier
## has its own readable colour, the secret rooms use the same ones, and an
## item's name shows in its colour in the inventory, its details, the
## storage chest, the merchant's rows and cards, and the event log.
## Run with: godot --headless -s tests/rarity_colours.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var shots := OS.get_environment("SHOTS")

## One piece of each tier, plain to finest, then one the hero crafts.
const SAMPLES := {"schwert": "normal", "wappenschild": "ungewoehnlich", "axt": "selten",
		"stachelschild": "episch", "langschwert": "gottgeboren", "klingenring": Rarity.SELF_MADE}
## The window's dark ground (see Menus.panel_style).
const WINDOW := Color(0.04, 0.03, 0.08)


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


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


## WCAG contrast of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


func _test() -> void:
	root.size = Vector2i(1280, 720)
	Lang.language = "en"
	Lang._apply()
	game.hero_name = "Rarity colour test"
	game.load_level(game._outdoor_index(), false)
	game._title.visible = false
	_test_code()
	await _test_inventory()
	await _test_storage()
	await _test_merchant()
	await _test_event_log()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: rarity colours")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _test_code() -> void:
	for id in SAMPLES:
		check(Rarity.tier(id) == SAMPLES[id], "%s is %s, not %s" % [id, SAMPLES[id], Rarity.tier(id)])
	check(Rarity.tier("goldkarpfen") == "selten" and Rarity.tier("barsch") == "normal", "rare ingredients are rare, others common")
	check(Rarity.tier("eisen") == "normal", "iron bars are common")
	# One colour code: the secret rooms' tiers wear the same colours.
	for t in Level.TIERS:
		check(Level.TIERS[t].color == Rarity.TIERS[t].color, "the secret tier %s has the rarity colour" % t)
		check(Level.TIERS[t].name == Rarity.TIERS[t].name, "the secret tier %s has the rarity name" % t)
	var colours := []
	for t in Rarity.TIERS:
		var c: Color = Rarity.TIERS[t].color
		check(_contrast(c, WINDOW) >= 4.5, "%s reads on the window (%.1f : 1)" % [t, _contrast(c, WINDOW)])
		check(Lang.EN.has(Rarity.TIERS[t].name), "%s has an English name" % t)
		for other in colours:
			var d: float = Vector3(c.r - other.r, c.g - other.g, c.b - other.b).length()
			check(d > 0.3, "%s stands apart from the other tiers (%.2f)" % [t, d])
		colours.append(c)
	check(Lang.t("Selbst gefertigt") == "Self-crafted", "the hero's own work is named in English")
	# Marks in a text turn into names, plain or coloured.
	var text := "Found: %s and %s" % [Rarity.marked("axt"), Rarity.marked("goldkarpfen")]
	check(Rarity.plain(text) == "Found: %s and %s" % [Items.item_name("axt"), Crafting.ingredient_name("goldkarpfen")], "marks become plain names: " + Rarity.plain(text))
	check(Rarity.to_bbcode(text).contains("[color=#%s]%s[/color]" % [Rarity.RARE.to_html(false), Items.item_name("axt")]), "marks become coloured names")


func _test_inventory() -> void:
	var p: Player = game.player
	var menus: Menus = game.menus
	p.bag.clear()
	p.equipped.clear()
	p.equipped["rucksack"] = "grosser_rucksack"
	p.equipped["waffe"] = "langschwert"
	for id in SAMPLES:
		p.bag.append(id)
	p.bag.append("fackel")
	menus.open("inventar")
	await _wait()
	var cells := {}
	for b in menus._box.find_children("*", "Button", true, false):
		for id in SAMPLES:
			if b.text.replace("\n", " ").begins_with(Items.item_name(id).substr(0, 8)):
				cells[id] = b
	for id in SAMPLES:
		check(cells.has(id), "the bag shows %s" % id)
		if cells.has(id):
			check(cells[id].get_theme_color("font_color") == Rarity.color(id), "%s's name is in its rarity colour" % id)
	# The worn weapon's slot too.
	var worn_ok := false
	for b in menus._box.find_children("*", "Button", true, false):
		if b.text.contains(Items.item_name("langschwert")) and b.get_theme_color("font_color") == Rarity.GODBORN:
			worn_ok = true
	check(worn_ok, "the worn god-born sword is orange in its slot")
	# The details name the rarity in words, the name in its colour.
	menus._select(p.bag.find("axt"))
	await _wait()
	check(menus._info.get_parsed_text().contains("%s (%s)" % [Items.item_name("axt"), Lang.t("Selten")]), "the details name the rarity: " + menus._info.get_parsed_text())
	check(menus._info.text.contains(Rarity.RARE.to_html(false)), "the details show the name in blue")
	await _shot("inventory_rare_picked")
	menus._select(p.bag.find("klingenring"))
	await _wait()
	check(menus._info.get_parsed_text().contains(Lang.t("Selbst gefertigt")), "the details say the ring is self-crafted")
	await _shot("inventory_crafted_picked")
	menus.close()


func _test_storage() -> void:
	var menus: Menus = game.menus
	game.storage.clear()
	game.storage.append("stachelschild")
	menus.open("lager")
	await _wait()
	var ok := false
	for b in menus._box.find_children("*", "Button", true, false):
		if b.text.replace("\n", " ").contains(Items.item_name("stachelschild")) and b.get_theme_color("font_color") == Rarity.EPIC:
			ok = true
	check(ok, "the storage chest shows the epic shield in violet")
	menus._show_info("stachelschild")
	check(menus._info.text.contains(Rarity.EPIC.to_html(false)), "the chest's info line colours the name")
	await _shot("storage_epic")
	menus.close()


func _test_merchant() -> void:
	var p: Player = game.player
	var menus: Menus = game.menus
	var trade: TradeWindow = menus.trade
	p.bag.clear()
	p.equipped.clear()
	p.bag.append("rundschild")
	p.equip("rundschild")
	game.coins = 300
	game.shop_stock.assign(["schwert", "wappenschild", "axt", "stachelschild", "eilstiefel", "baerenkappe", "lederwams", "wurfbuch"])
	menus.open("haendler")
	await _wait()
	var rows := {}
	for l in menus._box.find_children("*", "Label", true, false):
		for id in ["schwert", "wappenschild", "axt", "stachelschild"]:
			if l.text == Items.item_name(id):
				rows[id] = l
	for id in ["schwert", "wappenschild", "axt", "stachelschild"]:
		check(rows.has(id) and rows[id].get_theme_color("font_color") == Rarity.color(id), "the merchant's row for %s is in its colour" % id)
	for key in trade._entries:
		if trade._entries[key].get("id", "") == "stachelschild" and not key.begins_with("sell:"):
			trade.pick(key)
	await _wait()
	var line := "%s · %s" % [Lang.t("Episch"), TradeWindow.subtitle("stachelschild")]
	var found := false
	for l in menus._box.find_children("*", "Label", true, false):
		if l.text == line and l.get_theme_color("font_color") == Rarity.EPIC:
			found = true
	check(found, "the card says '%s' in violet" % line)
	await _shot("merchant_epic_card")
	menus.close()


func _test_event_log() -> void:
	var log: EventLog = game.event_log
	for id in ["schwert", "axt", "langschwert"]:
		Events.found(Lang.t("Gefunden: %s (%s)") % [Rarity.marked(id), Items.describe(id)])
	Events.found(Lang.t("Ein seltener Fang: %s!") % Rarity.marked("goldkarpfen"), Color(0.6, 0.85, 1.0))
	await _wait()
	var lines := log.entries()
	check(lines.size() >= 4, "the log has the finds")
	for l in lines:
		check(not l.contains(Rarity.MARK_OPEN) and not l.contains(Rarity.MARK_CLOSE), "no marks show in the log: " + l)
	check(lines[-2].contains(Items.item_name("langschwert")), "the log names the find")
	var last: RichTextLabel = log._lines.get_child(log._lines.get_child_count() - 2)
	check(last.text.contains(Rarity.GODBORN.to_html(false)), "the god-born sword is orange in the log")
	await _shot("event_log")
