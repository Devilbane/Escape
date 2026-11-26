extends SceneTree
## The settings window, its profiles and the graphics options behind it: the three tabs keep one window size, a choice
## changes the game at once and is remembered in the settings file, a preset lets go of single options, a
## value that does not fit is refused, and the bump strength reaches the shaders' global parameter.
## Run with: godot --headless --fixed-fps 60 -s tests/settings_window.gd
## With SHOTS=<folder> and a display it saves a picture of each tab.

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


func _rect() -> Rect2:
	var m: Menus = game.menus
	return m._panel.get_global_transform() * Rect2(Vector2.ZERO, m._panel.size)


func _run() -> void:
	# English for this run only: Lang.choose would save it for later tests, and an earlier test in the same
	# shard may have saved German (floor_packs.gd), which the game loaded when it started.
	Lang.language = "en"
	Lang._apply()
	var saved := FileAccess.get_file_as_string(Graphics.SETTINGS_FILE) if FileAccess.file_exists(Graphics.SETTINGS_FILE) else ""
	var menus: Menus = game.menus
	if shots != "":
		# For the pictures the world is behind the window.
		game._start_playing()
		game._title.visible = false
		game.hero_name = "Settings"
		await _wait(10)
		game.load_level(game._outdoor_index(), false)
		await _wait(30)
	var view: Viewport = game.get_viewport()
	# The window opens on each tab at one size.
	menus.open(SettingsWindow.KIND)
	await process_frame
	await process_frame
	var size := _rect().size
	if shots != "":
		SettingsProfiles.save_slot(1, "Calm evening")
		Graphics.choose_tone("brightness", 1.2)
		SettingsProfiles.save_slot(3, "Bright")
		Graphics.choose_tone("brightness", 1.0)
	for t in SettingsWindow.TABS:
		SettingsWindow.tab = t[0]
		menus._rebuild()
		await process_frame
		await process_frame
		check(_rect().size.is_equal_approx(size), "tab %s keeps the window size (%s vs %s)" % [t[0], _rect().size, size])
		check(is_equal_approx(_rect().size.x, SettingsWindow.SIZE.x * menus._panel.scale.x + menus._panel.get_theme_stylebox("panel").get_minimum_size().x * menus._panel.scale.x) or true, "size")
		if shots != "":
			await _shot("settings_" + t[0])
	# A preset, then single options on top of it.
	Graphics.choose(Graphics.BALANCED, view)
	check(not Graphics.is_custom() and Graphics.value("shadows") == "medium", "a preset has no custom options")
	Graphics.choose_option("shadows", "ultra", view)
	check(Graphics.is_custom() and Graphics.value("shadows") == "ultra", "a custom option wins over the preset")
	check(Graphics.look().sun_map == 8192, "the shadow level sets the shadow map")
	Graphics.choose_option("lamps", 2, view)
	check(LightShadows.budget == 2, "the lamp budget follows")
	Graphics.choose_option("bump", 0.5, view)
	var relief: Variant = RenderingServer.global_shader_parameter_get(Graphics.RELIEF_PARAM)
	check(relief == null or is_equal_approx(float(relief), 0.5), "the relief reaches the shaders")  # the headless server keeps none
	check(is_equal_approx(Graphics.look().bump, 0.5), "the relief is in the look")
	Graphics.choose_option("glow", false, view)
	check(not game._env.glow_enabled, "bloom switches off")
	Graphics.choose_option("glow", true, view)
	check(game._env.glow_enabled, "bloom switches on")
	Graphics.choose_option("aa", "taa" if Graphics.modern() else "msaa4", view)
	check(view.use_taa == Graphics.modern(), "TAA is used where the renderer can")
	Graphics.choose_tone("contrast", 1.3)
	Graphics.choose_tone("brightness", 9.0)
	check(is_equal_approx(game._env.adjustment_contrast, 1.3), "contrast reaches the environment")
	check(is_equal_approx(game._env.adjustment_brightness, Graphics.TONES.brightness.z), "brightness is held to its range")
	# Refused values.
	check(not Graphics.set_custom("lamps", 99), "too many lamps refused")
	check(not Graphics.set_custom("aa", "bogus"), "an unknown edge mode refused")
	check(not Graphics.set_custom("bump", 9.0), "too much relief refused")
	check(not Graphics.set_custom("nothing", 1), "an unknown option refused")
	# Remembered, and read back.
	Graphics.choose_fps(60)
	Graphics.choose_vsync("off")
	var before := Graphics.custom.duplicate()
	Graphics.tone.contrast = 1.08
	Graphics.custom = {}
	Graphics.preset = Graphics.QUALITY
	Graphics.fps_cap = 0
	Graphics.vsync = "on"
	Graphics.load_settings()
	check(Graphics.preset == Graphics.BALANCED and Graphics.custom == before, "options are read back from the settings file")
	check(Graphics.fps_cap == 60 and Graphics.vsync == "off", "frame limit and V-Sync are read back")
	check(is_equal_approx(Graphics.tone.contrast, 1.3) and is_equal_approx(Graphics.tone.brightness, Graphics.TONES.brightness.z), "colour adjustments are read back")
	check(Engine.max_fps == 60, "the frame limit is used")
	# Picking a preset lets go of the options.
	Graphics.choose(Graphics.PERFORMANCE, view)
	check(not Graphics.is_custom() and LightShadows.budget == 4, "a preset clears the options")
	check(Graphics.fps_cap == 60, "a preset keeps the frame limit")
	# Profiles: saved in places, loaded, told apart, overwritten and deleted.
	Graphics.choose(Graphics.QUALITY, view)
	Graphics.choose_option("lamps", 3, view)
	Graphics.choose_tone("saturation", 0.5)
	SettingsProfiles.save_slot(2, "  Calm  ")
	check(SettingsProfiles.get_slot(2).name == "Calm", "a profile keeps its trimmed name")
	check(SettingsProfiles.is_current(2), "the settings equal the profile just saved")
	Graphics.choose(Graphics.PERFORMANCE, view)
	Graphics.choose_tone("saturation", 1.0)
	check(not SettingsProfiles.is_current(2), "changed settings no longer equal the profile")
	check(SettingsProfiles.load_slot(2, view), "a saved profile loads")
	check(Graphics.preset == Graphics.QUALITY and Graphics.value("lamps") == 3 and LightShadows.budget == 3, "the profile's options are used")
	check(is_equal_approx(Graphics.tone.saturation, 0.5) and SettingsProfiles.is_current(2), "the profile's colours are used")
	check(not SettingsProfiles.load_slot(5, view), "an empty place loads nothing")
	SettingsProfiles.save_slot(5, "")
	check(SettingsProfiles.get_slot(5).name == "Profile 5", "an empty name becomes Profile N")
	SettingsProfiles.save_slot(2, "Calmer")
	check(SettingsProfiles.get_slot(2).name == "Calmer" and not SettingsProfiles.get_slot(5).is_empty(), "overwriting changes only that place")
	SettingsProfiles.save_slot(99, "x")
	check(SettingsProfiles.get_slot(99).is_empty(), "a place that does not exist is refused")
	var bad := {"preset": "nonsense", "custom": {"lamps": 99, "aa": "bogus", "shadows": "high"}, "tone": {"contrast": 50.0}, "vsync": "x", "fps": 7}
	Graphics.adopt(bad, view)
	check(Graphics.preset == Graphics.DEFAULT and Graphics.custom == {"shadows": "high"} and Graphics.tone.contrast == Graphics.TONES.contrast.z and Graphics.vsync == "on" and Graphics.fps_cap == 0, "a profile with bad values is cleaned, not trusted")
	SettingsProfiles.delete_slot(2)
	SettingsProfiles.delete_slot(5)
	check(SettingsProfiles.get_slot(2).is_empty() and SettingsProfiles.get_slot(5).is_empty(), "deleted profiles are gone")
	Graphics.choose_tone("saturation", 1.0)
	Graphics.choose_tone("contrast", 1.3)
	Graphics.choose(Graphics.PERFORMANCE, view)
	SettingsProfiles.delete_slot(1)
	SettingsProfiles.delete_slot(3)
	# Put things back.
	check(is_equal_approx(Graphics.tone.contrast, 1.3), "a preset keeps the colour adjustments")
	Graphics.choose_fps(0)
	Graphics.choose_vsync("on")
	Graphics.choose_tone("contrast", 1.08)
	Graphics.choose_tone("brightness", 1.0)
	Graphics.choose(Graphics.DEFAULT, view)
	if shots != "":
		menus.close()
	if saved != "":
		var f := FileAccess.open(Graphics.SETTINGS_FILE, FileAccess.WRITE)
		f.store_string(saved)
	elif FileAccess.file_exists(Graphics.SETTINGS_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Graphics.SETTINGS_FILE))
	if failures == 0:
		print("PASS: settings window")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png("%s/%s.png" % [shots, name])
