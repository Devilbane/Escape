shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// Bare, dug earth on the floor and walls of a cellar (see BareEarth). The soil
// picture is laid in world space on every face (triplanar), so squares and walls
// join. So that it never shows as a repeating tile, it is laid twice, at two sizes
// whose ratio never lines up and turned against each other, and a slow, cloudy
// noise decides from place to place which of the two shows. The same noise
// darkens damp stretches and pales dry ones over a few metres.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D soil : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres one copy of the picture covers, in the first and second layer.
uniform float size_a = 1.6;
uniform float size_b = 2.47;
// How far the second layer is turned (radians) and shifted.
uniform float turn_b = 0.83;
uniform vec2 shift_b = vec2(0.37, 0.71);
// Metres across one patch of the cloudy noise that mixes the layers.
uniform float patch = 3.1;
// How strongly damp and dry stretches darken and pale the soil.
uniform float tone = 0.22;
uniform float bump = 0.8;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// The colour and the tilt of the soil at one flat spot (uv in metres).
void earth(vec2 uv, float mixing, out vec3 colour, out vec2 tilt) {
	vec2 a = uv / size_a;
	float c = cos(turn_b);
	float s = sin(turn_b);
	vec2 b = mat2(vec2(c, s), vec2(-s, c)) * uv / size_b + shift_b;
	colour = mix(texture(soil, a).rgb, texture(soil, b).rgb, mixing);
	vec2 na = texture(soil_normal, a).xy * 2.0 - 1.0;
	vec2 nb = texture(soil_normal, b).xy * 2.0 - 1.0;
	// The second layer's tilt turns with it.
	nb = mat2(vec2(c, -s), vec2(s, c)) * nb;
	tilt = mix(na, nb, mixing);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// One cloudy noise for the whole cellar, floor and walls alike.
	vec3 q = world_pos / patch;
	float mixing = smoothstep(0.38, 0.62, fbm(q));
	float damp = fbm(q * 0.45 + vec3(5.3, 1.7, 9.1));
	vec3 colour = vec3(0.0);
	vec3 tilt = vec3(0.0);
	vec3 c3;
	vec2 t2;
	if (w.x > 0.01) {
		earth(world_pos.zy, mixing, c3, t2);
		colour += c3 * w.x;
		tilt += vec3(0.0, t2.y, t2.x) * w.x;
	}
	if (w.y > 0.01) {
		earth(world_pos.xz, mixing, c3, t2);
		colour += c3 * w.y;
		tilt += vec3(t2.x, 0.0, t2.y) * w.y;
	}
	if (w.z > 0.01) {
		earth(world_pos.xy, mixing, c3, t2);
		colour += c3 * w.z;
		tilt += vec3(t2.x, t2.y, 0.0) * w.z;
	}
	// Damp stretches darker and a touch cooler, dry ones paler.
	float wet = smoothstep(0.3, 0.7, damp) * 2.0 - 1.0;
	colour *= 1.0 - wet * tone;
	colour = mix(colour, colour * vec3(0.92, 0.95, 1.0), max(wet, 0.0) * 0.5);
	ALBEDO = colour;
	ROUGHNESS = 0.95 - max(wet, 0.0) * 0.12;
	vec3 bent = normalize(n + tilt * bump * relief_strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ALBEDO = gl_colour(ALBEDO);
}
