extends SceneTree
## Headless test for the torch button on the right edge: a torch is lit only
## on request, never by the dark alone. The button stands below the home
## button, as big as the window icons, and shows only while the hero has a
## torch; showing it moves nothing on the rail. A click (or V) lights a torch
## from the bag, the button stays pressed and counts what is left; a second
## click puts it out and keeps what is left of it; a burnt-down torch is not
## replaced by itself; without torches a click says why.
## Run with: godot --headless --fixed-fps 60 -s tests/torch_button.gd

const TORCH := HandTorch.ITEM

var failures := 0
var game: Node
var frames := 0
var started := false
var shots := OS.get_environment("SHOTS")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n := 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _rail_rects() -> Array:
	var out := []
	for b in game._quick_buttons.values():
		out.append(b.get_global_rect())
	out.append(game._drawer_handle.get_global_rect())
	return out


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	game._unhandled_input(e)
	await _wait(2)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	if shots != "":
		game._title.visible = false
	game.hero_name = "Torch button test"
	game.escaped = false
	game.load_level(0, false)
	game.state = game.State.PLAYING
	await _wait()
	var p: Player = game.player
	var torch: HandTorch = p.torch
	var button: Button = game._torch_button
	check(button != null, "there is a torch button")

	# No torch at all: no button.
	p.bag.erase(TORCH)
	p.bag.erase(TORCH)
	torch.left = 0.0
	await _wait()
	check(not button.visible, "without a torch the button is hidden")
	var before := _rail_rects()

	# Torches in the bag: the button shows, out, with the count; nothing moves.
	for i in 3:
		p.bag.append(TORCH)
	await _wait()
	check(button.visible, "with torches in the bag the button shows")
	check(not button.button_pressed, "it is not pressed while no torch burns")
	check(game._torch_count.text == "3", "it counts the torches in the bag (%s)" % game._torch_count.text)
	var after := _rail_rects()
	for i in before.size():
		check(before[i].is_equal_approx(after[i]), "the rail does not move when the torch button shows (%d)" % i)
	var r := button.get_global_rect()
	var w: float = game._hud.get_viewport().get_visible_rect().size.x
	check(r.size.is_equal_approx(game.QUICK_SIZE), "the torch button is as big as the window icons")
	check(absf(r.end.x - w) < 1.0, "the torch button touches the right edge")
	var home_slot: Control = game._home_button.get_parent()
	var hr := home_slot.get_global_rect()
	check(absf(r.position.x - hr.position.x) < 0.5, "it lines up with the home button")
	check(absf(r.position.y - hr.end.y - game.QUICK_GAP) < 0.5, "it stands just below the home button")
	check(button.tooltip_text.ends_with("(Taste V)") or button.tooltip_text.ends_with("(key V)"), "the tooltip names the key: " + button.tooltip_text)
	# Centred on a 1280 x 720 screen, the rail stays clear of the gold line
	# at the top (ends at 101) and the corner mark at the bottom (from 612).
	var rail_h: float = game._drawer_rail.get_combined_minimum_size().y
	check(360.0 - rail_h / 2.0 > 104.0 and 360.0 + rail_h / 2.0 < 612.0, "the rail fits between the gold line and the corner mark at 720 px (%d high)" % rail_h)
	var keys: Array = game.menus.SHORTCUTS.map(func(s): return s[0])
	check(keys.has("Fackel anzünden oder löschen"), "the key is in the list of shortcuts")

	# The dark alone lights nothing.
	game.level.pitch_dark = true
	await _wait(10)
	check(not torch.lit and p.bag.count(TORCH) == 3, "in the dark no torch lights by itself")
	await _shot("torch_out")

	# A click lights one: pressed, burning, one fewer in the bag.
	button.button_down.emit()
	button.pressed.emit()
	await _wait()
	check(torch.lit and torch.left > 0.0, "a click lights a torch")
	check(p.bag.count(TORCH) == 2, "taken from the bag (%d left)" % p.bag.count(TORCH))
	check(button.button_pressed, "the button stays pressed while it burns")
	check((button.get_node("Icon") as ItemIcon).what == "kind:torch", "and shows a burning torch")
	check(game._torch_count.text == "2", "the count drops to 2 (%s)" % game._torch_count.text)
	check(p.is_lit(), "a burning torch cannot be hooded")
	await _shot("torch_lit")

	# V puts it out again and keeps what is left of it.
	torch.left = 100.0
	await _key(KEY_V)
	check(not torch.lit and is_equal_approx(torch.left, 100.0), "V puts the torch out and keeps what is left (%.1f)" % torch.left)
	check(not button.button_pressed, "the button is up again")
	await _key(KEY_V)
	check(torch.lit and p.bag.count(TORCH) == 2, "V lights the same torch again, none taken from the bag")

	# Burnt down: it goes out and the next one waits for the player.
	torch.left = 0.05
	await _wait(10)
	check(not torch.lit and p.bag.count(TORCH) == 2, "a burnt-down torch is not replaced by itself")

	# No torch left: the click says why.
	p.bag.erase(TORCH)
	p.bag.erase(TORCH)
	torch.left = 0.0
	check(torch.toggle() != "", "without a torch a click says why")
	await _wait()
	check(not button.visible, "and the button is hidden again")

	game.level.pitch_dark = false
	if failures == 0:
		print("PASS: torch button")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
