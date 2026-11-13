class_name WindowLights
extends RefCounted
## The village going to sleep, window by window. Every pane of a house (and the
## pool of light it throws, see WindowSpill) has its own bedtime between
## OFF_FROM and OFF_TO, worked out in the shader from where the pane stands, so
## it is the same every night and after every load, and nothing is stored.
## The panes go dark in a short fade, and stay dark until the day breaks. The
## temple's windows do not use this: they burn all night.

## Hours of the clock between which the first and the last window is lit in
## the evening (each fades in over FADE; the dusk's own glow rises meanwhile).
const ON_FROM := 18.0
const ON_TO := 20.4
## Hours of the clock between which the first and the last window goes out.
const OFF_FROM := 20.0
const OFF_TO := 22.9
## How long one window takes to fade, in hours.
const FADE := 0.1

## GLSL: how lit (0 to 1) the window with this key is at this hour. The key
## is the pane's place in its house plus the house's place in the world.
const LIT_FUNCTION := """
uniform float hour = 12.0;
float window_lit(vec2 place) {
	vec2 k = floor(place * 4.0 + 0.5);
	float h = fract(sin(dot(k, vec2(12.9898, 78.233))) * 43758.5453);
	float off = mix(%f, %f, h);
	float h2 = fract(sin(dot(k, vec2(39.346, 11.135))) * 24634.6345);
	float on = mix(%f, %f, h2);
	// After midnight everyone sleeps; the glow itself fades with the dawn.
	if (hour < 12.0) {
		return 0.0;
	}
	return smoothstep(on, on + %f, hour) * (1.0 - smoothstep(off, off + %f, hour));
}
""" % [OFF_FROM, OFF_TO, ON_FROM, ON_TO, FADE, FADE]

const GLASS_SHADER := """
shader_type spatial;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
varying vec2 key;
""" + LIT_FUNCTION + """
void vertex() {
	key = UV2 + MODEL_MATRIX[3].xz;
}
void fragment() {
	ALBEDO = vec3(0.16, 0.18, 0.22);
	ROUGHNESS = 0.25;
	EMISSION = colour * glow * window_lit(key);
}
"""


## Where a pane stands, as one number pair both the glass and its light pool
## carry, so that the two go out together.
static func key(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z + at.y * 3.1)


## The glass of the houses' windows; `light` is the glow colour.
static func glass_material(light: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GLASS_SHADER
	mat.shader = shader
	mat.set_shader_parameter("colour", Vector3(light.r, light.g, light.b))
	mat.set_shader_parameter("glow", 0.0)
	mat.set_shader_parameter("hour", 12.0)
	return mat
