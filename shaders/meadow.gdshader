shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
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
#include "res://shaders/cobbles.gdshaderinc"
#include "res://shaders/shore.gdshaderinc"
#include "res://shaders/under_ice.gdshaderinc"

uniform sampler2D ground_mask : filter_linear, repeat_disable;
// Scree in the mountains (see Mountains): one pixel per tile, red 1 where
// the ground is stony. Black (no scree) everywhere else by default.
uniform sampler2D stone_mask : filter_linear, repeat_disable, hint_default_white;
uniform float stone_reach = 6.0;
// The apron of earth at the foot of the mountains (see MountainFoot): 1 inside the rock at its foot, falling to 0 a few
// metres out on the open ground. foot_apron is how strongly it is drawn, foot_gravel how stony and foot_moss how
// grassy it is. foot_earth is the colour of the earth on the foot of the rock mesh (MountainFoot.EARTH).
uniform sampler2D foot_mask : filter_linear, repeat_disable, hint_default_black;
uniform float foot_apron = 0.0;
uniform float foot_gravel = 0.0;
uniform float foot_moss = 0.0;
uniform vec3 foot_earth = vec3(0.5, 0.44, 0.37);
uniform vec2 grid_size = vec2(16.0, 16.0);
uniform float tile = 4.0;
// Holes in the ground (a player's cellar): one pixel per 2 m cell of the map.
uniform sampler2D hole_mask : filter_nearest, repeat_disable, hint_default_black;
uniform bool holes_on = false;
uniform vec3 grass_a = vec3(0.22, 0.33, 0.14);
uniform vec3 grass_b = vec3(0.31, 0.40, 0.17);
uniform vec3 forest = vec3(0.11, 0.17, 0.08);
uniform vec3 dirt = vec3(0.40, 0.31, 0.22);
uniform vec3 grave_soil = vec3(0.20, 0.23, 0.14);
uniform vec3 water = vec3(0.16, 0.30, 0.38);
// Ice over the ponds (see IceCover): 0 open water to 1 frozen over. It creeps in from the banks,
// and the holes (x, z, radius) stay open for fishing.
uniform float ice : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ice_holes[4];
uniform vec3 ice_color = vec3(0.62, 0.76, 0.82);
// The ponds' shore (shore_mask, see shore.gdshaderinc) gives the water its curves, the shallows
// and the deep middle, and the muddy, sandy bank. The colours of those:
uniform vec3 shallow_water = vec3(0.20, 0.30, 0.27);
uniform vec3 deep_water = vec3(0.06, 0.16, 0.20);
uniform vec3 mud = vec3(0.24, 0.20, 0.14);
uniform vec3 sand = vec3(0.52, 0.46, 0.33);
uniform vec3 paving = vec3(0.50, 0.47, 0.43);
// The graveyard (x0, z0, x1, z1 in metres): its paving is old, sunk and
// overgrown, and fallen leaves lie on its turf. Empty by default.
uniform vec4 old_paving = vec4(0.0);

varying vec3 world_pos;

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
	if (holes_on) {
		vec2 hole_uv = (p + vec2(0.5 * tile)) / (grid_size * tile);
		if (hole_uv.x >= 0.0 && hole_uv.y >= 0.0 && hole_uv.x <= 1.0 && hole_uv.y <= 1.0 && texture(hole_mask, hole_uv).r > 0.5) {
			discard;
		}
	}
	float px = length(fwidth(world_pos));
	vec2 uv = (p / tile + 0.5) / grid_size;
	vec4 m = texture(ground_mask, uv);
	float n = fbm2(p * 0.18);
	float fray = fbm2(p * 1.1 + 50.0) - 0.5;
	float old = step(old_paving.x, p.x) * step(p.x, old_paving.z) * step(old_paving.y, p.y) * step(p.y, old_paving.w);

	// How much of each kind of ground lies here.
	float wood = smoothstep(0.45, 0.75, 1.0 - m.a + (n - 0.5) * 0.4 + fray * 0.15);
	float square = smoothstep(0.55, 0.7, min(m.r, m.g) + (n - 0.5) * 0.1 + fray * 0.12);
	float soil = smoothstep(0.4, 0.7, m.g + (n - 0.5) * 0.3) * (1.0 - square);
	float path = smoothstep(0.42, 0.6, m.r + (n - 0.5) * 0.3 + fray * 0.18) * (1.0 - square);
	// While the ponds are icing over, the water reaches a little past the bank's ragged edge, so no
	// strip of bare grass shows round the ice where the snow leaves the pond tiles clear.
	float reach = 0.16 * smoothstep(0.0, 0.5, ice);
	float wet = smoothstep(0.5 - reach, 0.62 - reach, m.b + (n - 0.5) * 0.15);
	// Metres from the nearest bank (plus over the water), meandering a little about the tiles' edge.
	float shore = shore_at(uv, p);
	if (shore_on) {
		wet = smoothstep(-0.05, 0.05, shore + reach * 4.0);
	}

	float h = 0.0;
	float hg;
	vec3 col = grass(p, px, n, soil, hg);
	col = flowers(p, px, col, (1.0 - soil) * (1.0 - wood) * (1.0 - path), hg);
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
		// Fallen leaves from the autumn trees round the graveyard.
		if (old > 0.5) {
			vec2 lp = p * 4.0 + (vec2(noise(p * 2.8), noise(p * 2.8 + 4.0)) - 0.5) * 0.8;
			vec4 l = cells(lp, 1.0);
			float drift = smoothstep(0.4, 0.7, fbm2(p * 0.35 + 81.0));
			float leaf = step(1.0 - 0.55 * drift, l.z) * (1.0 - smoothstep(0.24, 0.34, l.x)) * band(4.0, px) * soil;
			vec3 tint = l.w < 0.4 ? vec3(0.42, 0.22, 0.08) : (l.w < 0.75 ? vec3(0.55, 0.36, 0.1) : vec3(0.3, 0.26, 0.1));
			col = mix(col, tint * (0.6 + 0.5 * l.z), leaf * 0.85);
			h += 0.003 * leaf;
		}
	}
	// The masks hold one pixel per tile: read straight, a single tile shows as a diamond and a row of them as stairs.
	// Reading them through a wandering offset (a few metres, in lobes) turns every outline into rounded, irregular
	// lobes, and the soft threshold blends instead of cutting.
	vec2 wob = (vec2(fbm2(p * 0.26 + 13.0), fbm2(p * 0.26 + 71.0)) - 0.5) * 3.4 + (vec2(noise(p * 0.85 + 5.0), noise(p * 0.85 + 23.0)) - 0.5) * 1.1;
	vec2 wuv = uv + wob / (grid_size * tile);
	// The scree's edge is a distance in metres (like the shore), wandering a little, so it fades in soft curves.
	float sd = (texture(stone_mask, uv).r - 0.5) * 2.0 * stone_reach + (fbm2(p * 0.35 + 40.0) - 0.5) * 1.6 + (noise(p * 1.4 + 9.0) - 0.5) * 0.5;
	float stony = 1.0 - smoothstep(-1.0, 0.9, sd);
	if (stony > 0.001) {
		float hs;
		vec3 sc = scree(p, px, hs);
		col = mix(col, sc, stony);
		h = mix(h, hs, stony);
	}
	if (foot_apron > 0.0) {
		float f = texture(foot_mask, wuv).r;
		// The outline wanders in lobes a few metres wide and frays at the very edge: no tile line shows.
		float edge = f + (fbm2(p * 0.33 + 7.0) - 0.5) * 0.85 + (fbm2(p * 1.6 + 3.0) - 0.5) * 0.24 + (noise(p * 9.0) - 0.5) * 0.08;
		float apron = smoothstep(0.24, 0.62, edge) * foot_apron;
		if (apron > 0.001) {
			vec3 fe = foot_earth * (0.86 + 0.28 * fbm2(p * 0.8 + 21.0));
			fe *= 1.0 + (noise(p * 30.0) - 0.5) * 0.18 * band(30.0, px) + (noise(p * 90.0) - 0.5) * 0.14 * band(90.0, px);
			// Damp, darker patches in the dust.
			fe = mix(fe, fe * vec3(0.78, 0.76, 0.74), smoothstep(0.6, 0.78, fbm2(p * 0.45 + 90.0)) * 0.7);
			float fh = 0.0;
			if (foot_gravel > 0.0) {
				vec4 gs = cells(p * 5.0, 1.0);
				float gr = 0.14 + 0.14 * gs.w;
				float gst = step(0.42, gs.z) * (1.0 - smoothstep(gr - 0.05, gr, gs.x)) * band(5.0, px);
				vec3 gc = mix(vec3(0.6, 0.55, 0.5), vec3(0.4, 0.37, 0.34), gs.w) * (0.8 + 0.3 * (1.0 - gs.x / gr));
				fe = mix(fe, gc, gst * foot_gravel);
				fh = 0.012 * gst * foot_gravel;
			}
			// Grass creeps in over the earth in patches, thickest out where the apron thins.
			float gp = foot_moss * smoothstep(0.52, 0.72, fbm2(p * 0.85 + 55.0) + (1.0 - edge) * 0.35);
			fe = mix(fe, col * vec3(1.0, 0.97, 0.82), gp * 0.8);
			col = mix(col, fe, apron);
			h = mix(h, fh, apron);
		}
	}
	if (path > 0.001) {
		float he;
		vec3 e = earth(p, px, smoothstep(0.7, 1.0, m.r), he);
		col = mix(col, e, path);
		h = mix(h, he, path);
	}
	float rough = 0.95;
	float wet_ice = 0.0;
	// The bank: dark wet mud at the water's edge, pale sand and pebbles in places a step up, and
	// lusher grass a little further back. Paths and paving keep their own look.
	float bank = shore_on ? smoothstep(-1.4 - 1.2 * fbm2(p * 0.4 + 31.0), -0.25, shore) * (1.0 - wet) : 0.0;
	bank *= (1.0 - path) * (1.0 - square) * (1.0 - wood * 0.6);
	if (bank > 0.001) {
		float muddy = smoothstep(-1.0, -0.2, shore);
		float sandy = smoothstep(0.45, 0.65, fbm2(p * 0.35 + 21.0)) * (1.0 - muddy * 0.7);
		vec3 ground = mix(mud * (0.8 + 0.4 * noise(p * 9.0)), sand * (0.85 + 0.25 * noise(p * 14.0)), sandy);
		// Pebbles washed up along the edge.
		vec4 pc = cells(p * 5.0, 1.0);
		float pebble = (1.0 - smoothstep(0.18, 0.26, pc.x)) * step(0.55, pc.z) * band(5.0, px);
		ground = mix(ground, vec3(0.45, 0.43, 0.4) * (0.7 + 0.5 * pc.w), pebble * (0.4 + 0.6 * sandy));
		// Ragged tufts of grass still reach down into the mud.
		float tuft = smoothstep(0.5, 0.7, fbm2(p * 1.8 + 9.0)) * (1.0 - muddy);
		col = mix(col, mix(ground, col, tuft), bank);
		h = mix(h, 0.003 * pebble + 0.001 * noise(p * 20.0), bank);
		rough = mix(rough, mix(0.9, 0.55, muddy * (1.0 - sandy)), bank);
	}
	if (shore_on) {
		// Grass grows lush and dark a little back from the water.
		float lush = smoothstep(-4.0, -2.0, shore) * (1.0 - smoothstep(-1.6, -0.6, shore)) * (1.0 - path) * (1.0 - square);
		col = mix(col, col * vec3(0.8, 0.95, 0.75), lush * 0.6);
	}
	if (square > 0.001) {
		float hc;
		vec3 c = cobbles(p, px, old, paving, hc);
		col = mix(col, c, square);
		h = mix(h, hc, square);
		rough = mix(rough, 0.82, square);
	}
	// Still water with slow ripples.
	if (wet > 0.001) {
		float ripple = noise(p * 2.0 + vec2(TIME * 0.15, TIME * 0.1)) + 0.5 * noise(p * 5.0 - vec2(TIME * 0.2, 0.0));
		vec3 pond = water * (0.85 + 0.15 * sin(TIME * 0.8 + p.x * 0.7 + p.y * 0.4));
		pond *= 0.9 + 0.2 * fbm2(p * 0.6);
		float depth = clamp((m.b - 0.5) * 2.0, 0.0, 1.0);
		if (shore_on) {
			// Clear shallows over sand and pebbles at the edge, darkening to the deep middle.
			float deep = smoothstep(0.0, 3.2, shore + (fbm2(p * 0.3 + 5.0) - 0.5) * 1.4);
			vec4 sc = cells(p * 3.5, 1.0);
			float stone = (1.0 - smoothstep(0.2, 0.35, sc.x)) * step(0.5, sc.z) * band(3.5, px);
			vec3 bed = mix(sand * (0.7 + 0.2 * fbm2(p * 1.3)), vec3(0.34, 0.33, 0.29), stone * 0.5);
			vec3 shallows = mix(bed, shallow_water, 0.35 + 0.65 * smoothstep(0.0, 1.2, shore));
			pond = mix(shallows, deep_water, deep) * (0.92 + 0.08 * sin(TIME * 0.8 + p.x * 0.7 + p.y * 0.4));
			pond *= 0.93 + 0.14 * fbm2(p * 0.6);
			// A faint bright line where the water laps at the bank.
			float lap = 1.0 - smoothstep(0.0, 0.12, abs(shore - 0.06 - 0.04 * sin(TIME * 1.3 + p.x * 1.7)));
			pond += vec3(0.06) * lap;
			// Lily pads in a few clusters on the calmer water a few steps out.
			vec2 lq = p * 0.9 + vec2(noise(p * 0.5), noise(p * 0.5 + 3.0)) * 0.6;
			vec4 lc = cells(lq, 0.9);
			float cluster = smoothstep(0.55, 0.7, fbm2(p * 0.22 + 44.0));
			float pad_zone = smoothstep(0.7, 1.5, shore) * (1.0 - smoothstep(2.6, 3.6, shore)) * cluster * step(0.35, lc.z);
			float pad = (1.0 - smoothstep(0.2, 0.23, lc.x * (0.75 + 0.5 * lc.w))) * pad_zone;
			vec3 leaf = vec3(0.17, 0.31, 0.12) * (0.8 + 0.4 * noise(p * 6.0));
			pond = mix(pond, leaf, pad * 0.9);
			depth = clamp(shore / 2.5, 0.0, 1.0);
		}
		float frozen = 0.0;
		if (ice > 0.001) {
			// Ice grows from the banks inward, ragged where it meets the open water.
			float edge = depth * 0.6 + (fbm2(p * 0.9 + 11.0) - 0.5) * 0.3;
			frozen = smoothstep(edge, edge + 0.1, ice * 1.15);
			float opening = 0.0;
			float rim = 0.0;
			for (int i = 0; i < 4; i++) {
				float d = length(p - ice_holes[i].xy) + (fbm2(p * 3.0) - 0.5) * 0.25;
				float r = ice_holes[i].z;
				opening = max(opening, r > 0.0 ? 1.0 - smoothstep(r - 0.08, r + 0.08, d) : 0.0);
				rim = max(rim, r > 0.0 ? 1.0 - smoothstep(r + 0.1, r + 0.7, d) : 0.0);
			}
			frozen *= 1.0 - opening;
			// Frosted, scratched ice, a little whiter where it is thickest round the hole.
			float frost = fbm2(p * 1.6 + 5.0);
			float scratch = smoothstep(0.62, 0.7, noise(vec2(p.x * 7.0 + p.y * 2.0, p.y * 6.0 - p.x * 1.5)));
			vec3 sheet = ice_color * (0.85 + 0.3 * frost) + vec3(0.18) * scratch + vec3(0.12) * rim;
			// What drifts beneath: leaves, sticks and a fish now and then, dimmed and tinted by the ice over them.
			if (shore_on && frozen > 0.4) {
				vec4 under = under_ice(p, TIME);
				float seen = frozen * smoothstep(0.7, 1.6, shore);
				// Deep under the ice: faint shapes, mostly the colour of the ice itself.
				vec3 seen_col = mix(under.rgb * 0.6, ice_color * 0.8, 0.65);
				sheet = mix(sheet, ice_color * 0.8, under.a * seen * 0.22);
				sheet = mix(sheet, seen_col, under.a * seen * 0.42);
			}
			pond = mix(pond, sheet, frozen);
		}
		col = mix(col, pond, wet);
		h = mix(h, mix(0.004 * ripple, 0.002 * noise(p * 9.0), frozen), wet);
		wet_ice = frozen * wet;
	}
	ALBEDO = col;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	ROUGHNESS = mix(rough, mix(0.12, 0.3, wet_ice), wet);
	SPECULAR = mix(0.25, 0.6, wet);
	ALBEDO = gl_colour(ALBEDO);
}
