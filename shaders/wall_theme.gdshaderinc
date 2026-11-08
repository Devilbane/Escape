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
// The two other variants of the style: their colours, and how fine their
// pattern is (variant 0 is base_color and dark_color, with the pattern at 1).
uniform vec3 base_b : source_color = vec3(0.7);
uniform vec3 dark_b : source_color = vec3(0.3);
uniform vec3 base_c : source_color = vec3(0.7);
uniform vec3 dark_c : source_color = vec3(0.3);
uniform float scale_b = 1.35;
uniform float scale_c = 0.75;
// -1 mixes the three variants in patches a few metres wide, blended smoothly in
// world space (so two maps or tiles of one style never show a seam); 0, 1 and 2
// give one variant alone.
uniform int variant = -1;
uniform vec3 glow_color : source_color = vec3(0.4, 0.8, 1.0);
// See stone.gdshader: how see-through a near wall in front of the hero is.
#ifndef NO_FADE
instance uniform float fade = 0.0;
#endif

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
	// Which variant rules here: smooth patches in world space, or the one asked for.
	float wb = 0.0;
	float wc = 0.0;
	if (variant < 0) {
		wb = smoothstep(0.48, 0.62, fbm(p * 0.11 + vec3(11.0, 3.0, 5.0)));
		wc = smoothstep(0.48, 0.62, fbm(p * 0.13 + vec3(53.0, 17.0, 29.0))) * (1.0 - wb);
	} else if (variant == 1) {
		wb = 1.0;
	} else if (variant == 2) {
		wc = 1.0;
	}
	float wa = 1.0 - wb - wc;
	vec3 basec = base_color * wa + base_b * wb + base_c * wc;
	vec3 darkc = dark_color * wa + dark_b * wb + dark_c * wc;
	float kf = wa + scale_b * wb + scale_c * wc;
	float stains = fbm(p * 0.8);
	float grit = fbm(p * 5.0);
	float pits = smoothstep(0.62, 0.8, vnoise(p * 16.0)) * band(16.0, px);
	// The kit's block pattern as light and dark: joints stay dark.
	float blocks = dot(texture(albedo_tex, UV).rgb, vec3(0.3, 0.59, 0.11));
	// Half the kit's block pattern: its stone is dark, and the styles bring their own colour.
	blocks = mix(0.85, clamp(blocks * 2.2, 0.3, 1.3), 0.5);

	vec3 col = basec;
	float h = grit * 0.02 * band(5.0, px) - pits * 0.004;
	float rough = 0.9;
	float spec = 0.2;
	float metal = 0.0;
	vec3 glow = vec3(0.0);

	if (style == 0) {
		// Bone: grain along the bones (stretched upright on walls), stains, pits.
		vec3 q = surface == 0 ? vec3((p.x + p.z) * 28.0, p.y * 2.5, 0.0) * kf : vec3(p.x * 6.0, 0.0, p.z * 28.0) * kf;
		float fibre = vnoise(q + vec3(0.0, 0.0, 3.0));
		float yellow = smoothstep(0.35, 0.8, stains);
		col = mix(basec, darkc, 0.55 * (1.0 - yellow) * stains + 0.25 * (1.0 - fibre));
		col *= 1.0 + 0.14 * (grit - 0.5) - 0.2 * pits;
		col *= blocks;
		rough = 0.78 + 0.15 * grit;
		spec = 0.3;
	} else if (style == 1) {
		// Rock: layers warped by noise, dark cracks, sand.
		float layer = sin((p.y + 0.5 * stains) * 5.0 * kf + 1.3 * fbm(p * 1.3)) * 0.5 + 0.5;
		float crack = smoothstep(0.03, 0.0, abs(vnoise(p * 3.1) - 0.5)) * band(3.1, px);
		col = mix(basec, darkc, 0.45 * layer + 0.3 * (1.0 - stains));
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
		vec3 cell = floor(p * 1.7 * kf);
		vec3 f = fract(p * 1.7 * kf);
		vec3 tilt = vec3(hash3(cell) - 0.5, hash3(cell + 9.1) - 0.5, hash3(cell + 4.7) - 0.5);
		h = dot(tilt, f) * 0.05 * band(1.7, px) + grit * 0.002 * band(5.0, px);
		float flow = smoothstep(0.55, 0.9, vnoise(vec3(p.x * 1.5 + p.z * 1.5, p.y * 9.0, p.z * 0.7 + p.x * 0.7))) * band(9.0, px);
		col = mix(basec, darkc, 0.5 + 0.3 * (stains - 0.5));
		col += vec3(0.05, 0.04, 0.08) * flow;
		col *= mix(0.8, 1.15, blocks - 0.35);
		rough = 0.28 + 0.08 * grit;
		spec = 0.8;
		// A violet sheen along the edges seen at a slant, so a black wall keeps its outline.
		glow = vec3(0.32, 0.18, 0.55) * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.4;
	} else {
		// Crystal: bluish facets, pale flecks, glowing veins.
		vec3 cell = floor(p * 2.4 * kf);
		vec3 f = fract(p * 2.4 * kf);
		vec3 tilt = vec3(hash3(cell) - 0.5, hash3(cell + 9.1) - 0.5, hash3(cell + 4.7) - 0.5);
		h = dot(tilt, f) * 0.03 * band(2.4, px) + grit * 0.004 * band(5.0, px);
		float vein = smoothstep(0.1, 0.0, abs(vnoise(p * 2.2 * kf + 5.0) - 0.5)) * band(2.2, px);
		float fleck = smoothstep(0.75, 0.9, vnoise(p * 14.0)) * band(14.0, px);
		col = mix(basec, darkc, 0.5 * (1.0 - stains) + 0.2 * hash3(cell));
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
	NORMAL_MAP_DEPTH = style >= 2 ? 0.4 : 1.0;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
	EMISSION = glow;
#ifndef NO_FADE
	if (fade > 0.0) {
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(bayer[q.y * 4 + q.x]) + 0.5) / 16.0 < fade) {
			discard;
		}
	}
#endif
}
