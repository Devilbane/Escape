shader_type spatial;
// Old village stonework, to match the temple (the Modular Cathedral Kit's
// stone): every building in the village is built of the kit's stone blocks,
// weathered by years of rain and sun (see AgedStone). It adds:
// - stone blocks from the kit's trim sheet, laid out in world space so a
//   block is the same size on every building, with a little relief,
// - grime: light, earthy stains at the very foot of the walls,
// - streaks: dark runs of rain water down from the eaves and windowsills,
// - moss: green patches low on the walls and on what faces up,
// - faded colours: paint and roof tiles bleached and greyed by the weather.
//
// Two kinds of model wear it:
// - the KayKit buildings (smithy, tavern, shop, ...), whose texture is a
//   palette of flat colours (use_palette): their light, greyish colours are
//   the walls and become stone, the strong ones (roofs, doors, beams) stay
//   but fade, and up-facing ones get the trim sheet's roof tiles;
// - the villagers' houses (VillageHouse), which are stone all over in one
//   tint (use_palette off).
// The windows of the KayKit buildings glow at night through glow_mask, as
// before (see Outdoor._light_windows).

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_palette = true;
// The stone's tint (sandstone, grey, ...), and the strength of the weather.
uniform vec3 tint : source_color = vec3(0.86, 0.83, 0.78);
uniform float age = 1.0;
uniform sampler2D trim : source_color, filter_linear_mipmap, repeat_enable;
// Where the windows sit on the palette (white), and how bright they glow.
uniform sampler2D glow_mask : hint_default_black, filter_linear;
uniform vec3 glow_colour : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;

// The four rows of stone blocks on the trim sheet (v, top and bottom), the
// metres one copy of them covers across and up, and the red roof tiles.
const vec2 STONE_V = vec2(0.6, 0.92);
const vec2 STONE_SIZE = vec2(4.8, 2.4);
const vec4 TILES = vec4(0.5, 0.06, 0.5, 0.235);
const vec2 TILES_SIZE = vec2(2.4, 1.2);

varying vec3 wpos;
varying vec3 wnrm;
varying float foot;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	foot = NODE_POSITION_WORLD.y;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

// One band of the trim sheet, repeated by metres: rows v0 to v1 of the
// sheet across u0 to u1. textureGrad keeps the seams of fract() clean.
vec3 sheet(vec2 m, vec2 size, vec4 area) {
	vec2 f = m / size;
	vec2 uv = area.xy + vec2(fract(f.x), 1.0 - fract(f.y)) * area.zw;
	return textureGrad(trim, uv, dFdx(f) * area.zw, dFdy(f) * area.zw).rgb;
}

void fragment() {
	vec3 n = normalize(wnrm);
	// Laid on from three sides at once (triplanar), so curved and slanted
	// faces get the stone as well as the flat walls do.
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec2 mx = vec2(wpos.z, wpos.y);
	vec2 mz = vec2(wpos.x, wpos.y);
	vec2 my = vec2(wpos.x, wpos.z);
	float h = wpos.y - foot;
	float px = length(fwidth(wpos));

	vec3 base = use_palette ? texture(palette, UV).rgb : tint;
	float window = use_palette ? texture(glow_mask, UV).r : 0.0;
	float hi = max(base.r, max(base.g, base.b));
	float sat = hi > 0.001 ? (hi - min(base.r, min(base.g, base.b))) / hi : 0.0;
	float l = lum(base);
	// The walls: light colours without much colour in them.
	float wall = use_palette ? smoothstep(0.34, 0.2, sat) * smoothstep(0.28, 0.42, l) * (1.0 - window) : 1.0;
	float roof = smoothstep(0.3, 0.55, n.y) * (1.0 - wall);

	// Stone blocks, laid by metres; each block a little lighter or darker.
	vec4 band_area = vec4(0.0, STONE_V.x, 1.0, STONE_V.y - STONE_V.x);
	vec3 stone = sheet(mx, STONE_SIZE, band_area) * w.x + sheet(mz, STONE_SIZE, band_area) * w.z
			+ sheet(my, STONE_SIZE, band_area) * w.y;
	float relief = lum(stone);
	vec2 along = w.x > w.z ? mx : mz;
	float shade = hash3(vec3(floor(vec2(along.x / (STONE_SIZE.x / 7.0), along.y / (STONE_SIZE.y / 4.0))), 3.0));
	vec3 stone_tint = mix(tint, tint * vec3(1.04, 1.0, 0.92), shade);
	stone *= stone_tint * (0.86 + 0.28 * shade) * 1.2;

	// Faded paint, and roof tiles in the faded colour of the roof.
	vec3 faded = mix(base, vec3(l), 0.42) * 0.86;
	vec4 tile_area = vec4(TILES.x, TILES.y, TILES.z, TILES.w);
	vec3 tile_rgb = sheet(mx, TILES_SIZE, tile_area) * w.x + sheet(mz, TILES_SIZE, tile_area) * w.z
			+ sheet(my, TILES_SIZE, tile_area) * w.y;
	float tiles = lum(tile_rgb) / 0.3;
	faded *= mix(1.0, clamp(tiles, 0.55, 1.35), roof);
	if (window > 0.5) {
		faded = base;
	}

	vec3 col = mix(faded, stone, wall);

	// Weather.
	vec3 p = wpos * 0.5;
	float cloud = fbm(p * 1.3);
	// Grime, thickest at the foot of the walls.
	float low = 1.0 - smoothstep(0.0, 0.9 + cloud * 0.6, h);
	col *= mix(1.0, mix(0.9, 1.0, cloud), age);
	col = mix(col, col * vec3(0.62, 0.58, 0.5), low * 0.3 * age);
	// Rain streaks running down the walls.
	float streak = vnoise(vec3(along.x * 2.2, along.y * 0.18, 1.7)) * vnoise(vec3(along.x * 5.1, along.y * 0.4, 4.2));
	streak = smoothstep(0.32, 0.6, streak) * (1.0 - abs(n.y)) * band(5.0, px);
	col *= 1.0 - streak * 0.16 * age;
	// Moss: in patches low on the walls, and on what faces up (roofs, ledges).
	float moss_place = max(low * 0.8, smoothstep(0.5, 0.95, n.y) * 0.5);
	float moss = smoothstep(0.66, 0.82, fbm(p * 2.4 + 5.0) + moss_place * 0.25) * smoothstep(0.05, 0.4, moss_place);
	vec3 moss_col = mix(vec3(0.05, 0.08, 0.02), vec3(0.11, 0.14, 0.04), vnoise(wpos * 4.0));
	col = mix(col, moss_col, moss * 0.5 * age * (1.0 - window));

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.82, moss);
	// Relief: the joints between the blocks sink in.
	float height = (relief * wall + tiles * 0.15 * roof) * band(2.0, px);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(n, dFdx(wpos), dFdy(wpos), dFdx(height) * 0.6, dFdy(height) * 0.6), 0.0)).xyz);
	EMISSION = glow_colour * window * glow;
}
