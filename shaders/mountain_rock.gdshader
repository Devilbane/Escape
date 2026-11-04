shader_type spatial;
// Both sides drawn, as the rock's builders always did: a face seen from
// behind never leaves a hole.
render_mode cull_disabled;
// Weathered mountain rock, to match the aged stone of the village and the
// graveyard (aged_stone.gdshader): the high mountains (Mountains) and the
// mountain the dragon's lair is dug into (LairMountain) keep their low-poly
// facets and the colours their builders paint on each face (rock, moss,
// snow, earth, passed in as vertex colours), and this lays the same kind of
// weather over them that the village stone wears:
// - grain and pits, so a face reads as stone instead of flat paint,
// - strata: pale and dark layers of rock running across the steep faces,
// - grime: earthy stains at the foot of the rock,
// - streaks: dark runs of rain water down the steep faces,
// - moss in patches on what faces up, low down,
// - lichen: pale and orange crusts on the bare rock, as on the gravestones.
// Snow (the pale, colourless faces up high) stays clean.

#include "res://shaders/detail.gdshaderinc"

// Tints the painted colours a little towards the village's warm grey stone.
uniform vec3 tint = vec3(1.07, 1.06, 1.06);
// The strength of the weather (grime, streaks, moss), as in aged_stone.
uniform float age = 1.0;
// How much lichen crusts the bare rock.
uniform float lichen = 0.5;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 paint;
varying float foot;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	paint = COLOR.rgb;
	foot = NODE_POSITION_WORLD.y;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

void fragment() {
	vec3 n = normalize(wnrm);
	float h = wpos.y - foot;
	float px = length(fwidth(wpos));
	float steep = 1.0 - smoothstep(0.35, 0.8, n.y);

	vec3 base = paint * tint;
	float hi = max(base.r, max(base.g, base.b));
	float sat = hi > 0.001 ? (hi - min(base.r, min(base.g, base.b))) / hi : 0.0;
	// Snow: pale faces without colour in them.
	float snow = smoothstep(0.72, 0.85, lum(base)) * smoothstep(0.12, 0.04, sat);
	// Moss the builder painted (green faces), so the weather leaves it be.
	float painted_moss = smoothstep(0.05, 0.14, base.g - max(base.r, base.b) * 0.9);

	// Grain and pits of the stone.
	float grain = fbm(wpos * 0.55 + 2.0);
	float fine = fbm(wpos * 2.3 + 7.0);
	float pits = vnoise(wpos * 9.0);
	vec3 col = base * (0.9 + 0.22 * grain) * (0.94 + 0.12 * fine * band(2.3, px))
			* (0.95 + 0.1 * pits * band(9.0, px));

	// Strata: layers of rock, gently wavy and tilted, on the steep faces.
	float s = wpos.y * 0.9 + (fbm(wpos * 0.06) - 0.5) * 6.0 + wpos.x * 0.06;
	float layer = vnoise(vec3(s, 0.5, wpos.z * 0.01));
	float strata = mix(0.9, 1.08, smoothstep(0.25, 0.75, layer));
	col *= mix(1.0, strata, steep * (1.0 - snow) * band(0.9, px));

	// Weather.
	vec3 p = wpos * 0.5;
	float cloud = fbm(p * 0.7);
	// Grime, thickest at the foot of the rock.
	float low = 1.0 - smoothstep(0.0, 1.2 + cloud * 0.8, h);
	col *= mix(1.0, mix(0.95, 1.03, cloud), age);
	col = mix(col, col * vec3(0.62, 0.58, 0.5), low * 0.22 * age);
	// Rain streaks running down the steep faces.
	vec2 along = abs(n.x) > abs(n.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	float streak = vnoise(vec3(along.x * 1.1, along.y * 0.09, 1.7)) * vnoise(vec3(along.x * 2.6, along.y * 0.2, 4.2));
	streak = smoothstep(0.3, 0.6, streak) * steep * (1.0 - snow) * band(2.6, px);
	col *= 1.0 - streak * 0.15 * age;
	// Moss: in patches on what faces up, low down, like the village walls.
	float moss_place = smoothstep(0.45, 0.9, n.y) * (1.0 - smoothstep(6.0, 12.0, h)) + low * 0.25;
	float moss = smoothstep(0.62, 0.8, fbm(p * 1.4 + 5.0) + moss_place * 0.25) * smoothstep(0.05, 0.4, moss_place);
	moss *= (1.0 - snow) * (1.0 - painted_moss * 0.6);
	vec3 moss_col = mix(vec3(0.13, 0.17, 0.06), vec3(0.22, 0.26, 0.1), vnoise(wpos * 2.0));
	col = mix(col, moss_col, moss * 0.35 * age);
	// Lichen: round crusts, pale grey-green, now and then orange.
	vec3 lp = wpos * 3.2;
	float crust = smoothstep(0.66, 0.71, fbm(lp + 21.0) + 0.06 * vnoise(lp * 6.0));
	crust *= lichen * (1.0 - moss) * (1.0 - snow) * (1.0 - painted_moss) * band(3.2, px);
	vec3 lichen_col = vnoise(lp * 0.6 + 9.0) > 0.64 ? vec3(0.6, 0.42, 0.18) : vec3(0.56, 0.58, 0.47);
	col = mix(col, lichen_col * (0.85 + 0.3 * vnoise(lp * 8.0)), crust * 0.45);
	// Snow keeps its own colour, with only a faint, soft grain.
	col = mix(col, base * (0.95 + 0.07 * grain), snow);

	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.82, moss);
	// Relief: the grain and the strata stand out.
	float height = (grain * 0.5 + fine * 0.3 * band(2.3, px) + strata * steep) * (1.0 - snow * 0.7);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(n, dFdx(wpos), dFdy(wpos), dFdx(height) * 0.3, dFdy(height) * 0.3), 0.0)).xyz);
}
