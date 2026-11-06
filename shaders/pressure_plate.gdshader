shader_type spatial;
// The old pressure plates of the dungeon's puzzle rooms (see Level's
// _build_plate): a slab of carved stone, worn and dirty like the rest of the
// dungeon, with an ornament cut into its top:
// - a bevelled rim and a double groove along the edge,
// - a small ring in each corner,
// - a ring of eight runes around the middle,
// - a diamond with a ring and a dot in the very middle.
// Grime and moss sit in the grooves, the carving is worn away in places, and
// a few cracks and chips run over the stone. While a block weighs the plate
// down (glow 1) the carving glows a warm gold, so a pressed plate reads at a
// glance from the game's camera; an empty one is dark and dusty.
// The pattern is laid out on the slab itself (it sinks with it), its wear
// from where the plate lies, so no two plates look printed. Fine detail
// fades out where it would be smaller than a few pixels.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo_color : source_color = vec3(0.43, 0.41, 0.37);
uniform vec3 glow_color : source_color = vec3(1.0, 0.68, 0.3);
// 0 for an empty plate, 1 while a block lies on it.
uniform float glow = 0.0;
uniform float glow_energy = 1.5;
// The edge of the slab's square top, in metres.
uniform float plate_size = 1.5;

const vec3 GRIME = vec3(0.12, 0.105, 0.085);
const vec3 MOSS = vec3(0.15, 0.2, 0.08);
const vec3 DUST = vec3(0.58, 0.54, 0.48);

// The eight runes, one bit for each stroke in rune_strokes().
const int RUNES[8] = int[](3, 7, 11, 65, 97, 19, 225, 13);

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 stone_pos;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	// Where the plate lies, but not how far it has sunk: the stains stay put
	// while it goes down.
	stone_pos = VERTEX + vec3(NODE_POSITION_WORLD.x, 0.0, NODE_POSITION_WORLD.z);
}

// 1 on a line where d is 0, half w wide, with a soft edge one pixel across.
float groove(float d, float w) {
	float aa = max(fwidth(d), 0.0015);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distance to the strokes of one rune (bits of code), in a box about
// 0.05 wide and 0.07 high around p = 0.
float rune_strokes(vec2 p, int code) {
	const float H = 0.034;
	const float W = 0.021;
	float d = 1.0;
	if ((code & 1) != 0) { d = min(d, seg(p, vec2(0.0, -H), vec2(0.0, H))); }
	if ((code & 2) != 0) { d = min(d, seg(p, vec2(0.0, H), vec2(W, H * 0.35))); }
	if ((code & 4) != 0) { d = min(d, seg(p, vec2(0.0, H * 0.35), vec2(W, -H * 0.25))); }
	if ((code & 8) != 0) { d = min(d, seg(p, vec2(0.0, H), vec2(-W, H * 0.35))); }
	if ((code & 16) != 0) { d = min(d, seg(p, vec2(0.0, -H * 0.2), vec2(-W, -H))); }
	if ((code & 32) != 0) { d = min(d, seg(p, vec2(W, -H), vec2(W, H))); }
	if ((code & 64) != 0) { d = min(d, seg(p, vec2(-W, H * 0.6), vec2(W, -H * 0.6))); }
	if ((code & 128) != 0) { d = min(d, seg(p, vec2(-W, -H * 0.6), vec2(W, H * 0.6))); }
	return d;
}

// How deep the ornament is cut at q (the top, -0.5 to 0.5 across), 0 to 1.
float carving(vec2 q) {
	float r = length(q);
	float e = 0.5 - max(abs(q.x), abs(q.y));
	float c = 0.0;
	// The double groove along the edge.
	c = max(c, groove(e - 0.07, 0.008));
	c = max(c, groove(e - 0.1, 0.0035));
	// A ring with a dot in each corner, inside the grooves.
	vec2 corner = abs(q) - vec2(0.34);
	c = max(c, groove(length(corner) - 0.032, 0.006));
	c = max(c, 1.0 - smoothstep(0.009, 0.012, length(corner)));
	// The ring of runes between two circles.
	c = max(c, groove(r - 0.315, 0.007));
	c = max(c, groove(r - 0.205, 0.0055));
	float slice = 6.2831853 / 8.0;
	float a = atan(q.y, q.x) + 3.1415927 + slice * 0.5;
	float k = floor(a / slice);
	vec2 rp = vec2((a / slice - k - 0.5) * slice * r, r - 0.26);
	int code = RUNES[int(mod(k, 8.0))];
	c = max(c, groove(rune_strokes(rp, code), 0.0055));
	// The diamond in the middle, a ring inside it and a dot.
	c = max(c, groove(abs(q.x) + abs(q.y) - 0.15, 0.007));
	c = max(c, groove(r - 0.065, 0.005));
	c = max(c, 1.0 - smoothstep(0.016, 0.02, r));
	// Four short spokes from the diamond's points out to the rune ring.
	float spokes = min(abs(q.x), abs(q.y));
	c = max(c, groove(spokes, 0.004) * step(0.152, r) * step(r, 0.2));
	return c;
}

void fragment() {
	vec3 p = stone_pos;
	float px = length(fwidth(p));
	float top = smoothstep(0.5, 0.9, obj_normal.y);
	vec2 q = obj_pos.xz / plate_size;

	// The stone itself, as in decayed_stone.gdshader.
	float stains = fbm(p * 0.9);
	float grit = fbm(p * 5.0);
	float pits = smoothstep(0.6, 0.8, vnoise(p * 16.0)) * band(16.0, px);
	float sand = (vnoise(p * 40.0) - 0.5) * band(40.0, px);
	float n1 = vnoise(p * 3.1 + 4.0) + 0.35 * vnoise(p * 9.0);
	float cracks = (1.0 - smoothstep(0.0, 0.03, abs(n1 - 0.67))) * smoothstep(0.5, 0.68, vnoise(p * 1.6 + 7.0)) * band(9.0, px);
	float chips = smoothstep(0.72, 0.84, vnoise(p * 7.0 + 3.0)) * band(7.0, px);

	// The carving, worn shallow in places and filled with dirt in others.
	float cut = carving(q) * top;
	float wear = smoothstep(0.2, 0.6, fbm(p * 2.6 + 11.0));
	float depth = cut * (0.3 + 0.7 * wear);
	// The bevelled rim, chipped where the stone has flaked away.
	float e = 0.5 - max(abs(q.x), abs(q.y));
	float rim = top * (1.0 - smoothstep(0.0, 0.03 + 0.02 * chips, e));

	float shade = 1.0 + 1.6 * (0.24 * (stains - 0.5) + 0.16 * (grit - 0.5) - 0.14 * pits + 0.08 * sand);
	vec3 col = albedo_color * shade;
	// Dust on the top, thicker away from the middle where feet never tread.
	float dust = top * smoothstep(0.45, 0.75, fbm(p * 1.7 + 2.0) + 0.6 * length(q)) * (0.6 + 0.4 * grit);
	col = mix(col, DUST * (0.85 + 0.3 * grit), dust * 0.3);
	// Aged: darker and browner where the grime is cloudy.
	col = mix(col, GRIME * (0.8 + 0.6 * grit), 0.1 + 0.35 * smoothstep(0.45, 0.8, stains));
	// Grime and a little moss in the grooves, round the rim and on the sides.
	float dirty = max(depth, 0.6 * rim);
	vec3 dirt = mix(GRIME, MOSS, smoothstep(0.55, 0.75, fbm(p * 4.0 + 9.0))) * (0.7 + 0.6 * grit);
	col = mix(col, dirt, dirty * 0.7);
	col = mix(col, GRIME * (0.8 + 0.5 * grit), (1.0 - top) * 0.45);
	col *= 1.0 - 0.3 * chips * rim;
	col *= 1.0 - 0.6 * cracks;
	ALBEDO = col;

	// The pressed plate's carving glows, brightest where it is cut deepest.
	EMISSION = glow_color * glow * glow_energy * cut * (0.3 + 0.7 * wear) * (0.85 + 0.3 * grit);

	float h = 1.6 * (grit * 0.02 * band(5.0, px) - pits * 0.004 + sand * 0.0015)
		- depth * 0.012 - rim * 0.012 - cracks * 0.005;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	ROUGHNESS = 0.9 + 0.1 * grit;
	SPECULAR = 0.2;
}
