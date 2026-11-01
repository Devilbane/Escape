extends SceneTree
## Headless test: the mouse wheel over an open window scrolls the window, never
## the game camera behind it. With no window open the wheel still zooms.
## Run with: godot --headless -s tests/ui_wheel.gd

var failures := 0
var game: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_test()
	return false


## Turns the wheel once at the middle of the screen, the way a player does.
func _wheel(button: MouseButton) -> void:
	var centre := root.get_visible_rect().size * 0.5
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.factor = 1.0
		e.position = centre
		e.global_position = centre
		root.push_input(e)
	await process_frame


func _test() -> void:
	Lang.language = "en"
	Lang._apply()
	game.hero_name = "Wheel test"
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	game.shop_stock.assign(["schwert", "wappenschild", "stachelschild", "lederstiefel", "eilstiefel", "amulett_leben", "baerenkappe", "lederwams", "wurfbuch", "schildbuch"])
	await process_frame

	# Without a window the wheel zooms.
	game._zoom_target = 0.0
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	check(game._zoom_target > 0.0, "the wheel zooms while no window is open")

	# Every window that can scroll: the wheel (far past the end of the list,
	# so the list stops taking it) must not move the camera, nor do + and -.
	for kind in ["haendler", "schmied", "barbier", "inventar", "lager", "kompendium", "charakter", "laden"]:
		game.menus.open(kind)
		await process_frame
		var before: float = game._zoom_target
		var moved := false
		for button in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			for i in 30:
				await _wheel(button)
				moved = moved or not is_equal_approx(game._zoom_target, before)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_MINUS
		key.pressed = true
		root.push_input(key)
		await process_frame
		moved = moved or not is_equal_approx(game._zoom_target, before)
		check(not moved, "the camera stays put while the '%s' window is open" % kind)
		game.menus.close()
		await process_frame

	# Closing the window gives the wheel back to the camera.
	var closed: float = game._zoom_target
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(game._zoom_target < closed, "the wheel zooms again once the window is closed")

	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: ui wheel")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
