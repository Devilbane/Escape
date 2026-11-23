shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// Old, weathered boards for the village gate (see GateWood): grain running along the board (its
// own y axis) in wavy lines, darker and paler streaks, fine cracks along the grain, a knot here
// and there, a silver bleached film where sun and rain reach, grime and damp near the ground,
// and worn, paler rims. Every board has its own pattern (`plank`). Fine detail fades out where it
// would be smaller than a few pixels.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo_color = vec3(0.4, 0.28, 0.17);
// A number of the board's own, so no two look alike.
instance uniform float plank = 0.0;

varying vec3 obj_pos;
varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	obj_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float px = length(fwidth(world_pos));
	vec3 p = obj_pos + vec3(plank * 7.3, plank * 3.1, plank * 5.7);
	// Grain: lines along y, bent by slow noise so they wander like growth rings cut lengthways.
	float bend = fbm(vec3(p.x * 2.5, p.y * 0.6, p.z * 2.5));
	float lines = 0.5 + 0.5 * sin((p.x + p.z * 0.7) * 70.0 + bend * 9.0);
	float fine = vnoise(vec3(p.x * 90.0, p.y * 2.5, p.z * 90.0));
	float streak = fbm(vec3(p.x * 5.0, p.y * 0.5, p.z * 5.0) + 7.0);
	vec3 deep = albedo_color * 0.62;
	vec3 pale = albedo_color * 1.18;
	vec3 col = mix(deep, pale, clamp(0.25 + 0.5 * lines * band(70.0, px) + 0.35 * (streak - 0.4) + 0.5 * (1.0 - band(70.0, px)) * 0.5, 0.0, 1.0));
	col *= 0.9 + 0.2 * fine * band(90.0, px);
	// Cracks along the grain.
	float crack = smoothstep(0.86, 0.95, vnoise(vec3(p.x * 34.0, p.y * 0.35, p.z * 34.0) + 13.0)) * band(34.0, px);
	col *= 1.0 - 0.55 * crack;
	// A knot: a darker ring round a spot on the board.
	vec2 kn = vec2(p.x - 0.03 * sin(plank * 11.0), p.y - (0.4 + 1.0 * fract(plank * 3.7)));
	float kd = length(kn * vec2(1.0, 0.45));
	float has_knot = step(0.45, fract(plank * 5.3));
	float knot = (1.0 - smoothstep(0.0, 0.07, kd)) * has_knot;
	float knot_ring = smoothstep(0.045, 0.06, kd) * (1.0 - smoothstep(0.06, 0.1, kd)) * has_knot;
	col = mix(col, albedo_color * 0.42, knot * 0.8 + knot_ring * 0.4);
	// Silver, sun-bleached patches, strongest on what faces out and up.
	float bleach = smoothstep(0.5, 0.78, fbm(p * vec3(3.0, 1.2, 3.0) + 31.0));
	col = mix(col, vec3(0.55, 0.52, 0.47) * (0.8 + 0.3 * fine), bleach * 0.45);
	// Grime and damp near the ground, with a faint green film at the foot.
	float low = 1.0 - smoothstep(0.0, 0.7, world_pos.y);
	col = mix(col, vec3(0.2, 0.17, 0.12), low * 0.45);
	col = mix(col, vec3(0.33, 0.4, 0.22), low * low * 0.2 * smoothstep(0.4, 0.7, fbm(p * 4.0 + 5.0)));
	// Rims and corners are worn paler where hands and weather have rubbed them.
	float turn = clamp(length(fwidth(world_nrm)) * 5.0, 0.0, 1.0);
	col *= 1.0 + turn * 0.18;
	float h = (lines - 0.5) * 0.004 * band(70.0, px) - crack * 0.004 + (fbm(p * 12.0) - 0.5) * 0.003 * band(12.0, px);
	ALBEDO = col;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	ALBEDO = gl_colour(ALBEDO);
}
