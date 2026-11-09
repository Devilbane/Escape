extends SceneTree
## Headless test for the sound effects volume: the effects play through their
## own bus, the slider in the pull-out menu sets that bus's volume without
## touching the music, the level is remembered in the settings, and M (sound
## off) keeps working alongside the slider.
## Run with: godot --headless --fixed-fps 60 -s tests/effects_volume.gd

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


func _finish() -> void:
	if failures == 0:
		print("PASS: effects volume")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _settings() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Sfx.SETTINGS_FILE)
	return cfg


func _press_m() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(2)
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(2)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	await _wait(10)
	# Start from the defaults whatever an earlier run saved.
	if Sfx.muted:
		Sfx.toggle_mute()
	Sfx.set_volume(Sfx.DEFAULT_VOLUME)
	Music.set_volume(Music.DEFAULT_VOLUME)
	game._update_sound_button()

	var bus := AudioServer.get_bus_index(Sfx.BUS)
	check(bus >= 0, "there is an effects bus")
	check(AudioServer.get_bus_index("Master") == 0, "Master stays the first bus")
	check(AudioServer.bus_count == 2, "the effects bus comes from the bus layout, none is added at runtime")
	check(AudioServer.get_bus_send(bus) == &"Master", "the effects bus sends to Master")
	check(game._ambience.bus == Sfx.BUS, "the ambience plays through the effects bus")
	check(Sfx.start_loop(game, "rain").bus == Sfx.BUS, "the rain (and every soundscape loop) plays through the effects bus")
	Sfx.play(game, "step_0")
	var played := false
	for c in root.get_children():
		if c is AudioStreamPlayer and c.bus == Sfx.BUS:
			played = true
	check(played, "a sound effect plays through the effects bus")

	var slider: HSlider = game._effects_slider
	check(slider != null and game._drawer.is_ancestor_of(slider), "the effects slider is in the pull-out menu")
	check(game._drawer.is_ancestor_of(game._music_slider), "the music slider is still there too")
	check(is_equal_approx(slider.value, 1.0), "the slider shows the volume")

	slider.value = 0.3
	await _wait(2)
	check(is_equal_approx(Sfx.volume, 0.3), "the slider sets the effects volume")
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.3)) < 0.1, "the effects bus plays at that volume")
	check(is_equal_approx(Music.volume, Music.DEFAULT_VOLUME), "the music volume stays as it was")
	check(is_equal_approx(float(_settings().get_value("ton", "lautstaerke", 0.0)), 0.3), "the volume is saved")
	slider.value = 0.0
	await _wait(2)
	check(AudioServer.is_bus_mute(bus), "turned all the way down, the effects are silent")

	# M still switches all sound off and on.
	slider.value = 0.5
	await _wait(2)
	await _press_m()
	check(Sfx.muted, "M switches the sound off")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "with the sound off everything is silent")
	check(is_equal_approx(slider.value, 0.5), "M leaves the slider where it was")
	await _press_m()
	check(not Sfx.muted, "M switches the sound back on")
	check(is_equal_approx(Sfx.volume, 0.5), "and the effects come back at the slider's volume")

	# With the sound off, sliding the effects up switches it back on.
	await _press_m()
	slider.value = 0.7
	await _wait(2)
	check(not Sfx.muted, "sliding the effects up switches the sound back on")
	check(game._sound_button.text == Lang.t("Ton: an"), "the sound button says the sound is on")

	# The saved level comes back on the next start.
	Sfx.volume = 0.2
	Sfx.load_settings()
	check(is_equal_approx(Sfx.volume, 0.7), "the effects volume is loaded again")

	Sfx.set_volume(Sfx.DEFAULT_VOLUME)
	_finish()
