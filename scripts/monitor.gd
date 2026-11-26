class_name Monitor
extends RefCounted
## Which screen the game's window opens on.
##
## Windows numbers its displays 1, 2, 3 in Settings > Display, and that is the order Godot
## lists them in (screen 0 is Windows' "1"), whichever display is set as the main one. The
## window opens on screen 0, so Windows' monitor 1, even when another display is the main one.
## The choice can be changed with `monitor=N` (N counted like Windows, from 1) in the
## `[fenster]` section of the settings file, or for one run with `--monitor=N`.
## A number with no screen behind it falls back to the first screen.

const SETTINGS_FILE := "user://einstellungen.cfg"


## The screen index (from 0) the window should open on, for `count` screens.
static func pick(wanted: int, count: int) -> int:
	if count <= 0:
		return 0
	return wanted - 1 if wanted >= 1 and wanted <= count else 0


## The wanted Windows-style number: the command line first, then the settings file, else 1.
static func wanted_number(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--monitor="):
			return int(arg.get_slice("=", 1))
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		return int(cfg.get_value("fenster", "monitor", 1))
	return 1


## Moves `window` to the chosen screen and keeps its mode (maximized stays maximized).
static func apply(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen := pick(wanted_number(OS.get_cmdline_args()), DisplayServer.get_screen_count())
	if window.current_screen == screen:
		return
	var mode := window.mode
	# A maximized window cannot be moved to another screen, so it is let go and maximized again.
	if mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.current_screen = screen
	if mode != Window.MODE_WINDOWED:
		window.mode = mode
