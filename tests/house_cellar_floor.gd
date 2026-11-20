extends SceneTree
## The ground over a built cellar (see Outdoor.set_floor_holes): open over the
## dug cells with a floor at the bottom, whole beside them, and a ramp that
## carries the hero down. Run with: godot --headless -s tests/house_cellar_floor.gd

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


func _height_at(point: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = game.level.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 6, 0), point + Vector3(0, -20, 0))
	var hit := space.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else -999.0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game.hero_name = "Cellar test"
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
		return false
	if frames < 9:
		return false
	var whole := plan.cell_world(0, 0)
	var pit := plan.cell_world(4, 4)
	var ramp := plan.cell_world(2, 3)
	check(absf(_height_at(whole)) < 0.05, "the ground beside the cellar is whole at height 0 (is %f)" % _height_at(whole))
	check(absf(_height_at(pit) + HouseSketch.DEPTH) < 0.05, "the pit floor lies %f m down (is %f)" % [HouseSketch.DEPTH, _height_at(pit)])
	var h := _height_at(ramp)
	check(h < -0.5 and h > -HouseSketch.DEPTH + 0.5, "the ramp slopes between the two (is %f)" % h)
	check(absf(_height_at(plan.node_world(1, 3) + Vector3(0.05, 0, 1.0))) < 0.4, "the ramp starts level with the ground")
	var snow_material: ShaderMaterial = game.level.snow.material
	check(snow_material.get_shader_parameter("holes_on") == true, "the snow keeps off the dug squares")
	var mask: Image = (snow_material.get_shader_parameter("hole_mask") as Texture2D).get_image()
	var cell := Vector2i(floori((pit.x + game.level.TILE * 0.5) / 2.0), floori((pit.z + game.level.TILE * 0.5) / 2.0))
	check(mask.get_pixelv(cell).r > 0.5, "the snow mask is open over the pit")
	# Whatever lies on a dug square is cleared: litter lifted away, dropped things moved to the grass.
	game.level._drop_item(Items.KNIFE, pit + Vector3(0.3, 0, 0.3), false)
	game.house_sketcher._redraw()
	var pickup: Dictionary = game.level._pickups.back()
	var spot: Vector3 = (pickup.node as Node3D).position
	check(Vector2(spot.x - pit.x, spot.z - pit.z).length() > 1.0, "a dropped item is moved out of the pit")
	game.level.surface_life._clear_around_loot()
	check(game.level.surface_life.litter_near(pit, 1.4) == 0, "no leaves or twigs lie on the pit")
	print("PASS: house cellar floor" if failures == 0 else "FAILED: %d" % failures)
	Plots.release(game.hero_name)
	game.delete_save(game.save_path())
	quit(1 if failures > 0 else 0)
	return true
