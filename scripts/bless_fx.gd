class_name BlessFx
extends Node3D
## The light of a blessing (see BlessRound): a disc of glowing rings and runes laid on the ground and
## turning slowly, a soft column of light over it, golden motes drifting up and a warm lamp that
## swells and fades. Purely for show. The "warm" kind (thawing Fritz) is amber, with drifting steam.
## Takes LIFE seconds and frees itself.

const LIFE := 4.2
const SWELL := 0.7
const FADE := 1.6
const COLUMN_HEIGHT := 3.4
const GOLD := Color(1.0, 0.74, 0.28)
const AMBER := Color(1.0, 0.6, 0.28)

const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 tint = vec3(1.0, 0.85, 0.45);
uniform float strength = 1.0;
uniform float spin = 0.0;

float ring(float r, float c, float w) {
	return smoothstep(w, 0.0, abs(r - c));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + spin;
	float v = 0.0;
	v += ring(r, 0.93, 0.03);
	v += ring(r, 0.66, 0.018) * 0.7;
	v += ring(r, 0.40, 0.02) * 0.6;
	// Twelve runes in the band between the two outer rings: a bar, a cross or a chevron each.
	float seg = 6.2831853 / 12.0;
	float ia = mod(a, seg) - seg * 0.5;
	float id = floor(a / seg);
	vec2 q = vec2(ia * r, r - 0.795) * 15.0;
	float k = mod(id, 3.0);
	float g = smoothstep(0.14, 0.0, abs(q.x)) * step(abs(q.y), 0.55);
	if (k > 0.5) {
		g = max(g, smoothstep(0.14, 0.0, abs(q.y)) * step(abs(q.x), 0.45));
	}
	if (k > 1.5) {
		g = max(g, smoothstep(0.16, 0.0, abs(abs(q.x) - q.y * 0.9 - 0.2)) * step(abs(q.y), 0.55));
	}
	v += g * step(r, 0.9) * step(0.69, r);
	// A star of rays inside, and a soft glow over everything.
	v += pow(abs(cos(a * 4.0)), 24.0) * smoothstep(0.62, 0.05, r) * 0.55;
	v += smoothstep(1.0, 0.0, r) * 0.2;
	v *= smoothstep(1.0, 0.92, r);
	ALBEDO = tint * v * strength;
	ALPHA = 1.0;
	ALBEDO = gl_colour(ALBEDO);
}
"""

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 tint = vec3(1.0, 0.85, 0.45);
uniform float strength = 1.0;
uniform float height = 3.4;
varying float up;

void vertex() {
	up = VERTEX.y / height + 0.5;
}

void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.4);
	float rise = pow(clamp(1.0 - up, 0.0, 1.0), 1.6);
	ALBEDO = tint * edge * rise * strength * 0.55;
	ALPHA = 1.0;
	ALBEDO = gl_colour(ALBEDO);
}
"""

static var _disc_shader: Shader
static var _column_shader: Shader

var kind := "bless"
var radius := 2.4
var _age := 0.0
var _disc: MeshInstance3D
var _column: MeshInstance3D
var _disc_mat: ShaderMaterial
var _column_mat: ShaderMaterial
var _light: OmniLight3D
var _tint := GOLD


## Lays a blessing of `kind` ("bless" or "warm") on the ground at `at` (world), `radius` metres wide.
static func cast(level: Node, at: Vector3, which: String, wide: float) -> BlessFx:
	var fx := BlessFx.new()
	fx.kind = which
	fx.radius = wide
	fx.name = "BlessFx"
	level.add_child(fx)
	fx.global_position = Vector3(at.x, at.y + 0.06, at.z)
	return fx


func _ready() -> void:
	_tint = AMBER if kind == "warm" else GOLD
	if _disc_shader == null:
		_disc_shader = Shader.new()
		_disc_shader.code = DISC_SHADER
		_column_shader = Shader.new()
		_column_shader.code = COLUMN_SHADER
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = _disc_shader
	_disc_mat.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	_disc = MeshInstance3D.new()
	_disc.mesh = quad
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_column_mat = ShaderMaterial.new()
	_column_mat.shader = _column_shader
	_column_mat.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))
	_column_mat.set_shader_parameter("height", COLUMN_HEIGHT)
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.18
	cyl.bottom_radius = radius * 0.42
	cyl.height = COLUMN_HEIGHT
	cyl.radial_segments = 24
	cyl.rings = 1
	_column = MeshInstance3D.new()
	_column.mesh = cyl
	_column.material_override = _column_mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position.y = COLUMN_HEIGHT * 0.5
	add_child(_column)
	_light = OmniLight3D.new()
	_light.light_color = _tint
	_light.omni_range = radius * 2.6
	_light.light_energy = 0.0
	_light.position.y = 1.4
	add_child(_light)
	# Motes rising off the ring.
	var motes := Effects.make_sparkles(Color(_tint, 0.95), false)
	motes.amount = 36
	motes.lifetime = 2.2
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = radius * 0.8
	motes.emission_ring_inner_radius = radius * 0.2
	motes.emission_ring_height = 0.1
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3(0, 0.4, 0)
	motes.initial_velocity_min = 0.5
	motes.initial_velocity_max = 1.3
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.1
	add_child(motes)
	if kind == "warm":
		var steam := Effects.make_sparkles(Color(0.92, 0.94, 1.0, 0.5), false)
		steam.amount = 16
		steam.lifetime = 2.6
		steam.emission_sphere_radius = radius * 0.45
		steam.direction = Vector3.UP
		steam.spread = 25.0
		steam.gravity = Vector3(0, 0.25, 0)
		steam.initial_velocity_min = 0.3
		steam.initial_velocity_max = 0.7
		steam.scale_amount_min = 2.2
		steam.scale_amount_max = 3.6
		steam.position.y = 0.6
		add_child(steam)
	_apply()


## How strong the light is at an age: swells in, holds, fades out (0 to 1).
static func strength_at(age: float) -> float:
	var swell := clampf(age / SWELL, 0.0, 1.0)
	var fade := clampf((LIFE - age) / FADE, 0.0, 1.0)
	return swell * swell * (3.0 - 2.0 * swell) * fade


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_apply()


func _apply() -> void:
	var s := strength_at(_age)
	var pulse := 1.0 + 0.1 * sin(_age * 9.0)
	_disc_mat.set_shader_parameter("strength", s * 1.2 * pulse)
	_disc_mat.set_shader_parameter("spin", _age * 0.5)
	_column_mat.set_shader_parameter("strength", s * pulse)
	_light.light_energy = 1.8 * s * pulse
	# The disc opens from the middle as the light swells in.
	var open := lerpf(0.4, 1.0, clampf(_age / SWELL, 0.0, 1.0))
	_disc.scale = Vector3(open, 1.0, open)
