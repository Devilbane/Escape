shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// A rain puddle on the ground (see Puddles): see-through, glossy water like
// the slimes' body (see slime.gdshader), deeper and murkier in the middle,
// with a rim of dark, soaked soil around it. While it rains, drops ring the
// surface; a slow drift of ripples moves it the rest of the time. Like the
// rest of the scene it is drawn from noise in world space.
//
// The mesh carries in COLOR.r how far in a point lies: 0 at the outer edge of
// the wet soil, about 0.3 where the water starts, 1 in the middle.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.02, 0.03, 0.035);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.09, 0.085);
uniform vec3 mud_color : source_color = vec3(0.06, 0.045, 0.03);
// How far one sees through the deepest water, where it faces the eye (0
// opaque, 1 clear); the shallows near the edge show more of the ground.
uniform float clear = 0.1;
// How hard it rains on the puddles right now (0 to 1), for the rings.
uniform float rain = 0.0;
// How bright the sky is that the water mirrors (0 night to 1 day).
uniform float sky = 1.0;
// The last few steps into the puddles: where (xyz) and how long ago (w,
// seconds). Each sends a ring of waves out over the water.
uniform vec4 steps[3];
// How full this puddle is (0 dried up, 1 full) comes in the height of its
// scale, since the puddle itself is flat (see Puddles.set_water); it fades
// as it dries. Not an instance uniform: there are hundreds of puddles, and
// those share one small buffer with the stones of the walls.
varying float fill;

// How long the waves of a step run (seconds; see Puddles.STEP_WAVE).
const float STEP_WAVE = 1.2;

varying vec3 world_pos;
varying float inner;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inner = COLOR.r;
	fill = clamp(length(MODEL_MATRIX[1].xyz), 0.0, 1.0);
}

// Rings spreading from drops falling on the water: one drop at a time per
// cell of a grid, each at its own spot and moment.
float drop_rings(vec2 q, float t, float layer) {
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float seed = hash3(vec3(cell, layer));
	float age = fract(t * 0.9 + seed);
	vec2 at = (vec2(hash3(vec3(cell, layer + 7.0)), hash3(vec3(cell, layer + 13.0))) - 0.5) * 0.45;
	float d = length(f - at);
	float r = age * 0.26;
	float ring = sin((d - r) * 70.0) * (1.0 - smoothstep(0.0, 0.05, abs(d - r)));
	return ring * (1.0 - age) * step(hash3(vec3(cell, layer + floor(t * 0.9 + seed))), 0.7);
}

void fragment() {
	vec3 p = world_pos;
	float t = TIME;
	float px = length(fwidth(p));
	float water = smoothstep(0.24, 0.36, inner);
	// A slow drift of ripples, and the rain's rings on top.
	float r1 = vnoise(vec3(p.x * 1.7 + t * 0.18, p.z * 1.7 - t * 0.14, t * 0.2));
	float r2 = vnoise(vec3(p.x * 5.0 - t * 0.3, p.z * 5.0 + t * 0.25, 4.0 + t * 0.35));
	float rings = (drop_rings(p.xz * 2.4, t, 1.0) + drop_rings(p.xz * 2.4 + 0.5, t * 1.13, 5.0)) * band(30.0, px);
	float h = 0.01 * (r1 - 0.5) + 0.004 * (r2 - 0.5) * band(5.0, px) + 0.006 * rings * rain;
	// Waves running out from where a foot came down.
	float wake = 0.0;
	for (int i = 0; i < 3; i++) {
		float age = steps[i].w;
		if (age < 0.0 || age > STEP_WAVE) {
			continue;
		}
		float d = length(p.xz - steps[i].xz);
		float r = 0.15 + age * 1.6;
		float fade = 1.0 - age / STEP_WAVE;
		wake += sin((d - r) * 22.0) * (1.0 - smoothstep(0.0, 0.22, abs(d - r))) * fade * fade;
	}
	h += 0.02 * wake;
	vec3 n = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h) * water, dFdy(h) * water);
	NORMAL = n;
	float facing = clamp(dot(normalize(VIEW), n), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	float murk = fbm(vec3(p.x * 0.9, 0.0, p.z * 0.9));
	vec3 col = mix(shallow_color, deep_color, clamp(inner * 0.9 + 0.3 * (murk - 0.5), 0.0, 1.0));
	ALBEDO = mix(mud_color, col, water);
	// Clear in the middle like the slimes, mirroring more at a flat angle;
	// the soaked soil only darkens the ground a little.
	float see = mix(mix(0.72, 1.0 - clear, inner), 0.97, fresnel);
	float soil = smoothstep(0.0, 0.24, inner) * 0.6;
	ALPHA = mix(soil, see, water) * smoothstep(0.0, 0.3, fill);
	ROUGHNESS = mix(0.7, 0.12 + 0.1 * r2, water);
	// Not too mirror-like: a grey sky mirrored in full would wash the
	// puddle out to the colour of the ground around it.
	SPECULAR = mix(0.2, 0.25, water);
	// The grey sky mirrored in the water.
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float sheen = pow(clamp(dot(reflect(-normalize(VIEW), n), up), 0.0, 1.0), 6.0);
	// Seen from above, the water mirrors the grey sky, brighter in soft
	// streaks, so a puddle reads as water and not as a hole in the ground.
	float mirror = 0.24 + 0.2 * smoothstep(0.25, 0.95, r1) + 0.2 * sheen + 0.3 * fresnel;
	EMISSION = vec3(0.5, 0.55, 0.6) * sky * water * (mirror + 0.6 * max(wake, 0.0));
}
