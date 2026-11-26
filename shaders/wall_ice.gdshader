shader_type spatial;
// Ice on a climbing wall (see WallBuild): a glassy, bluish skin laid over the rock, thickest in the middle of
// a patch and thinning out to nothing at its ragged edge (the vertex alpha). Frozen veins and bubbles show in
// it, and it shines like wet glass.
render_mode blend_mix, cull_disabled, depth_draw_opaque;
#include "res://shaders/gl_colour.gdshaderinc"
#include "res://shaders/detail.gdshaderinc"

varying vec3 wpos;
varying vec3 wnrm;
varying float cover;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cover = COLOR.a;
}

void fragment() {
	float veins = fbm(wpos * 2.2 + 4.0);
	float fine = vnoise(wpos * 11.0);
	float crack = smoothstep(0.02, 0.0, abs(fbm(wpos * 2.6 + 9.0) - 0.5));
	vec3 deep = vec3(0.42, 0.64, 0.8);
	vec3 pale = vec3(0.86, 0.95, 1.0);
	vec3 col = mix(deep, pale, smoothstep(0.25, 0.8, veins) * 0.8 + fine * 0.15);
	// White frost where the layer is thin.
	col = mix(col, vec3(0.95, 0.98, 1.0), (1.0 - smoothstep(0.25, 0.7, cover)) * 0.6);
	col = mix(col, vec3(0.97, 0.99, 1.0), crack * 0.5);
	ALBEDO = gl_colour(col);
	ALPHA = gl_alpha(gl_colour(col), clamp(cover * 0.92, 0.0, 0.9));
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
	float h = veins * 0.6 + fine * 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), dFdx(wpos), dFdy(wpos), dFdx(h) * 0.25, dFdy(h) * 0.25), 0.0)).xyz);
}
