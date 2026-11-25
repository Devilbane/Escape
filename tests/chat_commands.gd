extends SceneTree
## Headless test for the compendium's chat commands page (see ChatCommands,
## Menus._build_chat_commands): every command that is switched on has an
## entry with an English text, the page builds, and it keeps the window's size.
## Run with: godot --headless --fixed-fps 60 -s tests/chat_commands.gd

var failures := 0
var game: Node
var frames := 0
var started := false


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


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	for i in 10:
		await process_frame
	var all := ChatCommands.entries()
	check(all.size() >= 5, "godmode, teleport, weather, the tour and the seasons are listed")
	var names := all.map(func(e): return e.name)
	check("Gottmodus" in names and "Teleport" in names and "Wetter und Zeit" in names and "Himmelstour" in names, "the entries: %s" % str(names))
	for e in all:
		check(Lang.EN.has(e.name) and Lang.EN.has(e.text), "%s has English texts" % e.name)
		check(not e.examples.is_empty() and e.syntax != "", "%s has syntax and examples" % e.name)
	# Every example is a command that the game takes as one.
	for e in all:
		for ex in e.examples:
			var line: String = ex
			check(Godmode.is_command(line) or HeroUnstick.is_command(line) or Teleport.parse(line) != null or SkyCommand.parse(line) != null or SkyCommand.parse_season(line) != null or CameraCommand.parse(line) != null, "example '%s' is a command" % line)
	check(CameraCommand.parse("camera:low").pitch == CameraCommand.LOW_PITCH, "camera:low parses")
	check(CameraCommand.parse("camera:500").pitch == CameraCommand.PITCH_MAX, "the tilt is clamped")
	check(CameraCommand.parse("camera:off").has("off") and CameraCommand.parse("hallo") == null, "off and no command")
	check(CameraCommand.distance_after(27.0, 100.0) == CameraCommand.FAR_MIN and CameraCommand.distance_after(27.0, -100.0) == CameraCommand.FAR_MAX, "the distance is clamped")
	game._camera_command({"pitch": 10.0})
	check(game.free_camera and game.free_pitch == 10.0, "camera:10 turns the free camera on")
	game.zoom_by(-15.0)
	check(game.free_distance > game.CAMERA_DISTANCE, "the free camera zooms out beyond the normal view")
	game._camera_command({"off": true})
	check(not game.free_camera, "camera:off ends it")
	check(Lang.EN.has("Befehle") and Lang.EN.has("Beispiele"), "page texts have English")

	# The page.
	var menus = game.menus
	menus.compendium_page = "wissen"
	menus.open("kompendium")
	await process_frame
	menus.compendium_page = "befehle"
	menus._rebuild()
	await process_frame
	check(menus.is_open(), "the page opens")
	menus.close()

	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: chat_commands")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
