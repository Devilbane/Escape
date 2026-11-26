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
// 0 in open water to 1 under a sheet of ice: in open water the fish is darker, bluer and a little clearer.
uniform float cover = 0.0;
uniform vec3 water_color = vec3(0.08, 0.2, 0.24);
uniform float open_veil = 0.92;

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
	// Overlapping scales: rows of rounded scales along the body, each lighter at its free edge.
	vec2 sp = vec2(lp.x * 520.0 + lp.z * 260.0, lp.y * 420.0);
	sp.x += floor(sp.y) * 0.5;
	vec2 sc = fract(sp) - 0.5;
	float rim = smoothstep(0.25, 0.5, length(sc * vec2(1.0, 0.8)));
	col *= 0.86 + 0.2 * rim;
	// Round shading from the smoothed normals: lit from above, darker towards the belly's edge.
	float round_lit = clamp(NORMAL.z * 0.5 + 0.5, 0.0, 1.0);
	col *= 0.7 + 0.5 * round_lit;
	// Darker towards the tail and the fins.
	col *= 0.85 + 0.25 * (1.0 - abs(along - 0.5) * 1.2);
	// Seen from the game camera's distance a fish is a few pixels: in open water its whole body must read against
	// the dark water, so it is lit up (back and flank both) and given a pale rim, and only lightly tinted.
	float open_water = 1.0 - cover;
	float edge = 1.0 - clamp(abs(NORMAL.z), 0.0, 1.0);
	col = mix(col, col * 1.35 + vec3(0.05, 0.07, 0.06), open_water);
	col += edge * 0.22 * open_water * flank_color;
	col = mix(col, mix(water_color, ice_color * 0.8, cover), mix(0.12, 0.32, cover));
	ALPHA = mix(open_veil, veil, cover) * fade;
	ALBEDO = col;
	ALBEDO = gl_colour(ALBEDO);
}
