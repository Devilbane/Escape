extends SceneTree
## The random wall's options window in the wall workshop (see WallRandomPanel, WallGenerator): the workshop opens
## without it, the button opens it over the workshop without moving anything, a fixed number of camps set there
## shows up on the rolled wall, Esc closes it keeping the values, and "Zurücksetzen" clears them.
## Run with: godot --headless -s tests/wall_random_panel.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	root.size = Vector2i(1280, 800)
	var shop: WallWorkshop = load("res://scenes/wall_workshop.tscn").instantiate()
	root.add_child(shop)
	_run.call_deferred(shop)


func _kinds(m: WallMap, kind: String) -> int:
	var n := 0
	for cell: Vector2i in m.markers:
		if m.markers[cell] == kind:
			n += 1
	return n


func _run(shop: WallWorkshop) -> void:
	for i in 4:
		await process_frame
	var panel: WallRandomPanel = shop._random_panel
	check(panel != null and not panel.visible, "the options window starts closed")
	var before := shop.canvas.get_global_rect()
	var width_before := shop._width_spin.get_global_rect()
	panel.open()
	await process_frame
	check(panel.visible, "the button's window opens")
	check(shop.canvas.get_global_rect() == before and shop._width_spin.get_global_rect() == width_before, "opening it moves nothing under it")
	var spin := panel._spins["camp"] as SpinBox
	spin.value = 3
	(panel._sliders["tar"] as HSlider).value = 1.0
	check(int(panel.options.features.camp.count) == 3 and is_equal_approx(float(panel.options.features.tar.chance), 1.0), "the rows write into the options")
	var size_before: Vector2 = (panel.get_child(1).get_child(0) as Control).size
	(panel._sliders["camp"] as HSlider).value = 0.5
	await process_frame
	check((panel.get_child(1).get_child(0) as Control).size == size_before, "changing a value does not resize the window")
	# Esc closes it and keeps the values.
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	panel._unhandled_input(esc)
	check(not panel.visible and int(panel.options.features.camp.count) == 3, "Esc closes it and the values stay")
	# Rolling uses the options on the workshop's wall.
	panel.open()
	panel.roll.emit()
	await process_frame
	check(_kinds(shop.map, "camp") >= 3, "the rolled wall has the three camps")
	check(_kinds(shop.map, "tar") >= 1, "the rolled wall has tar")
	check(shop.map.width == shop._width_spin.value, "the rolled wall keeps the workshop's size")
	panel.reset()
	check(int(panel.options.features.camp.count) == 0 and (panel._spins["camp"] as SpinBox).value == 0.0, "Zurücksetzen clears the rows")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
