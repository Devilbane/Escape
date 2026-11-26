extends SceneTree
## Headless test for the performance plate (see PerfOverlay): F1 shows and
## hides it, it fills in frames per second, CPU and GPU time and their graphs,
## keeps one size whatever the numbers say, sits in the top right corner
## without covering the save notice or the pull-out menu's rail, and shows the
## ping to a server on this computer while playing together.
## Run with: godot --headless --fixed-fps 60 -s tests/perf_overlay.gd
## With SHOTS=<folder> and a display it saves a picture of the HUD with the plate.

const PORT := 24597

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
	Storage.use(Storage.Memory.new())
	Lang.language = "en"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _press_f1() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F1
	key.keycode = KEY_F1
	key.pressed = true
	root.push_input(key)
	var up := key.duplicate()
	up.pressed = false
	root.push_input(up)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game._title.visible = false
	# The game read the language saved by an earlier test in the same shard (floor_packs saves
	# German): this test reads English labels.
	Lang.language = "en"
	Lang._apply()
	game.state = game.State.PLAYING
	await _wait(10)
	var overlay: PerfOverlay = game.perf_overlay
	check(overlay != null, "the game has a performance plate")
	if overlay == null:
		_end()
		return
	check(not overlay.visible, "the plate starts hidden")

	_press_f1()
	await _wait(2)
	check(overlay.visible, "F1 shows the plate")
	await _wait(40)
	check(overlay.fps > 0.0, "it measures frames per second (%s)" % overlay.fps)
	check(overlay.cpu_ms > 0.0, "it measures the CPU time per frame (%s)" % overlay.cpu_ms)
	check(overlay.cpu_graph.values.size() >= 3, "the CPU graph fills in")
	check(overlay.cpu_avg_ms > 0.0, "it averages the CPU time over the whole session (%s)" % overlay.cpu_avg_ms)
	var frames_before: int = overlay._total_frames
	_press_f1()
	await _wait(5)
	_press_f1()
	await _wait(2)
	check(overlay._total_frames > frames_before, "hiding the plate does not restart the session average")
	check(overlay.gpu_graph.values.size() == overlay.cpu_graph.values.size(), "the GPU graph fills in alongside")
	check(overlay.fps_label.text.ends_with("FPS"), "the frame rate is labelled (%s)" % overlay.fps_label.text)
	check(overlay.cpu_label.text.begins_with("CPU") and overlay.gpu_label.text.begins_with("GPU"), "the graphs say which is which")
	check(overlay.ping_label.text == "Ping: offline", "without a server the ping says offline (%s)" % overlay.ping_label.text)

	# The plate never takes the pointer and keeps its size, whatever it shows.
	for node in [overlay.plate] + overlay.plate.find_children("*", "Control", true, false):
		check((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s lets clicks through" % node)
	var rect := overlay.plate.get_global_rect()
	overlay.fps = 1234.0
	overlay.cpu_ms = 123.45
	overlay.gpu_ms = 99.9
	overlay.ping_ms = 9999
	overlay._show_values()
	await _wait(2)
	check(overlay.plate.get_global_rect() == rect, "long numbers do not resize the plate (%s, %s)" % [rect, overlay.plate.get_global_rect()])

	# Top right corner, clear of the save notice and the pull-out menu.
	var screen: Vector2 = root.get_visible_rect().size
	check(absf(screen.x - rect.end.x - PerfOverlay.EDGE) < 1.0, "it keeps clear of the right edge")
	check(rect.position.y < screen.y * 0.3, "it sits at the top (%s)" % rect)
	game.save_notice.plate.visible = true
	await _wait(2)
	var notice: Rect2 = game.save_notice.plate.get_global_rect()
	game.save_notice.plate.visible = false
	check(not rect.intersects(notice), "it does not cover the save notice (%s, %s)" % [rect, notice])
	for kind in game._quick_buttons:
		var icon: Rect2 = (game._quick_buttons[kind] as Control).get_global_rect()
		check(not rect.intersects(icon), "it does not cover the %s icon on the menu's rail (%s, %s)" % [kind, rect, icon])
	check(rect.end.x <= game._drawer_handle.get_global_rect().position.x, "it stays left of the menu handle")

	if shots != "":
		await _wait(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots.path_join("perf_overlay.png"))

	# Playing together: the ping to the server.
	var server := NetServer.new()
	check(server.start(PORT, 4) == OK, "a server opens on this computer")
	var client := NetClient.new()
	check(client.ping_ms() == -1, "a client that is not connected has no ping")
	check(client.connect_to("127.0.0.1", PORT, "Pinger") == OK, "a client connects")
	for i in 120:
		server.poll()
		client.poll()
		if client.is_welcomed():
			break
		await process_frame
	check(client.is_welcomed(), "the server welcomes the client")
	check(client.ping_ms() >= 0, "a connected client knows its ping (%d)" % client.ping_ms())
	overlay.ping_source = client.ping_ms
	overlay.set_shown(true)
	check(overlay.ping_label.text.begins_with("Ping ") and overlay.ping_label.text.ends_with(" ms"), "the plate shows the ping (%s)" % overlay.ping_label.text)
	client.leave()
	server.stop()

	_press_f1()
	await _wait(2)
	check(not overlay.visible, "F1 again hides the plate")
	_end()


func _end() -> void:
	print("PASS: perf overlay" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
