shader_type spatial;
// Felled trunks to chop for timber (see WoodLogs): the bark of a lying tree
// and its sawn ends. The mesh is built in code (WoodLogs.trunk_mesh) with the
// trunk along its own x axis, so everything here is in the trunk's own space
// and the pattern lies along the trunk however it is turned.
//   bark:      thick plates split by deep fissures running along the trunk,
//              lichen in patches, moss on the upper side and earth low down
//              where it lies on the ground;
//   end grain: growth rings that follow the outline round a pith a little
//              off the middle, darker heartwood, pale sapwood, the bark as a
//              dark rim, drying cracks running out from the pith and faint
//              marks of the saw.
// Fine detail fades out where it would be smaller than a few pixels.

#include "res://shaders/detail.gdshaderinc"

// The bark's colour as painted (sRGB), and the wood of the sawn ends.
uniform vec3 bark_colour : source_color = vec3(0.4, 0.27, 0.17);
uniform vec3 sapwood : source_color = vec3(0.86, 0.7, 0.48);
uniform vec3 heartwood : source_color = vec3(0.68, 0.48, 0.28);
// false: the bark (UV.x along the trunk in metres, UV.y round it, 0 to 1);
// true: a sawn end (UV from -1 to 1 across it, 1 at the bark).
uniform bool end_grain = false;
// How much moss grows on the upper side: little on a fresh trunk, much on a windfall.
uniform float moss : hint_range(0.0, 1.0) = 0.2;
// The trunk's radius (metres), so rings and fissures keep their real size.
uniform float radius = 0.3;
// Rings across the radius, and a number of its own for every trunk.
uniform float rings = 18.0;
uniform float seed = 0.0;

// As painted (sRGB); lin() turns them into the linear light the uniforms arrive in.
const vec3 MOSS = vec3(0.32, 0.4, 0.16);
const vec3 LICHEN = vec3(0.62, 0.65, 0.5);
const vec3 EARTH = vec3(0.24, 0.19, 0.13);

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

varying vec3 obj_pos;
varying vec3 world_nrm;
varying float ground;

void vertex() {
	obj_pos = VERTEX;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

vec3 bark(vec2 tex, float px, out float h) {
	float a = tex.y * TAU;
	// Round the trunk on a circle, so the pattern has no seam.
	vec3 q = vec3(tex.x, cos(a) * radius, sin(a) * radius) + seed;
	// Long bark plates, split by deep fissures that wander along the trunk.
	float plates = vnoise(vec3(q.x * 2.2, q.y * 11.0, q.z * 11.0));
	float ridge = 1.0 - abs(2.0 * vnoise(vec3(q.x * 1.6, q.y * 17.0, q.z * 17.0) + 5.0) - 1.0);
	float fissure = smoothstep(0.68, 0.88, ridge);
	// Cross breaks between the plates, and fine flaky texture on them.
	float breaks = smoothstep(0.82, 0.95, 1.0 - abs(2.0 * vnoise(vec3(q.x * 7.0, q.y * 4.0, q.z * 4.0) + 9.0) - 1.0));
	float flake = vnoise(q * vec3(14.0, 40.0, 40.0));
	float gb = band(17.0, px);
	float fb = band(40.0, px);
	float crack = max(fissure, breaks * 0.7) * gb;
	float shade = 0.8 + 0.4 * plates + 0.2 * (flake - 0.5) * fb - 0.75 * crack;
	// Real bark is a duller brown than the painted colour.
	vec3 c = mix(bark_colour, vec3(dot(bark_colour, vec3(0.3, 0.59, 0.11))), 0.3) * shade;
	// The plates' tops weather lighter and greyer than the fissures.
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))) * 1.15, 0.25 * plates * (1.0 - crack));
	// Lichen in pale patches, moss on the upper side, earth where it lies.
	float lichen = smoothstep(0.7, 0.8, fbm(q * vec3(3.0, 9.0, 9.0) + 17.0)) * (1.0 - crack);
	c = mix(c, lin(LICHEN) * (0.85 + 0.3 * flake), lichen * 0.55);
	float up = smoothstep(0.25, 0.85, world_nrm.y);
	float moss_patch = smoothstep(0.62 - 0.45 * moss, 0.75 - 0.4 * moss, fbm(q * vec3(2.0, 7.0, 7.0) + 41.0));
	float mossy = clamp(up * moss_patch * (0.4 + moss) + crack * up * moss * 0.6, 0.0, 1.0);
	c = mix(c, lin(MOSS) * (0.75 + 0.5 * flake), mossy);
	float low = 1.0 - smoothstep(0.0, radius * 0.6, ground);
	c = mix(c, lin(EARTH), low * 0.55);
	h = (0.03 * plates + 0.006 * flake * fb - 0.04 * crack) + 0.01 * mossy;
	return c;
}

vec3 sawn_end(vec2 uv, float px, out float h) {
	float d0 = length(uv);
	// The pith lies a little off the middle, and the rings crowd on one side
	// (the side that grew towards the shade).
	vec2 pith = vec2(cos(seed * 3.1), sin(seed * 3.1)) * 0.12;
	vec2 r = uv - pith * (1.0 - d0);
	float d = length(r);
	float ang = atan(r.y, r.x);
	vec3 n3 = vec3(uv * 3.0, seed);
	// Rings wobble a little round the trunk and are not evenly wide.
	float wob = d + 0.035 * (vnoise(n3) - 0.5) + 0.02 * (vnoise(n3 * 3.0 + 4.0) - 0.5);
	float k = wob * rings + 1.5 * vnoise(vec3(wob * 4.0, seed, 2.0));
	float ring = fract(k);
	// Each year ends in a thin dark band of late wood.
	float late = smoothstep(0.72, 0.9, ring) * (1.0 - smoothstep(0.9, 1.0, ring));
	float rb = band(rings / max(radius, 0.05), px);
	vec3 wood = mix(heartwood * 0.88, heartwood, smoothstep(0.0, 0.25, d));
	wood = mix(wood, sapwood, smoothstep(0.55, 0.7, d));
	wood *= 1.0 - 0.14 * late * rb;
	// The dark pith.
	wood = mix(wood * 0.6, wood, smoothstep(0.02, 0.06, d));
	// Drying cracks from the pith outwards: a few, of different lengths.
	float n = 5.0;
	float sector = floor((ang / TAU + 0.5) * n);
	float mid = (sector + 0.5 + 0.3 * (hash3(vec3(sector, seed, 1.0)) - 0.5)) / n;
	float off = abs(fract(ang / TAU + 0.5) - mid) * TAU * d;
	float reach = 0.2 + 0.4 * hash3(vec3(sector, seed, 7.0));
	float check = (1.0 - smoothstep(0.0, 0.004 + 0.025 * d * (1.0 - d / reach), off)) * (1.0 - smoothstep(reach - 0.1, reach, d)) * step(0.06, d);
	check *= step(0.5, hash3(vec3(sector, seed, 3.0))) * 0.8;
	// Faint marks of the saw across the cut.
	float saw = vnoise(vec3(uv.x * 2.0, uv.y * 60.0, seed)) * band(60.0 / max(radius, 0.05), px);
	wood *= 0.94 + 0.08 * saw;
	wood *= 1.0 - 0.7 * check;
	// The bark round the edge: dark and a finger thick, with a pale inner bark.
	float inner = smoothstep(0.86, 0.9, d0) * (1.0 - smoothstep(0.9, 0.93, d0));
	wood = mix(wood, sapwood * 1.08, inner * 0.6);
	float rim = smoothstep(0.9, 0.94, d0 + 0.02 * (vnoise(vec3(ang * 3.0, seed, 5.0)) - 0.5));
	wood = mix(wood, bark_colour * 0.75, rim);
	// The cut greys a little in the weather.
	wood = mix(wood, vec3(dot(wood, vec3(0.3, 0.59, 0.11))), 0.12);
	h = -0.01 * late * rb - 0.02 * check + 0.002 * saw - 0.01 * rim;
	return wood;
}

void fragment() {
	float px = length(fwidth(obj_pos));
	float h = 0.0;
	vec3 c = end_grain ? sawn_end(UV, px, h) : bark(UV, px, h);
	ALBEDO = c;
	ROUGHNESS = end_grain ? 0.85 : 0.95;
	SPECULAR = end_grain ? 0.15 : 0.12;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
}
