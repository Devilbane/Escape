extends SceneTree
## Headless test: every window (see Menus) stays inside the screen at small
## and odd window sizes. Each window is opened with as much in it as the game
## allows (full bag, every recipe, long lists), at several screen sizes and
## aspect ratios, and its frame must lie inside the visible screen.
## Run with: godot --headless -s tests/windows_fit_screen.gd
## With SHOTS=<folder> and a display it also saves screenshots of a few windows.

var failures := 0
var game: Node
var frames := 0
var audit := OS.get_environment("AUDIT") != ""
var shots := OS.get_environment("SHOTS")

const KINDS := ["inventar", "lager", "bank", "barbier", "steinmetz", "ausbau", "hauswerkbank",
	"trophaeen", "aushang", "schmied", "werkbank", "tresor", "haendler", "wanderhaendler", "bett",
	"laden", "kompendium", "charakter", "beenden", "plan", "rueckkehr", "hoehle", "karte", "kampfstil", "wunsch",
	"gefaehrten", "gefaehrte_name"]


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


func _finish() -> void:
	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: windows fit the screen")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


## Fills the hero's bag, gear, pouch, recipe book and logs to the brim.
func _fill() -> void:
	var p: Player = game.player
	game.coins = 99999
	p.bag.clear()
	p.equipped.clear()
	p.equipped["rucksack"] = "grosser_rucksack"
	for slot in Items.SLOTS:
		if p.equipped.has(slot):
			continue
		for id in Items.ALL:
			if Items.ALL[id].get("slot", "") == slot:
				p.equipped[slot] = id
				break
	var ids := Items.ALL.keys()
	for i in p.bag_size():
		p.bag.append(ids[i % ids.size()])
	for id in Crafting.RECIPES:
		game.crafting.learn_recipe(id)
	for ingredient in Crafting.INGREDIENTS:
		game.crafting.add(ingredient, 7)
	for i in 40:
		game.lore.append("Ein langer Hinweis, der viel Platz braucht, damit die Liste voll ist. %d" % i)
	for id in Quests.ALL:
		# Wishes stay open, so the wish window lists all of them.
		if not Quests.ALL[id].get("wish", false):
			game.quests.state[id] = {"state": "active", "count": 0}
	game.menus.bench = CraftingSquare.BENCHES.values()[0].craft
	game.menus.wish_master = Wishes.STYLE_ASKER
	# Every kind of companion, each with the longest name it can have.
	game.companions = Companions.ORDER.map(func(k): return Companions.make(k, "Wwwwwwwwwwwwwwwwww"))
	game.following = 0
	game.wishes.style = "schleichen"


func _test() -> void:
	game.hero_name = "Window fit test"
	game.load_level(game._outdoor_index(), false)
	await _wait()
	_fill()
	# Sizes of the game window in real pixels. The project stretches the 1280 × 720
	# design to fit, so these check odd aspect ratios: wide, square, tall, phone.
	var sizes := [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(2560, 1080), Vector2i(1024, 1024),
		Vector2i(720, 1280), Vector2i(640, 360)]
	for size in sizes:
		root.size = size
		for lang in ["de", "en"]:
			Lang.language = lang
			Lang._apply()
			for kind in KINDS:
				await _check_window(kind, "%dx%d %s" % [size.x, size.y, lang])
	# Without stretching (as when the project's stretch setting is turned off)
	# the screen can be smaller than the design; windows must still fit.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for size in [Vector2i(1024, 600), Vector2i(800, 600)]:
		root.size = size
		for kind in KINDS:
			await _check_window(kind, "unscaled %dx%d" % [size.x, size.y])
	_finish()


func _check_window(kind: String, where: String) -> void:
	var menus: Menus = game.menus
	if kind == "gefaehrte_name":
		menus.naming = 0
	menus.open(kind)
	if kind == "inventar":
		menus._select(0)
		await _check_rect("inventar/tasche", where)
		var bag_size: Vector2 = menus._panel.size
		menus._show_inventory_tab("beutel")
		await _check_rect("inventar/beutel", where)
		check(menus._panel.size == bag_size, "the pouch tab keeps the inventory's size (%s): %s, bag %s" % [where, menus._panel.size, bag_size])
		check(_has_text(menus._box, Crafting.ingredient_name("baerlauch") + "\n× 7"), "the pouch tab lists the wild garlic (%s)" % where)
	elif kind == "karte":
		for page in ["karte", "tagebuch"]:
			menus.map_page = page
			menus._rebuild()
			await _check_rect("%s/%s" % [kind, page], where)
	elif kind == "kompendium":
		for page in ["wissen", "auftraege", "ruf", "rezepte"]:
			menus.compendium_page = page
			menus._rebuild()
			await _check_rect("%s/%s" % [kind, page], where)
	else:
		await _check_rect(kind, where)
	menus.close()


func _has_text(node: Node, text: String) -> bool:
	if (node is Label or node is Button) and node.text.contains(text):
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false


func _check_rect(kind: String, where: String) -> void:
	await _wait()
	var menus: Menus = game.menus
	var screen := root.get_visible_rect()
	# The window may be scaled down to fit, so its corners go through its transform.
	var rect: Rect2 = menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)
	var inside := screen.grow(0.5).encloses(rect)
	if audit:
		print("%-24s %-16s screen %s  window %s %s" % [kind, where, screen.size, rect, "" if inside else "OUTSIDE"])
	check(inside, "%s (%s) fits the screen %s: window %s" % [kind, where, screen.size, rect])
	if shots != "" and where.ends_with(" en") and (where.begins_with("1280x720") or where.begins_with("720x1280")):
		await RenderingServer.frame_post_draw
		var name := "%s_%s" % [kind.replace("/", "_"), where.split(" ")[0]]
		root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
