shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;
#include "res://shaders/gl_colour.gdshaderinc"
// Icicles under the eaves and the window tops (see SnowCaps): clear, glassy ice hanging from
// the roll of snow. They ride on the snow as it grows (CUSTOM0) and lengthen once it lies
// deep (CUSTOM1), and shrink back into it as it melts.

#include "res://shaders/snow.gdshaderinc"

varying vec3 world_pos;

float ice_growth() {
	return smoothstep(0.35, 1.0, amount);
}

void vertex() {
	VERTEX += CUSTOM0.xyz * smoothstep(0.08, 0.9, amount) + CUSTOM1.xyz * ice_growth();
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (ice_growth() < 0.01 || snow_melted(world_pos, 0.5)) {
		discard;
	}
	// Bluish, see-through ice, clearer towards the tip and bright at its edges.
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = mix(vec3(0.45, 0.78, 0.98), vec3(0.85, 0.97, 1.0), rim);
	ALPHA = 0.6 + 0.35 * rim;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	// A soft crystal glow, stronger at the rim, so the ice reads as glinting by day and night.
	EMISSION = vec3(0.35, 0.7, 1.0) * (0.12 + 0.25 * rim) + vec3(0.4, 0.55, 0.8) * 0.04 * (1.0 - daylight);
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
