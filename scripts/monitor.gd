class_name Monitor
extends RefCounted
## Which screen the game's window opens on and how it is shown there.
##
## Windows numbers its displays 1, 2, 3 in Settings > Display, and that is the order Godot
## lists them in (screen 0 is Windows' "1"), whichever display is set as the main one. The
## window opens on screen 0, so Windows' monitor 1, even when another display is the main one.
## The choice can be changed with `monitor=N` (N counted like Windows, from 1) in the
## `[fenster]` section of the settings file, or for one run with `--monitor=N`.
## A number with no screen behind it falls back to the first screen.
##
## The display mode is picked in the pull-out menu (Game._make_display_row) and remembered as
## `modus` in the same section: maximized (the default, a normal window filling the screen),
## three window sizes, borderless fullscreen (a window the size of the screen without a frame)
## and exclusive fullscreen.

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
	return monitor


const MAXIMIZED := "maximiert"
const BORDERLESS := "rahmenlos"
const FULLSCREEN := "vollbild"
## The modes in the order the menu button steps through them, and the window sizes among them.
const MODES := [MAXIMIZED, "fenster1280", "fenster1600", "fenster1920", BORDERLESS, FULLSCREEN]
const SIZES := {"fenster1280": Vector2i(1280, 720), "fenster1600": Vector2i(1600, 900), "fenster1920": Vector2i(1920, 1080)}
## What each mode is called (German, translated by Lang).
const NAMES := {
	MAXIMIZED: "Maximiert", "fenster1280": "1280×720", "fenster1600": "1600×900",
	"fenster1920": "1920×1080", BORDERLESS: "Rahmenlos", FULLSCREEN: "Vollbild",
}
## What each mode is for, shown as the button's tooltip (German, translated by Lang).
const HINTS := {
	MAXIMIZED: "Maximiert: ein Fenster mit Titelleiste, das den Bildschirm füllt.",
	"fenster1280": "Fenster 1280×720: ein Fenster in der Mitte des Bildschirms.",
	"fenster1600": "Fenster 1600×900: ein Fenster in der Mitte des Bildschirms.",
	"fenster1920": "Fenster 1920×1080: ein Fenster in der Mitte des Bildschirms.",
	BORDERLESS: "Rahmenlos: ein Fenster ohne Rahmen, so groß wie der Bildschirm.",
	FULLSCREEN: "Vollbild: das Spiel allein auf dem Bildschirm.",
}

static var mode := MAXIMIZED
## The monitor the player picked in the menu, counted like Windows from 1.
static var monitor := 1


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		var saved := str(cfg.get_value("fenster", "modus", MAXIMIZED))
		mode = saved if saved in MODES else MAXIMIZED
		monitor = maxi(1, int(cfg.get_value("fenster", "monitor", 1)))


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("fenster", "modus", mode)
	cfg.set_value("fenster", "monitor", monitor)
	cfg.save(SETTINGS_FILE)


## The mode after `current` in the menu's order.
static func next_mode(current: String) -> String:
	return MODES[(MODES.find(current) + 1) % MODES.size()]


## The monitor number after `current`, wrapping round after the last of `count` screens.
static func next_monitor(current: int, count: int) -> int:
	return current % maxi(count, 1) + 1


## Picks a mode, remembers it and shows `window` that way at once.
static func choose_mode(which: String, window: Window) -> void:
	mode = which if which in MODES else MAXIMIZED
	_save_settings()
	apply(window)


## Picks a monitor, remembers it and moves `window` there at once.
static func choose_monitor(number: int, window: Window) -> void:
	monitor = number
	_save_settings()
	apply(window)


## Moves `window` to the chosen screen and shows it in the chosen mode. The launcher passes
## `launcher`: it only moves to the screen and stays its small fixed window.
static func apply(window: Window, launcher := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var count := DisplayServer.get_screen_count()
	var screen := pick(wanted_number(OS.get_cmdline_args()), count)
	if launcher:
		if window.current_screen != screen:
			window.current_screen = screen
		return
	if window.mode == Window.MODE_MAXIMIZED and mode == MAXIMIZED and window.current_screen == screen:
		return
	# A maximized or fullscreen window cannot change screens or size, so it is let go first.
	window.mode = Window.MODE_WINDOWED
	window.current_screen = screen
	match mode:
		MAXIMIZED:
			window.mode = Window.MODE_MAXIMIZED
		BORDERLESS:
			window.mode = Window.MODE_FULLSCREEN
		FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			var area := DisplayServer.screen_get_usable_rect(screen)
			var size: Vector2i = SIZES[mode].min(area.size)
			window.size = size
			window.position = area.position + (area.size - size) / 2
