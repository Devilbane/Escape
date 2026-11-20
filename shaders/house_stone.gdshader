shader_type spatial;
// The stone walls the hero builds (house walls, garden walls, cellar walls; see
// HouseLooks.temple_stone): the village's natural stonework (masonry.gdshaderinc)
// in the cool grey of the temple's blocks, laid in world space so the courses run
// level round the house, with the walls' outer edges rounded off (StoneLook).

#include "res://shaders/detail.gdshaderinc"
#include "res://shaders/masonry.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.6, 0.6, 0.58);
// See StoneLook.apply.
uniform float masonry = 1.0;
uniform float course = 0.3;
uniform float irregular = 0.0;
uniform float edge_round = 0.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 edge_d;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	edge_d = CUSTOM0;
}

void fragment() {
	vec3 n = normalize(wnrm);
	float px = length(fwidth(wpos));
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec2 along = w.x > w.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	vec4 side = natural_stone(along, tint, course, irregular, px);
	vec4 top = natural_stone(vec2(wpos.x, wpos.z), tint, course, irregular, px);
	vec4 laid = mix(side, top, w.y);
	// Faint stains a metre or so across.
	float stains = fbm(wpos * 0.7 + 4.0);
	ALBEDO = laid.rgb * (0.9 + 0.2 * stains);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	float h = laid.a * 0.012 * band(1.0 / course, px);
	vec2 bevel = edge_bevel(edge_d, edge_round);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(n, dFdx(wpos), dFdy(wpos), dFdx(h) + bevel.x, dFdy(h) + bevel.y), 0.0)).xyz);
}
