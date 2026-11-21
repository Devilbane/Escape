extends SceneTree
## Building plots stay clear (see Plots and Outdoor.clear_plot): no tree, boulder
## or mountain slope beside a plot reaches into it, whether the plot was
## registered before the map was built (an old save) or while it is open.
## Run with: godot --headless -s tests/plot_clearing.gd

const MAP := "res://levels/11_die_freiheit.txt"

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	Homes.reload()
	var probe := Outdoor.new()
	probe.load_from_file(MAP)
	var by_forest := _free_plot(probe, "#")
	var by_boulder := _free_plot(probe, "r")
	probe.free()
	check(by_forest.size != Vector2i.ZERO, "a free plot lies against the forest")
	check(by_boulder.size != Vector2i.ZERO, "a free plot lies beside a boulder")
	if failures > 0:
		_finish()
		return

	# Registered while the map is open.
	var level := _build()
	var trees := _trees(level)
	check(_trees_over(level, by_forest) > 0, "trees stand at the edge of the forest plot while it is free")
	check(_props_near(level, by_boulder) > 0, "a boulder stands at the edge of its plot while it is free")
	level.clear_plot(by_forest)
	level.clear_plot(by_boulder)
	level._plot_areas.clear()
	check(_trees_over(level, by_forest) == 0, "a plot registered on the open map clears the trees at its edge")
	check(_props_near(level, by_boulder) == 0, "a plot registered on the open map clears the boulder at its edge")
	check(_trees(level) > trees - 20, "only the trees at the plot's edge go")
	_check_mountains(level)
	level.free()

	# Registered before the map is built, as on a save loaded later.
	check(Plots.register(_loaded(), "Forester", by_forest) == "", "the forest plot can be registered")
	check(Plots.register(_loaded(), "Quarryman", by_boulder) == "", "the boulder plot can be registered")
	level = _build()
	level._plot_areas.clear()
	check(_trees_over(level, by_forest) == 0, "a registered plot has no tree at its edge when the map is built")
	check(_props_near(level, by_boulder) == 0, "a registered plot has no boulder at its edge when the map is built")
	check(_trees(level) > trees - 20, "the rest of the woods still stands")
	level.free()
	Plots.release("Forester")
	Plots.release("Quarryman")
	_finish()


func _finish() -> void:
	print("PASS: plot clearing" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _loaded() -> Outdoor:
	var level := Outdoor.new()
	level.load_from_file(MAP)
	level.queue_free()
	return level


func _build() -> Outdoor:
	var level := Outdoor.new()
	level.load_from_file(MAP)
	root.add_child(level)
	level.build()
	return level


## A free 3 x 3 plot with a tile of `letter` right beside it.
func _free_plot(level: Outdoor, letter: String) -> Rect2i:
	for y in range(1, level.height - 4):
		for x in range(1, level.width - 4):
			var r := Rect2i(x, y, 3, 3)
			if Plots.problem(level, r) != "":
				continue
			for by in range(r.position.y - 1, r.end.y + 1):
				for bx in range(r.position.x - 1, r.end.x + 1):
					if level.cell_char(Vector2i(bx, by)) == letter:
						return r
	return Rect2i()


## Whether something at `at` reaching `reach` comes too close to the plot.
func _near(level: Outdoor, rect: Rect2i, at: Vector3, reach: float) -> bool:
	var area := level.plot_area(rect)
	var p := Vector2(at.x, at.z)
	return p.clamp(area.position, area.end).distance_to(p) < reach + Outdoor.PLOT_CLEARANCE - 0.01


## How many trees are drawn.
func _trees(level: Outdoor) -> int:
	var count := 0
	for key in level._plants:
		# The ferns on the forest floor are no trees (and many grow along a plot's edge).
		if not (key[0] as String).begins_with("fern:"):
			count += level._plants[key].size()
	return count


## How many drawn trees come too close to the plot.
func _trees_over(level: Outdoor, rect: Rect2i) -> int:
	var count := 0
	for key in level._plants:
		for i in level._plants[key].size():
			if _near(level, rect, (level._plants[key][i] as Transform3D).origin, level._plant_reach[key][i]):
				count += 1
	return count


## How many boulders and lone trees still standing come too close to the plot.
func _props_near(level: Outdoor, rect: Rect2i) -> int:
	var count := 0
	for thing in level._clearable:
		if _near(level, rect, thing.at, thing.reach) and thing.nodes.any(func(n) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()):
			count += 1
	return count


## The mountains stay flat on a plot laid over rock and rise only past its edge.
func _check_mountains(level: Outdoor) -> void:
	var rock := Vector2i(-1, -1)
	for y in range(4, level.height - 4):
		for x in range(4, level.width - 4):
			if rock.x < 0 and level.cell_char(Vector2i(x, y)) == Mountains.ROCK_LETTER and level.cell_char(Vector2i(x - 1, y)) != Mountains.ROCK_LETTER:
				rock = Vector2i(x, y)
	check(rock.x >= 0, "the map has a foot of the mountains")
	var area := level.plot_area(Rect2i(rock - Vector2i(1, 1), Vector2i(3, 3)))
	var holder := Outdoor.new()
	holder.load_from_file(MAP)
	root.add_child(holder)
	var plain := _rock_over(Mountains.build(holder, 7), area)
	var flat := _rock_over(Mountains.build(holder, 7, [area]), area)
	check(plain > 0, "the rock rises where no plot lies")
	check(flat == 0, "the rock stays flat on a plot")
	holder.free()


func _rock_over(meshes: Array, area: Rect2) -> int:
	var inside := area.grow(-0.05)
	var count := 0
	for node in meshes:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y > 0.05 and inside.has_point(Vector2(v.x, v.z)):
				count += 1
	return count
