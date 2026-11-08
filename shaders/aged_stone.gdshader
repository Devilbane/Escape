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
// Their wood (the brown beams, frames, doors, posts and planks) gets the grain
// of the villagers' timber (wood_tex, the same texture as VillageHouse's
// beams), laid along the length of each beam on every face, the sides too:
// AgedStone.grained_mesh writes each triangle's beam direction into the
// vertex colours (alpha 0.5 marks it).
// The graveyard wears it too (see AgedStone.grave_material): the crypt and
// the fence's low wall are laid in blocks, the gravestones are hewn from one
// piece (blocks = 0), older still, greyer, and spotted with lichen.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_palette = true;
// The stone's tint (sandstone, grey, ...), and the strength of the weather.
uniform vec3 tint : source_color = vec3(0.86, 0.83, 0.78);
uniform float age = 1.0;
// 1: laid in stone blocks; 0: hewn from one piece (a gravestone).
uniform float blocks = 1.0;
// How far the strong colours (roofs, doors) are greyed by the weather.
uniform float fade = 0.42;
// Crusts of pale and orange lichen on the stone (old gravestones).
uniform float lichen = 0.0;
// 1: the near-black joints of the trim sheet become thin, grey mortar lines
// (the village buildings); 0: the sheet's own deep, dark joints.
uniform float soft_joints = 0.0;
// 1: the roof tiles are uneven (each tile its own shade, now and then a new
// or a blackened one) and bleached in patches (the village buildings).
uniform float uneven_roofs = 0.0;
uniform sampler2D trim : source_color, filter_linear_mipmap, repeat_enable;
// Where the windows sit on the palette (white), and how bright they glow.
uniform sampler2D glow_mask : hint_default_black, filter_linear;
uniform vec3 glow_colour : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
// The grain of the timber (read as painted, not as light; see wood_tex use).
uniform sampler2D wood_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
// How strongly the grain shows on the KayKit wood (0: flat colour).
uniform float wood_grain = 0.0;
// The windmill's sails (see SailCloth): the pale walls are woven canvas, not
// stone, and lie in shadow along the wooden frame. canvas_shadow is a picture
// of that shadow over the sail's flat shape, canvas_rect (x, y, width, height)
// where it sits on the mesh, canvas_dark how dark it gets.
uniform bool canvas = false;
uniform sampler2D canvas_shadow : hint_default_black, filter_linear;
uniform vec4 canvas_rect = vec4(-0.5, -0.5, 1.0, 1.0);
uniform float canvas_dark = 0.55;

// The four rows of stone blocks on the trim sheet (v, top and bottom), the
// metres one copy of them covers across and up, and the red roof tiles.
const vec2 STONE_V = vec2(0.6, 0.92);
const vec2 STONE_SIZE = vec2(4.8, 2.4);
const vec4 TILES = vec4(0.5, 0.06, 0.5, 0.235);
const vec2 TILES_SIZE = vec2(2.4, 1.2);
// The metres one copy of the wood texture covers along a beam and across it,
// and its mean brightness as painted.
const vec2 WOOD_SIZE = vec2(2.0, 0.9);
const float WOOD_MEAN = 0.333;

varying vec3 wpos;
varying vec3 wnrm;
varying float foot;
varying vec3 grain_dir;
varying float has_dir;
varying vec3 obj_pos;
varying float obj_scale;

void vertex() {
	obj_pos = VERTEX;
	obj_scale = length(MODEL_MATRIX[0].xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	foot = NODE_POSITION_WORLD.y;
	// The beam's length, from AgedStone.grained_mesh (alpha 0.5); meshes
	// without it have white vertex colours.
	has_dir = 1.0 - step(0.75, COLOR.a);
	grain_dir = (MODEL_MATRIX * vec4(COLOR.rgb * 2.0 - 1.0, 0.0)).xyz;
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
	// Softer joints: the dark rims along each joint are lifted to the
	// stone's own colour, so the line gets thinner, and only its darkest
	// core stays as mortar, a dark grey instead of black. The faces of the
	// blocks (relief above ~0.42), even the darker ones, keep their shade.
	// The scratches on the faces are lifted the same way and the relief is
	// pressed flatter below, so they no longer read as black carvings.
	float rim = smoothstep(0.16, 0.42, relief);
	float lifted = max(mix(0.38, relief, rim), relief);
	float core = 1.0 - smoothstep(0.02, 0.09, relief);
	vec3 soft = mix(stone * (lifted / max(relief, 0.02)), vec3(0.24, 0.235, 0.225), core);
	stone = mix(stone, soft, soft_joints);
	relief = mix(relief, lum(stone), soft_joints);
	vec2 along = w.x > w.z ? mx : mz;
	float shade = hash3(vec3(floor(vec2(along.x / (STONE_SIZE.x / 7.0), along.y / (STONE_SIZE.y / 4.0))), 3.0));
	vec3 stone_tint = mix(tint, tint * vec3(1.04, 1.0, 0.92), shade);
	stone *= stone_tint * (0.86 + 0.28 * shade) * 1.2;
	// Hewn from one piece: no joints, only the grain and pits of the stone.
	float grain = fbm(wpos * 2.2 + 3.0);
	float pits = vnoise(wpos * 17.0);
	vec3 solid = tint * (0.74 + 0.32 * grain) * (0.94 + 0.12 * pits * band(17.0, px));
	stone = mix(solid, stone, blocks);
	relief = mix(0.35 * grain + 0.25 * pits * band(17.0, px), relief, blocks);

	// Faded paint, and roof tiles in the faded colour of the roof.
	vec3 faded = mix(base, vec3(l), fade) * 0.86;
	vec4 tile_area = vec4(TILES.x, TILES.y, TILES.z, TILES.w);
	vec3 tile_rgb = sheet(mx, TILES_SIZE, tile_area) * w.x + sheet(mz, TILES_SIZE, tile_area) * w.z
			+ sheet(my, TILES_SIZE, tile_area) * w.y;
	float tiles = lum(tile_rgb) / 0.3;
	faded *= mix(1.0, clamp(tiles, 0.55, 1.35), roof);
	// Uneven, aged tiles: find the tile under this spot on the sheet (the
	// same grid as in aged_roof.gdshader) and give it its own shade.
	vec2 rm = w.y > max(w.x, w.z) ? my : (w.x > w.z ? mx : mz);
	vec2 rf = rm / TILES_SIZE;
	vec2 sp = vec2(fract(rf.x) * 256.0, (1.0 - fract(rf.y)) * 120.0);
	float trow = floor((sp.y - 4.0) / 13.0);
	float tcol = floor((sp.x - (mod(trow, 2.0) > 0.5 ? 16.0 : 29.5)) / 29.75);
	vec3 tid = vec3(tcol, trow, 0.0) + vec3(floor(rf) * vec2(11.0, 17.0), 0.0);
	float th1 = hash3(tid + 1.3);
	float th2 = hash3(tid + 7.9);
	float th3 = hash3(tid + 15.1);
	vec3 uneven = faded * (0.8 + 0.34 * th1);
	uneven = mix(uneven, th2 > 0.5 ? uneven * vec3(1.02, 0.9, 0.72) : vec3(lum(uneven)), abs(th2 - 0.5) * 0.9);
	uneven *= th3 > 0.94 ? 1.2 : (th3 < 0.05 ? 0.55 : 1.0);
	float bleach = smoothstep(0.45, 0.75, fbm(wpos * 0.35 + 11.0));
	uneven = mix(uneven, vec3(lum(uneven)) * vec3(1.25, 1.2, 1.12) + 0.04, bleach * 0.5);
	faded = mix(faded, uneven, roof * uneven_roofs * band(8.0, px));
	if (window > 0.5) {
		faded = base;
	}

	// Wood: the warm browns of the palette (beams, frames, doors, posts,
	// planks), told apart by their hue: redder is roof tiles, yellower and
	// stronger is paint. Slanted faces that look up stay roofs. (The palette
	// arrives here as painted, as the thresholds above take it too.)
	vec3 ps = base;
	float ps_hi = max(ps.r, max(ps.g, ps.b));
	float ps_lo = min(ps.r, min(ps.g, ps.b));
	float ps_sat = ps_hi > 0.001 ? (ps_hi - ps_lo) / ps_hi : 0.0;
	float hue = ps.r >= ps_hi - 0.0001 && ps_hi - ps_lo > 0.01 ? 60.0 * (ps.g - ps.b) / (ps_hi - ps_lo) : -1.0;
	float slope = smoothstep(0.3, 0.55, n.y) * (1.0 - smoothstep(0.93, 0.99, n.y));
	float woody = smoothstep(7.0, 10.0, hue) * (1.0 - smoothstep(42.0, 46.0, hue))
			* smoothstep(0.43, 0.48, ps_sat) * (1.0 - smoothstep(0.74, 0.78, ps_sat))
			* (1.0 - wall) * (1.0 - window) * (1.0 - slope) * wood_grain;
	// The grain runs along the beam: its direction from the mesh, laid flat
	// on this face. On the end of a beam, or without one, it lies level.
	vec3 level = abs(n.y) > 0.7 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec3 gd = grain_dir - n * dot(grain_dir, n);
	gd = has_dir > 0.5 && length(gd) > 0.3 * length(grain_dir) ? normalize(gd) : level;
	vec2 wm = vec2(dot(wpos, gd), dot(wpos, cross(n, gd))) / WOOD_SIZE;
	float wl = lum(textureGrad(wood_tex, wm, dFdx(wm), dFdy(wm)).rgb);
	// The grain's light and dark, a little stronger than in the texture.
	float rings = clamp(1.0 + 1.45 * (wl / WOOD_MEAN - 1.0), 0.45, 1.55);
	vec3 timber = mix(base, vec3(l) * vec3(1.08, 0.96, 0.8), fade * 0.85) * 0.92 * rings;
	faded = mix(faded, timber, woody);

	// Sail canvas: threads crossing over and under each other (a plain weave,
	// as on the barber's tent), laid out in the sail's own flat shape so they
	// turn with it, and a few thicker threads. Its colour is natural linen,
	// a little weathered, and it is darker in the shade of the frame.
	float weave_h = 0.0;
	float sail = canvas ? smoothstep(0.68, 0.74, l) : 0.0;
	vec3 woven = stone;
	float frame_shade = 0.0;
	if (canvas) {
		vec2 wp = obj_pos.xy * obj_scale;
		vec2 t = wp * 36.0;
		vec2 f = fract(t);
		float over = mod(floor(t.x) + floor(t.y), 2.0);
		float warp = sin(3.14159 * f.x) * (0.65 + 0.35 * sin(3.14159 * f.y));
		float weft = sin(3.14159 * f.y) * (0.65 + 0.35 * sin(3.14159 * f.x));
		weave_h = mix(warp, weft, over) * band(36.0, px);
		float slub = smoothstep(0.7, 0.9, vnoise(vec3(wp.x * 24.0, wp.y * 2.5, 3.0))) * band(24.0, px)
				+ smoothstep(0.7, 0.9, vnoise(vec3(wp.x * 2.5, wp.y * 24.0, 7.0))) * band(24.0, px);
		float yarn = vnoise(vec3(wp * 3.0, 11.0));
		woven = vec3(0.9, 0.86, 0.76) * (0.9 + 0.1 * weave_h + 0.05 * slub + 0.1 * (yarn - 0.5));
		vec2 suv = (obj_pos.xy - canvas_rect.xy) / canvas_rect.zw;
		frame_shade = clamp(texture(canvas_shadow, suv).r * 1.8, 0.0, 1.0);
		woven *= 1.0 - canvas_dark * frame_shade;
	}

	vec3 col = canvas ? mix(mix(faded, stone, wall), woven, sail) : mix(faded, stone, wall);

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
	// Lichen: round crusts, pale grey-green, now and then orange.
	vec3 lp = wpos * 3.5;
	float crust = smoothstep(0.6, 0.66, fbm(lp + 21.0) + 0.06 * vnoise(lp * 6.0)) * lichen * wall * (1.0 - moss);
	vec3 lichen_col = vnoise(lp * 0.6 + 9.0) > 0.62 ? vec3(0.62, 0.42, 0.16) : vec3(0.58, 0.6, 0.48);
	col = mix(col, lichen_col * (0.85 + 0.3 * vnoise(lp * 8.0)), crust * 0.75);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.82, moss);
	// Relief: the joints between the blocks sink in.
	float bump = mix(0.6, 0.3, soft_joints);
	float height = weave_h * 0.4 * sail + (relief * wall + tiles * 0.15 * roof * (1.0 - woody)) * band(2.0, px) + woody * wl * 0.6 * band(30.0, px);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(n, dFdx(wpos), dFdy(wpos), dFdx(height) * bump, dFdy(height) * bump), 0.0)).xyz);
	EMISSION = glow_colour * window * glow;
}
