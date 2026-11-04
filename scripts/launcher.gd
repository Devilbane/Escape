class_name Launcher
extends Control
## The Windows launcher: the first thing "Escape.exe" shows.
##
## Escape.exe is the Godot engine with this small launcher packed inside it. The game
## itself is a separate file, game/Escape.pck, which the launcher keeps up to date:
##   1. it reads version.json from the GitHub release "windows" (see .github/workflows/desktop.yml),
##   2. downloads a newer Escape.exe first when the launcher itself has changed (and
##      restarts), then a newer game/Escape.pck, with a progress bar, checking every file,
##   3. starts the game on "Play" by running Escape.exe again with --main-pack game/Escape.pck.
## Without an internet connection the installed version simply starts. Saved games live in
## the player's user folder and are never touched.
##
## Command-line switches (after the exe, or after `--` when run from the editor):
##   --launcher-source=URL   where version.json and the files are (default: the release "windows")
##   --launcher-dir=PATH     where the game is kept (default: the "game" folder next to the exe)

## UiKit and Lang, preloaded rather than named: the launcher's export ("Windows" in
## export_presets.cfg) packs only what the launcher scene depends on, and names alone are
## no dependency.
const Kit := preload("res://scripts/ui_kit.gd")
const Texts := preload("res://scripts/lang.gd")

const SOURCE := "https://github.com/devilbane/escape/releases/download/windows/"
const MANIFEST := "version.json"
const PACK := "Escape.pck"
const INSTALLED := "installed.json"
## Changed by the build (desktop.yml) to a fingerprint of the launcher and the engine. When the
## release names another one, this launcher is out of date and fetches the new Escape.exe.
## Empty in the editor: no self-update there.
const REV := ""
const CHECK_TIMEOUT := 15.0

const GREY := Color(0.75, 0.72, 0.68)
const NOTE := Color(1.0, 0.75, 0.5)
const TEXT := Color(0.92, 0.9, 0.86)
const BACKGROUND := Color(0.05, 0.035, 0.08)
const STATUS_WIDTH := 620.0

enum Step { CHECKING, DOWNLOADING, VERIFYING, READY, OFFLINE, FAILED, STARTING }

var step := Step.CHECKING
## Off in tests/launcher.gd, which drives the steps itself.
var auto_check := true
var source := SOURCE
var game_dir := ""
## What is installed now: {"version": "0.5", "build": "276"}, empty when nothing is.
var installed := {}
var manifest := {}

var _http: HTTPRequest
var _download_target := ""
var _download_size := 0
var _download_label := ""
## The status line as German text plus its arguments, so a language switch can redo it.
var _status_text := ""
var _status_args := []

var _status: Label
var _progress: ProgressBar
var _play: Button
var _quit: Button
var _version: Label
var _lang_buttons := {}


func _ready() -> void:
	Texts.setup()
	_read_switches()
	_remove_old_exe()
	installed = read_installed(game_dir)
	_build_ui()
	if auto_check:
		_check()
	else:
		_refresh()


# --- What to do -------------------------------------------------------------------------

## The next thing to do once version.json has been read: "launcher" (fetch a new
## Escape.exe), "game" (fetch a new Escape.pck) or "play" (all is up to date).
static func plan(release: Dictionary, have: Dictionary, rev: String) -> String:
	if rev != "" and String(release.get("launcher", "")) != "" and String(release.launcher) != rev:
		return "launcher"
	if String(release.get("build", "")) == "":
		return "play"
	if String(have.get("build", "")) != String(release.build):
		return "game"
	return "play"


## A release file must name the game's file with its size and checksum, or it is not used.
static func valid_manifest(data) -> bool:
	return data is Dictionary and String(data.get("build", "")) != "" \
		and String(data.get("pack_sha256", "")).length() == 64 and int(data.get("pack_size", 0)) > 0


static func read_installed(dir: String) -> Dictionary:
	var file := dir.path_join(INSTALLED)
	if not FileAccess.file_exists(file) or not FileAccess.file_exists(dir.path_join(PACK)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	return data if data is Dictionary else {}


## "12.3" in English, "12,3" in German.
static func megabytes(bytes: int) -> String:
	var text := "%.1f" % (bytes / 1048576.0)
	return text if Texts.language == "en" else text.replace(".", ",")


func _read_switches() -> void:
	game_dir = OS.get_executable_path().get_base_dir().path_join("game")
	if not OS.has_feature("template"):
		# Run from the editor: never write next to the Godot binary.
		game_dir = ProjectSettings.globalize_path("user://launcher_test/game")
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--launcher-source="):
			source = arg.get_slice("=", 1)
			if not source.ends_with("/"):
				source += "/"
		elif arg.begins_with("--launcher-dir="):
			game_dir = arg.substr(arg.find("=") + 1)
	if not _writable(game_dir):
		# Unpacked somewhere the player may not write (Program Files): keep the game in
		# the user folder instead.
		game_dir = ProjectSettings.globalize_path("user://game")
		DirAccess.make_dir_recursive_absolute(game_dir)


static func _writable(dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var probe := dir.path_join(".write_test")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true


## A launcher that renamed itself away during an update leaves its old file behind.
func _remove_old_exe() -> void:
	var old := OS.get_executable_path() + ".old"
	if OS.has_feature("template") and FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)


# --- Talking to GitHub --------------------------------------------------------------------

func _check() -> void:
	step = Step.CHECKING
	manifest = {}
	_set_status("Suche nach einer neuen Version …")
	_refresh()
	_request(source + MANIFEST, "", CHECK_TIMEOUT)


func _request(url: String, target: String, timeout: float) -> void:
	if _http:
		_http.cancel_request()
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = timeout
	_http.download_chunk_size = 1 << 20
	_http.download_file = target
	add_child(_http)
	_http.request_completed.connect(_on_request_done.bind(target))
	if _http.request(url, ["User-Agent: escape-launcher", "Cache-Control: no-cache"]) != OK:
		_on_request_done(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray(), target)


func _on_request_done(result: int, code: int, _headers, body: PackedByteArray, target: String) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
	if target == "":
		_on_manifest(ok, body)
	elif step == Step.DOWNLOADING and target == _download_target:
		_on_downloaded(ok)


func _on_manifest(ok: bool, body: PackedByteArray) -> void:
	if step != Step.CHECKING:
		return
	var data = JSON.parse_string(body.get_string_from_utf8()) if ok else null
	if not valid_manifest(data):
		_offline()
		return
	manifest = data
	match plan(manifest, installed, REV):
		"launcher":
			_download(source + String(manifest.get("launcher_file", "Escape.exe")),
				OS.get_executable_path() + ".new", int(manifest.get("launcher_size", 0)), "launcher")
		"game":
			_download(source + PACK, game_dir.path_join(PACK + ".part"), int(manifest.pack_size),
				"update" if installed else "first")
		_:
			_ready_to_play()


func _download(url: String, target: String, size: int, what: String) -> void:
	step = Step.DOWNLOADING
	_download_target = target
	_download_size = size
	_download_label = what
	DirAccess.remove_absolute(target)
	_show_progress(0)
	_refresh()
	_request(url, target, 0.0)


func _process(_delta: float) -> void:
	if step == Step.DOWNLOADING and _http:
		_show_progress(_http.get_downloaded_bytes())


func _show_progress(done: int) -> void:
	var total := _download_size if _download_size > 0 else maxi(_http.get_body_size() if _http else 0, 1)
	_progress.value = clampf(float(done) / total, 0.0, 1.0) * 100.0
	var text: String = {
		"launcher": "Lade den neuen Starter: %s von %s MB",
		"update": "Lade die neue Version: %s von %s MB",
		"first": "Lade das Spiel: %s von %s MB",
	}[_download_label]
	_set_status(text, [megabytes(done), megabytes(total)])


func _on_downloaded(ok: bool) -> void:
	step = Step.VERIFYING
	_set_status("Prüfe die heruntergeladene Datei …")
	_refresh()
	await get_tree().process_frame
	var target := _download_target
	var launcher := _download_label == "launcher"
	var sha := String(manifest.get("launcher_sha256" if launcher else "pack_sha256", ""))
	if ok and FileAccess.file_exists(target) and (sha == "" or FileAccess.get_sha256(target) == sha):
		if launcher:
			_replace_launcher(target)
		else:
			_install_pack(target)
		return
	DirAccess.remove_absolute(target)
	if installed:
		_offline("Der Download ist fehlgeschlagen. Du spielst die installierte Version.")
	else:
		_failed()


func _install_pack(part: String) -> void:
	var pack := game_dir.path_join(PACK)
	DirAccess.remove_absolute(pack)
	if DirAccess.rename_absolute(part, pack) != OK:
		_failed()
		return
	installed = {"version": String(manifest.get("version", "")), "build": String(manifest.build)}
	var file := FileAccess.open(game_dir.path_join(INSTALLED), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(installed))
		file.close()
	_ready_to_play()


## Windows lets a running program be renamed, though not overwritten: the old exe steps
## aside, the new one takes its name and is started, and this one ends.
func _replace_launcher(new_exe: String) -> void:
	var exe := OS.get_executable_path()
	var old := exe + ".old"
	DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		DirAccess.remove_absolute(new_exe)
		_after_launcher_failed()
		return
	if DirAccess.rename_absolute(new_exe, exe) != OK:
		DirAccess.rename_absolute(old, exe)
		_after_launcher_failed()
		return
	_set_status("Der Starter wird erneuert …")
	step = Step.STARTING
	_refresh()
	OS.create_process(exe, [])
	get_tree().quit()


## Without the new launcher the game can still be updated by this one.
func _after_launcher_failed() -> void:
	if plan(manifest, installed, "") == "game":
		_download(source + PACK, game_dir.path_join(PACK + ".part"), int(manifest.pack_size),
			"update" if installed else "first")
	else:
		_ready_to_play()


func _ready_to_play() -> void:
	step = Step.READY
	_set_status("Version %s ist bereit. Viel Glück auf der Flucht!", [_installed_version()])
	_refresh()


func _offline(why := "Keine Verbindung zum Server. Du spielst die installierte Version.") -> void:
	if not installed:
		_failed()
		return
	step = Step.OFFLINE
	_set_status(why)
	_refresh()


func _failed() -> void:
	step = Step.FAILED
	_set_status("Das Spiel konnte nicht geladen werden. Prüfe die Internetverbindung und versuche es erneut.")
	_refresh()


# --- Buttons ------------------------------------------------------------------------------

func _on_play() -> void:
	if step == Step.FAILED:
		_check()
		return
	if not installed or step in [Step.STARTING, Step.VERIFYING]:
		return
	# Playing during a download: the download is dropped, the installed version starts.
	if _http:
		_http.cancel_request()
	if step == Step.DOWNLOADING:
		DirAccess.remove_absolute(_download_target)
	step = Step.STARTING
	_set_status("Das Spiel startet …")
	_refresh()
	if OS.has_feature("template"):
		OS.create_process(OS.get_executable_path(), ["--main-pack", game_dir.path_join(PACK)])
		get_tree().quit()
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit() -> void:
	if _http:
		_http.cancel_request()
	if step == Step.DOWNLOADING:
		DirAccess.remove_absolute(_download_target)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _play.disabled:
				_on_play()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_quit()
			get_viewport().set_input_as_handled()


func _choose_language(code: String) -> void:
	Texts.choose(code)
	_refresh()


# --- Window -------------------------------------------------------------------------------

## Fixed layout: nothing moves when the status changes. The status keeps room for two
## lines, the progress bar keeps its place while hidden, and the buttons fit their
## longest text in both languages.
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(box)

	var title := Kit.label(Kit.TITLE_FONT, 120, Kit.GOLD)
	title.text = "Escape!"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Kit.label(Kit.TEXT_FONT, 20, GREY)
	sub.text = "Entkomme aus dem Verlies"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_status = Kit.label(Kit.TEXT_FONT, 18, TEXT)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(STATUS_WIDTH, 56)
	# The status and its progress bar are one group, set apart from the buttons below.
	var news := VBoxContainer.new()
	news.add_theme_constant_override("separation", 6)
	box.add_child(news)
	news.add_child(_status)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(STATUS_WIDTH, 14)
	_progress.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.05, 0.1, 0.9)
	back.border_color = Color(0.85, 0.66, 0.32, 0.55)
	back.set_border_width_all(1)
	back.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Kit.GOLD
	fill.set_corner_radius_all(7)
	_progress.add_theme_stylebox_override("background", back)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	news.add_child(_progress)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	box.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_play = Kit.button("Spielen", _on_play)
	_play.custom_minimum_size = Vector2(220, 60)
	row.add_child(_play)
	_quit = Kit.button("Beenden", _on_quit)
	_quit.custom_minimum_size = Vector2(180, 60)
	row.add_child(_quit)

	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	add_child(langs)
	for entry in [["Deutsch", "de"], ["English", "en"]]:
		var b := Kit.button(entry[0], _choose_language.bind(entry[1]))
		b.custom_minimum_size = Vector2(118, 44)
		b.add_theme_font_size_override("font_size", 16)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		langs.add_child(b)
		_lang_buttons[entry[1]] = b
	langs.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)

	_version = Kit.label(Kit.TEXT_FONT, 14, GREY)
	_version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_version.text = "Version 0.0.0000"
	add_child(_version)
	_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)


func _set_status(text: String, args := []) -> void:
	if text != _status_text or args != _status_args:
		print("Launcher: ", text % args if args else text)
	_status_text = text
	_status_args = args
	if _status:
		_status.text = Texts.t(text) % args if args else Texts.t(text)


func _installed_version() -> String:
	var version := String(installed.get("version", ""))
	var build := String(installed.get("build", ""))
	return version + ("." + build if build != "" and version != "" else build)


## Brings every part of the window in line with the current step.
func _refresh() -> void:
	if not _status:
		return
	_set_status(_status_text, _status_args)
	var problem := step in [Step.OFFLINE, Step.FAILED]
	_status.add_theme_color_override("font_color", NOTE if problem else TEXT)
	_progress.modulate.a = 1.0 if step in [Step.DOWNLOADING, Step.VERIFYING] else 0.0
	_play.text = "Erneut versuchen" if step == Step.FAILED else "Spielen"
	_play.disabled = step in [Step.STARTING, Step.VERIFYING] or (not installed and step != Step.FAILED)
	_quit.disabled = step == Step.STARTING
	for code in _lang_buttons:
		var chosen: bool = code == ("en" if Texts.language == "en" else "de")
		_lang_buttons[code].modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.5)
	# Buttons and the subtitle translate themselves; tell them the language changed.
	propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	var shown := _installed_version()
	_version.text = ("Version " + shown) if shown != "" else ""
