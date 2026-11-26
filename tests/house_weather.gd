extends SceneTree
## No weather inside a built house (see HouseGround.shelter, Game._shelter and IndoorMask): a hero who
## steps in out of a storm sees no rain, no fog and no storm dark in there, but the storm outside goes
## on and the rain drums muffled; in daytime fog a hero indoors is lit as on a clear day (see
## Outdoor.is_lit). Out in the open again, the storm is back.
## Run with: godot --headless -s tests/house_weather.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch
## The frame of the last step, and how far the view has to have moved in (1) or out (0) of the
## weather before the next step (see Game._shelter). The fade takes real time, not frames.
var step_at := 0
var want := 0.0
var step := 0


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


func _unit_checks() -> void:
	var house := HouseSketch.new()
	house.plot = Rect2i(10, 10, 3, 3)
	# A closed 2 x 2 ring of wall with a door, and a slab over one cell outside it.
	for e in [[1, 1, "x"], [2, 1, "x"], [1, 3, "x"], [2, 3, "x"], [1, 1, "y"], [1, 2, "y"], [3, 1, "y"]]:
		house.pieces[HouseSketch.key_of(e[0], e[1], e[2])] = {"kind": HouseSketch.WALL, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(3, 2, "y")] = {"kind": HouseSketch.DOOR, "state": HouseSketch.BUILT}
	var shelter := HouseGround.shelter(house)
	check(shelter.size() == 4, "the ring keeps the weather off four cells (is %d)" % shelter.size())
	var middle := house.cell_world(1, 1)
	check(HouseGround.sheltered(shelter, middle), "the middle of an inside cell is sheltered")
	check(HouseGround.sheltered(shelter, middle + Vector3(0.9, 0, 0.9)), "the edge of an inside cell is sheltered")
	check(not HouseGround.sheltered(shelter, house.cell_world(0, 0)), "the cell outside the ring is not")
	check(not HouseGround.sheltered(shelter, house.cell_world(3, 1)), "the cell past the door is not")
	check(not HouseGround.sheltered(shelter, middle + Vector3(0, HouseSketch.STOREY_HEIGHT, 0)), "on top of the walls is out in the weather")
	check(HouseGround.sheltered(shelter, middle - Vector3(0, 2, 0)), "below the house is sheltered")
	# A floor alone (a terrace) lies open to the sky; a slab keeps it off, an upper one higher up.
	house.pieces[HouseSketch.key_of(4, 0, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.COVER, "state": HouseSketch.BUILT}
	check(not HouseGround.sheltered(HouseGround.shelter(house), house.cell_world(4, 0)), "snow falls on a terrace")
	house.pieces[HouseSketch.key_of(5, 0, HouseSketch.CELL_ORIENT)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(1, 1, HouseSketch.CELL_ORIENT, 1)] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
	shelter = HouseGround.shelter(house)
	check(HouseGround.sheltered(shelter, house.cell_world(5, 0)), "under a slab is sheltered")
	check(not HouseGround.sheltered(shelter, house.cell_world(5, 0) + Vector3(0, HouseSketch.STOREY_HEIGHT, 0)), "on the slab is not")
	check(HouseGround.sheltered(shelter, middle + Vector3(0, HouseSketch.STOREY_HEIGHT + 0.5, 0)), "the upper storey under the upper slab is sheltered")
	check(not HouseGround.sheltered(shelter, house.cell_world(2, 1) + Vector3(0, HouseSketch.STOREY_HEIGHT, 0)), "beside it, the top of the walls is not")
	house.pieces.erase(HouseSketch.key_of(1, 1, HouseSketch.CELL_ORIENT, 1))
	house.pieces.erase(HouseSketch.key_of(5, 0, HouseSketch.CELL_ORIENT))
	house.pieces.erase(HouseSketch.key_of(4, 0, HouseSketch.CELL_ORIENT))
	house.pieces[HouseSketch.key_of(1, 1, "x")].state = HouseSketch.SKETCH
	check(HouseGround.shelter(house).is_empty(), "a sketched wall leaves the ring open")
	# A cellar reaching beyond the roof: its dug cells and the first two cells of its stairs keep the weather
	# out below the ground (see IndoorMask), under the roof or not.
	house.pieces[HouseSketch.key_of(7, 7, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.DIG, "state": HouseSketch.BUILT}
	house.pieces[HouseSketch.key_of(4, 7, "e", HouseSketch.CELLAR_STOREY)] = {"kind": HouseSketch.STAIRS, "state": HouseSketch.BUILT}
	var pits := HouseGround.pits(house)
	check(pits.has(HouseGround.cell_at(house.cell_world(7, 7))), "a dug cell is a pit")
	check(pits.has(HouseGround.cell_at(house.cell_world(4, 7))) and pits.has(HouseGround.cell_at(house.cell_world(5, 7))), "the cellar stairs' two cells are pits")
	check(pits.size() == 3, "nothing else is (%d)" % pits.size())


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_unit_checks()
	if frames == 5:
		game.hero_name = "Weather test"
		game.escaped = true
		game.load_level(game._outdoor_index(), false)
		game.state = game.State.PLAYING
		var found := Rect2i()
		for y in range(game.level.height - 4):
			for x in range(game.level.grid[y].length() - 4):
				var r := Rect2i(x, y, 3, 3)
				if Plots.problem(game.level, r) == "":
					found = r
					break
			if found.size != Vector2i.ZERO:
				break
		Plots.register(game.level, game.hero_name, found)
		game.plot_marker.refresh()
		plan = game.house_sketcher.plan
		plan.deposit("steinblock", 40)
		plan.sketch(plan.run_between(Vector2i(1, 1), Vector2i(5, 1)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(5, 1), Vector2i(5, 5)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(5, 5), Vector2i(1, 5)), HouseSketch.WALL)
		plan.sketch(plan.run_between(Vector2i(1, 5), Vector2i(1, 1)), HouseSketch.WALL)
		plan.ordered = true
		for i in 20:
			game.house_sketcher.work_once()
		game.house_sketcher._redraw()
		game.day_hour = 12.0
		game.set_weather(Weather.STORM, 5.0)
		game._weather_look = Weather.look(Weather.STORM)
		_put_hero(plan.node_world(0, 0) - Vector3(3, 0, 3))
		step_at = frames
		return false
	if frames > 5 and (frames - step_at < 20 or not is_equal_approx(game._shelter, want)) and frames < 3000:
		return false
	if frames > 5 and frames - step_at >= 20 and step == 0:
		check(plan.count(HouseSketch.WALL, HouseSketch.BUILT) == 16, "the walls are built (%d)" % plan.count(HouseSketch.WALL, HouseSketch.BUILT))
		check(game._rain.visible, "out in the open the storm's rain falls")
		check(game._env.fog_enabled, "out in the open the storm brings haze")
		# A yard closed in by walls but open to the sky: inside the house, but the weather falls in.
		var yard: Vector3 = plan.node_world(3, 3) + Vector3(0, 1, 0)
		check(game.level.is_sheltered(yard), "the walls close the yard in")
		check(not game.level.is_roofed(yard) and not IndoorMask.covers(yard), "the rain falls into a yard with no roof")
		# Now a roof over it (slabs on the walls).
		for cell: Array in plan.cells_between(Vector2i(1, 1), Vector2i(4, 4)):
			plan.pieces[HouseSketch.key_of(cell[0], cell[1], cell[2])] = {"kind": HouseSketch.SLAB, "state": HouseSketch.BUILT}
		game.house_sketcher._redraw()
		_put_hero(plan.node_world(3, 3))
		_lay_slab(plan.node_world(3, 3))
		_next(1.0)
		return false
	if step == 1:
		check(game.level.is_sheltered(game.player.global_position), "the hero stands inside the house")
		check(game.level.is_roofed(game.player.global_position), "under its roof")
		# The storm goes on outside (seen through the windows and over the walls), but the shaders leave
		# out everything inside the house (see IndoorMask), and the rain only drums, muffled.
		check(game._rain.visible, "outside the house the storm's rain still falls, seen from inside")
		var inside: Vector3 = game.player.global_position + Vector3(0, 1, 0)
		check(IndoorMask.covers(inside), "no rain, mist or fog clouds show inside the house")
		check(not IndoorMask.covers(plan.node_world(0, 0) - Vector3(3, -1, 3)), "outside the house they do")
		check(not IndoorMask.covers(inside + Vector3(0, HouseSketch.STOREY_HEIGHT * 2.0, 0)), "above the house they do")
		var bus := AudioServer.get_bus_index(Soundscape.WEATHER_BUS)
		check(bus >= 0 and AudioServer.get_bus_volume_db(bus) < -6.0, "the rain is heard muffled inside")
		check(not game._env.fog_enabled, "no haze inside the house")
		# No rain puddle lies inside the house, though one was laid on that ground outside it.
		var pu: Puddles = (game.level as Outdoor).puddles
		var spot := {"node": null, "at": game.player.global_position, "radius": 2.0, "needs": 0.0, "fill": 1.0, "span": 2.0, "long": false, "id": 9999}
		pu._register(spot)
		check(pu.puddle_at(game.player.global_position).is_empty(), "no puddle inside the house")
		var out_at: Vector3 = plan.node_world(0, 0) - Vector3(3, 0, 3)
		var out_spot := {"node": null, "at": out_at, "radius": 2.0, "needs": 0.0, "fill": 1.0, "span": 2.0, "long": false, "id": 9998}
		pu._register(out_spot)
		check(not pu.puddle_at(out_at).is_empty(), "but puddles outside it stay")
		pu._unregister(spot)
		pu._unregister(out_spot)
		check(float(game._seen_look().sat) > 0.95 and float(game._seen_look().sun) > 0.95, "no storm grey or dark inside the house")
		_snow_checks()
		game.set_weather(Weather.FOG, 5.0)
		game.level.night = false
		check(game.level.is_lit(game.player.global_position), "in daytime fog a hero indoors is seen as on a clear day")
		game.set_weather(Weather.STORM, 5.0)
		_put_hero(plan.node_world(0, 0) - Vector3(3, 0, 3))
		_next(0.0)
		return false
	if step == 2:
		check(game._rain.visible, "out again, the rain falls again")
		var bus := AudioServer.get_bus_index(Soundscape.WEATHER_BUS)
		check(bus >= 0 and AudioServer.get_bus_volume_db(bus) > -0.5, "out again, the rain is heard clearly")
		check(game._env.fog_enabled, "out again, the haze is back")
		print("PASS: house weather" if failures == 0 else "FAILED: %d" % failures)
		Plots.release(game.hero_name)
		game.delete_save(game.save_path())
		quit(1 if failures > 0 else 0)
	return false


## Winter: snow lies outside, but none settles inside the house, no prints are pressed and steps
## do not crunch in there (see SnowCover.set_shelter).
func _snow_checks() -> void:
	var o: Outdoor = game.level
	o.set_snow(1.0)
	var inside: Vector3 = game.player.global_position
	var outside := plan.node_world(0, 0) - Vector3(3, 0, 3)
	var mat: ShaderMaterial = o.snow.material
	check(bool(mat.get_shader_parameter("shelter_on")), "the snow knows where the houses keep it off")
	var mask: Texture2D = mat.get_shader_parameter("shelter_mask")
	check(mask != null, "the snow has a shelter mask")
	if mask != null:
		var img := mask.get_image()
		var c := HouseGround.cell_at(inside)
		var top := img.get_pixel(c.x, c.y).r * SnowCover.SHELTER_SCALE
		check(top > 2.0 and top < HouseSketch.STOREY_HEIGHT, "no snow on the floor inside, up to under the roof line (%.2f m)" % top)
		var out := HouseGround.cell_at(outside)
		check(img.get_pixel(out.x, out.y).r == 0.0, "snow lies outside the house")
	var before := SnowPrints._records.size()
	o.snow_print(inside, 0.0)
	check(SnowPrints._records.size() == before, "no footprints in the snow inside the house")
	o.snow_print(outside, 0.0)
	check(SnowPrints._records.size() == before + 1, "footprints outside it")
	# Up high with nothing underfoot no print is pressed (none falls through to the floor inside
	# the house); up on a flat roof (here a slab over the house) it lies on the roof.
	o.snow_print(inside + Vector3(0, 6.0, 0), 0.0)
	check(SnowPrints._records.size() == before + 1, "no print on the floor inside for a step high above it")
	o.snow_print(Vector3(inside.x, 3.12, inside.z), 0.0)
	check(SnowPrints._records.size() == before + 2, "footprints on the roof")
	var rec: Array = SnowPrints._records[SnowPrints._records.size() - 1]
	# The stand-in slab's top is 3.1 m; the built slabs over the house now collide too, and their top is
	# one storey up (3.2 m). The ray meets the higher one first. Either way the print lies on a roof.
	var on_roof := rec.size() > 6 and (absf(float(rec[5]) - 3.1) < 0.05 or absf(float(rec[5]) - HouseSketch.STOREY_HEIGHT) < 0.05)
	check(on_roof, "the roof's print lies on the roof, not on the floor (%s)" % [rec])
	var high: Node = SnowPrints._live[SnowPrints._live.size() - 1]
	SnowPrints.set_indoors(true)
	check(not (high as MeshInstance3D).visible, "roof prints are hidden while the hero is indoors")
	SnowPrints.set_indoors(false)
	check((high as MeshInstance3D).visible, "roof prints show again outside")
	slab.queue_free()
	check(Surfaces.step_ground(o, inside) != Surfaces.SNOW, "steps inside do not crunch in snow")
	check(Surfaces.step_ground(o, outside) == Surfaces.SNOW or Surfaces.ground(o, outside) == Surfaces.WOOD, "steps outside crunch")
	o.set_snow(0.0)


## A flat roof to stand on over the house (see _snow_checks), laid a while before so the physics
## knows it.
var slab: StaticBody3D


func _lay_slab(at: Vector3) -> void:
	slab = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 0.2, 4)
	slab.add_child(shape)
	game.level.add_child(slab)
	slab.global_position = Vector3(at.x, 3.0, at.z)


func _next(shelter: float) -> void:
	step += 1
	step_at = frames
	want = shelter


func _put_hero(at: Vector3) -> void:
	game.player.global_position = Vector3(at.x, game.player.global_position.y, at.z)
	game.player.reset_physics_interpolation()
