shader_type spatial;
render_mode cull_disabled;
// Snow on leaves and other cut-out cards (bushes, ivy, roof vines), see SnowCover: like
// snow_cover, but it keeps to the shape of the card (the alpha of its texture), so a leaf
// gets a white top and no white square round it. Leaves catch snow more readily than a
// roof: a card turned only a little towards the sky already holds some.

#include "res://shaders/snow.gdshaderinc"

uniform sampler2D cutout : source_color, filter_linear_mipmap;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Seen from either side, a card's snow lies on its upper face.
	if (wn.y < 0.0) {
		wn = -wn;
	}
	wp += wn * 0.01;
	world_pos = wp;
	world_normal = wn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	if (texture(cutout, UV).a < alpha_scissor) {
		discard;
	}
	float up = smoothstep(0.25, 0.75, world_normal.y);
	vec2 xz = world_pos.xz;
	float n = snow_noise(xz * 2.1) * 0.6 + snow_noise(xz * 7.0 + 3.0) * 0.4;
	float lies = up * amount * 1.7 + (n - 0.5) * 0.6;
	if (lies < 0.5 || snow_melted(world_pos, n)) {
		discard;
	}
	snow_look(world_pos, world_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
