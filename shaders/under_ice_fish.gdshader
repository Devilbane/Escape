shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
#include "res://shaders/gl_colour.gdshaderinc"
// A fish swimming under the ice (see IceFish): painted like a river fish seen from above, a dark back
// with a pale flank at its edges, bars across it and fine scales, then veiled by the ice over it:
// mostly the ice's own colour and see-through, so it reads as a shape deep under the sheet.

uniform vec3 back_color = vec3(0.22, 0.3, 0.15);
uniform vec3 flank_color = vec3(0.62, 0.58, 0.38);
uniform vec3 ice_color = vec3(0.62, 0.82, 0.94);
uniform float seed = 0.0;
// 0 hidden to 1 under a solid sheet.
uniform float fade = 0.0;
// How much of the fish shows through the ice, 0 to 1.
uniform float veil = 0.8;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// The model lies along y (about -0.03 to 0.05 long), is thin across x and deep along z.
	float along = clamp((lp.y + 0.03) / 0.08, 0.0, 1.0);
	float across = abs(lp.x) / 0.0058;
	vec3 col = mix(back_color, flank_color, smoothstep(0.35, 1.0, across) * 0.75);
	// Bars across the back.
	col *= 0.8 + 0.28 * smoothstep(0.35, 0.65, abs(fract(along * 6.0 + seed) - 0.5) * 2.0);
	// Fine scales.
	col *= 0.9 + 0.1 * sin(lp.y * 1100.0) * sin(lp.x * 1500.0 + lp.z * 400.0);
	// Darker towards the tail and the fins.
	col *= 0.85 + 0.25 * (1.0 - abs(along - 0.5) * 1.2);
	col = mix(col, ice_color * 0.8, 0.32);
	ALPHA = veil * fade;
	ALBEDO = col;
	ALBEDO = gl_colour(ALBEDO);
}
