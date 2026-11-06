shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// The water of a stone basin: a glossy, slightly see-through surface with
// slow drifting ripples, rings spreading from where the spout falls in, and a
// faint, breathing glow for the fountain that heals. Like the ground and the
// stone, it is drawn from noise in world space with a little height for bump
// lighting, so it fits the matt, natural look of the rest of the scene.

#include "res://shaders/detail.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.07, 0.19, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.4, 0.43);
uniform vec3 glow_color : source_color = vec3(0.45, 0.85, 0.85);
// How strongly the water glows from inside (0 for plain water).
uniform float glow = 0.25;
// Rings spreading from the middle of the surface, where the spout lands.
uniform float rings = 1.0;
uniform float ring_spacing = 22.0;

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = world_pos;
	float t = TIME;
	float px = length(fwidth(p));
	// Two layers of ripples drifting across each other.
	float r1 = vnoise(vec3(p.x * 2.6 + t * 0.3, p.z * 2.6 - t * 0.22, t * 0.25));
	float r2 = vnoise(vec3(p.x * 6.5 - t * 0.45, p.z * 6.5 + t * 0.35, 5.0 + t * 0.5));
	// Rings from the middle, fading toward the rim.
	float d = length(local_pos.xz);
	float ring = sin(d * ring_spacing - t * 5.5) * exp(-d * 2.4) * rings;
	float h = 0.014 * (r1 - 0.5) + 0.006 * (r2 - 0.5) * band(6.5, px) + 0.004 * ring * band(ring_spacing / 6.0, px);
	vec3 n = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	NORMAL = n;
	// Seen at a flat angle the water mirrors more and shows less of its depth.
	float facing = clamp(dot(normalize(VIEW), n), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	ALBEDO = mix(deep_color, shallow_color, 0.3 + 0.7 * r1);
	ALPHA = mix(0.8, 0.95, fresnel);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	float breath = 0.85 + 0.15 * sin(t * 1.3);
	EMISSION = glow_color * glow * breath * (0.55 + 0.45 * r2) * (1.0 + 0.5 * max(ring, 0.0));
}
