shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
// Snow on leaves and other cut-out cards (bushes, ivy, roof vines), see SnowCover: like
// snow_cover, but it keeps to the shape of the card (the alpha of its texture), so a leaf
// gets a white top and no white square round it. Leaves catch snow more readily than a
// roof: a card turned only a little towards the sky already holds some.

#include "res://shaders/snow.gdshaderinc"

uniform sampler2D cutout : filter_linear_mipmap_anisotropic;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor = 0.5;
// How readily snow settles on a card's upper rim even when it stands upright (the ivy's leaves
// on the walls): 0 keeps to what faces the sky.
uniform float cling = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
// How high this point of the card stands over the card's anchor, in card sizes.
varying float rise;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Seen from either side, a card's snow lies on its upper face.
	if (wn.y < 0.0) {
		wn = -wn;
	}
	vec3 anchor = MODEL_MATRIX[3].xyz;
	rise = (wp.y - anchor.y) / max(length(MODEL_MATRIX[0].xyz), 0.001);
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
	// The upper rim of a clinging card: the higher on the card, the more snow.
	lies = max(lies, cling * amount * smoothstep(0.2, 0.55, rise) * 1.6 + (n - 0.5) * 0.5);
	if (lies < 0.5 || snow_melted(world_pos, n) || snow_sheltered(world_pos)) {
		discard;
	}
	snow_look(world_pos, world_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.08 * mix(0.4, 1.0, daylight);
	ALBEDO = gl_colour(ALBEDO);
}
