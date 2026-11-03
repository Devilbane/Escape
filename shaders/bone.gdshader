shader_type spatial;
// Old bones lying in the dungeon (DungeonLife's bone piles and skulls, and
// the bones in the pits under the grates). A plain bone colour looks clean
// and fresh; this ages it:
// - a yellowed, uneven tone: some bones and patches browner than others,
// - grime: cloudy grey-brown stains all over,
// - earth: dark brown dirt on the sides that face down or lie low, where the
//   bone has rested on the floor for years,
// - fine grit and a few dark pits in the surface.
// The pattern is laid out in world space, so no two bones look alike. Fine
// detail fades out where it would be smaller than a few pixels, so it never
// flickers.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo_color : source_color = vec3(0.74, 0.69, 0.57);
// 0 keeps the clean look, 1 is a bone that lay in the dirt for ages.
uniform float strength = 1.0;

const vec3 YELLOWED = vec3(0.6, 0.52, 0.38);
const vec3 GRIME = vec3(0.36, 0.31, 0.25);
const vec3 EARTH = vec3(0.27, 0.2, 0.14);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos;
	float px = length(fwidth(p));
	vec3 col = albedo_color;
	// Yellowed with age, more on some bones than others.
	float age = fbm(p * 1.3 + 11.0);
	col = mix(col, YELLOWED, (0.25 + 0.4 * age) * strength);
	// Cloudy grime stains.
	float stains = fbm(p * 4.5);
	col = mix(col, GRIME, (0.05 + 0.55 * smoothstep(0.38, 0.75, stains)) * strength);
	// Less bright overall: no fresh, white bone.
	col *= 1.0 - 0.08 * strength;
	// Earth on the underside and the sides near the floor, ragged at its edge.
	float down = smoothstep(0.55, -0.35, world_normal.y);
	float edge = fbm(p * 9.0 + 4.0) * band(9.0, px);
	float earth = smoothstep(0.35, 0.75, down + (edge - 0.5) * 0.6 + (stains - 0.5) * 0.4);
	col = mix(col, EARTH, earth * 0.85 * strength);
	// Grit and small dark pits.
	float grit = vnoise(p * 40.0) * band(40.0, px);
	float pits = smoothstep(0.84, 0.94, vnoise(p * 34.0 + 7.0)) * band(34.0, px);
	col *= 1.0 - strength * (0.12 * (grit - 0.5) + 0.3 * pits);
	ALBEDO = col;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(grit * 0.002), dFdy(grit * 0.002));
	ROUGHNESS = 0.85 + 0.15 * earth;
	SPECULAR = 0.25;
}
