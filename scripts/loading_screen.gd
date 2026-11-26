class_name LoadingScreen
extends Control
## The screen shown while the game sets up at start (see WorldPreload): the key art picture as large as
## the upper part allows, with the newest patch notes in two columns below it, so no text lies on the picture.
##
## The picture is loaded from disk only for this screen and let go of with it, so it does not stay in
## memory. The notes come from the patch archive (see PatchHistory), the
## newest build, cut into two halves. Nothing here reads the game's level, so it works before any
## level is loaded. Tested by tests/loading_screen.gd.

const ART := "res://assets/logo/loading_art.jpg"
const TITLE_FONT := preload("res://assets/fonts/CinzelDecorative-Black.woff2")
const TEXT_FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const MARGIN := 80
## The picture fills the top of the screen down to here; the notes start below it.
const ART_BOTTOM := 0.6
const NOTES_TOP := 0.625
const BACKDROP := Color(0.03, 0.015, 0.04, 1.0)
const GOLD := Color(0.96, 0.8, 0.38)
## Notes shown per side; what does not fit is counted in a line below.
const MAX_PER_SIDE := 7
## The screen stays up at least this long, so it never flashes by.
const MIN_SECONDS := 1.0
const FADE_IN := 0.4
const FADE_OUT := 0.5

var _age := 0.0
var _leaving := false
var _game: Node
var _status: Label


## Puts the screen over everything of `game`'s HUD, unless there is nothing to wait for (the
## village is ready already, or no window is drawn) or the language is still to be chosen.
static func start(parent: Node, game: Node, headless_ok := false) -> LoadingScreen:
	if WorldPreload.is_ready() or Lang.language == "":
		return null
	if DisplayServer.get_name() == "headless" and not headless_ok:
		return null
	var screen := LoadingScreen.new()
	screen._game = game
	parent.add_child(screen)
	return screen


## The newest build's notes in two halves: [left, right], each an Array of lines, plus how many
## did not fit.
static func halves(notes: Array) -> Dictionary:
	var shown := notes.slice(0, MAX_PER_SIDE * 2)
	var cut := (shown.size() + 1) / 2
	return {
		"left": shown.slice(0, cut),
		"right": shown.slice(cut),
		"more": notes.size() - shown.size(),
	}


func _ready() -> void:
	name = "LoadingScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := ColorRect.new()
	back.color = BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	add_child(_art())

	# The notes sit in a band below the picture: heading and version on top, the notes in two columns.
	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.anchor_top = NOTES_TOP
	row.anchor_bottom = 0.9
	row.offset_left = MARGIN
	row.offset_right = -MARGIN
	row.add_theme_constant_override("separation", 48)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var build := _newest_build()
	var parts := halves(build.get("notes", []))
	row.add_child(_column(Lang.t("Patchnotes"), parts.left, "", HORIZONTAL_ALIGNMENT_LEFT))
	var version_line := ""
	if build.has("version"):
		version_line = "%s %s" % [Lang.t("Version"), build.version]
	row.add_child(_column(version_line, parts.right, _more_line(parts.more), HORIZONTAL_ALIGNMENT_LEFT))

	_status = UiKit.label(TEXT_FONT, UiKit.sized(22), Color(1, 1, 1, 0.75))
	_status.text = Lang.t("Die Welt wird vorbereitet …")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.anchor_right = 1.0
	_status.anchor_top = 0.9
	_status.anchor_bottom = 0.97
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


func _newest_build() -> Dictionary:
	var builds := PatchHistory.builds()
	return builds[0] if not builds.is_empty() else {}


func _more_line(count: int) -> String:
	return Lang.t("… und %d weitere in der Enzyklopädie") % count if count > 0 else ""


## The key art, as large as the upper part allows, never stretched.
func _art() -> Control:
	var pic := TextureRect.new()
	pic.name = "Art"
	pic.texture = load(ART)
	pic.anchor_left = 0.0
	pic.anchor_right = 1.0
	pic.anchor_top = 0.02
	pic.anchor_bottom = ART_BOTTOM
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Mipmaps: the picture is drawn smaller than it is.
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


## One side's notes under a heading; the heading is always there so both sides line up.
func _column(heading: String, lines: Array, footer: String, align: int) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.custom_minimum_size.x = 120
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UiKit.label(TITLE_FONT, UiKit.sized(30), GOLD)
	head.text = heading
	head.horizontal_alignment = align
	head.custom_minimum_size.y = UiKit.sized(36)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	for line in lines:
		var l := UiKit.label(TEXT_FONT, UiKit.sized(19), Color(1, 1, 1, 0.9))
		l.text = "•  " + str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = align
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		col.add_child(l)
	if footer != "":
		var more := UiKit.label(TEXT_FONT, UiKit.sized(17), Color(1, 1, 1, 0.55))
		more.text = footer
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(more)
	return col


func _process(delta: float) -> void:
	_age += delta
	# A slow pulse on the status line: the game is not frozen.
	_status.modulate.a = 0.6 + 0.4 * sin(_age * 3.0)
	if _leaving:
		return
	# A game that has begun (a level is loaded, the title is gone) never waits behind this screen.
	var begun: bool = _game != null and _game.state != _game.State.TITLE
	if begun or (_age >= MIN_SECONDS and WorldPreload.is_ready()):
		leave()


## Fades out and goes; the picture is freed with the node.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)
