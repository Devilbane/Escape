extends SceneTree
## Headless test for the shop signs: a name that fits on the board is written
## under a small picture, a name that is too wide is left off and the picture
## stands alone, bigger, and every picture a sign can show can be built.
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
	check(short.find_children("*", "Label3D", true, false).size() == 1, "one label for a short name")
	var long := Effects.shop_sign("Steinmetz-Werkstatt am Marktplatz", font, "stone")
	check(not long.get_meta("text_shown"), "a long name is left off")
	check(long.find_children("*", "Label3D", true, false).is_empty(), "no label for a long name")
	var big := long.get_node("SignIcon") as Node3D
	check(big.scale.x > 1.0, "the picture alone is shown larger")
	check(short.get_node("SignIcon").scale.x < 1.0, "the picture beside writing is small")
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
