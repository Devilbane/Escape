class_name SlimeBar
extends Node3D
## The health bar of a slime with its level beside it, floating over its head.
## It follows the rules of the bosses' bar (see BossBar): it shows while the
## slime hunts the hero nearby, or is hurt and close, and fades away otherwise.
## It grows with the slime, a little less than the slime does, so a lump stays
## readable and a hulk's bar does not cover the screen. The red is the bosses'.

const FONT := preload("res://assets/fonts/Cinzel-Bold.woff2")
## The bar shows while the slime is this close to the hero (metres).
const SHOW_RANGE := 16.0
## Width of the bar in metres: WIDTH_BASE plus WIDTH_PER_SIZE per unit of slime size, never over WIDTH_TOP.
const WIDTH_BASE := 0.7
const WIDTH_PER_SIZE := 0.5
const WIDTH_TOP := 2.2
## The bar's thickness against its width, with a floor in metres.
const THICKNESS := 0.11
const THICKNESS_MIN := 0.1
const RIM := 0.02
const BACK := Color(0.07, 0.05, 0.08, 0.85)
const RIM_COLOUR := Color(0.85, 0.66, 0.32, 0.9)
const LEVEL_COLOUR := Color(1.0, 0.86, 0.6)

var slime: Enemy
var _width := 1.0
var _fill: MeshInstance3D
var _label: Label3D
var _mats: Array[StandardMaterial3D] = []
var _opacity: Array[float] = []
var _alpha := 0.0
var _shown_level := -1


func _init(who: Enemy) -> void:
	slime = who


func _ready() -> void:
	var size := float(slime._stats.size)
	_width = clampf(WIDTH_BASE + WIDTH_PER_SIZE * size, WIDTH_BASE + WIDTH_PER_SIZE * 0.6, WIDTH_TOP)
	var thick := maxf(THICKNESS_MIN, _width * THICKNESS)
	_quad(Vector2(_width + RIM * 2.0, thick + RIM * 2.0), RIM_COLOUR, 0)
	_quad(Vector2(_width, thick), BACK, 1)
	_fill = _quad(Vector2(_width, thick), SlimeBar.fill_colour(), 2)
	# The fill grows from the left edge.
	(_fill.mesh as QuadMesh).center_offset = Vector3(_width * 0.5, 0, 0)
	_fill.position.x = -_width * 0.5
	_label = Label3D.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.font = FONT
	_label.font_size = 32
	_label.pixel_size = thick * 1.7 / 32.0
	_label.outline_size = 10
	_label.outline_modulate = Color(0.05, 0.03, 0.06, 0.9)
	_label.modulate = LEVEL_COLOUR
	_label.no_depth_test = true
	_label.render_priority = 13
	_label.outline_render_priority = 12
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.position.x = -_width * 0.5 - RIM * 3.0
	add_child(_label)
	_set_alpha(0.0)


## The bosses' red.
static func fill_colour() -> Color:
	return BossBar.FILL[0]


func _quad(size: Vector2, colour: Color, order: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10 + order
	mat.albedo_color = colour
	mesh.material = mat
	_mats.append(mat)
	_opacity.append(colour.a)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## Whether the bar is meant to show right now.
func wanted() -> bool:
	if slime.dead or not slime.visible or slime.level == null or slime.level.player == null:
		return false
	var player: Player = slime.level.player
	if player.dead:
		return false
	var dist: float = slime.global_position.distance_to(player.global_position)
	return dist < SHOW_RANGE and (slime.is_hunting() or slime.hp < slime.max_hp())


func _set_alpha(a: float) -> void:
	_alpha = a
	visible = a > 0.01
	for i in _mats.size():
		_mats[i].albedo_color.a = a * _opacity[i]
	_label.modulate.a = a
	_label.outline_modulate.a = a * 0.9


func _process(delta: float) -> void:
	var target := 1.0 if wanted() else 0.0
	if _alpha != target:
		_set_alpha(move_toward(_alpha, target, delta * 3.0))
	if not visible:
		return
	# Faces the camera whichever way it looks (a billboard of several parts
	# would leave the fill behind its offset).
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_basis = cam.global_basis
	# Over the head, following the slime as it swells (its model's scale).
	var grown: float = slime._model.scale.x if slime._model != null else float(slime._stats.size)
	position.y = slime._slime_height * grown + 0.35
	var max_hp := maxi(1, slime.max_hp())
	var hp := clampi(slime.hp, 0, max_hp)
	_fill.scale.x = maxf(0.001, float(hp) / float(max_hp))
	if slime.rated_level != _shown_level:
		_shown_level = slime.rated_level
		_label.text = Lang.t("Stufe %d") % _shown_level
