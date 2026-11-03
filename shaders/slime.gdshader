shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// The slimes' body: a glossy, wet, see-through lump of murky water, like the
// neglected water in the dungeon's fountain (see water.gdshader). It wobbles
// and breathes, sags in lobes along its lower rim that creep down and drip,
// carries specks of dirt and a film of scum, and wet runs crawl down its
// sides. Like the rest of the scene it is drawn from noise in world space.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.06, 0.1, 0.06);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.28, 0.15);
uniform vec3 scum_color : source_color = vec3(0.22, 0.24, 0.1);
uniform vec3 glow_color : source_color = vec3(0.4, 0.8, 0.62);
// How strongly it glows from inside (a faint murk, more for the glowing kinds).
uniform float glow = 0.12;
// How far one sees through it where it is thinnest (0 opaque, 1 clear).
uniform float clear = 0.45;
// The body's height in the world, so wobble and drips keep their size.
uniform float height = 1.0;
// Each slime wobbles in a rhythm of its own.
uniform float phase = 0.0;

varying vec3 world_pos;
// How far up the body (0 at the floor, 1 at the top).
varying float up;
// Where a drip hangs down the side (0 none, 1 a full drip).
varying float drip;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 rel = wp - base;
	float t = TIME + phase;
	float h = clamp(rel.y / height, 0.0, 1.0);
	// The foot stays on the floor; the higher, the more it wobbles.
	float sway = smoothstep(0.0, 0.5, h);
	vec3 disp = vec3(0.0);
	// Lumps rolling over the surface.
	float lump = vnoise(wp / height * 2.2 + vec3(t * 0.7, t * 0.9, -t * 0.6)) - 0.5;
	disp += wn * lump * 0.11 * height * sway;
	// Breathing: it squats and swells by turns, and its top lags behind.
	float breath = sin(t * 2.1) * 0.5 + sin(t * 3.3 + 1.7) * 0.25;
	disp.y += rel.y * 0.07 * breath;
	disp.xz += rel.xz * -0.04 * breath * sway;
	disp.xz += vec2(sin(t * 1.6), cos(t * 1.3)) * 0.035 * height * h * h;
	// Lobes along the lower rim slowly creep down the sides and swell.
	float around = atan(rel.x, rel.z);
	float lobe = smoothstep(0.55, 0.85, vnoise(vec3(cos(around) * 2.6, sin(around) * 2.6, t * 0.25 + phase)));
	float rim = smoothstep(0.05, 0.25, h) * (1.0 - smoothstep(0.45, 0.75, h)) * (1.0 - max(wn.y, 0.0));
	drip = lobe * rim;
	disp += wn * drip * 0.13 * height;
	disp.y -= min(drip * 0.2 * height, max(rel.y - 0.02 * height, 0.0));
	VERTEX += (inverse(MODEL_MATRIX) * vec4(disp, 0.0)).xyz;
	world_pos = wp + disp;
	up = h;
}

void fragment() {
	vec3 p = world_pos / height;
	float t = TIME + phase;
	float px = length(fwidth(world_pos)) / height;
	// Small ripples across the wet skin.
	float r1 = vnoise(p * 7.0 + vec3(0.0, -t * 0.6, t * 0.4));
	float r2 = vnoise(p * 17.0 + vec3(t * 0.5, -t * 0.9, 0.0));
	float hgt = 0.02 * (r1 - 0.5) + 0.008 * (r2 - 0.5) * band(17.0, px);
	vec3 n = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(hgt), dFdy(hgt));
	NORMAL = n;
	float facing = clamp(dot(normalize(VIEW), n), 0.0, 1.0);
	// Thin where it faces the eye, thick and dark toward its outline.
	float thick = pow(1.0 - facing, 1.6);
	float murk = fbm(p * 2.5 + vec3(0.0, t * 0.08, 0.0));
	vec3 col = mix(shallow_color, deep_color, clamp(thick * 0.6 + 0.25 * (1.0 - up) + 0.3 * (murk - 0.5), 0.0, 1.0));
	// Specks of dirt drifting inside.
	float specks = smoothstep(0.8, 0.93, vnoise(p * 38.0 + vec3(t * 0.05, t * 0.12, -t * 0.04))) * band(38.0, px);
	col *= 1.0 - 0.4 * specks;
	// A film of scum on top, in patches.
	float film = smoothstep(0.55, 0.72, fbm(p * 3.0 + vec3(t * 0.03, 0.0, -t * 0.02)) + 0.25 * up - 0.15) * smoothstep(0.35, 0.8, up);
	col = mix(col, scum_color * (0.8 + 0.4 * r1), film * 0.85);
	// Wet runs crawling down the sides, and the drips a little darker.
	float runs = smoothstep(0.7, 0.95, vnoise(vec3(atan(p.x, p.z) * 6.0, p.y * 1.5 + t * 0.35, phase))) * (1.0 - film);
	col *= 1.0 - 0.25 * drip;
	ALBEDO = col;
	ALPHA = clamp(mix(1.0 - clear, 1.0, thick) + 0.25 * film + 0.15 * drip + 0.1 * specks, 0.0, 1.0);
	ROUGHNESS = mix(mix(0.05, 0.18, r2), 0.6, film) * (1.0 - 0.6 * runs);
	SPECULAR = mix(0.75, 0.3, film);
	RIM = 0.35 * (1.0 - film);
	RIM_TINT = 0.6;
	// A wet sheen: the light from above mirrored in its skin.
	vec3 sky = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float sheen = pow(clamp(dot(reflect(-normalize(VIEW), n), sky), 0.0, 1.0), 10.0) * (1.0 - film);
	EMISSION = vec3(0.55, 0.62, 0.5) * sheen * 0.8 + glow_color * glow * (0.6 + 0.4 * sin(t * 1.4)) * (0.5 + murk) * (1.0 - thick * 0.5);
}
