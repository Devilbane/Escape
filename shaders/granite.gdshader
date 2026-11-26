shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// Natural granite for the village wall (see Granite): a coarse mix of grey and pinkish feldspar,
// pale quartz grains and dark specks of mica, in patches of a metre or so, and every stone its own
// shade. A little lichen settles on what faces up, worn rims and chipped edges are paler, and the
// surface is rough and matt with a few glinting grains. The pattern is laid in the stone's own space,
// so it moves with it. Fine detail fades out where it would be smaller than a few pixels.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo_color = vec3(0.55);

varying vec3 obj_pos;
varying vec3 world_pos;
varying vec3 world_nrm;
varying float stone_id;

void vertex() {
	obj_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	stone_id = hash3(floor(NODE_POSITION_WORLD * 8.0) + vec3(5.0, 3.0, 1.0));
}

void fragment() {
	float px = length(fwidth(world_pos));
	vec3 p = obj_pos + vec3(stone_id * 41.0, stone_id * 13.0, stone_id * 27.0);
	// Patches of paler and darker rock, and of faint pink feldspar.
	float blotch = fbm(p * 1.4);
	float pink = smoothstep(0.42, 0.7, fbm(p * 2.3 + 3.0));
	float coarse = fbm(p * 7.0 + 11.0);
	vec3 col = albedo_color * (0.84 + 0.3 * blotch) * (0.92 + 0.16 * stone_id);
	col = mix(col, col * vec3(1.02, 0.99, 0.98), pink * 0.3);
	col *= 0.93 + 0.14 * coarse;
	// Quartz (pale), feldspar (warm) and mica or hornblende (dark): the speckle of granite.
	float quartz = smoothstep(0.7, 0.82, vnoise(p * 46.0)) * band(46.0, px);
	float feldspar = smoothstep(0.72, 0.84, vnoise(p * 38.0 + 17.0)) * band(38.0, px);
	float mica = smoothstep(0.74, 0.86, vnoise(p * 62.0 + 29.0)) * band(62.0, px);
	col = mix(col, vec3(0.88, 0.89, 0.9), quartz * 0.45);
	col = mix(col, vec3(0.68, 0.65, 0.63), feldspar * 0.25);
	col = mix(col, vec3(0.1, 0.1, 0.11), mica * 0.7);
	col *= 1.0 + (vnoise(p * 140.0) - 0.5) * 0.14 * band(140.0, px);
	// Lichen on the upward faces, low in contrast.
	float up = smoothstep(0.55, 0.95, world_nrm.y);
	float lichen = smoothstep(0.58, 0.76, fbm(p * 3.2 + 21.0)) * up;
	col = mix(col, vec3(0.5, 0.54, 0.42), lichen * 0.2);
	// Edges that turn sharply (a rim, a chip) are paler where the stone has been rubbed or split.
	float turn = clamp(length(fwidth(world_nrm)) * 5.0, 0.0, 1.0);
	col *= 1.0 + turn * 0.12;
	// The relief: grain and pits on the surface.
	float h = (fbm(p * 9.0) - 0.5) * 0.012 * band(9.0, px) + (vnoise(p * 30.0) - 0.5) * 0.004 * band(30.0, px) - mica * 0.002;
	ALBEDO = col;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	// Quartz grains stay matt enough not to sparkle in single pixels in the sun.
	ROUGHNESS = 0.88 - 0.15 * quartz;
	SPECULAR = 0.25 + 0.15 * quartz;
	ALBEDO = gl_colour(ALBEDO);
}
