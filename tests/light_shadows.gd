extends SceneTree
## Headless test: walls block light, and nothing else does (see LightShadows), and a wall torch in
## a built house hangs flat against its wall. Only walls (dungeon wall pieces, a built house) are on
## the wall layer, the only one point lights take shadows from. The lights nearest the hero cast
## them, never more than the budget, fading in and out; far ones and small glows stay plain, and a
## light marked NO_SHADOW never casts any.
## Run with: godot --headless --fixed-fps 60 -s tests/light_shadows.gd
## With SHOTS=<folder> and a display it also saves pictures of a lit house at night.

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


## A room of 3 x 2 cells at (1, 1) with walls round it, a door in the south wall and a flat roof.
func _build_house(plan: HouseSketch) -> void:
	for x in range(1, 4):
		plan.pieces[HouseSketch.key_of(x, 1, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(x, 3, HouseSketch.ORIENT_X)] = {"kind": HouseSketch.DOOR if x == 3 else HouseSketch.WALL, "state": HouseSketch.BUILT}
		for y in range(1, 3):
			plan.pieces[HouseSketch.key_of(x, y, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	for y in range(1, 3):
		plan.pieces[HouseSketch.key_of(1, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
		plan.pieces[HouseSketch.key_of(4, y, HouseSketch.ORIENT_Y)] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Light test"
	game.escaped = true
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(5)
	var shadows: LightShadows = game.light_shadows
	check(shadows != null, "the game keeps the wall shadows")
	var level: Outdoor = game.level
	var found := Rect2i()
	for y in range(level.height - 4):
		for x in range(level.grid[y].length() - 4):
			if Plots.problem(level, Rect2i(x, y, 3, 3)) == "":
				found = Rect2i(x, y, 3, 3)
				break
		if found.size != Vector2i.ZERO:
			break
	check(Plots.register(level, game.hero_name, found) == "", "a plot is registered")
	game.plot_marker.refresh()
	var plan: HouseSketch = game.house_sketcher.plan
	_build_house(plan)
	plan.save(game.hero_name)
	var store := HouseFurniture.of(game.hero_name)
	store.add("fackel")
	store.add("leuchter")
	check(store.place(plan, "fackel", 0, 2, 1, 0) == "", "a torch hangs on the north wall")
	check(store.place(plan, "leuchter", 0, 1, 2, 0) == "", "a candle stand stands in the room")
	store.save(game.hero_name)
	game.house_sketcher.refresh()
	await _wait(3)

	# The torch's plate touches the wall's inner face: no gap behind it.
	var torch_light: OmniLight3D = null
	var plate_back := INF
	for light: OmniLight3D in game.find_children("FurnitureLight", "OmniLight3D", true, false):
		var holder := light.get_parent() as Node3D
		var off := holder.global_position - plan.cell_world(2, 1)
		if Vector2(off.x, off.z).length() > 1.5:
			continue # The candle stand's light.
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = holder.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			torch_light = light
			plate_back = minf(plate_back, box.position.z)
	check(torch_light != null, "the torch is up")
	var wall_face := plan.cell_world(2, 1).z - HouseSketch.CELL * 0.5 + HouseSketcher.THICK * 0.5
	if torch_light != null:
		var holder := torch_light.get_parent() as Node3D
		var back_world := holder.to_global(Vector3(0, 0, plate_back)).z
		check(absf(back_world - wall_face) < 0.03, "the torch's plate lies flat on the wall (gap %.3f m)" % (back_world - wall_face))

	# The hero in the room: its lights cast shadows, so the walls hold their light in.
	game.player.global_position = plan.cell_world(2, 2)
	shadows.refresh(true)
	check(torch_light != null and torch_light.shadow_enabled, "the torch near the hero casts shadows")
	check(shadows.shadowed() <= LightShadows.BUDGET, "never more than %d lights cast shadows (%d)" % [LightShadows.BUDGET, shadows.shadowed()])
	# Small glows and marked lights stay plain.
	var glow := OmniLight3D.new()
	glow.omni_range = 2.0
	game.player.add_child(glow)
	var marked := OmniLight3D.new()
	marked.omni_range = 10.0
	marked.set_meta(LightShadows.NO_SHADOW, true)
	game.player.add_child(marked)
	shadows.refresh(true)
	check(not glow.shadow_enabled, "a small glow casts no shadows")
	check(not marked.shadow_enabled, "a light marked NO_SHADOW casts none")
	check(game.player._fill.has_meta(LightShadows.NO_SHADOW), "the soft light on the hero's face stays plain")
	glow.queue_free()
	marked.queue_free()
	# Far away, the house's lights need no shadows: they fade out, not at once.
	game.player.global_position = plan.cell_world(2, 2) + Vector3(200, 0, 0)
	shadows.refresh()
	check(torch_light != null and not shadows.casts(torch_light), "a torch far from the hero is let go")
	check(torch_light != null and torch_light.shadow_enabled and torch_light.shadow_opacity > 0.5, "its shadows fade out instead of vanishing at once")
	shadows._fade(0.5)
	check(torch_light != null and torch_light.shadow_enabled and torch_light.shadow_opacity < 0.6, "half way they are half gone (%.2f)" % torch_light.shadow_opacity)
	shadows._fade(0.6)
	check(torch_light != null and not torch_light.shadow_enabled, "then the torch casts no shadows")
	# Coming back, they fade in the same way.
	game.player.global_position = plan.cell_world(2, 2)
	shadows.refresh()
	check(torch_light != null and torch_light.shadow_enabled and torch_light.shadow_opacity < 0.5, "coming back, its shadows fade in")
	shadows._fade(1.0)
	check(torch_light != null and torch_light.shadow_opacity == 1.0, "until they are whole")
	# Only walls stop light: point lights take shadows from the wall layer alone, the built
	# house and dungeon wall pieces are on it, the torch's bracket, lamps and the hero are not.
	check(torch_light != null and torch_light.shadow_caster_mask == LightShadows.WALL_LAYER | LightShadows.LID_LAYER, "a torch takes shadows from walls (and lifted roofs) only")
	var lamp: OmniLight3D = level._lamps[0]
	check(lamp.shadow_caster_mask == LightShadows.WALL_LAYER | LightShadows.LID_LAYER, "so does a street lamp")
	var house_walls := 0
	for m: MeshInstance3D in game.house_sketcher._solid.find_children("*", "MeshInstance3D", false, false):
		if m.layers & LightShadows.WALL_LAYER:
			house_walls += 1
	check(house_walls > 4, "the built house's walls stop light (%d)" % house_walls)
	# Floors are lit but cast no shadow of their own (no stripes of shadow acne on the boards);
	# an upper floor keeps the light below it with a thin shadow-only board at its underside.
	var floors := 0
	var lit_floors := 0
	var lids := 0
	for m: MeshInstance3D in game.house_sketcher._solid.find_children("*", "MeshInstance3D", false, false):
		if m.has_meta(LightShadows.FLOOR):
			floors += 1
			if not (m.layers & LightShadows.WALL_LAYER):
				lit_floors += 1
		elif m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and m.layers & LightShadows.WALL_LAYER and not LightShadows.lifted(m):
			lids += 1
	check(floors >= 6 and lit_floors == floors, "the house's floors cast no shadow of their own (%d of %d)" % [lit_floors, floors])
	check(lids >= 6, "the upper floor keeps a shadow-only board under it (%d)" % lids)
	var torch_holder := torch_light.get_parent() if torch_light != null else null
	var bracket_walls := 0
	if torch_holder != null:
		for g: GeometryInstance3D in torch_holder.find_children("*", "GeometryInstance3D", true, false):
			if g.layers & LightShadows.WALL_LAYER:
				bracket_walls += 1
	check(torch_holder != null and bracket_walls == 0, "the torch's own bracket does not")
	var hero_walls := 0
	for g: GeometryInstance3D in game.player.find_children("*", "GeometryInstance3D", true, false):
		if g.layers & LightShadows.WALL_LAYER:
			hero_walls += 1
	check(hero_walls == 0, "the hero does not")
	var dungeon_wall := level._place("wall", plan.cell_world(0, 0) + Vector3(0, -40, 0))
	var wall_parts: Array = dungeon_wall.find_children("*", "GeometryInstance3D", true, false)
	check(not wall_parts.is_empty() and wall_parts.all(func(g): return g.layers & LightShadows.WALL_LAYER), "a dungeon wall piece stops light")
	dungeon_wall.queue_free()
	var barrel := level._place("barrel_large", plan.cell_world(0, 0) + Vector3(0, -40, 0))
	check(barrel.find_children("*", "GeometryInstance3D", true, false).all(func(g): return not (g.layers & LightShadows.WALL_LAYER)), "a barrel does not")
	barrel.queue_free()
	game.player.global_position = plan.cell_world(2, 2) + Vector3(200, 0, 0)
	shadows.refresh(true)
	check(torch_light != null and not torch_light.shadow_enabled, "a torch far from the hero casts no shadows")
	# Many lights at once: only the budget's nearest.
	var many: Array = []
	for i in LightShadows.BUDGET + 4:
		var l := OmniLight3D.new()
		l.omni_range = 8.0
		l.position = Vector3(i * 1.5, 2, 0)
		game.player.add_child(l)
		many.append(l)
	await _wait(1)
	shadows.refresh(true)
	check(shadows.shadowed() == LightShadows.BUDGET, "with many lights only %d cast shadows (%d)" % [LightShadows.BUDGET, shadows.shadowed()])
	check(many[0].shadow_enabled and not many[-1].shadow_enabled, "the nearest ones do")
	for l in many:
		l.queue_free()

	if shots != "":
		game.day_hour = 23.0
		game._set_atmosphere(true)
		level.set_hour(23.0)
		game.player.global_position = plan.cell_world(2, 2)
		await _wait(2)
		shadows.refresh(true)
		if OS.get_environment("NO_WALL_SHADOWS") != "":
			# For comparison pictures: the light as it was before walls blocked it.
			shadows.set_process(false)
			for light: Light3D in game.find_children("*", "Light3D", true, false):
				if not light is DirectionalLight3D:
					light.shadow_enabled = false
		var mid := plan.cell_world(2, 1)
		await _shot("torch_close", mid + Vector3(1.6, 1.6, 2.6), mid + Vector3(0, 1.4, -0.9))
		await _shot("torch_side", mid + Vector3(2.4, 1.8, -0.2), mid + Vector3(0, 1.6, -0.85))
		# Behind the north wall, outside: the torch's light stays in.
		await _shot("outside_north", mid + Vector3(0, 5, -9), mid + Vector3(0, 0, -2))
		# From further out, the hero inside: the roof is lifted off for the hero, but the light
		# still does not spill out over the walls onto the ground and trees around.
		await _shot("hero_inside_wide", mid + Vector3(-10, 9, -14), mid + Vector3(0, 0, 1))
		var temple_lamp := level.find_child("TempleLamp0", false, false) as Node3D
		if temple_lamp != null:
			var front := Vector3(sin(temple_lamp.rotation.y), 0, cos(temple_lamp.rotation.y))
			game.player.global_position = temple_lamp.global_position + front * 6.0 - Vector3(0, temple_lamp.global_position.y, 0)
			await _wait(45)
			await _shot("temple_lamps", temple_lamp.global_position + front * 9.0 + Vector3(0, 3.0, 0) + front.cross(Vector3.UP) * 2.0, temple_lamp.global_position - Vector3(0, 1.0, 0) - front.cross(Vector3.UP) * 2.0)
		var lamp_post: OmniLight3D = level._lamps[0]
		game.player.global_position = lamp_post.global_position + Vector3(3, -lamp_post.global_position.y, 3)
		await _wait(45)
		await _shot("lamp_post", lamp_post.global_position + Vector3(5, 2.5, 6), lamp_post.global_position - Vector3(0, 1.8, 0))
		var well: Dictionary = {}
		for st in level.stations:
			if st.kind == "brunnen":
				well = st
		if not well.is_empty():
			for d in [36, 24, 14, 6]:
				game.player.global_position = well.pos + Vector3(d, 0, 0)
				await _wait(45)
				await _shot("fountain_hero_%02d" % d, well.pos + Vector3(0, 14, 12), well.pos)
		await _shot("from_above", plan.cell_world(2, 2) + Vector3(0, 16, 9), plan.cell_world(2, 2))
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	print("PASS: light shadows" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await _wait(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	cam.queue_free()
	game.camera.make_current()
