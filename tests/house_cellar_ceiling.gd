extends SceneTree
## The cellar ceiling (HouseSketch.COVER): one piece over a dug cell that is the
## cellar's ceiling and the ground floor's floor at once, of wood or stone, never
## bare earth. It goes only over dug cells, so the stairs stay open; it works on a
## cellar that was dug before it existed; and on the map the hero walks over it at
## ground level while the cellar stays below.
## Run with: godot --headless -s tests/house_cellar_ceiling.gd

var failures := 0
var game: Node
var frames := 0
var plan: HouseSketch


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


## The rules of the plan, without a map.
func _plan_rules() -> void:
	var s := HouseSketch.new()
	s.plot = Rect2i(0, 0, 4, 4)
	check(s.ceiling_surface == "wood" and not HouseSketch.CEILINGS.has(""), "a cellar ceiling is wood or stone, never bare earth")
	# A cellar dug and built before the ceiling existed (an old save): 2 x 2 cells and stairs from the west.
	s.sketch_dig(s.cells_between(Vector2i(3, 3), Vector2i(4, 4)))
	s.sketch_stairs(1, 3, "e")
	for key in s.pieces:
		s.pieces[key].state = HouseSketch.BUILT
	check(s.problem_cover(1, 3) == "no dig" and s.problem_cover(2, 3) == "no dig", "no ceiling over the stairs")
	check(s.problem_cover(0, 0) == "no dig", "no ceiling where nothing is dug")
	check(s.problem_cover(3, 3) == "", "a ceiling fits over a dug cell")
	# Drag over the whole cellar with its stairs: the stairs are left open by themselves.
	var n := s.sketch_cover(s.cells_between(Vector2i(1, 3), Vector2i(4, 4)))
	check(n == 4, "dragging over cellar and stairs covers only the four dug cells (%d)" % n)
	check(s.cover_at(1, 3).is_empty() and s.cover_at(2, 3).is_empty(), "the stairs opening stays open")
	check(s.cover_at(3, 3).surface == "wood", "the ceiling takes the chosen material")
	check(s.problem_cover(3, 3) == "taken", "one ceiling per cell")
	check(HouseSketch.cost_of(s.cover_at(3, 3)) == {HouseSketch.TIMBER: 1}, "a wooden ceiling costs one timber, like a slab")
	s.undo()
	s.ceiling_surface = "stone"
	s.sketch_cover(s.cells_between(Vector2i(3, 3), Vector2i(4, 4)))
	check(HouseSketch.cost_of(s.cover_at(4, 4)) == {HouseSketch.STONE: 1}, "a stone ceiling costs one stone block")
	check(s.missing() == {HouseSketch.STONE: 4}, "the plan asks for the ceiling's material (%s)" % s.missing())
	# Saved and read back.
	s.save("Ceiling rules")
	HouseSketch._loaded = false
	var back := HouseSketch.of("Ceiling rules", s.plot)
	check(back.count(HouseSketch.COVER) == 4 and back.cover_at(4, 4).surface == "stone", "the ceiling is saved with its material")
	check(back.ceiling_surface == "stone", "the chosen ceiling material is saved")
	# Built from the plot's stock, after the cells under it.
	back.deposit(HouseSketch.STONE, 4)
	back.order()
	var built := 0
	for i in 6:
		if back.build_next().get("kind", "") == HouseSketch.COVER:
			built += 1
	check(built == 4 and back.is_covered(3, 3) and int(back.stock.get(HouseSketch.STONE, 0)) == 0, "the hero builds the ceiling from the stock")
	# The eraser takes the ceiling first, and the cell under it only after.
	check(back.erase_cell(3, 3) == "" and back.cover_at(3, 3).state == HouseSketch.DEMOLISH, "the eraser in the cellar marks the ceiling first")
	check(back.pieces[HouseSketch.key_of(3, 3, HouseSketch.CELL_ORIENT, HouseSketch.CELLAR_STOREY)].state == HouseSketch.BUILT, "the dug cell stays")
	check(back.erase_above(4, 4, 0) == "" and back.cover_at(4, 4).state == HouseSketch.DEMOLISH, "on the ground floor the eraser takes the ceiling (its floor)")
	back.erase_cell(4, 4)
	back.order()
	var first: Dictionary = back.build_next()
	check(first.get("kind", "") == HouseSketch.COVER, "a ceiling comes down before the cell under it is filled in")
	back.build_next()
	back.build_next()
	check(back.cover_at(4, 4).is_empty() and not back.is_dug(4, 4) and int(back.stock.get(HouseSketch.STONE, 0)) == 2, "taken down, its material comes back")
	check(back.problem_cover(4, 4) == "no dig", "no ceiling over a filled-in cell")


func _height_at(point: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = game.level.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 6, 0), point + Vector3(0, -20, 0))
	var hit := space.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else -999.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_plan_rules()
	if frames == 5:
		game.hero_name = "Ceiling test"
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
		plan.deposit("steinblock", 20)
		plan.deposit("bauholz", 10)
		plan.sketch_dig(plan.cells_between(Vector2i(3, 3), Vector2i(4, 4)))
		plan.sketch_stairs(1, 3, "e")
		plan.ordered = true
		for i in 8:
			game.house_sketcher.work_once()
		# Then the ceiling over three of the four cells.
		plan.sketch_cover([[3, 3], [4, 3], [3, 4]])
		plan.ordered = true
		for i in 4:
			game.house_sketcher.work_once()
		return false
	if frames < 9:
		return false
	check(plan.count(HouseSketch.COVER, HouseSketch.BUILT) == 3, "the ceiling is built")
	var covered := plan.cell_world(3, 4)
	var open := plan.cell_world(4, 4)
	check(absf(_height_at(covered)) < 0.05, "the ceiling carries the hero at ground level (is %f)" % _height_at(covered))
	check(absf(_height_at(open) + HouseSketch.DEPTH) < 0.05, "the cell left open is still a pit (is %f)" % _height_at(open))
	var h := _height_at(plan.cell_world(2, 3))
	check(h < -0.5 and h > -HouseSketch.DEPTH + 0.5, "the stairs still lead down (is %f)" % h)
	# Under the ceiling the cellar is still there.
	var space: PhysicsDirectSpaceState3D = game.level.get_world_3d().direct_space_state
	var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(covered + Vector3(0, -0.5, 0), covered + Vector3(0, -20, 0)))
	check(not below.is_empty() and absf(below.position.y + HouseSketch.DEPTH) < 0.05, "the cellar floor is still under the ceiling")
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(covered + Vector3(0, -HouseSketch.DEPTH + 0.2, 0), covered + Vector3(0, 2, 0)))
	check(not roof.is_empty() and roof.position.y < -HouseSketch.COVER_THICK + 0.05, "from the cellar the ceiling is overhead")
	var landing := space.intersect_ray(PhysicsRayQueryParameters3D.create(plan.cell_world(3, 3) + Vector3(0, -HouseSketch.DEPTH + 0.2, 0), plan.cell_world(3, 3) + Vector3(0, 2, 0)))
	check(not landing.is_empty() and landing.position.y + HouseSketch.DEPTH > 2.2, "the cell at the foot of the stairs keeps headroom under its ceiling")
	# Snow lies on the ceiling but not in the open pit; dropped things stay on the ceiling.
	var snow_material: ShaderMaterial = game.level.snow.material
	var mask: Image = (snow_material.get_shader_parameter("hole_mask") as Texture2D).get_image()
	var cell := func(p: Vector3) -> Vector2i: return Vector2i(floori((p.x + game.level.TILE * 0.5) / 2.0), floori((p.z + game.level.TILE * 0.5) / 2.0))
	check(mask.get_pixelv(cell.call(open)).r > 0.75, "the snow keeps off the open pit")
	var half: float = mask.get_pixelv(cell.call(covered)).r
	check(half > 0.25 and half < 0.75, "the snow lies on the ceiling but not in the cellar under it (%f)" % half)
	game.level._drop_item(Items.KNIFE, covered + Vector3(0.3, 0, 0.3), false)
	game.house_sketcher._redraw()
	var spot: Vector3 = (game.level._pickups.back().node as Node3D).position
	check(Vector2(spot.x - covered.x, spot.z - covered.z).length() < 1.0, "a thing dropped on the ceiling stays there")
	print("PASS: house cellar ceiling" if failures == 0 else "FAILED: %d" % failures)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
	return true
