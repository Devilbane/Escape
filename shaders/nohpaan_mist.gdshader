shader_type spatial;
// Drifting valley mist (see Nohpaan, NohpaanLife): a flat sheet low over the meadow whose patchy cover slides
// slowly with the wind and thins out round the hero, so the hero and the ground nearby stay clear.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/gl_colour.gdshaderinc"

uniform vec3 tint = vec3(0.93, 0.97, 1.0);
uniform float density = 0.4;
uniform float scale = 0.03;
uniform vec2 drift = vec2(0.9, 0.35);
uniform vec3 hero = vec3(0.0);
uniform float clear_radius = 7.0;

varying vec3 world_pos;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	return 0.5 * n2(p) + 0.3 * n2(p * 2.1 + 3.7) + 0.2 * n2(p * 4.3 + 9.1);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + drift * TIME * 0.03;
	float cover = smoothstep(0.38, 0.78, fbm2(p) + 0.25 * fbm2(p * 2.3 - drift * TIME * 0.02));
	float near = smoothstep(clear_radius * 0.35, clear_radius, distance(world_pos.xz, hero.xz));
	float alpha = clamp(cover * density * near, 0.0, 0.9);
	ALPHA = gl_alpha(gl_colour(tint), alpha);
	ALBEDO = tint;
	ALBEDO = gl_colour(ALBEDO);
}
