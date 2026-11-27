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
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec3 world_pos;

// A tiling soft noise (see FogClouds.make_noise), read with linear filtering: smooth everywhere. The mist used a
// sin() hash for value noise before; on some graphics cards its rounding differed from one tile to the next
// and the mist showed hard-edged squares.
float fbm2(vec2 p) {
	float big = texture(noise_tex, p * 0.37).r;
	float small = texture(noise_tex, p * 0.85 + vec2(0.31, 0.57)).r;
	return 0.62 * big + 0.38 * small;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + drift * TIME * 0.03;
	float cover = smoothstep(0.4, 0.74, fbm2(p) + 0.12 * fbm2(p * 2.3 - drift * TIME * 0.02));
	float near = smoothstep(clear_radius * 0.35, clear_radius, distance(world_pos.xz, hero.xz));
	float alpha = clamp(cover * density * near, 0.0, 0.9);
	ALPHA = gl_alpha(gl_colour(tint), alpha);
	ALBEDO = tint;
	ALBEDO = gl_colour(ALBEDO);
}
