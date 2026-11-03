shader_type spatial;
// Old, neglected stone for the dungeon's fountain: the rough, matt stone of
// stone.gdshader, left for centuries in a damp cellar. On top of its stains,
// grain and pits it adds:
// - cracks: thin, dark, branching lines that run across the blocks,
// - streaks: dark runs of damp that trickle down the sides from the top,
// - a crust of lime just above each water line and darker, wet stone below,
// - moss and green slime on what faces up and near the floor and the water,
// - chipped, bitten edges where the stone has flaked away.
// strength 0 is plain carved stone, 1 the long-forgotten dungeon fountain.
// The pattern is laid out in world space like the walls' stone; heights are
// measured from the piece's own origin (the foot of the fountain). Fine
// detail fades out where it would be smaller than a few pixels.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo_color : source_color = vec3(0.56, 0.54, 0.5);
uniform float strength = 1.0;
// How much more moss grows low down, near the floor (0 for loose rubble,
// whose own foot is not the fountain's).
uniform float low_moss = 1.0;
// Where water stands against the stone: the height of its surface (above
// the fountain's foot; negative for none), the radius of the basin that holds
// it and the height of that basin's floor.
uniform float water_line_a = -1.0;
uniform float water_radius_a = 1.32;
uniform float water_floor_a = 0.2;
uniform float water_line_b = -1.0;
uniform float water_radius_b = 0.52;
uniform float water_floor_b = 2.04;

const vec3 MOSS = vec3(0.16, 0.22, 0.08);
const vec3 SLIME = vec3(0.12, 0.17, 0.11);
const vec3 LIME = vec3(0.7, 0.69, 0.6);
const vec3 GRIME = vec3(0.17, 0.15, 0.12);

varying vec3 world_pos;
varying vec3 world_normal;
varying float height;
varying float dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = world_pos.y - NODE_POSITION_WORLD.y;
	dist = length(world_pos.xz - NODE_POSITION_WORLD.xz);
}

// Whether a point is inside a basin, between its floor and the top of its
// wall (only there does the water touch the stone).
float inside(float radius, float bottom, float r, float h) {
	return (1.0 - smoothstep(radius, radius + 0.02, r)) * step(bottom, h);
}

// 1 on a band just above a water line: the lime crust.
float crust(float line, float h) {
	if (line < 0.0) {
		return 0.0;
	}
	return smoothstep(-0.015, 0.0, h - line) * (1.0 - smoothstep(0.03, 0.08, h - line));
}

// 1 below a water line: wet, dark stone.
float wet(float line, float h) {
	return line < 0.0 ? 0.0 : 1.0 - smoothstep(-0.01, 0.01, h - line);
}

void fragment() {
	vec3 p = world_pos;
	float px = length(fwidth(p));
	float s = strength;
	float up = smoothstep(0.4, 0.9, world_normal.y);
	float side = 1.0 - smoothstep(0.3, 0.7, abs(world_normal.y));

	// The carved stone underneath (as in stone.gdshader, a little coarser).
	float stains = fbm(p * 0.8);
	float grit = fbm(p * 5.0);
	float pits = smoothstep(0.58, 0.8, vnoise(p * 16.0)) * band(16.0, px);
	float sand = (vnoise(p * 40.0) - 0.5) * band(40.0, px);

	// Cracks: the zero lines of two noises, kept only in some places, so a
	// few long cracks wander over the stone instead of a net.
	float n1 = vnoise(p * vec3(2.6, 3.4, 2.6) + 4.0) + 0.35 * vnoise(p * 9.0);
	float n2 = vnoise(p * vec3(5.5, 7.0, 5.5) + 13.0);
	float c1 = 1.0 - smoothstep(0.0, 0.03, abs(n1 - 0.67));
	float c2 = (1.0 - smoothstep(0.0, 0.02, abs(n2 - 0.5))) * smoothstep(0.6, 0.75, vnoise(p * 2.0 + 21.0));
	float cracks = max(c1 * smoothstep(0.55, 0.7, vnoise(p * 1.3 + 7.0)), c2 * 0.8) * band(9.0, px) * s;

	// Damp streaks running down the sides: noise stretched along the height,
	// strongest just under the coping and the bowl.
	float runs = vnoise(vec3(p.x * 7.0, p.y * 0.9, p.z * 7.0) + 2.0);
	float streaks = smoothstep(0.55, 0.85, runs) * side * band(7.0, px) * s;

	// Water lines: a pale crust of lime above, dark, wet stone below.
	float h = height;
	float in_a = inside(water_radius_a, water_floor_a, dist, h);
	float in_b = inside(water_radius_b, water_floor_b, dist, h);
	float lime = max(crust(water_line_a, h) * in_a, crust(water_line_b, h) * in_b) * (0.6 + 0.4 * vnoise(p * 14.0));
	float under = max(wet(water_line_a, h) * in_a, wet(water_line_b, h) * in_b);

	// Moss and slime: on what faces up, low down where the damp collects and
	// along the water, in patches.
	float patches = fbm(p * 2.4 + 5.0);
	float low = 1.0 - smoothstep(0.0, 0.5, h);
	float near_water = max((1.0 - smoothstep(0.0, 0.2, abs(h - water_line_a))) * in_a, (1.0 - smoothstep(0.0, 0.12, abs(h - water_line_b))) * in_b);
	float moss = smoothstep(0.68, 0.82, patches + 0.1 * up + 0.1 * low * low_moss + 0.15 * near_water) * s;
	float fuzz = vnoise(p * 34.0) * band(34.0, px);

	// Chipped spots: bigger, bitten pits where the stone has flaked away.
	float chips = smoothstep(0.7, 0.82, vnoise(p * 7.0 + 3.0)) * smoothstep(0.4, 0.6, stains) * band(7.0, px) * s;

	float shade = 1.0 + 1.7 * (0.24 * (stains - 0.5) + 0.16 * (grit - 0.5) - 0.14 * pits + 0.08 * sand);
	vec3 col = albedo_color * shade;
	// Aged: darker and dirtier overall, browner where the grime is cloudy.
	col = mix(col, GRIME * (0.8 + 0.6 * grit), s * (0.1 + 0.3 * smoothstep(0.45, 0.8, stains)));
	col *= 1.0 - 0.38 * streaks;
	col *= 1.0 - 0.35 * under * s;
	col = mix(col, LIME * (0.85 + 0.3 * grit), lime * 0.8 * s);
	col = mix(col, mix(SLIME, MOSS, smoothstep(0.3, 0.8, up + 0.3 * fuzz)) * (0.7 + 0.6 * fuzz), moss * 0.8);
	col *= 1.0 - 0.3 * chips;
	col *= 1.0 - 0.65 * cracks;
	ALBEDO = col;

	float bump = 1.7 * (grit * 0.02 * band(5.0, px) - pits * 0.004 + sand * 0.0015)
		- cracks * 0.006 - chips * 0.01 + moss * fuzz * 0.004;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(bump), dFdy(bump));
	// Matt stone and moss; wet stone and slime have a dull sheen.
	ROUGHNESS = mix(0.92 + 0.08 * grit, 0.55, max(under, moss * (1.0 - up)) * s * 0.6);
	SPECULAR = mix(0.2, 0.4, under * s);
}
