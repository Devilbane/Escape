shader_type spatial;
render_mode cull_back;
#include "res://shaders/gl_colour.gdshaderinc"
// The body of the snow on roofs, ledges and window tops (see SnowCaps): a slab over each
// surface that faces the sky and a rounded, overhanging roll along its open edges. Every
// vertex sits on the surface it covers and is pushed out to its full place (CUSTOM0) as the
// snow deepens, so the caps grow out of the roof and sink back into it as they melt.

#include "res://shaders/snow.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

// How far the snow has grown (0 bare, 1 full), from how much lies.
float snow_growth() {
	return smoothstep(0.08, 0.9, amount);
}

void vertex() {
	// A hair out of the surface it covers even when thin, so the slab never shares a plane with the
	// roof tiles under it (z-fighting, a flicker over the shingles).
	VERTEX += CUSTOM0.xyz * snow_growth() + NORMAL * 0.012;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float n = snow_noise(world_pos.xz * 1.3) * 0.65 + snow_noise(world_pos.xz * 5.0 + 7.0) * 0.35;
	if (snow_growth() < 0.01 || snow_melted(world_pos, n)) {
		discard;
	}
	snow_look(world_pos, world_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	// The underside of an overhang is in its own shadow.
	ALBEDO *= mix(0.78, 1.0, smoothstep(-0.6, 0.2, world_normal.y));
	ROUGHNESS = 0.95;
	SPECULAR = 0.08 * mix(0.4, 1.0, daylight);
	ALBEDO = gl_colour(ALBEDO);
}
