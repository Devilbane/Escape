shader_type spatial;
// Rough stone for the dungeon walls. The kit's wall texture gives each brick a
// flat, even face, which looks like plastic where a torch shines on it. This
// keeps the kit's colour and normal map and adds stains, grain and small pits
// in world space (so they run on across wall pieces instead of repeating),
// with a matt, barely glossy surface.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 albedo_color : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos;
	float px = length(fwidth(p));
	// Stains about a metre across, the grain of the stone, small pits and sand.
	float stains = fbm(p * 0.8);
	float grit = fbm(p * 5.0);
	float pits = smoothstep(0.62, 0.8, vnoise(p * 16.0)) * band(16.0, px);
	float sand = (vnoise(p * 40.0) - 0.5) * band(40.0, px);
	float shade = 1.0 + 0.24 * (stains - 0.5) + 0.16 * (grit - 0.5) - 0.14 * pits + 0.08 * sand;
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_color * shade;
	float h = grit * 0.02 * band(5.0, px) - pits * 0.004 + sand * 0.0015;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = 0.92 + 0.08 * grit;
	SPECULAR = 0.2;
}
