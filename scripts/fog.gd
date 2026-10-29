class_name Fog
extends MeshInstance3D
## Line-of-sight fog of war. Tiles in view are clear, tiles seen before are
## grey, and tiles never seen stay black.

const SIGHT_RADIUS := 8
const FADE_SPEED := 6.0

var level: Level
var _visible_target := PackedFloat32Array()
var _visible := PackedFloat32Array()
var _explored := PackedFloat32Array()
var _image: Image
var _texture: ImageTexture
var _last_cell := Vector2i(-999, -999)


func setup(owner_level: Level) -> void:
	level = owner_level
	var n := level.width * level.height
	_visible_target.resize(n)
	_visible.resize(n)
	_explored.resize(n)
	_image = Image.create(level.width, level.height, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	_texture = ImageTexture.create_from_image(_image)

	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mesh = quad
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fog.gdshader")
	mat.render_priority = 100
	mat.set_shader_parameter("fog_tex", _texture)
	mat.set_shader_parameter("grid_size", Vector2(level.width, level.height))
	mat.set_shader_parameter("tile", Level.TILE)
	material_override = mat


func is_cell_visible(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= level.width or c.y >= level.height:
		return false
	return _visible_target[c.y * level.width + c.x] > 0.5


func _recompute(origin: Vector3) -> void:
	_visible_target.fill(0.0)
	var center := level.world_to_cell(origin)
	for y in range(center.y - SIGHT_RADIUS, center.y + SIGHT_RADIUS + 1):
		for x in range(center.x - SIGHT_RADIUS, center.x + SIGHT_RADIUS + 1):
			if x < 0 or y < 0 or x >= level.width or y >= level.height:
				continue
			var c := Vector2i(x, y)
			if (c - center).length() > SIGHT_RADIUS + 0.5:
				continue
			if level.has_line_of_sight(origin, level.cell_to_world(c)):
				var i := y * level.width + x
				_visible_target[i] = 1.0
				_explored[i] = 1.0


func _process(delta: float) -> void:
	if level.player == null:
		return
	var cell := level.world_to_cell(level.player.global_position)
	if cell != _last_cell or Engine.get_process_frames() % 10 == 0:
		_last_cell = cell
		_recompute(level.player.global_position)
	var t := minf(1.0, delta * FADE_SPEED)
	for y in level.height:
		for x in level.width:
			var i := y * level.width + x
			_visible[i] = lerpf(_visible[i], _visible_target[i], t)
			_image.set_pixel(x, y, Color(_visible[i], _explored[i], 0, 1))
	_texture.update(_image)
