extends SceneTree
## The climbing wall workshop (see WallWorkshop, WallCanvas): it opens with the sample wall, paints holds along a
## stroke with links, switches an arrow, opens a gap and a surface, undoes, saves a wall and loads it again,
## shows the 3D wall and the climbing test, and the weather picker changes the climber's weather.
## With SHOTS=<folder> it saves pictures of the three pages.
## Run with: SHOTS=<folder> xvfb-run -a godot --rendering-driver opengl3 -s tests/wall_workshop.gd

var failures := 0
var shots := OS.get_environment("SHOTS")
var shop: WallWorkshop


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Lang.language = "en"
	root.size = Vector2i(1280, 900)
	shop = load("res://scenes/wall_workshop.tscn").instantiate()
	root.add_child(shop)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func _click(cell: Vector2i, button := MOUSE_BUTTON_LEFT) -> void:
	var at := shop.canvas.rect_of(cell.x, cell.y).get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		shop.canvas._gui_input(ev)


func _run() -> void:
	await _frames(6)
	shop.size = Vector2(root.size)
	await _frames(4)
	var c := shop.canvas
	check(shop.map.width >= 24 and c.map == shop.map, "the workshop opens with the sample wall")
	check(c.square_px() > 10.0, "the squares are big enough to paint: %.0f px" % c.square_px())
	await _shot("00_template")
	# A fresh wall to paint on.
	shop._new_wall()
	check(shop.map.markers.is_empty() and not shop.map.has_hold(3, 3), "a new wall is empty")
	# Holds along a stroke link up.
	c.tool = WallCanvas.Tool.HOLD
	c.malus = 3
	for cell in [Vector2i(4, 23), Vector2i(4, 22), Vector2i(4, 21)]:
		_click(cell)
	check(shop.map.has_hold(4, 22) and shop.map.malus_at(4, 22) == 3, "a click paints a hold with the malus")
	check(shop.map.dirs_at(4, 22) & WallMap.UP != 0 and shop.map.dirs_at(4, 22) & WallMap.DOWN != 0, "neighbouring holds link both ways")
	check(shop.map.dirs_at(4, 23) & WallMap.UP != 0 and shop.map.dirs_at(4, 21) & WallMap.DOWN != 0, "the ends point at the middle")
	# An arrow switched off.
	c.tool = WallCanvas.Tool.DIRS
	var rect := c.rect_of(4, 22)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = rect.get_center() + Vector2(0, -rect.size.y * 0.4)
		c._gui_input(ev)
	check(shop.map.dirs_at(4, 22) & WallMap.UP == 0, "a click near the top edge switches the up arrow off")
	# A gap by dragging, a surface and a marker.
	c.tool = WallCanvas.Tool.GAP
	var a := c.rect_of(8, 10).get_center()
	var b := c.rect_of(10, 11).get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = a
	c._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = b
	c._gui_input(drag)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = b
	c._gui_input(release)
	check(shop.map.gaps.size() == 1 and shop.map.gap_area(0) == 6.0, "dragging a rectangle makes a 6 m² gap")
	c.tool = WallCanvas.Tool.SURFACE
	c.surface = WallMap.LOOSE
	_click(Vector2i(4, 21))
	check(shop.map.hazard_at(4, 21) == WallMap.LOOSE, "the surface tool paints loose stones")
	_click(Vector2i(4, 21), MOUSE_BUTTON_RIGHT)
	check(shop.map.hazard_at(4, 21) == WallMap.NONE, "right click clears it")
	c.tool = WallCanvas.Tool.MARKER
	c.marker = "nest"
	_click(Vector2i(4, 21))
	check(shop.map.marker_at(4, 21) == "nest", "the goal tool places a marker")
	# Undo.
	var before := shop.map.markers.size()
	shop._undo_step()
	check(shop.map.markers.size() < before or before == 0, "undo takes the last stroke back")
	# Save and load again.
	shop.map.wall_name = "Workshop test wall"
	shop._save()
	var path := WallWorkshop.SAVE_DIR + WallWorkshop.slug("Workshop test wall") + ".txt"
	check(FileAccess.file_exists(path), "the wall is saved in your folder: %s" % path)
	var loaded := WallMap.load_file(path)
	check(loaded != null and loaded.to_text() == shop.map.to_text(), "it loads again as it was")
	check(shop._file_paths.has(path), "the file list shows it")
	DirAccess.remove_absolute(path)
	# The sample wall again, then the 3D pages.
	shop._files.select(shop._file_paths.find(WallWorkshop.SHIPPED_DIR + "sample_three_paths.txt"))
	shop._load_selected()
	await _frames(2)
	check(shop.map.gaps.size() >= 3, "the sample wall loads")
	shop._show_page(1)
	await _frames(3)
	check(shop.stage.visible and not shop.canvas.visible and shop.stage.climber != null, "the wall view shows the 3D wall")
	await _shot("01_wall_view")
	shop._show_page(2)
	await _frames(3)
	check(shop.stage.interactive and shop.stage.follow, "the climbing test lets the keys climb")
	await _shot("02_climbing_test")
	shop.stage.set_weather(WallWeather.SNOW)
	await _frames(3)
	await _shot("03_snow")
	check(shop.stage.weather == WallWeather.SNOW, "the weather changes on the wall")
	shop._show_page(0)
	await _frames(3)
	await _shot("04_template_sample")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
