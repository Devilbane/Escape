class_name SaveNotice
extends CanvasLayer
## A small bronze plate in the top right corner that says the game was just
## saved: a scroll and "Game saved". It fades in, stays a moment and fades
## out again. Every save shows it (see Game.save_game): beds, the camp, the
## bedroll, autosaves in safe rooms, the bank. A save while it still shows
## starts it over instead of stacking a second one.
##
## It is a layer of its own above the HUD, the windows and the screen fade,
## so a save while a window is open or the screen is black is still seen. It
## sits in a corner nothing else uses and never takes the pointer, so no other
## part of the HUD moves or is covered.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## Seconds to fade in, to stay, and to fade out.
const FADE_IN := 0.25
const HOLD := 1.8
const FADE_OUT := 0.8
## Distance from the screen's top and right edges (the HUD edge margin).
const EDGE := 24
const ICON := 26
const TEXT_SIZE := 18

var plate: PanelContainer
var label: Label
var _tween: Tween


func _ready() -> void:
	layer = 4
	# Shows and fades while the world is paused (a window open).
	process_mode = Node.PROCESS_MODE_ALWAYS
	plate = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# The purse plate's frame: a bronze rim around the HUD's dark ground.
	var frame := UiKit.frame_style(Color(0.09, 0.066, 0.047, 0.92), UiKit.BRONZE, 4, 6)
	frame.content_margin_left = 10
	frame.content_margin_right = 14
	frame.content_margin_top = 4
	frame.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", frame)
	add_child(plate)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)
	var icon := ItemIcon.make("kind:scroll", ICON, true)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	label = UiKit.label(FONT, UiKit.sized(TEXT_SIZE), UiKit.BRONZE.lightened(0.25))
	label.text = Lang.t("Spiel gespeichert")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	plate.modulate.a = 0.0
	plate.visible = false


## Shows the plate (again, from the start, if it still shows).
func flash() -> void:
	if plate == null:
		return
	label.text = Lang.t("Spiel gespeichert")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	plate.visible = true
	_tween = create_tween()
	_tween.tween_property(plate, "modulate:a", 1.0, FADE_IN * (1.0 - plate.modulate.a))
	_tween.tween_interval(HOLD)
	_tween.tween_property(plate, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): plate.visible = false)


## True while the plate can be seen.
func showing() -> bool:
	return plate != null and plate.visible and plate.modulate.a > 0.0
