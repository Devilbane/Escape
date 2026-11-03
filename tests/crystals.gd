extends SceneTree
## Headless test for mining crystals (see Mines and Crafting): running into a
## crystal cluster in the Crystal Grotto knocks two grotto crystals into the
## pouch and teaches the recipes of the gem cutter's wheel; the cluster stays
## dull (also after leaving and coming back, and in the saved game) until the
## next morning, when it grows back. At the wheel the crystals and a fine bar
## from Gorm's forge become a crystal ring.
## Run with: godot --headless --fixed-fps 60 -s tests/crystals.gd
## With SHOTS=<folder> and a display it also saves screenshots there.

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
const HERO := "Crystal test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	game._title.visible = false
	game._fade.color.a = 0.0
	await _wait(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _clusters() -> Array:
	return game.level.stations.filter(func(s): return s.kind == Mines.CLUSTER)


## Keeps the grotto's monsters away while the test looks around.
func _calm() -> void:
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
			e.visible = false


## Puts the hero right beside a cluster, facing it.
func _stand_by(s: Dictionary) -> void:
	# Beside it to the east or west when there is room, so the camera (from
	# the south) sees both the hero and the crystals.
	var cell: Vector2i = game.level._open_side(s.cell)
	for d in [Vector2i(1, 0), Vector2i(-1, 0)]:
		if game.level.cell_char(s.cell + d) != "#":
			cell = s.cell + d
			break
	var side: Vector3 = game.level.cell_to_world(cell)
	game.player.global_position = side
	game.player.face(s.pos - side)
	game._message.text = ""
	game._zoom = 0.4
	game._zoom_target = 0.4
	game._snap_camera()


func _enter_grotto() -> void:
	game.state = game.State.PLAYING
	game.go_inside("mine2")
	for i in 600:
		await process_frame
		if game.level.theme == "kristall" and game.state == game.State.PLAYING and i > 10:
			break
	await _wait(10)
	_calm()


func _run() -> void:
	game.hero_name = HERO
	game.escaped = true
	game.crafting.clear()
	game.lore.clear()
	game.bars = {}
	game.day = 3
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	check(Lang.EN.has(Mines.CRYSTAL_LEARN), "the compendium text has its English")
	check(game.crafting.recipes_for("edelsteinschleifen").is_empty(), "the gem cutter's wheel has no recipes before the first crystals")

	await _enter_grotto()
	check(game.level.theme == "kristall", "the hero is in the Crystal Grotto")
	var clusters := _clusters()
	check(clusters.size() >= 6, "the grotto has crystal clusters to mine (%d)" % clusters.size())
	# One standing in the open, so the pictures show it well.
	var s: Dictionary = clusters[0]
	for c in clusters:
		var open := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			open += 0 if game.level.cell_char(c.cell + d) == "#" else 1
		if open == 8:
			s = c
			break
	check(not s.spent, "a cluster starts full grown")
	_stand_by(s)
	game.player.hp = game.player.max_hp
	if shots != "":
		# Let the floor's title fade first.
		await _wait(240)
		game._message.text = ""
	await _shot("crystals_1_before")
	game._message.text = ""

	# Running into it: two blows, then the crystals.
	game._on_player_bumped(s.pos)
	check(s.get("digging", false), "the hero starts knocking at the crystals")
	game._on_player_bumped(s.pos)
	await _wait(10)
	await _shot("crystals_2_digging")
	await create_timer(1.2).timeout
	check(game.crafting.have(Mines.CRYSTAL_ID) == Mines.CRYSTAL_YIELD, "a cluster gives %d crystals, bumping twice gives no more (%d)" % [Mines.CRYSTAL_YIELD, game.crafting.have(Mines.CRYSTAL_ID)])
	check(s.spent, "the mined cluster is dull")
	check(game.lore.has(Mines.CRYSTAL_LEARN), "the compendium explains mining")
	check(game.crafting.knows("kristallring") and game.crafting.knows("kristallamulett"), "the first crystals teach the gem cutter's recipes")
	check(game.crafting.found.has(Mines.CRYSTAL_ID), "the place is marked as found in the ingredient book")
	await _wait(60)
	await _shot("crystals_3_mined")

	# Mined is mined: no more until the morning.
	game._use_station(s)
	await create_timer(1.2).timeout
	check(game.crafting.have(Mines.CRYSTAL_ID) == Mines.CRYSTAL_YIELD, "a dull cluster gives nothing")

	print("mining all")
	# Mine every cluster of the grotto.
	for other in clusters:
		if not other.spent:
			_stand_by(other)
			game._use_station(other)
			await create_timer(1.1).timeout
	check(clusters.all(func(c): return c.spent), "every cluster can be mined")
	var total: int = clusters.size() * Mines.CRYSTAL_YIELD
	check(game.crafting.have(Mines.CRYSTAL_ID) == total, "the whole grotto gives %d crystals a day (%d)" % [total, game.crafting.have(Mines.CRYSTAL_ID)])

	# Out and back in on the same day: still dull, also from the saved game.
	var cell: Vector2i = s.cell
	await _enter_grotto()
	check(_clusters().all(func(c): return c.spent), "mined clusters stay dull the same day")
	check(game.save_game(), "the game saves")
	var saved: Dictionary = game._read_save()
	var keys: Array = saved.get("looted", {}).get("20_die_kristallgrotte.txt", [])
	check(keys.has(Mines.crystal_key(cell, 3)), "the saved game knows the cluster was mined on day 3")

	print("morning")
	# A new morning: the clusters grow back before the hero's eyes.
	game._new_day(true)
	await create_timer(2.0).timeout
	check(_clusters().all(func(c): return not c.spent), "the clusters grow back with the morning")
	check(not game.level.taken.keys().any(func(k): return str(k).begins_with("crystal:")), "their marks are gone")
	_stand_by(_clusters()[0])
	game._use_station(_clusters()[0])
	await create_timer(1.2).timeout
	check(game.crafting.have(Mines.CRYSTAL_ID) == total + Mines.CRYSTAL_YIELD, "a grown-back cluster can be mined again")
	# Coming back on a later day, the clusters have grown back too.
	game.day += 1
	await _enter_grotto()
	check(_clusters().all(func(c): return not c.spent), "a cluster mined on an earlier day has grown back")

	# The gem cutter's wheel: crystals and a silver bar make a ring.
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	game.menus.bench = "edelsteinschleifen"
	game.menus.open("werkbank")
	check(game.crafting.recipes_for("edelsteinschleifen") == ["kristallring", "kristallamulett"], "the wheel lists the crystal recipes")
	check(not game.crafting.recipes_for("feinschmieden").has("kristallring"), "the fine metalwork bench does not")
	check(game.crafting.why_not("kristallring").contains(Lang.t("Silberbarren")), "without a silver bar the ring cannot be made yet")
	await _shot("crystals_4_wheel_missing")
	game.menus.close()
	game.bars["silber"] = 1
	game.bars["gold"] = 1
	game.menus.open("werkbank")
	check(game.crafting.why_not("kristallring") == "", "with crystals and a silver bar the ring can be made")
	await _shot("crystals_5_wheel_ready")
	var crystals: int = game.crafting.have(Mines.CRYSTAL_ID)
	var bag_before: int = game.player.bag.count("kristallring") + game.storage.count("kristallring")
	game.menus._make_recipe("kristallring")
	check(game.player.bag.count("kristallring") + game.storage.count("kristallring") == bag_before + 1, "the crystal ring is made")
	check(game.crafting.have(Mines.CRYSTAL_ID) == crystals - 3, "it takes three crystals")
	check(not game.bars.has("silber"), "and the silver bar")
	check(game.crafting.why_not("kristallamulett") == "", "the amulet can be made from crystals and a gold bar")
	game.menus._make_recipe("kristallamulett")
	check(not game.bars.has("gold") and game.crafting.have(Mines.CRYSTAL_ID) == crystals - 8, "the amulet takes five crystals and the gold bar")
	await _shot("crystals_6_wheel_made")
	game.menus.close()
	check(Items.ALL.kristallring.get("hp", 0) > 0 and Items.ALL.kristallamulett.get("power", 0) > 0, "the crystal jewellery helps in a fight")

	game.delete_save(game.save_path())
	print("PASS: crystals" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
