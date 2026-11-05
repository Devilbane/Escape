shader_type spatial;
// Rough stone for the dungeon walls and the stone of the cartoon pieces. The kit's wall texture gives each brick a
// flat, even face, which looks like plastic where a torch shines on it. This
// keeps the kit's colour and normal map and adds stains, grain and small pits
// in world space (so they run on across wall pieces instead of repeating),
// with a matt, barely glossy surface.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 albedo_color : source_color = vec3(1.0);
// The flat cartoon pieces (spike and grate tiles, stairs, doorways) have no
// normal map and need a little more grain to match the kit's carved stone.
uniform bool use_normal_map = true;
uniform float strength = 1.0;
// 1 turns the texture grey (keeping its light and dark) before albedo_color.
uniform float desaturate = 0.0;
// How see-through this piece is (0 solid, 1 gone): a near wall in front of
// the hero (see WallFade). Pixels drop out in a fine even pattern, so the
// wall stays an ordinary solid one in the opaque pass.
instance uniform float fade = 0.0;

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
	float shade = 1.0 + strength * (0.24 * (stains - 0.5) + 0.16 * (grit - 0.5) - 0.14 * pits + 0.08 * sand);
	vec3 c = texture(albedo_tex, UV).rgb;
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), desaturate);
	ALBEDO = c * albedo_color * shade;
	float h = strength * (grit * 0.02 * band(5.0, px) - pits * 0.004 + sand * 0.0015);
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ROUGHNESS = 0.92 + 0.08 * grit;
	SPECULAR = 0.2;
	if (fade > 0.0) {
		// A 4 x 4 ordered dither: the share of pixels dropped is the fade.
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(bayer[q.y * 4 + q.x]) + 0.5) / 16.0 < fade) {
			discard;
		}
	}
}
