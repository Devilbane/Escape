shader_type spatial;
render_mode cull_disabled;
// The mountains round Nohpaan (see Nohpaan.dress): jagged peaks of grey rock with strata and cracks, alpine turf on
// the low slopes and snow above the snow line, all drawn from noise in world space, so every peak differs and
// none repeats.
#include "res://shaders/gl_colour.gdshaderinc"

uniform vec3 rock_light = vec3(0.62, 0.6, 0.57);
uniform vec3 rock_dark = vec3(0.26, 0.25, 0.27);
uniform vec3 turf = vec3(0.3, 0.44, 0.2);
uniform float snow_line = 13.0;
uniform float turf_line = 7.5;

varying vec3 world_pos;
varying vec3 world_normal;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return 0.5 * n3(p) + 0.3 * n3(p * 2.1 + 3.3) + 0.2 * n3(p * 4.3 + 8.1);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Roughen the cone into crags: push the vertices in and out along their normal.
	float crag = fbm3(w * 0.3) - 0.5;
	float ridge = abs(n3(w * 0.22 + 7.0) - 0.5);
	VERTEX += NORMAL * (crag * 4.6 - ridge * 3.0);
	VERTEX.xz += vec2(n3(w * 0.5) - 0.5, n3(w * 0.5 + 4.0) - 0.5) * 1.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos;
	float grain = fbm3(p * 1.4);
	float layer = sin((p.y + 0.35 * p.x + 0.2 * p.z) * 1.7 + 4.0 * fbm3(p * 0.35)) * 0.5 + 0.5;
	float crack = smoothstep(0.04, 0.0, abs(n3(p * 0.9) - 0.5));
	vec3 col = mix(rock_dark, rock_light, clamp(0.25 + 0.55 * layer + 0.4 * (grain - 0.5), 0.0, 1.0));
	col *= 1.0 - 0.35 * crack;
	float steep = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	// Turf on the gentle low slopes.
	float turf_k = smoothstep(turf_line, turf_line - 2.5, p.y + 3.0 * (grain - 0.5)) * smoothstep(0.7, 0.35, steep);
	col = mix(col, turf * (0.75 + 0.5 * grain), turf_k);
	// Snow above the snow line, thicker on the flat faces.
	float snow_k = smoothstep(snow_line - 1.0, snow_line + 3.0, p.y + 6.0 * (fbm3(p * 0.6) - 0.5)) * smoothstep(0.62, 0.3, steep + 0.25 * (grain - 0.5));
	col = mix(col, vec3(0.94, 0.96, 1.0), snow_k);
	ROUGHNESS = mix(0.95, 0.55, snow_k);
	SPECULAR = 0.2 + 0.3 * snow_k;
	ALBEDO = col;
	ALBEDO = gl_colour(ALBEDO);
}
