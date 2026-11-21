extends SceneTree
## Headless test of the whole way back into the self-built house: the hero sleeps in a bed of
## their built house (sleep and log out), the game is closed, started again and the saved game
## continued from the title. The hero must wake up in that bed and stand in the house once the
## welcome back is over, also when the house has an open doorway, and a camp
## still stands elsewhere in the open air.
## Run with: godot --headless --fixed-fps 60 -s tests/house_login_flow.gd

const HERO := "House login flow test"

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
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
		await physics_frame


func _cells(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			out.append(Vector2i(x, y))
	return out


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = HERO
	game.escaped = true
	game.home_claimed = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var level: Level = game.level
	var found := Rect2i()
	for y in range(level.height - 5):
		for x in range(level.grid[y].length() - 5):
			if Plots.problem(level, Rect2i(x, y, 4, 4)) == "":
				found = Rect2i(x, y, 4, 4)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, HERO, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var sk: HouseSketcher = game.house_sketcher
	var plan: HouseSketch = sk.plan
	plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(5, 1)) + plan.run_between(Vector2i(1, 1), Vector2i(1, 5))
			+ plan.run_between(Vector2i(5, 1), Vector2i(5, 5)) + plan.run_between(Vector2i(1, 5), Vector2i(5, 5)), HouseSketch.WALL)
	# An open gap where the door will go.
	plan.pieces.erase(HouseSketch.key_of(2, 5, "x", 0))
	plan.sketch_roof(_cells(Vector2i(1, 1), Vector2i(4, 4)), HouseSketch.SLAB, 0)
	plan.deposit(HouseSketch.STONE, 800)
	plan.deposit(HouseSketch.TIMBER, 800)
	plan.order()
	for i in 600:
		if not sk.work_once():
			break
	check(plan.open_pieces() == 0, "the house is built")
	plan.save(HERO)
	# A bed in the house.
	var furniture := HouseFurniture.of(HERO)
	furniture.owned["bett"] = 1
	var why := furniture.place(plan, "bett", 0, 2, 2, 0)
	check(why == "", "a bed is put in the house (%s)" % why)
	furniture.save(HERO)
	game.house_furnisher.refresh()
	await _wait(5)
	var bed := {}
	for s in game.level.stations:
		if s.kind == "bett" and s.has("furniture"):
			bed = s
	check(not bed.is_empty(), "the built bed is a station")
	if bed.is_empty():
		_end()
		return
	# Up to the bed's foot and to sleep: the game saves and logs out.
	game.player.global_position = bed.side
	game.player.reset_physics_interpolation()
	await _wait(5)
	check(sk.holds(game.player.global_position), "beside the bed the hero is in the house")
	# A camp left standing elsewhere in the open air does not take the wake-up away from home.
	var camp_spot: Vector3 = plan.node_world(0, 0) + Vector3(-24, 0, -24)
	game.camp = Camp.pitch(game.level, camp_spot, 0.0)
	check(game.has_camp(), "a camp stands elsewhere in the open air")
	var logged := [false]
	game.logged_out.connect(func(_saved): logged[0] = true)
	game.quit_on_log_out = false
	game.sleep()
	for i in 900:
		if logged[0]:
			break
		await physics_frame
	check(logged[0], "the hero slept and logged out")
	var path: String = game.save_path()
	var data: Dictionary = game._read_save(path)
	check(data.has("built_house"), "the save keeps the spot in the house")
	# The game is closed and started again.
	game.queue_free()
	await _wait(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _wait(30)
	game.continue_game(path)
	for i in 1500:
		if game.state == game.State.PLAYING and not game.player.frozen and not game.menus.is_open():
			break
		if game.menus.is_open():
			game.menus.close()
		await physics_frame
	await _wait(30)
	var hero: Vector3 = game.player.global_position
	check(game.level is Outdoor, "the game continues in the open air")
	check(game.house_sketcher != null and game.house_sketcher.holds(hero), "after the load the hero stands in the built house (at %s, bed side %s)" % [hero, bed.side])
	check(Vector2(hero.x - bed.side.x, hero.z - bed.side.z).length() < 2.0, "the hero got up beside the bed (%.2f m off)" % Vector2(hero.x - bed.side.x, hero.z - bed.side.z).length())
	_end()


func _end() -> void:
	Plots.release(HERO)
	game.delete_save(game.save_path())
	print("PASS: house login flow" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
