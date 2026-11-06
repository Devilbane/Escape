extends SceneTree
## Headless test for the village buildings: every house block gets a
## half-timbered house (see VillageHouse) and the temple a chapel from the
## Modular Cathedral Kit. Each building stays inside its block, keeps its
## door in front for the villagers, and its windows glow at night only.
## Run with: godot --headless --fixed-fps 60 -s tests/village_buildings.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: village buildings")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


## The box round everything a building shows, in world space.
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The block of tiles (in metres) a building stands on.
func _block_area(lvl: Outdoor, block: Rect2i) -> Rect2:
	var half := Level.TILE * 0.5
	var a := lvl.cell_to_world(block.position)
	return Rect2(Vector2(a.x - half, a.z - half), Vector2(block.size) * Level.TILE)


func _run() -> void:
	game.load_level(game._outdoor_index(), false)
	await _wait(2)
	var lvl: Outdoor = game.level

	var houses: Array[Node3D] = []
	var chapel: Node3D
	for child in lvl.get_children():
		if not child is Node3D or not child.has_meta("block"):
			continue
		if child.has_meta("village_house"):
			houses.append(child)
		elif child.name.begins_with("Chapel"):
			chapel = child

	# The houses.
	var blocks := 0
	var seen := {}
	for y in lvl.height:
		for x in lvl.width:
			var c := Vector2i(x, y)
			if lvl.cell_char(c) == "h" and not seen.has(c):
				blocks += 1
				for dy in 2:
					for dx in 2:
						seen[c + Vector2i(dx, dy)] = true
	check(blocks > 0, "the village has house blocks")
	check(houses.size() == blocks, "every house block gets a half-timbered house (%d of %d)" % [houses.size(), blocks])
	check(lvl.spots.houses.size() == blocks, "every house has a door the villagers walk to")
	var looks := {}
	for house in houses:
		var box := _bounds(house)
		var area := _block_area(lvl, house.get_meta("block"))
		check(area.grow(0.3).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "a house stays inside its block")
		check(box.size.y > 6.0 and box.size.y < 14.0, "a house has two floors and a roof (%.1f m high)" % box.size.y)
		var mesh: Mesh = (house.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		var glass := false
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i) == lvl._house_glass():
				glass = true
			elif (mesh.surface_get_material(i) as StandardMaterial3D).albedo_texture == null:
				check(false, "every part of a house is textured")
		check(glass, "a house has windows")
		looks["%.2f" % box.size.x + "/%.2f" % box.size.y] = true
	check(looks.size() > 1, "the houses do not all look the same")

	# The chapel.
	check(chapel != null, "the temple is a chapel")
	if chapel:
		check(chapel.get_child_count() >= Outdoor.CHAPEL_PARTS.size() + 2, "the chapel has all its pieces and both gables")
		var box := _bounds(chapel)
		var area := _block_area(lvl, chapel.get_meta("block"))
		check(area.grow(0.3).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "the chapel stays inside its block")
		check(box.size.y > 15.0, "the chapel's spire rises over the village (%.1f m)" % box.size.y)
		var dark := 0
		for mi: MeshInstance3D in chapel.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(i) == null:
					dark += 1
		check(dark == 0, "every piece of the chapel has the kit's textures")
		check(lvl.doors.has("s") and not lvl.astar.is_point_solid(lvl.world_to_cell(lvl.doors["s"])), "the square in front of the chapel door is free")
		var front: Vector3 = lvl.doors["s"] - box.get_center()
		check(front.z > 0.0, "the chapel door looks to the square")

	# Windows: dark by day, warm at night.
	var house_glass := lvl._house_glass()
	var chapel_glass: StandardMaterial3D = lvl._scenes.get("mat_chapel_glass")
	lvl.set_hour(12.0)
	check(is_zero_approx(house_glass.emission_energy_multiplier), "house windows are dark by day")
	check(chapel_glass != null and is_zero_approx(chapel_glass.emission_energy_multiplier), "the chapel's windows are dark by day")
	lvl.set_hour(23.0)
	check(house_glass.emission_energy_multiplier > 1.0, "house windows glow at night")
	check(chapel_glass != null and chapel_glass.emission_energy_multiplier > 1.0, "the chapel's stained glass glows at night")
	lvl.set_hour(12.0)

	# The houses keep the villagers out of their walls.
	for house in houses:
		var mid := lvl.world_to_cell(house.position)
		check(lvl.astar.is_point_solid(mid), "a house is solid")
	_finish()
