class_name WallRain
extends RefCounted
## The rain of the climbing wall (see WallStage): thin, soft, slightly slanted streaks that fade with distance, and
## small splashes on the rock where the drops hit. Both are cheap particles with a soft-edged shader.

const DROP_SHADER := preload("res://shaders/wall_rain.gdshader")
const SPLASH_SHADER := preload("res://shaders/wall_splash.gdshader")
## How far the top of a drop leans (metres per metre of its length) with the wind.
const SLANT := 0.16


## A drop: a quad `width` wide and `length` tall, sheared by SLANT, with the streak shader.
static func drop_mesh(width := 0.014, length := 0.7) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var lean := -length * SLANT   # the top trails upwind of the fall
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-width * 0.5, 0, 0), Vector3(width * 0.5, 0, 0), Vector3(width * 0.5 + lean, length, 0), Vector3(-width * 0.5 + lean, length, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = DROP_SHADER
	mesh.surface_set_material(0, mat)
	return mesh


## The splashes on the face: little rings in a box over the climber, `amount` of them.
static func splashes(amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Splashes"
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 6.0, 0.02)
	p.direction = Vector3.ZERO
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat := ShaderMaterial.new()
	mat.shader = SPLASH_SHADER
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
