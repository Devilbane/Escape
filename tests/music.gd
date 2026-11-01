extends SceneTree
## Headless test for the background music: it loops, waits for the first
## click or key press where the browser demands it, keeps paused while the
## music is off or turned all the way down, and its on/off button and volume
## slider sit in the pull-out menu and are remembered in the settings.
## Run with: godot --headless --fixed-fps 60 -s tests/music.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# Act like the browser: no music before the first input.
	Music.wait_for_input = true
	Music.heard_input = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: music")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _settings() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Music.SETTINGS_FILE)
	return cfg


func _run() -> void:
	check(Music.has_track(), "the music track is part of the game")
	var player: AudioStreamPlayer = Music._player
	check(player != null, "the game creates a music player")
	if player == null:
		_finish()
		return
	check(player.stream.loop, "the music loops")
	# Start from the defaults whatever an earlier run saved.
	if Music.muted:
		Music.toggle_mute()
	Music.set_volume(Music.DEFAULT_VOLUME)
	await _wait(2)
	check(not Music.is_playing(), "no music before the first click or key press")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	Input.parse_input_event(click)
	await _wait(3)
	check(Music.heard_input, "the first click is noticed")
	check(Music.is_playing(), "the music starts with the first click")
	var release := click.duplicate()
	release.pressed = false
	Input.parse_input_event(release)

	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	check(game._drawer.is_ancestor_of(game._music_button), "the music button is in the pull-out menu")
	check(game._drawer.is_ancestor_of(game._music_slider), "the volume slider is in the pull-out menu")
	check(game._music_button.text == Lang.t("Musik: an"), "the button says the music is on")
	check(is_equal_approx(game._music_slider.value, Music.DEFAULT_VOLUME), "the slider shows the volume")

	game._music_button.button_down.emit()
	await _wait(2)
	check(Music.muted, "the button switches the music off")
	check(not Music.is_playing(), "switched off, the music pauses")
	check(game._music_button.text == Lang.t("Musik: aus"), "the button says the music is off")
	check(bool(_settings().get_value("musik", "stumm", false)), "music off is saved")
	game._music_button.button_down.emit()
	await _wait(2)
	check(not Music.muted and Music.is_playing(), "the button switches it back on")

	game._music_slider.value = 0.2
	await _wait(2)
	check(is_equal_approx(Music.volume, 0.2), "the slider sets the volume")
	check(absf(player.volume_db - linear_to_db(0.2)) < 0.1, "the player plays at that volume")
	check(is_equal_approx(float(_settings().get_value("musik", "lautstaerke", 0.0)), 0.2), "the volume is saved")
	game._music_slider.value = 0.0
	await _wait(2)
	check(not Music.is_playing(), "turned all the way down, the music pauses")

	# Off, then sliding the volume up brings the music back.
	game._music_button.button_down.emit()
	game._music_slider.value = 0.6
	await _wait(2)
	check(not Music.muted and Music.is_playing(), "sliding the volume up switches the music back on")

	# The saved settings come back on the next start.
	Music.volume = 0.3
	Music.muted = true
	Music.load_settings()
	check(is_equal_approx(Music.volume, 0.6) and not Music.muted, "the settings are loaded again")

	Music.set_volume(Music.DEFAULT_VOLUME)
	_finish()
