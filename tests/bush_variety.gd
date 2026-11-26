extends SceneTree
## Headless test: the bushes come in many kinds (BushKinds), so a row of them never repeats itself:
## - the kinds differ in shape, size, leaf shape, colour and number of branches;
## - a row of bushes uses most kinds and no two neighbours share one;
## - every leaf shape has a texture with a leaf and a transparent rim;
## - the evergreens' colours are not green to the seasons (they keep them), the other kinds' leaves are;
## - an evergreen grows into the evergreen dictionary, never into the one that sheds;
## - berries and blooms are drawn only near the camera, the leaves further;
## - a bush costs about what the old one did (leaf cards), twigs are a few thin strips;
## - in autumn the green leaves turn and the evergreens, berries and red leaves stay as they were.
## Run with: godot --headless -s tests/bush_variety.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var kinds: Array = BushKinds.KINDS
	check(kinds.size() >= 8, "at least eight bush kinds (%d)" % kinds.size())
	var shapes := {}
	var profiles := {}
	var widths := []
	var heights := []
	var lows := []
	var twigs := []
	for k: Dictionary in kinds:
		shapes[k.leaf] = true
		profiles[k.profile] = true
		widths.append((k.radius as Vector2).y)
		heights.append((k.tall as Vector2).y * (k.radius as Vector2).y)
		lows.append((k.tall as Vector2).x * (k.radius as Vector2).x)
		twigs.append(int(k.twigs))
		check(float(k.weight) > 0.0 and not (k.palettes as Array).is_empty(), "kind %s has a weight and colours" % k.name)
	check(shapes.size() >= 4, "at least four leaf shapes (%d)" % shapes.size())
	check(profiles.size() >= 4, "at least four outlines (%d)" % profiles.size())
	check((widths.max() as float) / (widths.min() as float) > 2.0, "wide and narrow bushes")
	check((heights.max() as float) / (lows.min() as float) > 5.0, "tall and low bushes")
	check((twigs.max() as int) - (twigs.min() as int) >= 6, "bushes with few and with many branches")
	for shape in [BushKinds.LOBED, BushKinds.OVAL, BushKinds.LANCE, BushKinds.FEATHER, BushKinds.NEEDLE, BushKinds.BERRY, BushKinds.BLOOM]:
		var img := BushKinds.texture(shape).get_image()
		var solid := 0
		var clear := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
				else:
					clear += 1
		check(solid > 200 and clear > 200, "the %s texture has a leaf and a see-through rim" % shape)
		check(BushKinds.material(shape).get_meta("snow_cling", 0.0) > 0.0, "%s leaves hold snow" % shape)

	# A row planted the way the undergrowth is.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leaves := {"xforms": [], "colours": []}
	var shed := {"xforms": [], "colours": []}
	var recent := []
	var used := {}
	var last := -1
	var repeats := 0
	var cards := 0
	for i in 200:
		var before := recent.duplicate()
		BushKinds.grow(Vector3(i * 2.0, 0, 0), rng, shed, leaves, recent)
		var now: int = recent.back()
		used[now] = true
		if before.has(now):
			repeats += 1
	check(repeats == 0, "no bush shares its kind with one of the last %d (%d did)" % [BushKinds.RECENT, repeats])
	check(used.size() >= kinds.size() - 1, "a row of 200 bushes uses nearly every kind (%d of %d)" % [used.size(), kinds.size()])
	for d: Dictionary in [leaves, shed]:
		cards += (d.xforms as Array).size()
		for shape: Dictionary in (d.get("shapes", {}) as Dictionary).values():
			cards += (shape.xforms as Array).size()
	var per_bush := float(cards) / 200.0
	check(per_bush < 260.0, "a bush costs about what the old one did (%.0f cards on average)" % per_bush)
	var ever := _count(leaves)
	var ever_evergreen := 0
	for c: Color in _colours(leaves, BushKinds.NEEDLE):
		ever_evergreen += 1
		check(not IvySeasons.is_green(c), "an evergreen's colour is not green to the seasons")
	check(ever_evergreen > 0, "evergreens grow into the dictionary that keeps its leaves")
	check(_colours(shed, BushKinds.NEEDLE).is_empty(), "no evergreen in the dictionary that sheds")
	check(ever > 0 and _count(shed) > 0, "bushes of both dictionaries")
	for i in kinds.size():
		var one := {"xforms": [], "colours": []}
		BushKinds.grow_kind(i, Vector3.ZERO, rng, one)
		if kinds[i].get("evergreen", false):
			continue
		for c: Color in _colours(one, kinds[i].leaf):
			if kinds[i].name != "red":
				check(IvySeasons.is_green(c), "the leaves of the %s bush are green, so they turn in autumn" % kinds[i].name)
				break
	var twiggy := {"xforms": [], "colours": []}
	BushKinds.grow_kind(3, Vector3.ZERO, rng, twiggy)
	check((twiggy.get("stems", []) as Array).size() >= 10 and (twiggy.stems as Array).size() <= 40, "a twiggy bush shows its branches (%d strips)" % (twiggy.get("stems", []) as Array).size())

	# The drawn nodes: one MultiMesh per leaf shape and tile, details only near.
	var all := {"xforms": [], "colours": []}
	for i in 120:
		BushKinds.grow(Vector3(i * 2.0, 0, 0), rng, all, all, recent)
	var node := AgedStone.ivy_node(all)
	var near_only := 0
	var far := 0
	var seen := {}
	for child in node.get_children():
		if not child is MultiMeshInstance3D or not child.name.begins_with("Leaves_"):
			continue
		var name: String = child.name
		var shape := name.get_slice("_", 3) if name.count("_") >= 3 else ""
		seen[shape] = true
		check(child.has_meta("summer"), "%s remembers its summer colours" % name)
		if shape == BushKinds.BERRY or shape == BushKinds.BLOOM:
			near_only += 1
			check((child as GeometryInstance3D).visibility_range_end < AgedStone.LEAF_RANGE, "%s is drawn only near" % name)
		else:
			far += 1
	check(seen.size() >= 5, "the row draws several leaf shapes (%d)" % seen.size())
	check(near_only > 0 and far > 0, "details and leaves are drawn in their own batches")
	# Autumn: green leaves turn, evergreens, berries and blooms stay.
	var autumn := Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + IvySeasons.TURN_DAYS - 1
	IvySeasons.apply(node, autumn)
	var turned := 0
	var kept := 0
	for child in node.get_children():
		var mm := child as MultiMeshInstance3D
		if mm == null or not mm.has_meta("summer"):
			continue
		var summer: PackedColorArray = mm.get_meta("summer")
		for i in summer.size():
			var now: Color = (mm.get_meta("now") as PackedColorArray)[i]
			if IvySeasons.is_green(summer[i]):
				if _differs(now, summer[i]):
					turned += 1
			elif _differs(now, summer[i]):
				kept = -1000000
			else:
				kept += 1
	check(turned > 100, "the green leaves turn in autumn (%d)" % turned)
	check(kept > 100, "evergreens, berries, blooms and red leaves keep their colour (%d)" % kept)
	node.free()
	print("PASS" if failures == 0 else "FAILED: %d" % failures, " (bush variety)")
	quit()


func _count(d: Dictionary) -> int:
	var n := (d.xforms as Array).size()
	for shape: Dictionary in (d.get("shapes", {}) as Dictionary).values():
		n += (shape.xforms as Array).size()
	return n


## The summer colours of one leaf shape in `d`.
func _colours(d: Dictionary, shape: String) -> Array:
	return ((d.get("shapes", {}) as Dictionary).get(shape, {"colours": []}) as Dictionary).colours


## Whether a colour changed (an instance colour is stored with less precision than the summer one).
func _differs(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03
