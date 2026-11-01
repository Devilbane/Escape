extends SceneTree
## Headless test for the UI button click: pressing any button, including one
## made after the game started, plays the soft "ui_click" sound quietly on the
## Effects bus (so the effects volume slider controls it), and only once.
## Run with: godot --headless --fixed-fps 60 -s tests/button_click.gd

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


func _clicks() -> Array:
	var found := []
	for p in root.get_children():
		if p is AudioStreamPlayer and p.stream and p.stream.resource_path.ends_with("ui_click.wav"):
			found.append(p)
	return found


func _run() -> void:
	check(ResourceLoader.exists("res://assets/sounds/ui_click.wav"), "the click sound is imported")

	# A button that was already there when the game started.
	var existing: Array = root.find_children("*", "BaseButton", true, false)
	check(existing.size() > 0, "the game has buttons")
	if existing.size() > 0:
		var before := _clicks().size()
		existing[0].button_down.emit()
		var after := _clicks()
		check(after.size() == before + 1, "pressing an existing button plays one click")
		if after.size() > before:
			var p: AudioStreamPlayer = after[-1]
			check(p.bus == Sfx.BUS, "the click plays on the Effects bus")
			check(AudioServer.get_bus_index(p.bus) >= 0, "the Effects bus exists")
			check(p.volume_db <= -10.0, "the click is quiet")

	# A button made later (say, in a merchant window) picks it up by itself.
	var late := Button.new()
	game.add_child(late)
	await process_frame
	var before2 := _clicks().size()
	late.button_down.emit()
	check(_clicks().size() == before2 + 1, "a button added later also clicks")

	# Taking it out and putting it back must not double the click.
	game.remove_child(late)
	game.add_child(late)
	var before3 := _clicks().size()
	late.button_down.emit()
	check(_clicks().size() == before3 + 1, "a re-added button clicks only once")

	# A button that closes itself on press still gets its click.
	# Its own handler is connected first, so it runs before the click.
	var closer := Button.new()
	closer.button_down.connect(func(): game.remove_child(closer))
	game.add_child(closer)
	var before4 := _clicks().size()
	closer.button_down.emit()
	check(_clicks().size() == before4 + 1, "a button that removes itself still clicks")
	closer.free()

	if failures == 0:
		print("PASS: button click")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
