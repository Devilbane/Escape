extends SceneTree
## Headless test for the weapon rack of the self-built house (see WeaponRack, HomeStores.WEAPONS and
## HouseFurniture): the furnisher sells it, it stands in a built house and is a station, its window
## keeps every weapon the hero puts in it (and nothing else), and it shows the finest weapons kept
## with their own models, the rarest first and every kind once before a second, with the count on
## its plaque. What it keeps is in the saved game.
## Run with: godot --headless --fixed-fps 60 -s tests/weapon_rack.gd
## With a display, SHOTS=<folder> also takes pictures of it: from the game's own camera and close up.

const HERO := "Weapon rack test"

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	HouseFurniture.reload()
	Lang.language = OS.get_environment("SHOT_LANG") if OS.get_environment("SHOT_LANG") != "" else "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## The weapons standing in a rack, by item id, slot by slot.
func _standing(rack: Node) -> Array:
	var out := []
	for slot in rack.get_node(WeaponRack.WEAPONS_NODE).get_children():
		if not slot.is_queued_for_deletion():
			out.append(slot.get_meta("item", ""))
	return out


func _plaque(rack: Node) -> String:
	return (rack.get_node(WeaponRack.PLAQUE_NODE) as Label3D).text


func _run() -> void:
	# What goes in it: every weapon, nothing else (no shield, no throwing knife, no book).
	var weapons := []
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("slot", "") == "waffe":
			weapons.append(id)
			check(HomeStores.store_of(id) == HomeStores.WEAPONS, "the weapon %s goes in the rack" % id)
			check(WeaponRack.weapon_model(id) != null, "the weapon %s has a model for the rack" % id)
		elif HomeStores.store_of(id) == HomeStores.WEAPONS:
			check(false, "%s is no weapon and must not go in the rack" % id)
	check(weapons.size() >= 8, "there are weapons to keep (%d)" % weapons.size())
	for id in ["rundschild", "wurfmesser", "fechtbuch", "fackel"]:
		check(HomeStores.store_of(id) != HomeStores.WEAPONS, "%s does not go in the rack" % id)
	check(HomeStores.STATIONS[HomeStores.WEAPONS] == WeaponRack.KIND, "the store has the rack's station kind")
	check(HomeStores.empty().has(HomeStores.WEAPONS), "a new game has an empty rack")

	# Which weapons stand in view: the rarest first, every kind once, at most SLOTS.
	var few := WeaponRack.shown({"schwert": 3, "runenhammer": 1, "langschwert": 1})
	check(few[0] == "runenhammer", "the rarest stands first (%s)" % [few])
	check(few.slice(0, 3).has("schwert") and few.slice(0, 3).has("langschwert"), "every kind stands once before a second (%s)" % [few])
	check(few.size() == 5 and few.count("schwert") == 3, "spare slots take the copies (%s)" % [few])
	var many := {}
	for id in weapons:
		many[id] = 4
	check(WeaponRack.shown(many).size() == WeaponRack.SLOTS, "no more than the slots stand in view")
	check(WeaponRack.shown({}).is_empty(), "an empty rack shows nothing")
	for i in range(1, WeaponRack.SLOTS):
		var a: String = WeaponRack.shown(many)[i - 1]
		var b: String = WeaponRack.shown(many)[i]
		check(Level.rank_of(a) >= Level.rank_of(b), "rarer before plainer: %s before %s" % [a, b])

	# A built house on a plot, and the rack bought from the furnisher.
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = HERO
	game.escaped = true
	game.home_stores = HomeStores.empty()
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	await _wait(10)
	var found := Rect2i()
	for y in range(game.level.height - 5):
		for x in range(game.level.grid[y].length() - 5):
			if Plots.problem(game.level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(game.level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sketcher: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sketcher.plan
	# A room of 3 x 2 cells at (1, 1), walls round it, a door in the south wall, a flat roof.
	for x in range(1, 4):
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 3, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.DOOR if x == 3 else HouseSketch.WALL, "state": HouseSketch.BUILT}
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		plan.pieces[HouseSketch.key_of(1, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(4, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	plan.save(game.hero_name)
	sketcher.refresh()
	check(HouseFurniture.KINDS.has(WeaponRack.KIND), "the rack is a piece of furniture")
	check(HouseFurniture.SECTIONS.any(func(s): return WeaponRack.KIND in s[3]), "the furnisher sells it")
	game.coins = 1000
	game.trader_role = "µ"
	game.menus.open("raumausstatter")
	game.menus._buy_furniture(WeaponRack.KIND)
	game.menus.close()
	check(game.coins == 1000 - int(HouseFurniture.KINDS[WeaponRack.KIND].price), "buying it costs its price")
	var store := HouseFurniture.of(game.hero_name)
	check(store.count(WeaponRack.KIND) == 1, "it waits to be put down")
	var why := store.place(plan, WeaponRack.KIND, 0, 1, 1, 0)
	check(why == "", "it stands against the north wall (%s)" % why)
	store.add("leuchter")
	store.place(plan, "leuchter", 0, 3, 1, 0)
	store.save(game.hero_name)
	game.house_furnisher.refresh()
	var furnisher: HouseFurnisher = game.house_furnisher
	check(furnisher._racks.size() == 1, "the rack is drawn")
	var stations: Array = game.level.stations.filter(func(s): return s.kind == WeaponRack.KIND)
	check(stations.size() == 1, "the rack is a station")
	if furnisher._racks.is_empty() or stations.is_empty():
		_finish()
		return
	var rack: Node3D = furnisher._racks[0]
	check(game.level.station_at(stations[0].pos) == stations[0], "running into it finds it")
	check(_standing(rack).is_empty() and _plaque(rack) == WeaponRack.plaque_text(0), "an empty rack shows no weapons and reads 0")

	# Storing and taking through the window moves weapons and changes the rack.
	var p: Player = game.player
	p.bag.clear()
	for id in ["schwert", "schwert", "langschwert", "kriegshammer", "runenhammer", "rabenklinge", "streitaxt", "donnerklinge", "rundschild", "fechtbuch"]:
		p.bag.append(id)
	var menus: Menus = game.menus
	menus.open(WeaponRack.KIND)
	check(menus.current == WeaponRack.KIND and Menus.fixed_size(WeaponRack.KIND) != Vector2.ZERO, "the window opens with a fixed size")
	var listed := HomeStores.shown(game, HomeStores.WEAPONS)
	check(not listed.has("rundschild") and not listed.has("fechtbuch") and listed.has("schwert") and listed.has("runenhammer"),
			"the window lists only the weapons the hero carries: %s" % [listed])
	menus._store_move("schwert", 1, true)
	check(p.bag.count("schwert") == 1 and HomeStores.stored(game, "schwert") == 1, "one sword goes in")
	check(_standing(rack) == ["schwert"] and _plaque(rack) == WeaponRack.plaque_text(1), "it stands in the rack at once")
	menus._store_all(HomeStores.WEAPONS, true)
	check(p.bag == ["rundschild", "fechtbuch"], "all weapons go in, the shield and the book stay (%s)" % [p.bag])
	check(HomeStores.total(game.home_stores, HomeStores.WEAPONS) == 8 and _plaque(rack) == WeaponRack.plaque_text(8), "the plaque counts all eight")
	var standing := _standing(rack)
	check(standing.size() == WeaponRack.SLOTS, "the slots are full (%s)" % [standing])
	check(standing == WeaponRack.shown(game.home_stores[HomeStores.WEAPONS]), "the finest stand in view (%s)" % [standing])
	check(standing.count("schwert") == 1, "a second sword waits for a free slot (%s)" % [standing])
	for slot: Node3D in rack.get_node(WeaponRack.WEAPONS_NODE).get_children():
		var box := _bounds(slot)
		check(box.size.y <= WeaponRack.WEAPON_HEIGHT + 0.01 and box.size.x <= WeaponRack.WEAPON_WIDTH + 0.01,
				"%s fits its slot (%s)" % [slot.get_meta("item"), box.size])
		check(box.position.y >= WeaponRack.BLOCK_TOP - WeaponRack.SINK - 0.01 and box.end.y <= WeaponRack.HEIGHT - 0.3,
				"%s stands in its slot under the plaque (%.2f to %.2f)" % [slot.get_meta("item"), box.position.y, box.end.y])
	if shots != "":
		await _pictures(plan, rack)
	menus._store_move("runenhammer", 1, false)
	check(p.bag.has("runenhammer") and not _standing(rack).has("runenhammer"), "taken out, it leaves the rack")
	check(_standing(rack).size() == WeaponRack.SLOTS and _standing(rack).count("schwert") == 2, "the second sword takes the free slot")
	menus.close()

	# Kept in the saved game.
	var saved := HomeStores.for_save(game.home_stores)
	var back := HomeStores.load_from(saved)
	check(back[HomeStores.WEAPONS] == game.home_stores[HomeStores.WEAPONS], "the rack's weapons come back from the saved game")
	check(HomeStores.load_from({"waffen": {"rundschild": 2}})[HomeStores.WEAPONS].is_empty(), "a shield in the rack is left out on loading")

	# Every text has its English.
	for text in [HomeStores.WEAPONS_LEARN, "Waffenständer", "Waffen: %d", "Dagegenlaufen, um Waffen in den Ständer zu stellen oder zu nehmen",
			HouseFurniture.KINDS[WeaponRack.KIND].text, HouseFurniture.LEARN,
			"Alle Waffen, die du nicht bei dir trägst. Im Ständer: %d, die schönsten zur Schau. Er fasst beliebig viel.",
			"Noch keine Waffe bei dir oder hier. Waffen aus deiner Tasche kommen hier hinein, sobald du welche hast."]:
		check(Lang.EN.has(text), "English for: " + text)
	_finish()


func _finish() -> void:
	print("PASS: weapon rack" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


## The box round every mesh under a slot, in the rack's space.
func _bounds(slot: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in slot.find_children("*", "MeshInstance3D", true, false):
		var to_rack := Transform3D.IDENTITY
		var n: Node = mesh
		while n != slot.get_parent() and n is Node3D:
			to_rack = (n as Node3D).transform * to_rack
			n = n.get_parent()
		var b := to_rack * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _pictures(plan: HouseSketch, rack: Node3D) -> void:
	var front := rack.global_transform.basis * Vector3(0, 0, 1)
	var at := rack.global_position + Vector3(0, 1.1, 0)
	# The furnishing tool, as the player sees the room with the rack from above.
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	game.menus.close()
	game.house_furnisher.enter()
	game.house_furnisher.select(WeaponRack.KIND)
	await _wait(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join("rack_tool.png"))
	game.house_furnisher.leave()
	await _shot("rack_front", at + front * 3.4 + Vector3(0, 0.5, 0), at, 62.0)
	await _shot("rack_close", at + front * 1.5 + rack.global_transform.basis * Vector3(-0.9, 0.4, 0),
			at + rack.global_transform.basis * Vector3(-0.6, 0.3, 0), 50.0)
	# The window, with the HUD.
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = true
	game.player.bag.append_array(["axt", "krummsaebel"])
	game.menus.open(WeaponRack.KIND)
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join("rack_window.png"))
	for i in 2:
		game.player.bag.pop_back()
	game.menus._rebuild()


func _hide_hud() -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false


func _shot(name: String, from: Vector3, to: Vector3, fov: float) -> void:
	_hide_hud()
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
