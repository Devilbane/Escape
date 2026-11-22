extends SceneTree
## Headless test for the shop signs (HangingShield): a big shield on two chains with the shop's
## mark on both faces, a name that fits written on a board under it (on both sides) and one too
## wide left off, every mark buildable, and every sign high enough to walk under.
## Run with: godot --headless -s tests/shop_signs.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var font: Font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	check(Effects.sign_text_fits("Bar", font), "a short name fits")
	check(not Effects.sign_text_fits("Steinmetz-Werkstatt am Marktplatz", font), "a long name does not fit")
	var short := Effects.shop_sign("Bar", font, "coin")
	check(short.get_meta("text_shown"), "a short name is written")
	check(short.find_children("*", "Label3D", true, false).size() == 2, "a short name is written on both sides")
	var long := Effects.shop_sign("Steinmetz-Werkstatt am Marktplatz", font, "stone")
	check(not long.get_meta("text_shown"), "a long name is left off")
	check(long.find_children("*", "Label3D", true, false).is_empty(), "no label for a long name")
	for sign: Node3D in [short, long, HangingShield.on_wall("tavern", 1.1, true), HangingShield.on_wall("shop", 1.1, false)]:
		var shield := sign.get_node("Shield") as Node3D
		check(shield != null, "%s has a shield" % sign.name)
		var marks := shield.find_children("Mark*", "", false, false)
		check(marks.size() == 2, "the mark is on both faces (%d)" % marks.size())
		check((marks[0] as Node3D).scale.x > 2.0, "the mark is painted large")
		var chains := 0
		for mi: MeshInstance3D in sign.find_children("*", "MeshInstance3D", false, false):
			if mi.mesh is TorusMesh and mi.position.y > shield.position.y:
				chains += 1
		check(chains >= 8, "the shield hangs on chains (%d links)" % chains)
	check(HangingShield.post_low_point(true) >= HangingShield.CLEAR - 0.05, "a post sign with its name is high enough to walk under (%.2f)" % HangingShield.post_low_point(true))
	check(HangingShield.post_low_point(false) >= HangingShield.CLEAR - 0.05, "a post sign is high enough to walk under")
	var on_wall_low := VillageHouse.PLINTH + VillageHalls.SIGN_HIGH - HangingShield.CHAIN - HangingShield.TALL
	check(on_wall_low >= HangingShield.CLEAR - 0.05, "a hall's sign is high enough to walk under (%.2f)" % on_wall_low)
	for kind: String in HangingShield.LOOKS:
		var pic := HangingShield.emblem(HangingShield.LOOKS[kind].mark)
		check(pic.get_child_count() > 0, "the mark of %s has parts" % kind)
		pic.free()
	for kind: String in VillageHalls.KINDS.values():
		check(HangingShield.LOOKS.has(kind), "the %s has its own shield" % kind)
	check(Geometry2D.triangulate_polygon(HangingShield.outline()).size() > 0, "the shield's outline can be filled")
	for kind in Effects.SIGN_ICONS:
		var pic := Effects.sign_icon(kind)
		check(pic.get_child_count() > 0, "picture %s has parts" % kind)
		pic.free()
	check(Effects.sign_icon("nonsense").get_child_count() > 0, "an unknown picture falls back to a coin")
	check(Effects.shop_sign("x", font, "nonsense").get_meta("icon") == "coin", "unknown icon recorded as coin")
	# Every sign of the game is built with a known picture.
	for bench: Dictionary in CraftingSquare.BENCHES.values():
		check(bench.icon in Effects.SIGN_ICONS, "bench %s has a picture" % bench.sign)
	if failures == 0:
		print("PASS: shop_signs")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
