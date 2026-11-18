shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;
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
	ALBEDO = mix(vec3(0.62, 0.74, 0.86), vec3(0.92, 0.96, 1.0), rim);
	ALPHA = 0.55 + 0.35 * rim;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = vec3(0.4, 0.55, 0.8) * 0.04 * (1.0 - daylight);
}
