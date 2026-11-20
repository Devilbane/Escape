extends SceneTree
## Checks that the village's vines follow the seasons (IvySeasons): green in summer, more and more
## leaves red and gold through autumn, dark and without grapes in winter, green again in spring;
## flowers and the all-year red leaves keep their colour; the sky command finds autumn; and the ivy's
## leaves hold snow on their upper rims (the cling of their snow material).
## Run with: godot --headless -s tests/ivy_seasons.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _house() -> Node3D:
	var house := Node3D.new()
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 5, 6)
	walls.mesh = box
	walls.position = Vector3(0, 2.5, 0)
	house.add_child(walls)
	root.add_child(house)
	return house


## The share of the green summer leaves that shows another colour now, and whether a non-green
## summer leaf changed.
func _turned(ivy: Node3D) -> Array:
	var green := 0
	var changed := 0
	var other_changed := false
	for node: Node in ivy.get_children():
		if not node.has_meta("summer"):
			continue
		var summer: PackedColorArray = node.get_meta("summer")
		var colours: PackedColorArray = node.get_meta("now")
		for i in summer.size():
			var now := colours[i]
			if IvySeasons.is_green(summer[i]):
				green += 1
				if not IvySeasons.is_green(now):
					changed += 1
			elif not now.is_equal_approx(summer[i]):
				other_changed = true
	return [float(changed) / maxf(1.0, float(green)), other_changed]


func _grapes_shown(ivy: Node3D) -> bool:
	for node: Node in ivy.get_children():
		if node.name.begins_with("Grapes") and (node as Node3D).visible:
			return true
	return false


## How many grape bunches show (x) and their mean size (y).
func _grape_sizes(ivy: Node3D) -> Vector2:
	var shown := 0
	var size := 0.0
	for node: Node in ivy.get_children():
		if node.name.begins_with("Grapes") and (node as Node3D).visible:
			for s: float in node.get_meta("sizes", PackedFloat32Array()):
				if s > 0.01:
					shown += 1
					size += s
	return Vector2(shown, size / maxf(1.0, float(shown)))


var ran := false


func _process(_delta: float) -> bool:
	if not ran:
		ran = true
		_run()
	return false


func _run() -> void:
	# The calendar.
	var autumn_first := Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS
	check(not Weather.is_autumn(autumn_first - 1) and Weather.is_autumn(autumn_first), "autumn starts AUTUMN_DAYS before winter")
	check(Weather.is_autumn(Weather.YEAR_DAYS - Weather.WINTER_DAYS - 1) and not Weather.is_autumn(Weather.YEAR_DAYS - Weather.WINTER_DAYS), "autumn ends when winter starts")
	check(Weather.autumn_day(autumn_first) == 0 and Weather.autumn_day(0) == -1, "days into autumn")
	check(IvySeasons.stage(0) == IvySeasons.SPRING, "spring at the start")
	check(IvySeasons.stage(Weather.SPRING_DAYS) == IvySeasons.SUMMER, "summer after a week of spring")
	check(IvySeasons.stage(Weather.YEAR_DAYS - 1) == IvySeasons.WINTER, "winter at the end of the year")
	check(IvySeasons.stage(Weather.YEAR_DAYS) == IvySeasons.SPRING, "spring comes back after winter")
	check(Weather.YEAR_DAYS == 28 and Weather.WINTER_DAYS == 7 and Weather.AUTUMN_DAYS == 7, "four seasons of a real week each")
	# The real calendar: Monday 2026-11-16 starts an autumn, the Monday a week later a winter, and
	# four weeks later the next autumn.
	var monday := 1794787200.0
	check(Weather.is_autumn(Seasons.today(monday)) and Weather.autumn_day(Seasons.today(monday)) == 0, "a real Monday starts autumn")
	check(Weather.is_autumn(Seasons.today(monday + 6.9 * 86400.0)), "autumn lasts the whole week")
	check(Weather.is_winter(Seasons.today(monday + 7.0 * 86400.0)), "winter the week after")
	check(Weather.is_spring(Seasons.today(monday + 14.0 * 86400.0)), "then spring")
	check(Weather.season(Seasons.today(monday + 21.0 * 86400.0)) == Weather.SUMMER, "then summer")
	check(Weather.autumn_day(Seasons.today(monday + 28.0 * 86400.0)) == 0, "and autumn again after four weeks")

	# The sky command's autumn.
	var a: Dictionary = SkyCommand.parse("weather:autumn")
	check(a.autumn and a.winter == 0, "weather:autumn is understood")
	var to := SkyCommand.autumn_from(2)
	check(Weather.is_autumn(to) and IvySeasons.stage(to) == IvySeasons.TURN_DAYS, "weather:autumn goes to turned leaves (%d)" % to)
	check(SkyCommand.autumn_from(autumn_first + 1) == autumn_first + 1, "already in autumn, the day stays")
	check(SkyCommand.autumn_from(Weather.YEAR_DAYS - 1) > Weather.YEAR_DAYS, "from winter, next year's autumn")

	# A house's vines, plus a flower (not green), as the village builds them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leaves := {"xforms": [], "colours": []}
	AgedStone.grow_ivy(AgedStone.triangles(_house()), Vector3.ZERO, 0.0, [Vector3(0, 0, 3.4)], rng, leaves, 7, false, [], 0.0, 0.0, 1.0, false, 0, 2.0)
	leaves.xforms.append(Transform3D(Basis(), Vector3(1, 1, 3.2)))
	leaves.colours.append(Color(0.9, 0.85, 0.95))
	check(not (leaves.get("grapes", []) as Array).is_empty(), "the vines carry grapes")
	var ivy := AgedStone.ivy_node(leaves)
	root.add_child(ivy)

	IvySeasons.apply(ivy, 2)
	var t := _turned(ivy)
	check(t[0] == 0.0 and not _grapes_shown(ivy), "spring: green leaves and no grapes yet")
	IvySeasons.apply(ivy, Weather.SPRING_DAYS + 2)
	t = _turned(ivy)
	check(t[0] == 0.0 and _grapes_shown(ivy), "summer: green leaves and grapes")
	var summer_grapes := _grape_sizes(ivy)
	var last := 0.0
	for d in IvySeasons.TURN_DAYS:
		IvySeasons.apply(ivy, autumn_first + d)
		t = _turned(ivy)
		check(t[0] > last, "autumn day %d turns more leaves (%.2f)" % [d, t[0]])
		check(not t[1], "autumn leaves flowers and red leaves as they are")
		check(_grapes_shown(ivy), "the grapes hang in autumn")
		last = t[0]
	var autumn_grapes := _grape_sizes(ivy)
	check(autumn_grapes.x > summer_grapes.x and autumn_grapes.y > summer_grapes.y, "autumn's grapes are more and bigger (%s, summer %s)" % [autumn_grapes, summer_grapes])
	var w := IvySeasons.tree_turn(IvySeasons.stage(autumn_first + IvySeasons.TURN_DAYS))
	check(w.x > 0.9 and IvySeasons.tree_turn(IvySeasons.SUMMER) == Vector2.ZERO and IvySeasons.tree_turn(IvySeasons.SPRING) == Vector2.ZERO, "the trees turn in autumn only")
	check(last > 0.8, "by the end of autumn nearly all leaves have turned (%.2f)" % last)
	IvySeasons.apply(ivy, Weather.YEAR_DAYS - Weather.WINTER_DAYS)
	t = _turned(ivy)
	check(not _grapes_shown(ivy), "no grapes in winter")
	check(not t[1], "winter leaves flowers and red leaves as they are")
	var dark := true
	for node: Node in ivy.get_children():
		if node.has_meta("summer"):
			var summer: PackedColorArray = node.get_meta("summer")
			for i in summer.size():
				var c: Color = (node.get_meta("now") as PackedColorArray)[i]
				if IvySeasons.is_green(summer[i]) and c.get_luminance() > 0.4:
					dark = false
	check(dark, "winter leaves are dark")
	IvySeasons.apply(ivy, Weather.YEAR_DAYS + 1)
	t = _turned(ivy)
	check(t[0] == 0.0 and not _grapes_shown(ivy), "spring: green again, no grapes yet")
	IvySeasons.apply(ivy, Weather.YEAR_DAYS + Weather.SPRING_DAYS)
	check(_grapes_shown(ivy), "summer: grapes back")

	# The snow on the ivy's leaves clings to their rims.
	var world := Node3D.new()
	root.add_child(world)
	var cover := SnowCover.new(world)
	var leaf_card := ivy.get_child(0) as GeometryInstance3D
	var over := cover._cutout_for(leaf_card)
	check(over != null and float(over.get_shader_parameter("cling")) > 0.0, "the ivy's snow clings to the leaves' rims")

	print("PASS: ivy seasons" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
