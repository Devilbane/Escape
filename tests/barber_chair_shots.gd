extends SceneTree
## Pictures of Benno's barber's chair (see BarberChair, BarberCut): the chair and its table beside his tent,
## the hero in the chair with the cape on, and the storm of hair during the cut. It also checks that the
## chair is a seat for the hero, that the window only opens from the chair, and that the cut applies the
## new look at its end. SHOTS=<folder> saves the pictures.
## Run with a display: SHOTS=<folder> godot --fixed-fps 60 -s tests/barber_chair_shots.gd

var failures := 0
var game: Node
var frames := 0
var started := false
var _cam: Camera3D
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Lang.language = "en"
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


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _view(at: Vector3, offset: Vector3, look_at_offset := Vector3(0, 0.9, 0)) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 45.0
		root.add_child(_cam)
		_cam.make_current()
	var cam := _cam
	cam.global_position = at + offset
	cam.look_at(at + look_at_offset)


func _run() -> void:
	game._title.visible = false
	game.hero_name = "Barber chair"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.day_hour = 12.0
	await _wait(10)
	var level: Outdoor = game.level
	var hero: Player = game.player
	var chair: BarberChair = level.barber_chair
	check(not chair.station.is_empty(), "the village has a barber's chair")
	check(chair.barber != null and chair.barber.role == "Z", "Benno stands behind it")
	var benno: Villager = chair.barber
	var tent := level.find_child("BarberTent", true, false) as Node3D
	check(tent != null and chair.tent == tent, "the chair stands under the tent")
	check(Vector2(tent.global_position.x - chair.chair_pos.x, tent.global_position.z - chair.chair_pos.z).length() < 1.0, "the chair is in the tent's middle")
	check(not level.astar.is_point_solid(level.world_to_cell(tent.global_position)), "the tent can be walked into")
	check(tent.find_child("BarberRoof", true, false) != null, "the tent has its linen roof")
	check(not level.shrubs.any(func(s: Vector3): return Vector2(s.x - tent.global_position.x, s.z - tent.global_position.z).length() < Outdoor.BARBER_CLEAR), "no shrubs round the tent")
	check(benno.station.kind == "npc", "talking to Benno opens no window")
	check(level.stations.has(chair.station) and chair.station.kind == Seats.KIND, "the chair is a seat")
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		if layer != game.menus.get_parent():
			layer.visible = false
	var at := chair.chair_pos
	hero.global_position = at + Vector3(0, 0, 3.5)
	hero.reset_physics_interpolation()
	benno.global_position = level.cell_to_world(benno.home)
	await _wait(5)
	_view(at, Vector3(3.2, 3.2, 7.0), Vector3(0.0, 1.0, -0.5))
	await _wait(3)
	await _shot("chair_empty")
	_view(at, Vector3(5.5, 3.0, 9.0), Vector3(0.0, 2.2, 0.0))
	await _wait(3)
	await _shot("tent_outside")
	_view(at, Vector3(-4.0, 1.8, 7.0), Vector3(0.0, 2.4, 0.0))
	await _wait(3)
	await _shot("tent_corner")
	_view(at, Vector3(2.0, 1.2, 2.2), Vector3(0.3, 0.45, 0.2))
	await _wait(3)
	await _shot("chair_close")
	_view(at, Vector3(-1.2, 1.6, 2.4), Vector3(0.0, 0.6, 0.2))
	await _wait(3)
	await _shot("chair_side")

	# Standing beside the tent fades it, walking away brings it back.
	hero.global_position = tent.global_position + Vector3(BarberTent.REACH + 0.5, 0, 0)
	await _wait(40)
	check(not tent.visible, "the tent is gone while the hero stands beside it")
	hero.global_position = at + Vector3(6.0, 0, 9.0)
	await _wait(40)
	check(tent.visible, "the tent returns when the hero walks away")
	hero.global_position = at + Vector3(0, 0, 3.5)
	await _wait(5)
	# The hero sits: running into the chair seats them, the cape goes on, the window opens a moment later.
	check(not game.menus.is_open(), "the window is shut before the hero sits")
	game._use_station(chair.station)
	check(hero.is_seated(), "the hero sits in the chair")
	check(chair.hero_in(level), "the chair knows its sitter")
	await _wait(40)
	check(not tent.visible, "the tent is gone while the hero sits")
	check(benno.snip_spot != Vector3.INF and benno.customer_at != Vector3.INF, "Benno comes to the chair")
	check(chair.cut.cape != null, "the cape goes on")
	# The window waits until Benno has walked round to his place up and left of the chair (it stops the village).
	for i in 600:
		if game.menus.is_open():
			break
		await _wait(1)
	check(game.menus.is_open() and game.menus.current == "barbier", "Benno's window opens when the hero sits")
	check(Vector2(benno.global_position.x - benno.snip_spot.x, benno.global_position.z - benno.snip_spot.z).length() < 0.2, "Benno has walked to his place before the window opens")
	check(benno.snip_spot.x < chair.chair_pos.x and benno.snip_spot.z < chair.chair_pos.z, "his place is up and left of the customer from the camera")
	_view(at, Vector3(1.6, 1.7, 3.0), Vector3(0.0, 0.85, -0.2))
	await _wait(5)
	await _shot("hero_caped")
	_view(at, Vector3(-0.2, 1.4, 2.6), Vector3(0.0, 0.8, -0.3))
	await _wait(3)
	await _shot("hero_front")

	# A style is picked: the window shuts, the cut starts, the new look waits for the end.
	var old_style: String = hero.hair.style
	game.coins = 500
	game.menus._restyle("style", "mohawk", 15)
	check(not game.menus.is_open(), "the window shuts when a style is picked")
	check(chair.cut.active(), "the cut begins")
	check(hero.hair.style == old_style, "the new look is not worn yet")
	await _wait(40)
	_view(at, Vector3(2.3, 1.9, 3.6), Vector3(0.0, 1.0, -0.3))
	await _wait(2)
	await _shot("storm_a")
	await _wait(30)
	_view(at, Vector3(0.6, 1.6, 3.2), Vector3(0.0, 0.9, -0.2))
	await _wait(2)
	await _shot("storm_b")
	await _wait(30)
	_view(at, Vector3(-2.2, 2.4, 3.8), Vector3(0.0, 0.6, 0.0))
	await _wait(2)
	await _shot("storm_floor")
	check(benno.customer_at != Vector3.INF, "Benno turns to the chair and snips")
	chair.cut.left = 0.3
	await _wait(40)
	check(not chair.cut.active(), "the cut is over after its time")
	check(hero.hair.style == "mohawk", "the new look is worn at the end")
	await _wait(30)
	check(chair.cut.cape == null, "the cape comes off")
	await _wait(30)
	check(tent.visible == false, "the tent stays away while the hero still sits")
	_view(at, Vector3(1.6, 1.6, 3.0), Vector3(0.0, 0.85, -0.2))
	await _wait(2)
	await _shot("done")
	hero.stand_up()
	await _wait(60)
	check(not tent.visible, "the tent stays away while the hero stands beside the chair")
	hero.global_position = at + Vector3(6.0, 0, 9.0)
	await _wait(60)
	check(tent.visible, "the tent comes back when the hero gets up")
	check(benno.customer_at == Vector3.INF, "Benno goes back to his post")
	# A villager takes the chair: they sit, Benno snips, the hero cannot sit down, then they get up.
	# Some villagers are busy with a task of their own and ignore the offer: the first who sits will do.
	var guests: Array[Villager] = []
	for v: Villager in level.villagers:
		if v != benno and BenchRest.rests_here(v) and v.visible and not v.at_home:
			guests.append(v)
	check(not guests.is_empty(), "a villager who may rest is about")
	var guest: Villager = null
	for candidate in guests:
		guest = candidate
		guest.global_position = chair.seat.stand + Vector3(0, 0, 6.0)
		guest.reset_physics_interpolation()
		chair.seat.taker = guest
		guest.go_to_meal(chair.seat)
		for i in 900:
			guest._physics_process(1.0 / 30.0)
			benno._physics_process(1.0 / 30.0)
			chair.tick(level, 1.0 / 30.0)
			if guest.seated_on_bench():
				break
		if guest.seated_on_bench():
			break
		guest.forget_meal()
		chair.seat.taker = null
	if guest != null:
		check(guest.seated_on_bench(), "the villager sits in the chair")

		chair.tick(level, 0.1)
		check(chair.taken(chair.station), "a chair with a villager in it is taken")
		check(benno.customer_at != Vector3.INF, "Benno snips at the villager")
		chair.seat.until = 0.01
		for i in 300:
			guest._physics_process(1.0 / 30.0)
			benno._physics_process(1.0 / 30.0)
			chair.tick(level, 1.0 / 30.0)
			if not guest.rests():
				break
		check(not chair.taken(chair.station), "the villager gets up again")
		check(benno.customer_at == Vector3.INF, "Benno stops snipping")
	print("PASS: barber chair shots" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
