shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
#include "res://shaders/gl_colour.gdshaderinc"
#include "res://shaders/detail.gdshaderinc"
// The sewer's water: murky green-brown, drifting slowly along the channel (`flow` is the way it runs
// on the ground, x and z), with ripples and streaks of scum carried along with it.

uniform vec2 flow = vec2(0.0, -1.0);
uniform float flow_speed = 0.4;
uniform vec3 deep_color = vec3(0.04, 0.05, 0.03);
uniform vec3 shallow_color = vec3(0.17, 0.19, 0.08);
uniform vec3 scum_color = vec3(0.32, 0.36, 0.16);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos;
	vec2 d = normalize(flow);
	vec2 across = vec2(-d.y, d.x);
	float t = TIME * flow_speed;
	vec2 q = p.xz - d * t;
	// Three layers of ripples at different sizes, each carried along at its own pace, and a slow
	// swell across the current, so the surface is never a flat sheet.
	float r1 = vnoise(vec3(q * 1.7, TIME * 0.10));
	float r2 = vnoise(vec3((p.xz - d * t * 1.5) * 4.6, TIME * 0.2 + 3.0));
	float r3 = vnoise(vec3((p.xz - d * t * 2.3) * 11.0, TIME * 0.35 + 7.0));
	float swell = vnoise(vec3(dot(p.xz, across) * 1.3 + sin(TIME * 0.25) * 0.4, dot(p.xz - d * t * 0.6, d) * 0.7, 5.0));
	// Streaks along the current: noise stretched in the flow direction.
	float s = vnoise(vec3(dot(p.xz - d * t * 1.2, d) * 0.8, dot(p.xz, across) * 4.0, 9.0));
	float px = length(fwidth(p));
	float h = 0.028 * (r1 - 0.5) + 0.012 * (r2 - 0.5) * band(4.6, px) + 0.005 * (r3 - 0.5) * band(11.0, px) + 0.02 * (swell - 0.5);
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	// Murk: a dark, thick water whose colour wanders between peaty brown and green; the scum floats on top.
	float murk = clamp(0.2 + 0.7 * swell + 0.3 * (r1 - 0.5), 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, murk);
	col = mix(col, vec3(0.16, 0.13, 0.07), smoothstep(0.55, 0.9, r2) * 0.35);
	float scum = smoothstep(0.64, 0.82, s) * (0.6 + 0.4 * r3);
	col = mix(col, scum_color, scum * 0.65);
	ALBEDO = col;
	// What the lamps and the daylight shafts do on its surface: soft sheen towards the grazing view.
	EMISSION = vec3(0.05, 0.06, 0.05) * fresnel * (0.6 + 0.4 * swell);
	ALPHA = mix(0.93, 0.985, fresnel);
	ROUGHNESS = mix(0.1, 0.3, scum);
	SPECULAR = 0.7;
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
