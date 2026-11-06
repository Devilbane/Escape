extends SceneTree
## Headless test: small things stack and the biggest backpack holds 20.
## Rings, amulets, bracelets and animal food bundle up to five alike in one
## bag slot, like torches; different items (a copper ring and a ruby ring)
## never share a slot. A full bag still takes one more of a bundle with room,
## the inventory shows one cell with its count, equipping one off a bundle
## keeps the rest bundled, and a swap that would need a slot the bag lacks
## is refused. The traveller's backpack gives 20 slots, the inventory shows
## 20 cells for it and the window still fits a 1280 x 720 screen.
## Run with: godot --headless --fixed-fps 60 -s tests/jewellery_stacks.gd

const BIG := "reiserucksack"

var failures := 0
var game: Node
var frames := 0


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


## The first item of a slot that needs nothing to wear.
func _of_slot(slot: String, skip := "") -> String:
	for id in Items.ALL:
		if id != skip and Items.ALL[id].slot == slot and Items.ALL[id].get("requires", {}).is_empty() and not Items.ALL[id].get("custom", false):
			return id
	return ""


## Something plain to fill the bag with: never bundled.
func _filler() -> String:
	for id in Items.ALL:
		if Items.ALL[id].slot in ["waffe", "schild", "schuhe"] and Items.stack_size(id) == 1:
			return id
	return ""


## The bag cells (inventory grid buttons) in the open window.
func _cells(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c is Button and c.custom_minimum_size == Menus.INVENTORY_CELL and c.get_parent() is GridContainer and c.get_parent().get_child_count() > 12:
			out.append(c)
		_cells(c, out)
	return out


func _test() -> void:
	root.size = Vector2i(1280, 720)
	game.hero_name = "Jewellery stack test"
	await _wait()
	var p: Player = game.player
	var menus: Menus = game.menus
	var ring := _of_slot("ring")
	var other_ring := _of_slot("ring", ring)
	var amulet := _of_slot("amulett")
	var bracelet := _of_slot("armreif")
	var food := _of_slot("futter")
	var filler := _filler()
	check(ring != "" and other_ring != "" and amulet != "" and bracelet != "" and food != "" and filler != "", "there are items to try")

	# Which things stack.
	for id in [ring, other_ring, amulet, bracelet, food, HandTorch.ITEM]:
		check(Items.stack_size(id) == 5, "%s stacks up to 5 (%d)" % [id, Items.stack_size(id)])
	for slot in ["waffe", "schild", "ruestung", "kopf", "rucksack", "buch"]:
		var id := _of_slot(slot)
		check(id == "" or Items.stack_size(id) == 1, "%s does not stack" % id)
	check("5" in Items.describe(ring), "a ring's details say it stacks: %s" % Items.describe(ring))

	# Only alike items share a slot.
	var mixed := [ring, other_ring, ring, ring, other_ring, amulet]
	check(Items.slots_used(mixed) == 3, "3 of one ring, 2 of another and an amulet take 3 slots (%d)" % Items.slots_used(mixed))
	var six := []
	for i in 6:
		six.append(ring)
	check(Items.slots_used(six) == 2, "6 alike rings take 2 slots")

	# A full bag still takes a ring while its bundle has room.
	p.equipped.clear()
	p.bag.clear()
	for i in Items.BAG_SIZE - 1:
		p.bag.append(filler)
	p.bag.append(ring)
	p.bag.append(ring)
	check(p.bag_used() == p.bag_size(), "the plain bag is full: %d / %d" % [p.bag_used(), p.bag_size()])
	check(p.bag_fits(ring), "a third alike ring fits on the bundle")
	check(not p.bag_fits(other_ring), "a different ring does not")

	# Equipping one off a bundle keeps the other in the bag; a worn ring that
	# needs a slot of its own is not swapped into a full bag.
	check(p.equip(ring) and p.bag.count(ring) == 1, "one ring of the bundle is put on, one stays")
	p.bag.append(ring)
	p.equipped["ring"] = other_ring
	check(not p.equip(ring), "a swap that needs one more slot in a full bag is refused")
	check(p.bag.count(ring) == 2 and p.equipped.ring == other_ring, "nothing moved")
	p.equipped["ring"] = ring
	check(p.equip(ring) and p.bag.count(ring) == 2, "swapping alike rings goes back onto the bundle")

	# The traveller's backpack: 20 slots, 20 cells, one cell per bundle.
	check(Items.ALL.has(BIG) and Items.bag_size(BIG) == 20, "the traveller's backpack holds 20")
	check(not Items.merchant_sells(BIG), "the merchant does not sell the biggest backpack")
	p.equipped["rucksack"] = BIG
	check(p.bag_size() == 20, "wearing it, the bag has 20 slots")
	p.bag.clear()
	for i in 3:
		p.bag.append(ring)
	for i in 4:
		p.bag.append(amulet)
	for i in 16:
		p.bag.append(filler)
	check(p.bag_used() == 18, "16 plain things and two bundles take 18 slots (%d)" % p.bag_used())
	menus.inventory_tab = "tasche"
	menus.open("inventar")
	await _wait()
	var cells := _cells(menus._box, [])
	check(cells.size() == 20, "the inventory shows 20 cells (%d)" % cells.size())
	var texts := cells.map(func(b): return b.tooltip_text)
	check(texts.filter(func(t): return t.begins_with(Items.item_name(ring).left(6)) and "× 3" in t).size() == 1, "one cell shows the 3 rings")
	check(texts.filter(func(t): return "× 4" in t).size() == 1, "one cell shows the 4 amulets")
	check(texts.any(func(t): return "(18 / 20)" in t) or menus._box.find_children("*", "Button", true, false).any(func(b): return "(18 / 20)" in b.text), "the bag tab counts 18 / 20")
	var rect: Rect2 = menus._panel.get_global_transform() * Rect2(Vector2.ZERO, menus._panel.size)
	var screen := root.get_visible_rect()
	check(screen.encloses(rect), "the inventory with 20 slots fits the screen: %s" % rect)
	var shots := OS.get_environment("SHOTS")
	if shots != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("backpack_20.png"))
	menus.close()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: jewellery stacks")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
