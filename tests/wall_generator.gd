extends SceneTree
## Headless test of the random wall (see WallGenerator): the fill share is kept, 100 % puts a hold on every square,
## every wall can be climbed from the foot to the summit, the same seed gives the same wall, and the base wall's
## size, level and name carry over.
## Run with: godot --headless -s tests/wall_generator.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _holds(m: WallMap) -> int:
	var n := 0
	for r in m.height:
		for c in m.width:
			if m.has_hold(c, r):
				n += 1
	return n


func _initialize() -> void:
	var base := WallMap.blank(30, 26)
	base.wall_name = "Probe"
	base.level = 5
	var full := WallGenerator.generate(base, 1.0, 7)
	check(_holds(full) == 30 * 26, "100 percent: a hold on every square")
	check(full.width == 30 and full.height == 26 and full.level == 5 and full.wall_name == "Probe", "size, level and name carry over")
	check(full.validate().filter(func(i: Dictionary) -> bool: return i.level == "error").is_empty(), "the full wall can be climbed")
	for fill in [0.0, 0.2, 0.5, 0.8]:
		for s in 5:
			var m := WallGenerator.generate(base, fill, s)
			var errors := m.validate().filter(func(i: Dictionary) -> bool: return i.level == "error")
			check(errors.is_empty(), "wall %d at fill %s can be climbed" % [s, fill])
			var want := int(round(fill * 30 * 26))
			var got := _holds(m)
			check(got >= want and got <= want + 30 + 26 * 4, "fill %s: %d holds for %d wanted" % [fill, got, want])
	check(_holds(WallGenerator.generate(base, 0.5, 1)) == _holds(WallGenerator.generate(base, 0.5, 1)), "same seed, same wall")
	check(WallGenerator.generate(base, 0.5, 1).to_text() == WallGenerator.generate(base, 0.5, 1).to_text(), "same seed, same text")
	check(WallGenerator.generate(base, 0.5, 1).to_text() != WallGenerator.generate(base, 0.5, 2).to_text(), "another seed, another wall")
	var back := WallMap.parse(full.to_text())
	check(_holds(back) == 30 * 26, "a generated wall survives the text format")
	_features(base)
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _count_markers(m: WallMap, kind: String) -> int:
	var n := 0
	for cell: Vector2i in m.markers:
		if m.markers[cell] == kind:
			n += 1
	return n


func _hazards(m: WallMap, kind: int) -> int:
	var n := 0
	for r in m.height:
		for c in m.width:
			if m.hazard_at(c, r) == kind:
				n += 1
	return n


## The special features: fixed counts are met, chances add more, markers lie on holds a climber can reach, and the
## wall stays climbable with everything switched on.
func _features(base: WallMap) -> void:
	var opts := WallGenerator.default_options()
	check(_count_markers(WallGenerator.generate_with(base, opts, 3), "camp") == 0, "no features by default")
	for f: Dictionary in WallGenerator.FEATURES:
		check(opts.features.has(f.key), "default options list %s" % f.key)
		if f.kind == "marker":
			check(WallMap.MARKERS.has(f.key), "%s is a marker of the wall format" % f.key)
	opts.features.camp = {"count": 3, "chance": 0.0}
	opts.features.edelweiss = {"count": 2, "chance": 0.0}
	opts.features.secret = {"count": 1, "chance": 0.0}
	opts.features.loose = {"count": 2, "chance": 0.0}
	opts.features.gap = {"count": 2, "chance": 0.0}
	for s in 6:
		var m := WallGenerator.generate_with(base, opts, s)
		check(_count_markers(m, "camp") == 3, "seed %d: three resting places" % s)
		check(_count_markers(m, "edelweiss") == 2 and _count_markers(m, "secret") == 1, "seed %d: loot and the secret door" % s)
		check(_hazards(m, WallMap.LOOSE) > 0, "seed %d: a danger zone of loose stones" % s)
		check(m.gaps.size() >= 1, "seed %d: a crack in the wall" % s)
		check(m.validate().filter(func(i: Dictionary) -> bool: return i.level == "error").is_empty(), "seed %d: still climbable with features" % s)
		for cell: Vector2i in m.markers:
			check(m.has_hold(cell.x, cell.y) and cell.y < m.height - 1, "seed %d: a marker sits on a hold above the foot" % s)
		var back := WallMap.parse(m.to_text())
		check(back.markers.size() == m.markers.size() and back.gaps.size() == m.gaps.size(), "seed %d: features survive the text format" % s)
	# A chance of 100 % adds one for every FEATURE_ROWS rows of the wall's height.
	var sure := WallGenerator.default_options()
	sure.features.tar = {"count": 0, "chance": 1.0}
	check(_count_markers(WallGenerator.generate_with(base, sure, 1), "tar") == 26 / WallGenerator.FEATURE_ROWS, "100 percent chance: one per six rows")
	# Everything at once, on a full wall.
	var all := WallGenerator.default_options()
	all.fill = 1.0
	for f: Dictionary in WallGenerator.FEATURES:
		all.features[f.key] = {"count": 1, "chance": 0.5}
	var wall := WallGenerator.generate_with(base, all, 9)
	check(wall.validate().filter(func(i: Dictionary) -> bool: return i.level == "error").is_empty(), "everything switched on: still climbable")
	check(WallGenerator.generate_with(base, all, 9).to_text() == wall.to_text(), "features: same seed, same wall")
