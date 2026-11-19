shader_type spatial;
render_mode cull_back;
// The snow of the snowman (see Snowman): the very look of the snow on the ground tiles (see
// snow.gdshaderinc), so he is the same cold off-white with blue-grey hollows, the same grain and
// bumps, and is lit by the light of the hour and the lamps like the ground, not glowing by itself.

#include "res://shaders/snow.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	snow_look(world_pos, world_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	ROUGHNESS = 0.85;
	SPECULAR = 0.3 * mix(0.4, 1.0, daylight);
}
