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
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
