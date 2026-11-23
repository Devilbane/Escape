shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
#include "res://shaders/gl_colour.gdshaderinc"
#include "res://shaders/detail.gdshaderinc"
// The sewer's water: murky green-brown, drifting slowly along the channel (`flow` is the way it runs
// on the ground, x and z), with ripples and streaks of scum carried along with it.

uniform vec2 flow = vec2(0.0, -1.0);
uniform float flow_speed = 0.4;
uniform vec3 deep_color = vec3(0.07, 0.08, 0.04);
uniform vec3 shallow_color = vec3(0.22, 0.23, 0.1);
uniform vec3 scum_color = vec3(0.32, 0.36, 0.16);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos;
	vec2 d = normalize(flow);
	float t = TIME * flow_speed;
	vec2 q = p.xz - d * t;
	float r1 = vnoise(vec3(q.x * 2.4, q.y * 2.4, TIME * 0.12));
	float r2 = vnoise(vec3((p.xz - d * t * 1.6) * 6.0, 4.0));
	// Streaks along the current: noise stretched in the flow direction.
	vec2 across = vec2(-d.y, d.x);
	float s = vnoise(vec3(dot(p.xz - d * t * 1.2, d) * 0.9, dot(p.xz, across) * 5.0, 9.0));
	float px = length(fwidth(p));
	float h = 0.012 * (r1 - 0.5) + 0.005 * (r2 - 0.5) * band(6.0, px);
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	vec3 col = mix(deep_color, shallow_color, 0.25 + 0.6 * r1);
	float scum = smoothstep(0.62, 0.8, s);
	col = mix(col, scum_color, scum * 0.7);
	ALBEDO = gl_colour(col);
	ALPHA = mix(0.88, 0.97, fresnel);
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
}
