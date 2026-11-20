extends SceneTree
## The whole house-building flow, played the way a player does it: with real mouse and keyboard
## events (Input.parse_input_event), through the real window, so what the player would see and
## click is what is checked. It marks a plot with the Land button, registers it at the Crown Office,
## runs into the blueprint sign, draws walls, a door and a window, plans a cellar by dragging,
## adds stairs, hands in material, orders the build and lets the hero build, takes a fox down
## the cellar stairs (and sees it wait at the rim of a pit without them), closes the cellar
## with a ceiling that leaves the stairs open, then goes up:
## a floor slab, stairs up, an upper wall, a saddle roof and a flat roof with things set on it.
##
## Run with a display (the checks about what is on screen need one):
##   SHOTS=/tmp/house xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##       --fixed-fps 60 -s tests/house_playtest.gd
## Without a display it still runs (--headless) but skips the screenshots and the pixel checks.
## Every step prints "ok" or "FAIL: ..."; the run ends with a summary of the failed steps.

var failures: Array[String] = []
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")
var shot_no := 0
var plan: HouseSketch
var sk: HouseSketcher
var plot := Rect2i()
const FRAME_SLACK := 2.0
var snow := OS.get_environment("NO_SNOW") == ""


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: ", what)
	else:
		failures.append(what)
		print("FAIL: ", what)


func _initialize() -> void:
	seed(9)
	Storage.use(Storage.Memory.new())
	Plots.reload()
	HouseSketch.reload()
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


# --- Input as a player gives it ------------------------------------------------

func _wait(n := 3) -> void:
	for i in n:
		await process_frame


## The screen point of a point in the world.
func _scr(world: Vector3) -> Vector2:
	return game.camera.unproject_position(world)


func _move(pos: Vector2) -> void:
	root.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(e)
	await _wait(2)


func _button(pos: Vector2, index: int, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = index
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down and index == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(e)
	await _wait(2)


func _click(pos: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	await _button(pos, index, true)
	await _button(pos, index, false)


## A drag with the left button: down at `a`, a few moves on the way, up at `b`.
func _drag(a: Vector2, b: Vector2) -> void:
	await _move(a)
	await _button(a, MOUSE_BUTTON_LEFT, true)
	for i in range(1, 5):
		await _move(a.lerp(b, i / 4.0))
	await _button(b, MOUSE_BUTTON_LEFT, false)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(2)
	e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	await _wait(2)


## A visible button with this text, anywhere under `from`.
func _find_button(from: Node, text: String) -> Button:
	for b: Button in from.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.begins_with(text):
			return b
	return null


func _press(text: String, from: Node = null) -> bool:
	var b := _find_button(from if from != null else game, text)
	if b == null:
		return false
	await _click(b.get_global_rect().get_center())
	return true


func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.render_loop_enabled = true
	await _wait(4)
	shot_no += 1
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join("%02d_%s.png" % [shot_no, name]))
	RenderingServer.render_loop_enabled = false


## Waits until the camera stands still (it glides after the hero is moved).
func _settle() -> void:
	var probe := Vector3.ZERO
	var last := _scr(probe)
	var calm := 0
	for i in 600:
		await _wait(1)
		var now := _scr(probe)
		calm = calm + 1 if now.distance_to(last) < 0.3 else 0
		last = now
		if calm >= 10:
			return


## Lets the hero build until the plan is finished. The screen is not drawn meanwhile (a
## software renderer would take minutes over the same game time).
func _wait_built(seconds: int) -> void:
	RenderingServer.render_loop_enabled = false
	var left := seconds * 60
	while plan.open_pieces() > 0 and left > 0:
		await _wait(60)
		left -= 60
		game.day_hour = 12.0 # no night, and nobody comes to rob the hero meanwhile
		for e in game.level.enemies:
			if is_instance_valid(e):
				e.queue_free()
		game.level.enemies.clear()
	await _wait(3)
	for key in plan.pieces:
		if plan.pieces[key].state != HouseSketch.BUILT:
			print("  (open: ", key, " ", plan.pieces[key], " stock ", plan.stock, ")")
	print("  (built after ", seconds - left / 60, " s of game time, ", plan.open_pieces(), " pieces left)")


func _step(title: String) -> void:
	print("== ", title)
	if title == OS.get_environment("STOP_AT"): # for working on one step: STOP_AT="hand in material and order the build"
		_end()


# --- Helpers about the plan --------------------------------------------------------

func _cell_scr(x: int, y: int) -> Vector2:
	return _scr(plan.cell_world(x, y) + Vector3(HouseSketch.CELL * 0.5, 0, HouseSketch.CELL * 0.5)) if false else _scr(plan.cell_world(x, y))


func _node_scr(x: int, y: int) -> Vector2:
	return _scr(plan.node_world(x, y))


func _bar_ok(what: String) -> void:
	var bar: Control = sk._bar
	var share := bar.get_global_rect().size.y / game.get_viewport().get_visible_rect().size.y
	check(share < 0.4, "%s: the tool bar takes %d%% of the screen height (limit 40%%)" % [what, int(share * 100)])
	var rect := bar.get_global_rect()
	check(game.get_viewport().get_visible_rect().encloses(rect.grow(-1)), "%s: the tool bar fits on the screen" % what)


func _select(text: String) -> void:
	var ok: bool = await _press(text, sk._bar)
	check(ok, "the bar has a \"%s\" button the player can click" % text)


func _stage(want: String) -> void:
	check(plan.stage() == want, "the bar's stage is \"%s\" (is \"%s\")" % [want, plan.stage()])


func _work(max_pieces: int) -> void:
	# The hero builds by himself while he stands near the plan (see HouseSketcher._process).
	var left := 60 * 60
	while plan.open_pieces() > 0 and left > 0 and max_pieces > 0:
		await _wait(30)
		left -= 30
		if plan.stage() != "build":
			break
	await _wait(10)


## Pushes the hero in the pit against its walls, one direction after another, until a
## climb starts from the pit floor. A push that walks up the stairs ramp and starts
## a climb from there is let through (with a fine roll) and tried again.
func _push_into_pit_wall(hero, pit_spot: Vector3, roll: float) -> void:
	for round in 3:
		for action in ["ui_left", "ui_up", "ui_right", "ui_down"]:
			hero.global_position = pit_spot
			hero.reset_physics_interpolation()
			await _wait(20)
			hero.pit_roll_forced = roll
			Input.action_press(action)
			for i in 90:
				await _wait(1)
				if hero.is_climbing():
					break
			Input.action_release(action)
			if hero.is_climbing() and hero._pit_floor < -2.4:
				return
			if hero.is_climbing():
				hero.pit_roll_forced = 0.0
				for i in 900:
					await _wait(1)
					if not hero.is_climbing():
						break
				await _wait(20)


func _run() -> void:
	# Drawing the frames is what makes a software renderer slow, so the game runs without it
	# and draws only when a screenshot is taken (see _shot). What is checked does not need it.
	RenderingServer.render_loop_enabled = false
	if DisplayServer.get_name() == "headless":
		# Real mouse input needs a window. The "House playtest" workflow runs this under Xvfb.
		print("SKIPPED: the house playtest needs a display (see the header)")
		print("PASS: house playtest (skipped without a display)")
		quit(0)
		return
	game.hero_name = "Playtest hero"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	game.set_weather(Weather.SNOW if snow else Weather.CLEAR, 8.0)
	if snow:
		game.snow_cover = 1.0
	game.coins = 5000
	game._title.visible = false # no title screen over the game, as after a start
	game._fade.color = Color(0.03, 0.015, 0.04, 0.0)
	for e in game.level.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.level.enemies.clear()
	game.player.godmode = true # a wolf or a bat must not interrupt the playtest
	await _wait(10)
	var lvl: Outdoor = game.level
	check(game.plot_marker != null and game.house_sketcher != null, "the open map has the land tool and the blueprint tool")
	sk = game.house_sketcher

	# --- 1. Where to build: a free spot of grass, with the hero beside it
	_step("find a spot")
	var size := 4
	for y in range(lvl.height - size - 1):
		for x in range(lvl.grid[y].length() - size - 1):
			var r := Rect2i(x, y, size, size)
			if Plots.problem(lvl, r) == "":
				plot = r
				break
		if plot.size != Vector2i.ZERO:
			break
	check(plot.size != Vector2i.ZERO, "there is a free %dx%d spot of grass on the map" % [size, size])
	if plot.size == Vector2i.ZERO:
		return _end()
	game.player.global_position = lvl.cell_to_world(plot.position + Vector2i(size / 2, size / 2))
	game.player.reset_physics_interpolation()
	await _settle()
	await _shot("start")
	if OS.get_environment("BIG_ONLY") != "": # quick run of the last step only
		Plots.register(lvl, game.hero_name, plot)
		game.plot_marker.refresh()
		plan = sk.plan
		await _big_plot()
		return _end()

	# --- 2. The Land button: marks a plot with two clicks
	_step("mark a plot")
	game.set_drawer_open(true)
	await _wait(30)
	var land: Button = _find_button(game, "Land")
	check(land != null, "the pull-out menu has a Land button")
	if land == null:
		return _end()
	await _click(land.get_global_rect().get_center())
	check(game.plot_marker.marking(), "the Land button starts marking")
	game.set_drawer_open(false)
	await _settle()
	var a := lvl.cell_to_world(plot.position)
	var b := lvl.cell_to_world(plot.end - Vector2i.ONE)
	var sa := _scr(a)
	var sb := _scr(b)
	var view := game.get_viewport().get_visible_rect()
	check(view.grow(-20).has_point(sa) and view.grow(-20).has_point(sb), "the plot's corners are on screen (%s, %s)" % [sa, sb])
	await _click(_scr(a))
	print("  (first corner ", game.plot_marker.corner, ")")
	check(game.plot_marker.stage == PlotMarker.Stage.SECOND, "the first click sets a corner")
	await _move(_scr(b))
	await _shot("plot_second_corner")
	var why_not := Plots.problem(lvl, Plots.rect_between(plot.position, game.plot_marker.tile_at(game.level.cell_to_world(plot.end - Vector2i.ONE))))
	await _click(_scr(b))
	var hc: Control = game.get_viewport().gui_get_hovered_control()
	print("  (hovered control: ", hc, " text=", hc.text if hc is Button else "", " rect=", hc.get_global_rect() if hc else null, " parent=", hc.get_parent().name if hc else "", " at ", _scr(b), ")")
	print("  (second click on tile ", game.plot_marker.tile_at(game._mouse_to_floor(sb)), ", problem: ", why_not, ", state ", game.state, ", marking ", game.plot_marker.stage, ")")
	check(game.plot_marker.pending == plot, "the second click marks the plot (%s, wanted %s)" % [game.plot_marker.pending, plot])
	check(not game.plot_marker.marking(), "marking is over after the second corner")

	# --- 3. The Crown Office registers the plot
	_step("register the plot")
	game.menus.open(PlotOffice.KIND)
	await _wait(10)
	var coins_before: int = game.coins
	var reg := await _press("Register")
	check(reg, "the Crown Office window has a register button")
	await _wait(10)
	check(Plots.plot_of(game.hero_name) == plot, "the plot is in the land registry")
	check(game.coins < coins_before, "the fee was paid")
	game.menus.close()
	await _wait(10)
	plan = sk.plan
	check(plan != null, "a registered plot brings a building plan")
	if plan == null:
		return _end()
	await _shot("plot_registered")

	# --- 4. Into the blueprint sign
	_step("open the blueprint sign")
	var sign_station: Dictionary = {}
	for s in lvl.stations:
		if s.kind == HouseSketcher.KIND and s.get("owner", "") == game.hero_name:
			sign_station = s
	check(not sign_station.is_empty(), "the plot has a blueprint sign")
	if sign_station.is_empty():
		return _end()
	game.player.global_position = sign_station.pos + Vector3(-0.5, 0, -0.5)
	game.player.reset_physics_interpolation()
	game._use_station(sign_station)
	await _settle()
	check(sk.active, "running into the sign opens the blueprint tool")
	_bar_ok("wall tool")
	var bar_top: float = sk._bar.get_global_rect().position.y
	var hidden := 0
	var nn := plan.nodes()
	for corner in [Vector2i(0, 0), Vector2i(nn.x, 0), Vector2i(0, nn.y), nn]:
		var sp := _node_scr(corner.x, corner.y)
		if sp.y > bar_top or not game.get_viewport().get_visible_rect().has_point(sp):
			hidden += 1
	check(hidden == 0, "the whole plot is on screen above the tool bar, so every square can be clicked (%d corners hidden)" % hidden)
	await _shot("blueprint_open")
	game.camera.global_position = game.camera.global_position # keep the camera; it follows the hero

	# --- 5. Walls: dragging on the grid
	_step("draw walls")
	# A square house of 4 x 4 cells in the middle of the plot (cells 1..4).
	await _select("Wall")
	var ok_all := true
	var square := [[Vector2i(1, 1), Vector2i(5, 1)], [Vector2i(5, 1), Vector2i(5, 5)], [Vector2i(5, 5), Vector2i(1, 5)], [Vector2i(1, 5), Vector2i(1, 1)]]
	for seg in square:
		await _drag(_node_scr(seg[0].x, seg[0].y), _node_scr(seg[1].x, seg[1].y))
		if sk.drag_from.x >= 0:
			ok_all = false
	check(ok_all, "every wall drag ends (the pen is up)")
	check(plan.count("wall") == 16, "four walls of four pieces are planned (%d)" % plan.count("wall"))
	await _shot("walls_sketched")
	# A door and a window by clicking a wall.
	await _select("Door")
	await _click(_scr(plan.node_world(2, 1) + Vector3(HouseSketch.CELL * 0.5, 0, 0)))
	check(plan.count("door") == 1, "a click on a wall makes a door (%d)" % plan.count("door"))
	await _select("Window")
	await _click(_scr(plan.node_world(5, 2) + Vector3(0, 0, HouseSketch.CELL * 0.5)))
	check(plan.count("window") == 1, "a click on a wall makes a window (%d)" % plan.count("window"))
	await _shot("door_window")

	# --- 6. Undo and the eraser
	_step("undo and eraser")
	var walls := plan.count("wall")
	await _press("Undo", sk._bar)
	check(plan.count("window") == 0 and plan.count("wall") == walls + 1, "Undo takes the window back")
	await _press("Redo", sk._bar)
	check(plan.count("window") == 1, "Redo brings it back")

	# --- 7. The cellar: drag a rectangle; the planned squares must stay
	_step("dig a cellar")
	await _select("Dig cellar")
	check(sk.tool == HouseSketcher.TOOL_DIG, "the dig tool is selected")
	await _drag(_cell_scr(2, 2), _cell_scr(3, 3))
	check(plan.count("dig") == 4, "dragging with the dig tool plans a 2x2 cellar (%d dig squares; status: %s; from %s to %s; cells %s %s)" % [plan.count("dig"), sk._status.text, _cell_scr(2, 2), _cell_scr(3, 3), plan.cell_at(game._mouse_to_floor(_cell_scr(2, 2))), plan.cell_at(game._mouse_to_floor(_cell_scr(3, 3)))])
	await _move(_cell_scr(0, 0))
	await _wait(5)
	await _shot("cellar_planned")
	check(plan.count("dig") == 4, "the planned squares stay when the mouse moves on")
	check(sk.drag_from.x < 0, "the pen is up after the drag")
	var planned_marks := sk._built.get_child_count()
	check(planned_marks > 0, "the planned squares are drawn on the ground")

	# --- 8. Stairs down
	_step("cellar stairs")
	# One stairs tool: it says "up" or "down" by the level, and a click in front
	# of the cellar puts stairs down whatever the level.
	await _select("Stairs")
	check(sk.tool == HouseSketcher.TOOL_STAIRS, "the stairs tool is selected")
	check(sk._tool_buttons[HouseSketcher.TOOL_STAIRS].text == ("Stairs down" if sk.storey < 0 else "Stairs up"), "the stairs tool names its way by the level (%s)" % sk._tool_buttons[HouseSketcher.TOOL_STAIRS].text)
	var before := plan.count("stairs")
	var hc2: Control = game.get_viewport().gui_get_hovered_control()
	print("  (stairs click at ", _cell_scr(0, 2), " cell ", plan.cell_at(game._mouse_to_floor(_cell_scr(0, 2))), " dir ", plan.stairs_dir(0, 2), " hovered ", hc2, " tool ", sk.tool, ")")
	await _click(_cell_scr(0, 2))
	check(plan.count("stairs") == before + 1, "a click beside the cellar plans stairs down (%d; status: %s)" % [plan.count("stairs"), sk._status.text])
	await _shot("stairs_planned")
	_bar_ok("cellar tools")

	# --- 9. Material and the order
	_step("hand in material and order the build")
	check(not plan.missing().is_empty(), "material is missing before it is handed in")
	for i in 80:
		game.player.bag.append(HouseSketch.STONE)
	for i in 60:
		game.player.bag.append(HouseSketch.TIMBER)
	game._update_hud()
	await _wait(30)
	await _press("Hand in material", sk._bar) # the bag changed behind the open bar
	var pressed_unrefreshed: bool = int(plan.stock.get(HouseSketch.STONE, 0)) > 0
	check(pressed_unrefreshed, "material picked up while the tool is open can be handed in at once")
	sk.leave()
	await _wait(5)
	sk.enter()
	await _wait(5)
	await _press("Hand in material", sk._bar)
	check(plan.stock.get(HouseSketch.STONE, 0) >= 80 and plan.stock.get(HouseSketch.TIMBER, 0) >= 60, "handing in moves the bag into the stock (%s)" % [plan.stock])
	check(plan.missing().is_empty(), "nothing is missing any more (%s)" % [plan.missing()])
	await _press("Order the build", sk._bar)
	check(plan.ordered and plan.stage() == "build", "the order starts the build")
	await _shot("build_ordered")
	sk.leave()
	await _wait(5)
	game.player.global_position = plan.cell_world(plan.nodes().x / 2, plan.nodes().y / 2) + Vector3(HouseSketch.CELL * 3.5, 0, 0)
	game.player.reset_physics_interpolation()
	await _wait_built(400)
	check(plan.open_pieces() == 0, "the hero builds everything while standing near (%d pieces left)" % plan.open_pieces())
	await _shot("ground_floor_built")
	check(plan.count("dig", "built") == 4 and plan.count("stairs", "built") == 1, "the cellar and its stairs are built")
	check(game.level._floor_slabs.get_child_count() > 0, "the ground is cut open over the cellar")

	# --- 9a. The companion follows down and up the stairs
	_step("companion on the cellar stairs")
	var top: Vector3 = plan.cell_world(0, 2)
	game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
	game.player.reset_physics_interpolation()
	game.companions.append(Companions.make("fuchs", "Fuchs"))
	game.following = game.companions.size() - 1
	game._spawn_pet()
	await _wait(30)
	var pet: Pet = game.pet
	check(is_instance_valid(pet) and pet.global_position.y > -0.3, "the fox stands beside the hero on the ground")
	game.player.global_position = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	game.player.reset_physics_interpolation()
	var stairs_cells := [HouseFloors.cell_of(top), HouseFloors.cell_of(plan.cell_world(1, 2))]
	var off_stairs := 0
	for i in 300:
		await process_frame
		var y := pet.global_position.y
		if y < -0.3 and y > -HouseSketch.DEPTH + 0.3 and not stairs_cells.has(HouseFloors.cell_of(pet.global_position)):
			off_stairs += 1
	check(pet.global_position.y < -HouseSketch.DEPTH + 0.2, "the fox follows the hero down into the cellar (y %.2f)" % pet.global_position.y)
	check(off_stairs == 0, "it goes down over the stairs, not down a pit wall (%d frames between the floors elsewhere)" % off_stairs)
	game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
	game.player.reset_physics_interpolation()
	await _wait(300)
	check(pet.global_position.y > -0.1 and not pet.is_cut_off(), "and back up the stairs after the hero (y %.2f)" % pet.global_position.y)

	# --- 9b. Climbing out of the pit without the stairs
	_step("climb out of the cellar")
	var hero = game.player
	var pit_spot := plan.cell_world(2, 2) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	hero.global_position = pit_spot
	hero.reset_physics_interpolation()
	await _wait(30)
	check(hero.in_pit(), "the hero stands in the pit (y %.2f)" % hero.global_position.y)
	check(hero.climbing_level() == 1, "every hero climbs at level 1")
	# Two slips in a row at the hang: the first is caught, the second drops the hero back.
	hero.pit_roll_forced = 0.99
	await _push_into_pit_wall(hero, pit_spot, 0.99)
	check(hero.is_climbing(), "pushing against the pit wall starts the climb")
	await _shot("climb_start")
	var floor_y: float = hero._pit_floor
	var hung := false
	for i in 400:
		await _wait(1)
		if hero.global_position.y > floor_y + 1.0 and not hung:
			hung = true
			var arm: Skeleton3D = hero._skeleton
			var raised: Quaternion = arm.get_bone_pose_rotation(arm.find_bone("upperarm.l"))
			check(not raised.is_equal_approx(hero._pit_base.ua_l.q), "the arms are posed for the hang (the rig follows the climb)")
			await _shot("climb_hang")
		if not hero.is_climbing():
			break
	check(hung, "the hero got up to the ledge before slipping")
	check(not hero.is_climbing() and hero.in_pit(), "the second slip drops the hero back into the pit (y %.2f)" % hero.global_position.y)
	check(absf(hero.global_position.y - floor_y) < 0.1, "the hero is back where the climb began (%.2f, began at %.2f)" % [hero.global_position.y, floor_y])
	await _wait(60)
	# The next try goes through (a fine roll), all the way up.
	hero.pit_roll_forced = 0.0
	await _push_into_pit_wall(hero, pit_spot, 0.0)
	var shot_at := [0.3, 0.45, 0.6, 0.8]
	for i in 900:
		await _wait(1)
		if not hero.is_climbing():
			break
		if not shot_at.is_empty() and hero._pit_u >= shot_at[0]:
			await _shot("climb_%d" % int(shot_at[0] * 100))
			shot_at.pop_front()
	await _wait(30)
	check(hero.global_position.y > -0.5, "pushing against the pit wall climbs the hero out (y %.2f)" % hero.global_position.y)
	await _shot("climb_out")

	# --- 9c. A pit without stairs: the companion waits at the rim, then goes home
	_step("companion at the rim of a pit without stairs")
	var stairs_key := plan.stairs_to(2, 2)
	plan.pieces[stairs_key].state = HouseSketch.SKETCH
	sk._redraw()
	pet = game.pet
	game.player.global_position = top + Vector3(-HouseSketch.CELL * 2.0, 0, 0)
	game.player.reset_physics_interpolation()
	await _wait(60)
	game.player.global_position = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	game.player.reset_physics_interpolation()
	var lowest := 0.0
	var first_low := -1
	for i in 240:
		await process_frame
		if is_instance_valid(pet):
			if pet.global_position.y < lowest - 0.3 and first_low < 0:
				first_low = i
				print("  (pet below the rim at frame ", i, ": y ", pet.global_position.y, " state ", pet.state, " cut off ", pet.is_cut_off(), " gap ", Vector2(pet.global_position.x - game.player.global_position.x, pet.global_position.z - game.player.global_position.z).length(), ")")
			lowest = minf(lowest, pet.global_position.y)
	check(is_instance_valid(pet) and pet.is_cut_off(), "the fox knows it cannot follow into the pit")
	check(lowest > -0.3, "it never jumps down into the pit (lowest y %.2f)" % lowest)
	check(is_instance_valid(pet) and pet.state == "rim" and game.following >= 0, "it waits at the rim while the hero is in sight")
	var rim_d := Vector2(pet.global_position.x - game.player.global_position.x, pet.global_position.z - game.player.global_position.z).length()
	check(rim_d < HouseSketch.CELL * 3.0, "the rim it waits at is next to the hero (%.1f m)" % rim_d)
	# The hero goes out of its sight: off home it runs.
	pet.global_position = game.player.global_position + Vector3(60, HouseSketch.DEPTH - 0.1, 0)
	pet.reset_physics_interpolation()
	await _wait(150)
	check(not is_instance_valid(game.pet) and game.following == -1, "out of sight it goes home to the hero's house")
	check(game.companions.size() > 0, "and stays the hero's companion there")
	plan.pieces[stairs_key].state = HouseSketch.BUILT
	sk._redraw()

	# --- 9c. The cellar ceiling: the ground floor's floor over the cellar, open over the stairs
	_step("cellar ceiling")
	sk.enter()
	await _settle()
	await _select("Floor")
	check(sk.tool == HouseSketcher.TOOL_COVER, "the floor tool is selected")
	var bar_before: Rect2 = sk._bar.get_global_rect()
	await _press("Floor: of wood", sk._bar)
	check(plan.ceiling_surface == "stone", "the material button turns the ceiling to stone")
	await _press("Floor: of stone", sk._bar)
	check(plan.ceiling_surface == "wood", "and back to wood: never bare earth")
	check(sk._bar.get_global_rect() == bar_before, "switching the material does not move or resize the tool bar")
	await _drag(_cell_scr(0, 2), _cell_scr(3, 3))
	check(plan.count(HouseSketch.COVER) == 5, "dragging over the cellar and its stairs plans the floor over every square off the stairs and their foot (%d)" % plan.count(HouseSketch.COVER))
	check(plan.cover_at(0, 2).is_empty() and plan.cover_at(1, 2).is_empty() and plan.cover_at(2, 2).is_empty(), "the stairs and their foot stay open")
	await _move(_cell_scr(0, 0))
	await _wait(5)
	await _shot("ceiling_planned")
	_bar_ok("cellar ceiling")
	await _press("Order the build", sk._bar)
	sk.leave()
	await _wait_built(200)
	check(plan.count(HouseSketch.COVER, HouseSketch.BUILT) == 5, "the hero builds the floor (%d)" % plan.count(HouseSketch.COVER, HouseSketch.BUILT))
	hero.global_position = plan.cell_world(3, 3) + Vector3(0, 0.5, 0)
	hero.reset_physics_interpolation()
	await _wait(60)
	check(absf(hero.global_position.y) < 0.15, "the hero stands on the ceiling at ground level (y %.2f)" % hero.global_position.y)
	await _shot("ceiling_built")
	# Down in the cellar under the ceiling: the hero fits upright and cannot climb out through it.
	hero.global_position = plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	hero.reset_physics_interpolation()
	await _wait(30)
	check(hero.global_position.y < -HouseSketch.DEPTH + 0.3 and hero._under_ceiling(), "the hero stands in the cellar under the ceiling (y %.2f)" % hero.global_position.y)
	await _shot("under_ceiling")
	# From the open foot of the stairs, onto the stairs (they lead down eastwards, so up is to the
	# left). This house's west wall stands over the top of the stairs (node x 1), so the hero gets
	# as far as under it: what counts is that nothing over the foot of the stairs stops them.
	hero.global_position = plan.cell_world(2, 2) + Vector3(0, -HouseSketch.DEPTH + 0.1, 0)
	hero.reset_physics_interpolation()
	await _wait(30)
	Input.action_press("ui_left")
	for i in 80:
		await _wait(5)
		if hero.global_position.y > -1.5:
			break
	Input.action_release("ui_left")
	await _wait(10)
	check(hero.global_position.y > -2.0 and plan.cell_at(hero.global_position) == Vector2i(1, 2) and not hero.is_climbing(),
			"the hero walks from the open foot onto the stairs (y %.2f, cell %s)" % [hero.global_position.y, plan.cell_at(hero.global_position)])

	# --- 10. Upper floor
	_step("floor slab, stairs up, upper wall")
	sk.enter()
	await _settle()
	check(sk.active, "the blueprint tool opens again")
	await _press("Level", sk._bar)
	check(sk.storey == 1, "the Level button goes to the upper floor (%d)" % sk.storey)
	await _press("Level", sk._bar)
	check(sk.storey == -1, "then to the cellar (%d)" % sk.storey)
	await _press("Level", sk._bar)
	check(sk.storey == 0, "and back to the ground floor (%d)" % sk.storey)
	await _select("Slab or flat roof")
	await _drag(_cell_scr(2, 3), _cell_scr(3, 4))
	check(plan.count("slab") == 4, "dragging the floor tool plans four slab squares (%d)" % plan.count("slab"))
	await _select("Stairs up")
	await _click(_cell_scr(0, 4))
	check(plan.count("upstairs") == 1, "stairs up are planned beside the slab (%d)" % plan.count("upstairs"))
	await _shot("upper_planned")
	await _press("Level", sk._bar)
	check(sk.storey == 1, "the Level button reaches the upper floor (%d)" % sk.storey)
	await _select("Wall")
	await _drag(_node_scr(2, 3), _node_scr(4, 3))
	check(plan.count("wall", "sketch") == 2, "upper walls are planned (%d)" % plan.count("wall", "sketch"))
	await _select("Saddle roof")
	await _drag(_cell_scr(2, 3), _cell_scr(3, 3))
	check(plan.count("saddle") > 0, "a gable roof is planned on the upper floor (%d)" % plan.count("saddle"))
	await _shot("roof_planned")
	_bar_ok("roof tools")
	await _press("Order the build", sk._bar)
	check(plan.ordered, "the upper floor is ordered")
	sk.leave()
	await _wait_built(400)
	check(plan.open_pieces() == 0, "the hero builds the upper floor and roof (%d left)" % plan.open_pieces())
	await _shot("upper_built")

	# --- 11. A flat roof: set things on it
	_step("flat roof")
	sk.enter()
	await _settle()
	sk.storey = 0
	await _select("Slab or flat roof")
	await _drag(_cell_scr(1, 1), _cell_scr(2, 1))
	check(plan.count("slab", "sketch") == 2, "a flat roof over the ground floor is planned")
	await _press("Order the build", sk._bar)
	sk.leave()
	await _wait_built(200)
	check(plan.open_pieces() == 0, "the flat roof is built")
	var lvl2: Level = game.level
	var on_roof := plan.cell_world(1, 1)
	var spot_col := lvl2.stone_column(StoneBlock.grid_cell(on_roof))
	check(spot_col == 4, "the flat roof raises the stone grid (%d)" % spot_col)
	game.player.global_position = Vector3(on_roof.x, HouseSketch.STOREY_HEIGHT, on_roof.z)
	game.player.reset_physics_interpolation()
	await _wait(30)
	await _shot("on_the_roof")
	check(game.player.global_position.y > 2.0, "the hero can stand on the flat roof (y=%.2f)" % game.player.global_position.y)
	var crate_spot := lvl2.crate_spot(game.player)
	check(crate_spot != Vector3.INF, "a crate can stand on the roof")
	var spot := lvl2.stone_spot_under(game.player, Vector3.BACK)
	check(not spot.is_empty() and spot.layer == 4, "a stone block can be set down on the roof")
	await _big_plot()
	_end()


## The biggest plot the clerk allows (8 x 8 tiles, 32 m) does not fit the usual view: the
## camera has to pull back so the north wall can be drawn as well as the south one.
func _big_plot() -> void:
	_step("big plot, north wall")
	sk.leave()
	Plots.release(game.hero_name)
	Plots._load()
	var big := Rect2i(plot.position, Vector2i(Plots.MAX_SIDE, Plots.MAX_SIDE))
	Plots._deeds.append({"owner": Homes.deed_name(game.hero_name), "x": big.position.x, "y": big.position.y, "w": big.size.x, "h": big.size.y})
	Plots._save()
	game.plot_marker.refresh()
	plan = sk.plan
	check(plan != null and plan.plot == big, "the big plot has a fresh plan")
	var sign_station: Dictionary = {}
	for s in game.level.stations:
		if s.kind == HouseSketcher.KIND and s.get("owner", "") == game.hero_name:
			sign_station = s
	game.player.global_position = sign_station.pos + Vector3(-0.5, 0, -0.5)
	game.player.reset_physics_interpolation()
	game._use_station(sign_station)
	await _settle()
	await _wait(60)
	await _settle()
	await _shot("big_plot_open")
	var free: Rect2 = sk._free_area()
	var nn := plan.nodes()
	print("  (pull ", game.frame_pull, " corners ", _node_scr(0, 0), _node_scr(nn.x, 0), _node_scr(0, nn.y), _node_scr(nn.x, nn.y), " fits ", sk.plot_fits(), ")")
	var outside := 0
	for x in range(0, nn.x + 1):
		for y in [0, nn.y]:
			if not free.grow(FRAME_SLACK).has_point(_node_scr(x, y)):
				outside += 1
	check(outside == 0, "every node of the north and south edge is on screen above the tool bar (%d outside; free area %s)" % [outside, free])
	# The mouse wheel works on top of the framing and the camera comes to rest (it used to
	# hunt back and forth, zooming in and out a little, once the player zoomed in).
	var zoom_before: float = game._zoom_target
	for i in 3:
		await _button(Vector2(640, 250), MOUSE_BUTTON_WHEEL_UP, true)
	check(game._zoom_target > zoom_before, "the mouse wheel zooms in while the tool is open (%.2f to %.2f)" % [zoom_before, game._zoom_target])
	await _wait(240)
	var cam_a: Vector3 = game.camera.global_position
	var swing := 0.0
	for i in 120:
		await _wait(1)
		swing = maxf(swing, game.camera.global_position.distance_to(cam_a))
		cam_a = game.camera.global_position
	check(swing < 0.01, "after zooming in the camera is at rest, not hunting (largest step %.4f m)" % swing)
	game._zoom_target = zoom_before
	await _wait(240)
	await _select("Wall")
	var base := plan.count("wall")
	await _drag(_node_scr(1, 0), _node_scr(6, 0))
	check(plan.count("wall") == base + 5, "a north wall of five pieces can be dragged along the top edge (%d new)" % (plan.count("wall") - base))
	await _drag(_node_scr(1, nn.y), _node_scr(6, nn.y))
	check(plan.count("wall") == base + 10, "and a south wall along the bottom edge (%d new)" % (plan.count("wall") - base))
	await _drag(_node_scr(0, 1), _node_scr(0, 6))
	check(plan.count("wall") == base + 15, "and a west wall along the left edge (%d new)" % (plan.count("wall") - base))
	await _drag(_node_scr(nn.x, 1), _node_scr(nn.x, 6))
	check(plan.count("wall") == base + 20, "and an east wall along the right edge (%d new)" % (plan.count("wall") - base))
	sk.leave()
	await _settle()
	check(game.frame_pull == 0.0, "closing the tool gives the usual view back (pull %.1f)" % game.frame_pull)


func _end() -> void:
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	if failures.is_empty():
		print("PASS: house playtest")
	else:
		print("FAILED STEPS (%d):" % failures.size())
		for f in failures:
			print("  - ", f)
	quit(1 if not failures.is_empty() else 0)
