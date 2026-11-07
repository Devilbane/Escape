class_name FogClouds
extends MeshInstance3D
## Large, soft fog clouds drifting over the open air in fog weather (see
## Weather and shaders/fog_clouds.gdshader). One full-screen pass with a tiling
## noise texture: no particles. The pass draws first among all see-through
## things (PRIORITY), so labels, bubbles and particles are never covered.

## Lower than every label and particle (damage numbers 19-20, bubbles 20-22,
## news over the fog of war 109-110).
const PRIORITY := -128
## Noise tile size in pixels.
const NOISE_SIZE := 256
## How fast the wind carries the clouds (texture units per second).
const WIND := Vector2(0.0042, 0.0016)
## How far (0 to 1) the cloud cover swells and thins around its mean.
const BREATH := 0.05
## Cover of the ground by clouds at full strength.
const COVERAGE := 0.5

var _mat: ShaderMaterial
var _time := 0.0


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mesh = quad
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/fog_clouds.gdshader")
	_mat.render_priority = PRIORITY
	_mat.set_shader_parameter("noise_tex", make_noise())
	_mat.set_shader_parameter("coverage", COVERAGE)
	material_override = _mat
	visible = false


## A tiling soft noise, the shape of the clouds.
static func make_noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 4711
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.012
	var image := noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE, false, false, 0.2, true)
	image.convert(Image.FORMAT_L8)
	return ImageTexture.create_from_image(image)


## Thickness of the clouds (0 none to 1 full) and their colour. Hidden, and
## not drawn at all, when there are none.
func set_look(strength: float, haze: Color) -> void:
	visible = strength > 0.02
	_mat.set_shader_parameter("strength", strength)
	_mat.set_shader_parameter("haze", Vector3(haze.r, haze.g, haze.b))


func strength() -> float:
	return _mat.get_shader_parameter("strength")


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_mat.set_shader_parameter("drift", WIND * _time)
	_mat.set_shader_parameter("breathe", sin(_time * 0.05) * BREATH)
