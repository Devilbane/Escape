extends SceneTree
## A candle, sconce or lamp inside a house must not light the house's outside walls (see LightShadows.INDOOR).
## At night, every house the hero can walk into is drawn from outside the way the game camera sees it, once with
## the indoor lights on and once with them all hidden; the two pictures may differ only at the windows (light
## falling out of a pane is meant), so the pixels that differ are counted outside the windows' glow.
## Run with: SHOTS=<folder> godot -s tests/house_wall_light_shots.gd (needs a display); without SHOTS it only
## checks that the indoor lights are marked. With SHOTS it also saves the pictures and the difference.

## How much brighter (0..1, summed over the colour channels) a pixel must be with the lights on to count as lit.
const LIT := 0.06
## How many pixels of a picture may be lit by the indoor lights before the walls count as lit through.
const MAX_LIT_SHARE := 0.004
## How much of the picture from inside a room the candles must light.
const MIN_ROOM_LIT := 0.05
## Where the camera stands from a house's front: up and back, looking at the wall like the game camera.
const CAM_UP := 9.0
const CAM_BACK := 9.0
## How many sides of each house are drawn (turned a quarter each).
const VIEWS := 4
## Frames to wait after the lights change, for their shadows to fade in or out.
const SETTLE := 20
## The pictures are compared at this size, which keeps the per-pixel loop short.
const COMPARE := Vector2i(320, 180)

var game: Node
var frames := 0
var started := false
var failures := 0
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
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


## A picture in which every wall is flat magenta and the rest is as drawn: where the walls are.
func _wall_mask(lvl: Node) -> Image:
	var walls: Array[MeshInstance3D] = []
	for g: Node in lvl.find_children("*", "MeshInstance3D", true, false):
		if LightShadows.is_wall(g) and (g as MeshInstance3D).visible and (g as MeshInstance3D).mesh != null:
			walls.append(g as MeshInstance3D)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(1, 0, 1)
	var other := StandardMaterial3D.new()
	other.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	other.albedo_color = Color(0, 1, 0)
	var soil := StandardMaterial3D.new()
	soil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soil.albedo_color = Color(0, 1, 1)
	var painted := []
	for g: Node in lvl.get_children():
		if g is MeshInstance3D and (g as MeshInstance3D).mesh is PlaneMesh and (g as MeshInstance3D).material_override is ShaderMaterial:
			painted.append([g, 0, (g as MeshInstance3D).get_surface_override_material(0)])
			(g as MeshInstance3D).set_surface_override_material(0, soil)
	for mi in walls:
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			# Glass is no wall: what shows through a pane is the lit room, which is meant to be seen.
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if mat != null and mat.resource_name.begins_with("window"):
				continue
			painted.append([mi, i, mi.get_surface_override_material(i)])
			mi.set_surface_override_material(i, paint if mi.layers & LightShadows.UNSHADOWED_LAYER != 0 else other)
	await _wait(3)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	for p in painted:
		(p[0] as MeshInstance3D).set_surface_override_material(p[1], p[2])
	await _wait(3)
	return picture


func _indoor_lights() -> Array[Light3D]:
	var found: Array[Light3D] = []
	for light: Node in root.find_children("*", "Light3D", true, false):
		if light.has_meta(LightShadows.INDOOR):
			found.append(light as Light3D)
	return found


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	game.hero_name = "Wall light"
	await _wait(10)
	game.load_level(game._outdoor_index(), false)
	await _wait(30)
	var lvl: Outdoor = game.level
	for layer: CanvasLayer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.day_hour = 22.0
	game.set_weather(Weather.CLEAR, 100.0)
	game._weather_look = Weather.look(Weather.CLEAR)
	lvl.set_hour(22.0)
	if lvl.walk_in != null:
		# Every household is awake with its candles lit.
		for rec in lvl.walk_in.buildings:
			rec["light_from"] = 18.0
			rec["bedtime"] = 30.0
		lvl.walk_in.set_hour(22.0)
	await _wait(30)
	var lights := _indoor_lights()
	check(lights.size() > 0, "the village has indoor lights")
	if shots == "":
		print("PASS" if failures == 0 else "FAIL", ": house wall light (%d indoor lamps)" % lights.size())
		quit(failures)
		return
	if OS.get_environment("BIAS") != "":
		for light in lights:
			light.shadow_normal_bias = float(OS.get_environment("BIAS"))
			light.shadow_bias = float(OS.get_environment("BIAS")) * 0.1
	if OS.get_environment("HIDE") != "":
		for n: Node in root.find_children(OS.get_environment("HIDE") + "*", "Node3D", true, false):
			(n as Node3D).visible = false
	var lit_houses := 0
	for rec in lvl.walk_in.buildings:
		var node: Node3D = rec.node
		if OS.get_environment("HOUSES") != "" and lit_houses >= int(OS.get_environment("HOUSES")):
			break
		if not is_instance_valid(node):
			continue
		var name := str(node.name)
		var front: Vector3 = node.global_position
		game.player.global_position = front + Vector3(0, 0, CAM_BACK)
		var cam := Camera3D.new()
		cam.fov = 55.0
		root.add_child(cam)
		for view in range(VIEWS):
			if OS.get_environment("VIEW") != "" and view != int(OS.get_environment("VIEW")):
				continue
			var turn := Basis(Vector3.UP, view * PI * 0.5)
			if view == 3:
				# From inside, looking at the floor and the far wall: the room must stay candle-lit.
				cam.global_position = front + Vector3(0, 1.9, 1.6)
				cam.look_at(front + Vector3(0, 0.2, -1.6))
			elif view == 2:
				# From straight above: the whole ground round the house.
				cam.global_position = front + Vector3(0, 24.0, 0.01)
				cam.look_at(front, Vector3(0, 0, -1))
			else:
				cam.global_position = front + turn * Vector3(0, CAM_UP, CAM_BACK)
				cam.look_at(front + Vector3(0, 1.5, 0))
			cam.make_current()
			for light in lights:
				if is_instance_valid(light):
					light.set_meta(&"was_visible", light.visible)
			await _wait(SETTLE)
			await RenderingServer.frame_post_draw
			var on := root.get_texture().get_image()
			if OS.get_environment("DEBUG") != "":
				for light in lights:
					if is_instance_valid(light) and light.visible and light.global_position.distance_to(front) < 15.0:
						print("light ", light.get_path(), " shadow ", light.shadow_enabled, " op ", light.shadow_opacity, " cull ", light.light_cull_mask, " mask ", light.shadow_caster_mask, " range ", (light as OmniLight3D).omni_range, " at ", light.global_position)
				var walls := 0
				var wall_layers := {}
				for g: Node in node.find_children("*", "GeometryInstance3D", true, false):
					if LightShadows.is_wall(g):
						walls += 1
						wall_layers[(g as GeometryInstance3D).layers] = wall_layers.get((g as GeometryInstance3D).layers, 0) + 1
				print("walls ", walls, " layers ", wall_layers)
			for light in lights:
				if is_instance_valid(light) and OS.get_environment("NOISE") == "":
					# Lit as before as far as picking goes (shadows, the budget), but lighting nothing.
					light.set_meta(&"cull_test", light.light_cull_mask)
					light.light_cull_mask = 0
			await _wait(SETTLE)
			await RenderingServer.frame_post_draw
			var off := root.get_texture().get_image()
			var mask := await _wall_mask(lvl)
			for light in lights:
				if is_instance_valid(light) and light.has_meta(&"cull_test"):
					light.light_cull_mask = light.get_meta(&"cull_test")
					light.remove_meta(&"cull_test")
			var count := 0
			var other_lit := 0
			var ground_lit := 0
			var room_lit := 0
			var full := on
			on = on.duplicate()
			off = off.duplicate()
			on.resize(COMPARE.x, COMPARE.y)
			off.resize(COMPARE.x, COMPARE.y)
			mask.resize(COMPARE.x, COMPARE.y, Image.INTERPOLATE_NEAREST)
			var diff := Image.create(on.get_width(), on.get_height(), false, Image.FORMAT_RGB8)
			for y in on.get_height():
				for x in on.get_width():
					var a := on.get_pixel(x, y)
					var b := off.get_pixel(x, y)
					var d := (a.r - b.r) + (a.g - b.g) + (a.b - b.b)
					var m := mask.get_pixel(x, y)
					var wall := m.r > 0.6 and m.b > 0.6 and m.g < 0.3
					if d > LIT and m.g > 0.6 and m.r < 0.3 and m.b < 0.3:
						other_lit += 1
					if d > LIT and m.g > 0.6 and m.b > 0.6 and m.r < 0.3:
						ground_lit += 1
					if d > LIT:
						room_lit += 1
					if d > LIT and wall:
						count += 1
						diff.set_pixel(x, y, Color(1, 0.3, 0.1))
					else:
						diff.set_pixel(x, y, Color(b.r, b.g, b.b) * 0.5 + (Color(0.3, 0, 0.3) if wall else Color(0, 0, 0)))
			var share := float(count) / float(on.get_width() * on.get_height())
			print("lit on walls still lit by the lamps (green): ", other_lit)
			var ground_share := float(ground_lit) / float(on.get_width() * on.get_height())
			print("%s view %d: ground lit: %.4f" % [name, view, ground_share])
			if view == 3:
				var room_share := float(room_lit) / float(on.get_width() * on.get_height())
				print("%s view 3 (inside): %.3f of the picture lit by the indoor lights" % [name, room_share])
				check(room_share >= MIN_ROOM_LIT, "%s: the room inside is lit by its candles (%.1f%% of the picture)" % [name, room_share * 100.0])
				full.save_png(shots.path_join("%s_%d_on.png" % [name, view]))
				diff.save_png(shots.path_join("%s_%d_diff.png" % [name, view]))
				continue
			check(ground_share <= MAX_LIT_SHARE, "%s view %d: the indoor lights light the ground outside (%.2f%% of the picture)" % [name, view, ground_share * 100.0])
			print("%s view %d: %.4f of the picture lit by indoor lights" % [name, view, share])
			full.save_png(shots.path_join("%s_%d_on.png" % [name, view]))
			diff.save_png(shots.path_join("%s_%d_diff.png" % [name, view]))
			check(share <= MAX_LIT_SHARE, "%s view %d: the indoor lights light %.2f%% of the picture" % [name, view, share * 100.0])
		cam.queue_free()
		lit_houses += 1
	check(lit_houses > 0, "some houses were drawn")
	game.delete_save(game.save_path())
	print("PASS" if failures == 0 else "FAIL", ": house wall light")
	quit(failures)
