extends SceneTree
## Headless test for the heaps of village goods (see VillageClutter): barrels,
## crates, planks, handcarts, stones, buckets, sacks and pumpkins are laid out
## in tidy arrangements, so that no two of them overlap (nothing stacks or
## clips into its neighbour) and each arrangement stays inside its tile, with
## room to spare for the next tile's heap. Also checks that the footprints it
## goes by match the models' meshes.
## Run with: godot --headless -s tests/village_clutter.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var layouts := {"stump": VillageClutter.STUMP, "pumpkins": VillageClutter.PUMPKINS}
	for i in VillageClutter.HEAPS.size():
		layouts["heap %d" % i] = VillageClutter.HEAPS[i]
	for name: String in layouts:
		var layout: Array = layouts[name]
		for item: Array in layout:
			check(VillageClutter.FOOTPRINTS.has(item[0]), "%s: %s has a footprint" % [name, item[0]])
		check(VillageClutter.tightest(layout) >= VillageClutter.MIN_GAP,
				"%s: nothing overlaps or touches (tightest gap %.2f m)" % [name, VillageClutter.tightest(layout)])
		var box := VillageClutter.bounds(layout)
		check(box.position.x >= -VillageClutter.REACH and box.end.x <= VillageClutter.REACH
				and box.position.y >= -VillageClutter.REACH and box.end.y <= VillageClutter.REACH,
				"%s: stays within its tile (%s)" % [name, box])
	# Two things that do overlap are noticed.
	check(VillageClutter.gap(["barrel", 0.0, 0.0, 0.0, 6.0], ["crate_A_big", 0.5, 0.0, 0.0, 6.0]) < 0.0, "overlap is detected")
	check(VillageClutter.gap(["barrel", 0.0, 0.0, 0.0, 6.0], ["crate_A_big", 3.0, 0.0, 0.0, 6.0]) > 0.0, "distance is detected")
	# Every kind of heap turns up in the village's tiles.
	var seen := {}
	for x in 60:
		for y in 4:
			seen[VillageClutter.HEAPS.find(VillageClutter.heap_for("Die Freiheit", Vector2i(x, y)))] = true
	check(seen.size() == VillageClutter.HEAPS.size(), "all %d heaps are used" % VillageClutter.HEAPS.size())
	_check_footprints()
	if failures == 0:
		print("PASS: village_clutter")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


## The footprints agree with the models' own bounds (the position accessors of
## their glTF files), to a centimetre at scale 1.
func _check_footprints() -> void:
	for model: String in VillageClutter.FOOTPRINTS:
		var path := "res://assets/village/%s.gltf" % model
		if not FileAccess.file_exists(path):
			path = "res://assets/graveyard/%s.gltf" % model
		var json := JSON.new()
		check(FileAccess.file_exists(path) and json.parse(FileAccess.get_file_as_string(path)) == OK, "%s: model file reads" % model)
		if not json.data is Dictionary:
			continue
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for mesh: Dictionary in json.data.meshes:
			for prim: Dictionary in mesh.primitives:
				var acc: Dictionary = json.data.accessors[int(prim.attributes.POSITION)]
				low = Vector2(minf(low.x, acc.min[0]), minf(low.y, acc.min[2]))
				high = Vector2(maxf(high.x, acc.max[0]), maxf(high.y, acc.max[2]))
		var fp: Array = VillageClutter.FOOTPRINTS[model]
		var near := func(a: float, b: float) -> bool: return absf(a - b) <= 0.01
		check(near.call((low.x + high.x) * 0.5, fp[0]) and near.call((low.y + high.y) * 0.5, fp[1])
				and near.call((high.x - low.x) * 0.5, fp[2]) and near.call((high.y - low.y) * 0.5, fp[3]),
				"%s: footprint matches the model (%s to %s)" % [model, low, high])
