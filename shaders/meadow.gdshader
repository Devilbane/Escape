shader_type spatial;
// The open ground outside the dungeon in one piece: grass, dirt paths, the
// cobbled village square, graveyard soil, dark forest floor and still water.
// A small mask texture (one pixel per tile) says what lies where; noise
// frays the edges so nothing looks cut along the tile grid.
//
// Everything is drawn from noise in world space, down to a few centimetres,
// so the ground has about as much detail as the kit's dungeon floor tiles:
// grass clumps, blades, clover, flowers and dry patches; packed earth with
// pebbles and tufts; round cobbles with mossy joints; leaf litter under the
// trees. Each layer also gives a little height for bump lighting, and fades
// out before it gets small enough on screen to flicker (see band()).

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D ground_mask : filter_linear, repeat_disable;
// Scree in the mountains (see Mountains): one pixel per tile, red 1 where
// the ground is stony. Black (no scree) everywhere else by default.
uniform sampler2D stone_mask : filter_linear, repeat_disable, hint_default_black;
uniform vec2 grid_size = vec2(16.0, 16.0);
uniform float tile = 4.0;
uniform vec3 grass_a : source_color = vec3(0.22, 0.33, 0.14);
uniform vec3 grass_b : source_color = vec3(0.31, 0.40, 0.17);
uniform vec3 forest : source_color = vec3(0.11, 0.17, 0.08);
uniform vec3 dirt : source_color = vec3(0.40, 0.31, 0.22);
uniform vec3 grave_soil : source_color = vec3(0.20, 0.23, 0.14);
uniform vec3 water : source_color = vec3(0.16, 0.30, 0.38);
uniform vec3 paving : source_color = vec3(0.50, 0.47, 0.43);

varying vec3 world_pos;

// Hashes without sin(), which loses precision far from the origin on some
// (web) GPUs.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.7 + 1.7) * 0.15;
}

// Scattered cells (Worley noise): x = distance to the nearest point, y = to
// the second nearest, z and w two random numbers for the nearest cell.
vec4 cells(vec2 x, float jitter) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash22(n + g) - 0.5) * jitter - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = n + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(sqrt(d1), sqrt(d2), hash12(id), hash12(id + 17.31));
}

// Grass, seen from above: tufts with lit tips and darker gaps, fine blades
// crossing each other, dry patches and clover.
// Returns the colour; h gets the height in metres.
float streaks(vec2 p, vec2 dir, float along, float across) {
	vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
	return noise(vec2(q.x * along, q.y * across));
}

vec3 grass(vec2 p, float px, float n, float lush, out float h) {
	vec3 col = mix(grass_a, grass_b, smoothstep(0.35, 0.75, n));
	float mid = fbm2(p * 0.7 + 11.0);
	col *= 0.88 + mid * 0.24;
	// Olive, sun-dried patches; the lush hollows stay green.
	float dry = smoothstep(0.64, 0.82, fbm2(p * 0.32 + 40.0)) * (1.0 - lush);
	col = mix(col, vec3(0.36, 0.37, 0.17), dry * 0.45);
	// Tufts: soft, uneven lumps a hand or two wide.
	vec2 w = p * 2.2 + (vec2(noise(p * 1.1), noise(p * 1.1 + 7.0)) - 0.5) * 1.5;
	float tuft = noise(w) * 0.65 + noise(w * 2.3 + 3.0) * 0.35;
	float tb = band(4.0, px);
	col *= 1.0 + (tuft - 0.5) * 0.3 * tb;
	col = mix(col, col * vec3(0.95, 1.04, 0.86), (noise(w * 0.5 + 9.0) - 0.5) * 0.8 * tb);
	// Blades in three directions, so they look crossed and tangled.
	float b = max(max(streaks(p, vec2(1.0, 0.0), 5.0, 26.0), streaks(p + 3.1, vec2(0.5, 0.866), 5.0, 26.0)),
			streaks(p + 7.3, vec2(-0.5, 0.866), 5.0, 26.0));
	float bb = band(26.0, px);
	col *= 1.0 + (b - 0.6) * 0.5 * bb;
	// Dark gaps down between the blades.
	float gaps = smoothstep(0.62, 0.8, noise(p * 38.0 + 2.0)) * band(38.0, px);
	col *= 1.0 - 0.3 * gaps * (1.0 - b);
	// Clover: small, round, bluish leaves in patches.
	float clover_patch = smoothstep(0.66, 0.78, fbm2(p * 0.55 + 23.0)) * (1.0 - dry);
	vec4 cl = cells(p * 12.0, 1.0);
	float leaf = (1.0 - smoothstep(0.28, 0.42, cl.x)) * clover_patch * band(12.0, px);
	col = mix(col, vec3(0.16, 0.30, 0.13) * (0.85 + 0.3 * cl.z), leaf * 0.75);
	h = 0.01 * tuft * tb + 0.005 * b * bb - 0.003 * gaps + 0.002 * leaf;
	return col;
}

// Wild flowers in clusters: white, yellow and violet dots.
vec3 flowers(vec2 p, float px, vec3 col, float amount, inout float h) {
	vec4 f = cells(p * 2.4, 1.0);
	float cluster = smoothstep(0.55, 0.75, fbm2(p * 0.25 + 61.0));
	float here = step(1.0 - amount * (0.08 + 0.35 * cluster), f.z);
	float r = 0.06 + 0.04 * f.w;
	float dot_ = (1.0 - smoothstep(r - 0.025, r, f.x)) * here * band(8.0, px);
	vec3 petal = f.w < 0.45 ? vec3(0.92, 0.9, 0.82) : (f.w < 0.8 ? vec3(0.95, 0.8, 0.22) : vec3(0.62, 0.42, 0.8));
	// A darker heart in the middle of each flower.
	petal = mix(petal, vec3(0.78, 0.56, 0.12), 1.0 - smoothstep(r * 0.25, r * 0.45, f.x));
	h += 0.004 * dot_;
	return mix(col, petal, dot_);
}

// Packed earth: darker, damp edges, a lighter trodden middle, grit,
// pebbles and the odd tuft of grass. centre is 1 in the middle of a path.
vec3 earth(vec2 p, float px, float centre, out float h) {
	vec3 col = dirt * (0.82 + fbm2(p * 0.9) * 0.32);
	col *= mix(0.86, 1.06, centre);
	// Darker, damp spots and lighter, dusty ones.
	float damp = smoothstep(0.6, 0.78, fbm2(p * 0.45 + 90.0));
	col = mix(col, col * vec3(0.7, 0.68, 0.66), damp);
	float g1 = noise(p * 22.0);
	float g2 = noise(p * 70.0 + 3.0);
	col *= 1.0 + (g1 - 0.5) * 0.18 * band(22.0, px) + (g2 - 0.5) * 0.16 * band(70.0, px);
	// Footprint-sized dents.
	float dents = smoothstep(0.55, 0.85, noise(p * 3.5 + 12.0));
	col *= 1.0 - 0.08 * dents * band(3.5, px);
	h = 0.004 * g1 * band(22.0, px) + 0.0015 * g2 * band(70.0, px) - 0.006 * dents * band(3.5, px);
	// Pebbles of every size, grey to brownish, each a small dome.
	vec4 s = cells(p * 6.0, 1.0);
	float r = 0.12 + 0.2 * s.w;
	float pebble = step(0.7, s.z) * (1.0 - smoothstep(r - 0.05, r, s.x)) * band(6.0, px);
	vec3 stone = mix(vec3(0.46, 0.44, 0.41), vec3(0.42, 0.34, 0.26), s.w) * (0.55 + 0.6 * (s.z - 0.7) / 0.3);
	stone *= 0.85 + 0.25 * (1.0 - s.x / r);
	col = mix(col * (1.0 - 0.25 * smoothstep(r + 0.08, r, s.x) * step(0.7, s.z) * band(6.0, px)), stone, pebble);
	h += 0.012 * pebble * sqrt(max(0.0, 1.0 - s.x / r));
	// Small finer gravel.
	vec4 s2 = cells(p * 18.0 + 4.0, 1.0);
	float grit = step(0.82, s2.z) * (1.0 - smoothstep(0.18, 0.28, s2.x)) * band(18.0, px);
	col = mix(col, vec3(0.44, 0.4, 0.35) * (0.75 + 0.4 * s2.w), grit * 0.6);
	h += 0.003 * grit;
	// Tufts of grass on the trodden earth, more of them towards the edges.
	vec4 t = cells(p * 1.4 + 31.0, 1.0);
	float tuft = step(0.6 + 0.35 * centre, t.z) * (1.0 - smoothstep(0.1, 0.32, t.x + (noise(p * 14.0) - 0.3) * 0.25));
	col = mix(col, grass_a * (0.8 + 0.5 * noise(p * 40.0)), tuft * band(4.0, px));
	h += 0.006 * tuft;
	return col;
}

// Round cobbles of uneven size with joints of soil, moss and weeds.
vec3 cobbles(vec2 p, float px, out float h) {
	vec2 q = p / 0.42;
	q += (vec2(noise(p * 1.3), noise(p * 1.3 + 9.0)) - 0.5) * 0.7;
	vec4 c = cells(q, 0.6);
	// Rounded corners: the face shrinks where three stones meet.
	float edge = (c.y - c.x) * (0.75 + 0.25 * noise(q * 3.0));
	float face = smoothstep(0.06, 0.16, edge);
	float dome = sqrt(smoothstep(0.04, 0.5, edge));
	// Each stone its own shade, some warmer, some cooler, a few dark ones.
	vec3 stone = mix(paving, vec3(dot(paving, vec3(0.33))), 0.45) * (0.8 + 0.3 * c.z);
	stone *= mix(vec3(1.04, 1.0, 0.94), vec3(0.94, 0.98, 1.05), c.w);
	stone *= c.z < 0.06 ? 0.75 : 1.0;
	// Grain, pits and the polish of feet on the tops.
	float grain = noise(p * 26.0 + c.z * 10.0);
	float fine = noise(p * 80.0);
	stone *= 1.0 + (grain - 0.5) * 0.22 * band(26.0, px) + (fine - 0.5) * 0.14 * band(80.0, px);
	stone *= 0.62 + 0.42 * dome;
	// Soot and dirt in large stains across the square.
	float stain = fbm2(p * 0.4 + 70.0);
	stone *= 0.88 + 0.24 * stain;
	// Joints: dark soil with moss and a little grass growing in them.
	float moss = smoothstep(0.45, 0.75, fbm2(p * 1.6 + 5.0));
	vec3 joint = mix(paving * 0.4, vec3(0.17, 0.24, 0.11), moss);
	joint *= (0.8 + 0.4 * noise(p * 45.0)) * (0.7 + 0.5 * smoothstep(0.0, 0.06, edge));
	// Moss creeps onto the edge of some stones.
	stone = mix(stone, vec3(0.2, 0.28, 0.12), moss * (1.0 - smoothstep(0.1, 0.24, edge)) * 0.7);
	h = 0.025 * dome * face + 0.0015 * grain * band(26.0, px) + 0.0008 * fine * band(80.0, px);
	return mix(joint, stone, face);
}

// Leaf litter and needles over dark soil under the trees.
// Mountain scree: angular grey stones of every size on pale grit, a little
// dry grass between them.
vec3 scree(vec2 p, float px, out float h) {
	// Pale grit with darker, damp patches and a little dry grass.
	vec3 col = vec3(0.45, 0.44, 0.42) * (0.86 + 0.26 * fbm2(p * 0.6 + 61.0));
	col = mix(col, vec3(0.37, 0.38, 0.24), smoothstep(0.64, 0.82, fbm2(p * 0.45 + 19.0)) * 0.55);
	col *= 1.0 + (noise(p * 30.0) - 0.5) * 0.2 * band(30.0, px);
	// Loose stones, scattered rather than packed: most cells stay grit.
	vec4 s = cells(p * 1.6, 1.0);
	float r = 0.18 + 0.16 * s.w;
	float rock = step(0.62, s.z) * (1.0 - smoothstep(r - 0.06, r, s.x)) * band(1.6, px);
	vec3 stone = mix(vec3(0.55, 0.54, 0.52), vec3(0.4, 0.39, 0.38), s.w) * (0.78 + 0.35 * (1.0 - s.x / r));
	col = mix(col * (1.0 - 0.22 * step(0.62, s.z) * smoothstep(r + 0.1, r, s.x) * band(1.6, px)), stone, rock);
	vec4 s2 = cells(p * 7.0 + 3.0, 1.0);
	float r2 = 0.15 + 0.15 * s2.w;
	float pebble = step(0.7, s2.z) * (1.0 - smoothstep(r2 - 0.05, r2, s2.x)) * band(7.0, px);
	col = mix(col, vec3(0.52, 0.51, 0.49) * (0.75 + 0.4 * s2.w), pebble * 0.8);
	h = 0.02 * rock * sqrt(max(0.0, 1.0 - s.x / r)) + 0.004 * pebble;
	return col;
}

vec3 forest_floor(vec2 p, float px, float n, out float h) {
	vec3 col = forest * (0.8 + 0.4 * fbm2(p * 0.8 + 3.0));
	float needles = noise(vec2(p.x * 40.0 + p.y * 12.0, p.y * 6.0)) * noise(vec2(p.y * 40.0 - p.x * 12.0, p.x * 6.0) + 2.0);
	col *= 0.9 + needles * 0.5 * band(30.0, px);
	// Moss in soft, brighter cushions.
	float moss = smoothstep(0.58, 0.75, fbm2(p * 0.6 + 14.0));
	col = mix(col, vec3(0.16, 0.25, 0.09) * (0.85 + 0.3 * noise(p * 20.0)), moss);
	// Fallen leaves, two layers on top of each other.
	h = 0.004 * needles * band(30.0, px) + 0.008 * moss;
	for (int k = 0; k < 2; k++) {
		vec2 lp = p * (5.0 + float(k) * 2.0) + float(k) * 13.7;
		lp += (vec2(noise(lp * 0.7), noise(lp * 0.7 + 4.0)) - 0.5) * 0.8;
		vec4 l = cells(lp, 1.0);
		float leaf = step(0.35, l.z) * (1.0 - smoothstep(0.26, 0.36, l.x)) * band(5.0 + float(k) * 2.0, px);
		vec3 tint = l.w < 0.4 ? vec3(0.36, 0.22, 0.1) : (l.w < 0.75 ? vec3(0.5, 0.32, 0.12) : vec3(0.28, 0.25, 0.1));
		tint *= 0.6 + 0.5 * l.z;
		col = mix(col, tint, leaf * (1.0 - moss * 0.7));
		h += 0.003 * leaf;
	}
	return col;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float px = length(fwidth(world_pos));
	vec2 uv = (p / tile + 0.5) / grid_size;
	vec4 m = texture(ground_mask, uv);
	float n = fbm2(p * 0.18);
	float fray = fbm2(p * 1.1 + 50.0) - 0.5;

	// How much of each kind of ground lies here.
	float wood = smoothstep(0.45, 0.75, 1.0 - m.a + (n - 0.5) * 0.4 + fray * 0.15);
	float square = smoothstep(0.55, 0.7, min(m.r, m.g) + (n - 0.5) * 0.1 + fray * 0.12);
	float soil = smoothstep(0.4, 0.7, m.g + (n - 0.5) * 0.3) * (1.0 - square);
	float path = smoothstep(0.42, 0.6, m.r + (n - 0.5) * 0.3 + fray * 0.18) * (1.0 - square);
	float wet = smoothstep(0.5, 0.62, m.b + (n - 0.5) * 0.15);
	float bank = smoothstep(0.25, 0.5, m.b + (n - 0.5) * 0.15) * (1.0 - wet);

	float h = 0.0;
	float hg;
	vec3 col = grass(p, px, n, max(soil, bank), hg);
	col = flowers(p, px, col, (1.0 - soil) * (1.0 - wood) * (1.0 - path) * (1.0 - bank), hg);
	h = hg;
	if (wood > 0.001) {
		float hf;
		vec3 f = forest_floor(p, px, n, hf);
		col = mix(col, f, wood);
		h = mix(h, hf, wood);
	}
	if (soil > 0.001) {
		// Graveyard: dark, mossy turf, worn down to bare soil in places.
		vec3 turf = col * (grave_soil / grass_a) * 0.95;
		float bare = smoothstep(0.55, 0.75, fbm2(p * 0.5 + 33.0));
		vec3 ground = grave_soil * vec3(1.25, 1.0, 0.85) * (0.8 + 0.4 * noise(p * 12.0));
		col = mix(col, mix(turf, ground, bare * 0.7), soil);
	}
	float stony = smoothstep(0.4, 0.62, texture(stone_mask, uv).r + (n - 0.5) * 0.3 + fray * 0.2);
	if (stony > 0.001) {
		float hs;
		vec3 sc = scree(p, px, hs);
		col = mix(col, sc, stony);
		h = mix(h, hs, stony);
	}
	if (path > 0.001) {
		float he;
		vec3 e = earth(p, px, smoothstep(0.7, 1.0, m.r), he);
		col = mix(col, e, path);
		h = mix(h, he, path);
	}
	float rough = 0.95;
	if (square > 0.001) {
		float hc;
		vec3 c = cobbles(p, px, hc);
		col = mix(col, c, square);
		h = mix(h, hc, square);
		rough = mix(rough, 0.82, square);
	}
	// Muddy, dark banks round the water.
	col = mix(col, col * vec3(0.6, 0.58, 0.55), bank * 0.8);
	// Still water with slow ripples.
	if (wet > 0.001) {
		float ripple = noise(p * 2.0 + vec2(TIME * 0.15, TIME * 0.1)) + 0.5 * noise(p * 5.0 - vec2(TIME * 0.2, 0.0));
		vec3 pond = water * (0.85 + 0.15 * sin(TIME * 0.8 + p.x * 0.7 + p.y * 0.4));
		pond *= 0.9 + 0.2 * fbm2(p * 0.6);
		col = mix(col, pond, wet);
		h = mix(h, 0.004 * ripple, wet);
	}
	ALBEDO = col;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	ROUGHNESS = mix(rough, 0.12, wet);
	SPECULAR = mix(0.25, 0.6, wet);
}
