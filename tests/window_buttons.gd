extends SceneTree
## Headless test for how buttons look and act (see game._make_button and the
## keyboard part of Menus): a visible hover, pressed, disabled and focus state;
## window buttons act when the pointer is let go (so a click can be called
## off), the pull-out menu's game actions on press; the arrow keys put a
## focus on a window's buttons that a rebuild keeps and a click takes away;
## and the values a merchant's window shows for a decision are 16 px or more.
## Run with: godot --headless -s tests/window_buttons.gd

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


func _focus_owner() -> Control:
	return root.gui_get_focus_owner()


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _test() -> void:
	Lang.language = "en"
	Lang._apply()
	game.hero_name = "Window buttons test"
	var menus: Menus = game.menus

	# --- States: hover, pressed, disabled and focus each look different.
	var hits := [0]
	var b: Button = game._make_button("Test", func(): hits[0] += 1)
	game._hud.add_child(b)
	var normal: StyleBoxFlat = b.get_theme_stylebox("normal")
	var hover: StyleBoxFlat = b.get_theme_stylebox("hover")
	var pressed: StyleBoxFlat = b.get_theme_stylebox("pressed")
	var disabled: StyleBoxFlat = b.get_theme_stylebox("disabled")
	var focus: StyleBoxFlat = b.get_theme_stylebox("focus")
	check(hover != normal and hover.border_color != normal.border_color, "hover brightens the border")
	check(hover.bg_color != normal.bg_color, "hover lifts the background")
	check(pressed.bg_color != normal.bg_color and pressed.bg_color != hover.bg_color, "pressed looks different from normal and hover")
	check(disabled.bg_color.a < normal.bg_color.a and disabled.border_color.a < normal.border_color.a, "disabled is dimmed")
	check(not focus.draw_center and focus.border_color != hover.border_color, "focus is an outline, unlike hover")
	check(b.get_theme_color("font_hover_color") != b.get_theme_color("font_color"), "the text brightens on hover")
	check(b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "the pointer turns into a hand")
	check(b.focus_mode == Control.FOCUS_NONE, "no focus outside a window")

	# --- A window button acts on release, so a click can be called off.
	b.button_down.emit()
	check(hits[0] == 0, "pressing the pointer down alone does nothing yet")
	b.pressed.emit()
	check(hits[0] == 1, "letting go over the button acts")
	b.queue_free()

	# The drawer's game actions still act at once, on press.
	var opened := [false]
	var drawer_button: Button = game._make_button("Now", func(): opened[0] = true, true)
	drawer_button.button_down.emit()
	check(opened[0], "a drawer action acts on press")
	drawer_button.free()

	# --- Keyboard focus in a window.
	menus.open("kompendium")
	await process_frame
	check(menus._focus_index() == -1, "a window opens without a focused button")
	var buttons: Array = menus._focusables()
	check(buttons.size() >= 2, "the compendium has buttons")
	check(buttons.all(func(x): return x.focus_mode == Control.FOCUS_NONE), "no focus before a key is used")

	menus._input(_key("ui_down"))
	check(menus._focus_index() == 0, "the first arrow key focuses the first button")
	check(_focus_owner() == menus._focusables()[0], "that button has the focus")
	check(menus._focusables().all(func(x): return x.focus_mode == Control.FOCUS_ALL), "all buttons take the focus now")

	# Move on to the second button, then rebuild the window: the focus stays.
	var second: Button = menus._focusables()[1]
	second.grab_focus()
	menus._rebuild()
	await process_frame
	check(menus._focus_index() == 1, "a rebuild keeps the focus on the same button")

	# A click with the mouse takes the focus away again.
	menus._input(_click())
	check(menus._focus_index() == -1 and _focus_owner() == null, "a click hides the focus")
	check(menus._focusables().all(func(x): return x.focus_mode == Control.FOCUS_NONE), "and the buttons stop taking it")
	menus._rebuild()
	await process_frame
	check(menus._focus_index() == -1, "a rebuild after a click shows no focus")

	# Closing and opening again starts without focus.
	menus._input(_key("ui_down"))
	menus.close()
	menus.open("kompendium")
	await process_frame
	check(menus._focus_index() == -1, "a new window starts without focus")
	menus.close()

	# --- Values in the merchant's window are big enough to read.
	game.load_level(game._outdoor_index(), false)
	game.coins = 15
	var p: Player = game.player
	p.bag.clear()
	p.equipped.clear()
	p.bag.append("rundschild")
	p.equip("rundschild")
	game.shop_stock.assign(["schwert", "wappenschild", "lederwams"])
	menus.open("haendler")
	for key in menus.trade._entries:
		if menus.trade._entries[key].get("id", "") == "wappenschild":
			menus.trade.pick(key)
	await process_frame
	var small := []
	for l in menus._box.find_children("*", "Label", true, false):
		var c: Color = l.get_theme_color("font_color")
		# Prices, better and worse: the colours of a decision.
		var decides: bool = c in [game.GOLD, TradeWindow.GREEN, TradeWindow.RED]
		if decides and l.is_visible_in_tree() and l.get_theme_font_size("font_size") < 16:
			small.append("%s (%d)" % [l.text, l.get_theme_font_size("font_size")])
	check(small.is_empty(), "no price or comparison under 16 px: %s" % [small])

	# A disabled buy button is dimmed, not drawn like a live one.
	var dimmed := false
	for button in menus._box.find_children("*", "Button", true, false):
		if button.disabled:
			dimmed = button.get_theme_stylebox("disabled") != button.get_theme_stylebox("normal")
	check(dimmed, "an unaffordable buy button looks disabled")
	menus.close()

	game.delete_save(game.save_path(game.hero_name))
	if failures == 0:
		print("PASS: window buttons")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
