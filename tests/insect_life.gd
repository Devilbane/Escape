extends SceneTree
## The small life of the open ground and the sounds of the season (see InsectLife): fireflies and gnats, butterflies,
## crickets, cicadas and the owl, each in its season and hour. With SHOTS=<folder> and a display it also takes pictures.
## Run with: godot --headless --fixed-fps 60 -s tests/insect_life.gd

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


func _first(season: String) -> int:
	for d in Weather.YEAR_DAYS:
		if Weather.season(d) == season:
			return d + 2
	return 0


func _at(day: int, hour: float) -> void:
	game.season_shift += day - game.level.season_day
	game.day_hour = hour
	game.level.set_hour(hour)
	game.level.hour = hour
	await _wait(40)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()


func _visible_count(mm: MultiMeshInstance3D, colours: bool) -> int:
	var n := 0
	if not mm.visible:
		return 0
	for i in mm.multimesh.instance_count:
		if colours:
			if mm.multimesh.get_instance_color(i).a > 0.05:
				n += 1
		elif mm.multimesh.get_instance_transform(i).origin.y > -50.0:
			n += 1
	return n


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Insect test"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var summer := _first("summer")
	var spring := _first("spring")
	var winter := _first("winter")
	var autumn_first := _first("autumn")
	var autumn_last := autumn_first + Weather.AUTUMN_DAYS - 3
	# The levels: strongest in the summer night, thinner in spring, fading through autumn, none in winter.
	var c_summer := InsectLife.level_crickets(summer, 23.0, Weather.CLEAR)
	var c_spring := InsectLife.level_crickets(spring, 23.0, Weather.CLEAR)
	var c_early := InsectLife.level_crickets(autumn_first, 23.0, Weather.CLEAR)
	var c_late := InsectLife.level_crickets(autumn_last, 23.0, Weather.CLEAR)
	check(c_summer > c_spring and c_spring > 0.0, "crickets: summer louder than spring (%.2f, %.2f)" % [c_summer, c_spring])
	check(c_early > c_late and c_late > 0.0, "crickets fade through autumn (%.2f, %.2f)" % [c_early, c_late])
	check(InsectLife.level_crickets(winter, 23.0, Weather.CLEAR) == 0.0, "no crickets in winter")
	check(c_summer > InsectLife.level_crickets(summer, 12.0, Weather.CLEAR), "crickets chirp most at night")
	check(InsectLife.level_cicadas(summer, 13.0, Weather.CLEAR) > 0.5, "cicadas drone in the summer noon")
	check(InsectLife.level_cicadas(summer, 23.0, Weather.CLEAR) == 0.0 and InsectLife.level_cicadas(spring, 13.0, Weather.CLEAR) == 0.0, "no cicadas at night or in spring")
	check(InsectLife.level_fireflies(summer, 23.0, Weather.CLEAR) > 0.8 and InsectLife.level_fireflies(summer, 12.0, Weather.CLEAR) == 0.0, "fireflies: night only")
	check(InsectLife.level_fireflies(winter, 23.0, Weather.CLEAR) == 0.0 and InsectLife.level_fireflies(summer, 23.0, Weather.RAIN) == 0.0, "no fireflies in winter or rain")
	check(InsectLife.level_butterflies(summer, 13.0, Weather.CLEAR) > 0.9 and InsectLife.level_butterflies(summer, 23.0, Weather.CLEAR) == 0.0, "butterflies by day")
	check(InsectLife.level_butterflies(winter, 13.0, Weather.CLEAR) == 0.0 and InsectLife.level_butterflies(spring, 13.0, Weather.CLEAR) > 0.0, "butterflies in spring, none in winter")
	check(InsectLife.level_owl(winter, 23.0, Weather.CLEAR) == 0.0 and InsectLife.level_owl(summer, 23.0, Weather.CLEAR) > 0.5, "the owl calls in the nights but not in winter")
	# The pictures: an atlas of four kinds with a cut-out outline, and a mesh with body and two wings.
	var atlas := InsectLife.wing_atlas().get_image()
	check(atlas.get_width() == InsectLife.TILE_PX * 2, "the wing atlas is two tiles wide")
	for k in InsectLife.KINDS:
		var opaque := 0
		var colours := {}
		for y in InsectLife.TILE_PX:
			for x in InsectLife.TILE_PX:
				var px := atlas.get_pixel((k % 2) * InsectLife.TILE_PX + x, (k / 2) * InsectLife.TILE_PX + y)
				if px.a > 0.5:
					opaque += 1
					colours[px.to_html(false).substr(0, 4)] = true
		var share := float(opaque) / float(InsectLife.TILE_PX * InsectLife.TILE_PX)
		check(share > 0.35 and share < 0.85, "butterfly %d: the wing fills part of its tile (%.2f)" % [k, share])
		check(colours.size() >= 12, "butterfly %d: a painted wing, not a flat colour (%d tones)" % [k, colours.size()])
	check(InsectLife.wing_mesh().get_surface_count() == 1 and InsectLife.wing_mesh().get_aabb().size.x > 0.9, "the butterfly mesh is a unit wide")
	# In the world.
	var lvl: Outdoor = game.level
	var life: InsectLife = lvl.insect_life
	check(life != null, "the outdoor map has insect life")
	if life == null:
		quit(1)
		return
	lvl.weather = Weather.CLEAR
	await _at(summer, 23.0)
	life._refresh()
	life._process(0.1)
	for i in 30:
		life._process(0.1)
	var fl := _visible_count(life._flies, true)
	check(fl >= 20, "fireflies blink on a summer night (%d lit or resting)" % fl)
	var hero: Vector3 = game.player.global_position
	for f in life._fly:
		var h: Vector3 = f.home
		if h != Vector3.ZERO:
			check(Vector2(h.x - hero.x, h.z - hero.z).length() <= InsectLife.RANGE + 0.1, "a firefly stays near the hero")
	check(not life._wings.visible, "no butterflies at night")
	await _at(summer, 12.0)
	for i in 40:
		life._process(0.1)
	check(not life._flies.visible, "no fireflies by day")
	check(life._wings.visible and _visible_count(life._wings, false) >= 8, "butterflies by day (%d)" % _visible_count(life._wings, false))
	# They fly about and some settle.
	var start := {}
	for i in life._bf.size():
		start[i] = life._bf[i].pos
	var states := {}
	for i in 600:
		life._process(0.1)
		for b in life._bf:
			states[b.state] = true
	var moved := 0
	for i in life._bf.size():
		if (life._bf[i].pos as Vector3).distance_to(start[i]) > 1.0:
			moved += 1
	check(moved >= 6, "butterflies fly about (%d moved)" % moved)
	check(states.has("fly") and states.has("rest"), "they fly and settle (%s)" % str(states.keys()))
	# The sounds follow the season: the cricket loop in the summer night, the cicadas by day, nothing in winter.
	game.day_hour = 23.0
	var mix := Soundscape.wanted(game)
	check(float(mix.get("crickets_loop", 0.0)) > 0.5, "the soundscape plays crickets on a summer night")
	game.day_hour = 13.0
	mix = Soundscape.wanted(game)
	check(float(mix.get("cicadas_loop", 0.0)) > 0.5, "and cicadas on a summer day")
	check(Soundscape.outdoor_mix(false, true, {}, 0.0).get("crickets_loop", 0.0) == 0.0, "no insect loop without the insect levels")
	check(ResourceLoader.exists("res://assets/sounds/crickets_loop.ogg") and ResourceLoader.exists("res://assets/sounds/cicadas_loop.ogg"), "the loops are there")
	for s in ["cricket_0", "cricket_1", "cricket_2", "owl_0", "owl_1"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.ogg" % s), "the sound %s is there" % s)
	# Pictures.
	if shots != "":
		await _at(summer, 12.0)
		for i in 30:
			life._process(0.1)
		var bf: Vector3 = life._bf[0].pos
		await _shot("butterflies_day", hero + Vector3(0, 2.2, 4.5), hero + Vector3(0, 0.8, 0))
		await _shot("butterfly_close", bf + Vector3(0.5, 0.5, 0.7), bf)
		await _at(summer, 22.5)
		for i in 30:
			life._process(0.1)
		await _shot("fireflies_night", hero + Vector3(0, 1.6, 5.0), hero + Vector3(0, 0.9, -2.0))
	# Winter and autumn's end: nothing to see.
	await _at(winter, 23.0)
	life._refresh()
	life._process(0.1)
	check(not life._flies.visible and not life._wings.visible and not life._gnat_mmi.visible, "nothing flies in winter")
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: insect_life")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
