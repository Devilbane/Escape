shader_type spatial;
// The four cave styles for walls and floors (see WallThemes): bone, rock, obsidian
// and crystal. Like stone.gdshader it keeps the kit's block layout and normal map
// (so the joints, the edges and the resolution match the stone dungeon), and
// replaces the colour with a material of its own, built in world space so the
// grain runs on across pieces:
// - bone: ivory with yellow stains, grain along the bones and small pits,
// - rock: grey-brown rock in layers with cracks, pits and sand,
// - obsidian: glossy black glass in facets with sharp highlights,
// - crystal: blue facets with glowing veins that breathe faintly.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// 0 bone, 1 rock, 2 obsidian, 3 crystal.
uniform int style = 0;
// 0 for a wall, 1 for a floor (a little lighter and calmer, so the two stay
// apart), 2 for rough floor.
uniform int surface = 0;
uniform vec3 base_color : source_color = vec3(0.7);
uniform vec3 dark_color : source_color = vec3(0.3);
uniform vec3 glow_color : source_color = vec3(0.4, 0.8, 1.0);
// See stone.gdshader: how see-through a near wall in front of the hero is.
instance uniform float fade = 0.0;

// The relief meshes (see WallShapes) paint their dark parts, such as a skull's
// eye sockets, in the red channel of their vertex colour. The kit's walls leave
// it alone.
uniform bool use_tone = false;

varying vec3 world_pos;
varying float tone;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tone = use_tone ? COLOR.r : 1.0;
}

void fragment() {
	vec3 p = world_pos;
	float px = length(fwidth(p));
	float floor_k = surface == 0 ? 0.0 : 1.0;
	float stains = fbm(p * 0.8);
	float grit = fbm(p * 5.0);
	float pits = smoothstep(0.62, 0.8, vnoise(p * 16.0)) * band(16.0, px);
	// The kit's block pattern as light and dark: joints stay dark.
	float blocks = dot(texture(albedo_tex, UV).rgb, vec3(0.3, 0.59, 0.11));
	blocks = clamp(blocks * 1.6, 0.35, 1.2);

	vec3 col = base_color;
	float h = grit * 0.02 * band(5.0, px) - pits * 0.004;
	float rough = 0.9;
	float spec = 0.2;
	float metal = 0.0;
	vec3 glow = vec3(0.0);

	if (style == 0) {
		// Bone: grain along the bones (stretched upright on walls), stains, pits.
		vec3 q = surface == 0 ? vec3(p.x * 28.0 + p.z * 28.0, p.y * 2.5, 0.0) : vec3(p.x * 6.0, 0.0, p.z * 28.0);
		float fibre = vnoise(q + vec3(0.0, 0.0, 3.0));
		float yellow = smoothstep(0.35, 0.8, stains);
		col = mix(base_color, dark_color, 0.55 * (1.0 - yellow) * stains + 0.25 * (1.0 - fibre));
		col *= 1.0 + 0.14 * (grit - 0.5) - 0.2 * pits;
		col *= blocks;
		rough = 0.78 + 0.15 * grit;
		spec = 0.3;
	} else if (style == 1) {
		// Rock: layers warped by noise, dark cracks, sand.
		float layer = sin((p.y + 0.5 * stains) * 5.0 + 1.3 * fbm(p * 1.3)) * 0.5 + 0.5;
		float crack = smoothstep(0.03, 0.0, abs(vnoise(p * 3.1) - 0.5)) * band(3.1, px);
		col = mix(base_color, dark_color, 0.45 * layer + 0.3 * (1.0 - stains));
		col *= 1.0 + 0.2 * (grit - 0.5) - 0.18 * pits - 0.35 * crack;
		col *= blocks;
		float sand = (vnoise(p * 40.0) - 0.5) * band(40.0, px);
		col *= 1.0 + 0.1 * sand;
		h += sand * 0.0015 - crack * 0.01;
		rough = 0.95;
		spec = 0.12;
	} else if (style == 2) {
		// Obsidian: flat facets, each tilted its own way, so a lamp or a torch
		// catches a few of them in sharp glints; faint lighter flow lines.
		vec3 cell = floor(p * 1.7);
		vec3 f = fract(p * 1.7);
		vec3 tilt = vec3(hash3(cell) - 0.5, hash3(cell + 9.1) - 0.5, hash3(cell + 4.7) - 0.5);
		h = dot(tilt, f) * 0.09 + grit * 0.004 * band(5.0, px);
		float flow = smoothstep(0.55, 0.9, vnoise(vec3(p.x * 1.5 + p.z * 1.5, p.y * 9.0, p.z * 0.7 + p.x * 0.7)));
		col = mix(base_color, dark_color, 0.5 + 0.3 * (stains - 0.5));
		col += vec3(0.05, 0.04, 0.08) * flow;
		col *= mix(0.8, 1.15, blocks - 0.35);
		rough = 0.1 + 0.08 * grit;
		spec = 1.0;
	} else {
		// Crystal: bluish facets, pale flecks, glowing veins.
		vec3 cell = floor(p * 2.4);
		vec3 f = fract(p * 2.4);
		vec3 tilt = vec3(hash3(cell) - 0.5, hash3(cell + 9.1) - 0.5, hash3(cell + 4.7) - 0.5);
		h = dot(tilt, f) * 0.05 + grit * 0.004 * band(5.0, px);
		float vein = smoothstep(0.06, 0.0, abs(vnoise(p * 2.2 + 5.0) - 0.5)) * band(2.2, px);
		float fleck = smoothstep(0.75, 0.9, vnoise(p * 22.0)) * band(22.0, px);
		col = mix(base_color, dark_color, 0.5 * (1.0 - stains) + 0.2 * hash3(cell));
		col += vec3(0.25, 0.3, 0.35) * fleck;
		col *= mix(0.75, 1.1, blocks - 0.35);
		float pulse = 0.85 + 0.15 * sin(TIME * 1.3 + stains * 8.0);
		glow = glow_color * (0.04 + 0.5 * vein + 0.25 * fleck) * pulse * (1.0 - 0.6 * floor_k);
		rough = 0.28 + 0.2 * grit;
		spec = 0.7;
	}

	ALBEDO = col * tone;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = style == 2 ? 0.5 : 1.0;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
	EMISSION = glow;
	if (fade > 0.0) {
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(bayer[q.y * 4 + q.x]) + 0.5) / 16.0 < fade) {
			discard;
		}
	}
}
