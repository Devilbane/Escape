class_name BossBar
extends CanvasLayer
## The health bar of a boss, at the top of the screen: his name, his life
## and marks where his next phases begin. It shows while he hunts the hero
## nearby (or is hurt and close), and fades away otherwise.
## A boss (BanditChief, Dragon) has boss_title(), phase_marks(), max_hp(),
## is_dazed() and a phase.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
const WIDTH := 460.0
## The bar shows while the boss is this close to the hero (metres).
const SHOW_RANGE := 34.0
const FILL := [Color(0.78, 0.18, 0.14), Color(0.9, 0.42, 0.12), Color(1.0, 0.16, 0.1)]

var boss
var bar: ProgressBar
var _box: VBoxContainer
var _name: Label
var _fill: StyleBoxFlat


func _init(who: Node) -> void:
	boss = who
	layer = 2


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.offset_left = -WIDTH * 0.5
	_box.offset_right = WIDTH * 0.5
	_box.offset_top = 22
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 4)
	_box.modulate.a = 0.0
	add_child(_box)
	_name = Label.new()
	_name.text = boss.named_with_level(Lang.t(boss.boss_title()))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", FONT)
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.6))
	_name.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.06))
	_name.add_theme_constant_override("outline_size", 5)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_name)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(WIDTH, 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := BronzeStyle.new()
	back.bg_color = UiKit.BUTTON_BG
	back.border_color = Color(0.85, 0.66, 0.32, 0.9)
	back.set_border_width_all(2)
	back.set_corner_radius_all(6)
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(6)
	_fill.bg_color = FILL[0]
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", _fill)
	_box.add_child(bar)
	# Thin marks where phase 2 and phase 3 begin.
	for share in boss.phase_marks():
		var mark := ColorRect.new()
		mark.color = Color(1.0, 0.9, 0.6, 0.8)
		mark.size = Vector2(2, 18)
		mark.position = Vector2(WIDTH * share - 1.0, 0)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(mark)


## Whether the bar is meant to show right now.
func wanted() -> bool:
	if not is_instance_valid(boss) or boss.dead or boss.level == null or boss.level.player == null:
		return false
	var player: Player = boss.level.player
	if player.dead:
		return false
	var dist: float = boss.global_position.distance_to(player.global_position)
	return dist < SHOW_RANGE and (boss.is_hunting() or boss.hp < boss.max_hp())


func _process(delta: float) -> void:
	var on := wanted()
	_box.modulate.a = move_toward(_box.modulate.a, 1.0 if on else 0.0, delta * 3.0)
	if not is_instance_valid(boss):
		if _box.modulate.a <= 0.0:
			queue_free()
		return
	bar.max_value = boss.max_hp()
	bar.value = maxi(0, boss.hp)
	_fill.bg_color = FILL[clampi(boss.phase - 1, 0, FILL.size() - 1)]
	if boss.is_dazed():
		_fill.bg_color = _fill.bg_color.lerp(Color(1.0, 0.95, 0.5), 0.5)
