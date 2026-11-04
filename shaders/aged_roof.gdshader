shader_type spatial;
// The old tiled roofs of the villagers' houses (VillageHouse._roof): the red
// tiles of the cathedral trim sheet, one copy per patch of roof, aged like
// the stone of the walls (see aged_stone.gdshader). It adds:
// - uneven tiles: every tile a little lighter, darker, browner or greyer than
//   its neighbours, and now and then one replaced by a newer, redder tile or
//   an old, nearly black one,
// - faded patches: large, cloudy areas bleached and greyed by the sun,
// - grime: dark runs of rain water down the slope towards the eaves,
// - moss and lichen: green in the joints and in patches, thickest low on the
//   roof, with pale crusts of lichen here and there.
// Each patch's vertex colour (red) is a random number, so the same tile of
// the sheet looks different on every patch.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D tiles : source_color, filter_linear_mipmap, repeat_enable;
// The house's roof shade (VillageHouse.ROOFS).
uniform vec3 tint : source_color = vec3(1.0);
// How weathered the roof is.
uniform float age = 1.0;

// The tiles on the sheet, in its pixels: where the patch starts, how far
// apart the tiles sit across and down, where the first row line runs, and
// how far the odd and even rows are shifted.
const vec2 PATCH_ORIGIN = vec2(256.0, 30.72);
const vec2 TILE_PITCH = vec2(29.75, 13.0);
const float FIRST_ROW = 4.0;
const vec2 ROW_SHIFT = vec2(16.0, 29.5);

varying vec3 wpos;
varying vec3 wnrm;
varying float patch_seed;
varying float foot;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	patch_seed = COLOR.r;
	foot = NODE_POSITION_WORLD.y;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

void fragment() {
	vec3 n = normalize(wnrm);
	float px = length(fwidth(wpos));
	vec3 tex = texture(tiles, UV).rgb;
	float raw = lum(tex);

	// Which tile of the patch this is.
	vec2 sp = UV * 512.0 - PATCH_ORIGIN;
	float row = floor((sp.y - FIRST_ROW) / TILE_PITCH.y);
	float shift = mod(row, 2.0) > 0.5 ? ROW_SHIFT.x : ROW_SHIFT.y;
	float col = floor((sp.x - shift) / TILE_PITCH.x);
	vec3 id = vec3(col, row, patch_seed * 113.0);
	float h1 = hash3(id + 1.3);
	float h2 = hash3(id + 7.9);
	float h3 = hash3(id + 15.1);

	// Uneven tiles: lighter or darker, browner or greyer.
	vec3 col_rgb = tex * tint;
	col_rgb *= 0.8 + 0.34 * h1;
	vec3 brown = col_rgb * vec3(1.02, 0.9, 0.72);
	vec3 grey = vec3(lum(col_rgb)) * vec3(1.05, 1.0, 0.95);
	col_rgb = mix(col_rgb, h2 > 0.5 ? brown : grey, abs(h2 - 0.5) * 0.9);
	// Now and then a newer, redder tile, or an old, nearly black one.
	if (h3 > 0.94) {
		col_rgb = tex * tint * vec3(1.25, 0.95, 0.85);
	} else if (h3 < 0.05) {
		col_rgb *= 0.55;
	}

	// Weather, in metres over the roof.
	vec3 p = wpos * 0.5;
	float cloud = fbm(p * 1.1 + 2.0);
	// Faded patches: bleached by the sun towards a pale, dusty grey.
	float bleach = smoothstep(0.4, 0.7, fbm(p * 0.7 + 11.0)) * age;
	col_rgb = mix(col_rgb, vec3(lum(col_rgb)) * vec3(1.25, 1.2, 1.12) + 0.04, bleach * 0.65);
	col_rgb *= mix(1.0, 0.86 + 0.2 * cloud, age);
	// Rain runs down the slope: dark streaks, longer along the fall line.
	vec3 fall = normalize(vec3(0.0, -1.0, 0.0) + n * n.y);
	vec3 across = normalize(cross(n, fall));
	vec2 on_roof = vec2(dot(wpos, across), dot(wpos, fall));
	float streak = vnoise(vec3(on_roof.x * 3.0, on_roof.y * 0.25, 5.3));
	streak = smoothstep(0.55, 0.85, streak) * band(3.0, px);
	col_rgb *= 1.0 - streak * 0.28 * age;
	// Low on the roof (near the eaves), more moss and more grime.
	float low = 1.0 - smoothstep(0.0, 3.0, wpos.y - foot - 5.0);
	// Moss: in the joints first, and in patches over the tiles.
	float joint = 1.0 - smoothstep(0.06, 0.16, raw);
	float clump = smoothstep(0.68, 0.86, fbm(p * 2.2 + 5.0) + low * 0.15);
	float moss = clamp(joint * (0.15 + 0.35 * cloud) + clump * 0.85, 0.0, 1.0) * age;
	vec3 moss_col = mix(vec3(0.12, 0.16, 0.05), vec3(0.24, 0.28, 0.09), vnoise(wpos * 5.0));
	col_rgb = mix(col_rgb, moss_col, moss * 0.6);
	// Lichen: small pale crusts.
	vec3 lp = wpos * 4.0;
	float crust = smoothstep(0.75, 0.78, fbm(lp + 31.0)) * (1.0 - moss) * age;
	col_rgb = mix(col_rgb, vec3(0.6, 0.6, 0.5) * (0.85 + 0.3 * vnoise(lp * 7.0)), crust * 0.35);

	ALBEDO = col_rgb;
	ROUGHNESS = mix(0.9, 0.97, moss);
	// Relief: the joints between the tiles sink in, the odd tile sits a
	// little proud.
	float height = (raw + h1 * 0.08) * band(2.0, px);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(n, dFdx(wpos), dFdy(wpos), dFdx(height) * 0.5, dFdy(height) * 0.5), 0.0)).xyz);
}
