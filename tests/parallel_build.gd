extends SceneTree
## Trees grown on the worker threads (AppleTree.dress, which the village's load uses) come out exactly as
## the same trees built one by one with AppleTree.build: the same meshes, vertex for vertex, and the same
## notes about their apples, leaves and limbs, in every season. A tree dressed again with the same look is
## left alone, and one dressed for a new season is rebuilt without leaving the old parts behind.
## Run with: godot --headless -s tests/parallel_build.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var days := {}
	for d in Weather.YEAR_DAYS:
		var season := Weather.season(d)
		if not days.has(season):
			days[season] = d
	check(days.size() == 4, "found a day of each season")
	var spot := func(i: int) -> Vector3: return Vector3(3.3 * i, 0.0, 1.7 * i - 4.0)
	var dressed: Array = []
	for season: String in days:
		var day: int = days[season]
		var trees: Array = []
		var plain: Array[Node3D] = []
		for i in 6:
			var node := Node3D.new()
			node.position = spot.call(i)
			trees.append({"node": node, "look": ""})
			var ref := Node3D.new()
			ref.position = spot.call(i)
			AppleTree.build(ref, AppleTree.VILLAGE_TREE, day)
			plain.append(ref)
		AppleTree.dress(trees, day)
		for i in trees.size():
			var node: Node3D = trees[i].node
			check(_same(node, plain[i]), "%s: tree %d is the tree built one by one" % [season, i])
			check(node.get_child_count() > 0, "%s: tree %d has its parts" % [season, i])
		if season == Weather.SUMMER:
			dressed = trees
	# The same look again changes nothing; a new season rebuilds the tree whole.
	var before: Array = []
	for t in dressed:
		before.append((t.node as Node3D).get_child_count())
	AppleTree.dress(dressed, days[Weather.SUMMER])
	for i in dressed.size():
		check((dressed[i].node as Node3D).get_child_count() == before[i], "the same look leaves the tree as it was")
	var winter: int = days[Weather.WINTER]
	AppleTree.dress(dressed, winter)
	for i in dressed.size():
		var ref := Node3D.new()
		ref.position = spot.call(i)
		AppleTree.build(ref, AppleTree.VILLAGE_TREE, winter)
		check(_same(dressed[i].node, ref), "a tree dressed for winter is the winter tree, with nothing left of the summer one")
	print("PASS: parallel build" if failures == 0 else "FAILED: parallel build (%d)" % failures)
	quit(1 if failures > 0 else 0)


## Whether two trees have the same parts, the same meshes (every array of every surface) and the same notes.
func _same(a: Node3D, b: Node3D) -> bool:
	var pa := a.get_children()
	var pb := b.get_children()
	if pa.size() != pb.size():
		return false
	for i in pa.size():
		if pa[i].name != pb[i].name or pa[i].get_class() != pb[i].get_class():
			return false
		if pa[i] is MeshInstance3D and (pa[i] as MeshInstance3D).mesh != null:
			var ma: Mesh = pa[i].mesh
			var mb: Mesh = pb[i].mesh
			if ma.get_surface_count() != mb.get_surface_count():
				return false
			for s in ma.get_surface_count():
				var aa := ma.surface_get_arrays(s)
				var ab := mb.surface_get_arrays(s)
				for k in aa.size():
					if hash(aa[k]) != hash(ab[k]):
						return false
	for key in b.get_meta_list():
		if not a.has_meta(key) or a.get_meta(key) != b.get_meta(key):
			return false
	return true
