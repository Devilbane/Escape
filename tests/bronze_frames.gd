extends SceneTree
## Headless test for the forged-bronze frames (BronzeStyle, UiKit): windows,
## buttons and the merchant's rows wear the bronze frame; the frame keeps the
## layout (a window's margin, a button's size) of the flat frame before it; a
## hover, a pick or a fade still tint it; its metal is made once and reused;
## and it draws without errors at every size, from a hairline row to a window.
## Run with: godot --headless -s tests/bronze_frames.gd
## With SHOTS=<folder> and a display it also saves a picture of the inventory.

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
	elif frames == 10:
		_finish()
	return false


func _test() -> void:
	Lang.language = "en"
	Lang._apply()
	game.hero_name = "Bronze frames test"
	var menus: Menus = game.menus

	# --- The window frame: bronze, thick, riveted, the same inner margin.
	var panel = menus._panel.get_theme_stylebox("panel")
	check(panel is BronzeStyle, "the window frame is bronze")
	check(panel.border_width_top >= BronzeStyle.RIVET_FROM, "the window's rim is thick enough for rivets")
	check(panel.get_margin(SIDE_LEFT) == 26.0 and panel.get_margin(SIDE_TOP) == 26.0, "the window keeps its 26 px margin")
	check(panel.border_color.a == 1.0, "the window's rim is solid metal")

	# --- Buttons: bronze in every state, the states still tell apart.
	var b: Button = game._make_button("Test", func(): pass)
	game._hud.add_child(b)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		check(b.get_theme_stylebox(state) is BronzeStyle, "the %s button is bronze" % state)
	check(b.get_combined_minimum_size() == Vector2(118, 64), "a button keeps its size: %s" % b.get_combined_minimum_size())
	var copy: BronzeStyle = b.get_theme_stylebox("normal").duplicate()
	check(copy is BronzeStyle and copy.border_width_left == UiKit.BUTTON_RIM, "a copied frame stays bronze with its rim")
	copy.border_color = Color.RED
	check(b.get_theme_stylebox("normal").border_color != Color.RED, "tinting a copy leaves the button alone")
	b.queue_free()

	# --- A side's margin follows its rim until it is set, as in StyleBoxFlat.
	var box := BronzeStyle.new()
	box.set_border_width_all(4)
	check(box.get_margin(SIDE_LEFT) == 4.0, "an unset margin follows the rim")
	box.set_content_margin_all(12)
	box.set_border_width_all(2)
	check(box.get_margin(SIDE_LEFT) == 12.0, "a set margin stays")

	# --- The metal is made once per size and reused.
	var rim := BronzeStyle._rim(3, 6)
	check(rim == BronzeStyle._rim(3, 6), "a rim's texture is made once")
	var img := rim.get_image()
	var mid := img.get_size() / 2
	check(img.get_pixel(mid.x, 1).a > 0.9, "the rim is drawn at the edge")
	check(img.get_pixel(mid.x, mid.y).a == 0.0, "the rim leaves the middle free")
	var lit := img.get_pixel(mid.x, 1)
	check(lit.r > 0.4, "the rim is lit metal, not a dark line: %s" % lit)

	# --- Every window draws: open each kind the fixed-size test knows.
	for kind in ["inventar", "kompendium", "charakter"]:
		menus.open(kind)
		menus._rebuild()
		check(menus._panel.get_theme_stylebox("panel") is BronzeStyle, "%s has the bronze frame" % kind)
		menus.close()
	menus.open("inventar")

	# --- Drawing at every size: a hairline, a tiny box, a window.
	var canvas := Control.new()
	game._hud.add_child(canvas)
	var sizes := [Vector2(1, 1), Vector2(6, 6), Vector2(40, 12), Vector2(300, 60), Vector2(860, 600)]
	for width in [0, 1, 2, 3, 7]:
		for s in sizes:
			var style := BronzeStyle.new()
			style.set_border_width_all(width)
			style.set_corner_radius_all(8)
			style.shadow_size = 6
			style.draw(canvas.get_canvas_item(), Rect2(Vector2.ZERO, s))
	check(true, "frames of every size draw")


func _finish() -> void:
	var shots := OS.get_environment("SHOTS")
	if shots != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		root.get_texture().get_image().save_png(shots.path_join("bronze_inventory.png"))
	game.menus.close()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: bronze frames")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
