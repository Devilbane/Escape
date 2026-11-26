shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
#include "res://shaders/gl_colour.gdshaderinc"
// A fish seen from above (see IceFish), drawn on a flat strip: a tapered body, a forked tail, two pectoral fins,
// an eye and a gill line, a dark back with a pale flank, bars and fine scales. The strip lies along z with the
// head at +z; `len` is its length, and the outline is cut out per pixel, so the body reads as a solid fish at
// any distance. The tail and body sway as it swims. Water over it is a light tint, and under the ice it fades.

uniform vec3 back_color = vec3(0.22, 0.3, 0.15);
uniform vec3 flank_color = vec3(0.62, 0.58, 0.38);
uniform vec3 ice_color = vec3(0.62, 0.82, 0.94);
uniform float seed = 0.0;
uniform float len = 0.8;
uniform float sway = 0.0;
// 0 hidden to 1 under a solid sheet.
uniform float fade = 0.0;
// How much of the fish shows through the ice, 0 to 1.
uniform float veil = 0.8;
// 0 in open water to 1 under a sheet of ice.
uniform float cover = 0.0;
uniform vec3 water_color = vec3(0.08, 0.2, 0.24);
uniform float open_veil = 0.96;

varying vec2 fp;

void vertex() {
	// fp: x across and l along the fish from the nose (0) to the tail tip (1), both in body lengths.
	fp = vec2(VERTEX.x / len, 0.5 - VERTEX.z / len);
	float bend = sin(TIME * 7.0 + sway - fp.y * 5.0) * 0.06 * len * fp.y * fp.y;
	VERTEX.x += bend;
}

// Half-width of the body, the tail and the fins at l, 0 outside them.
float body_half(float l) {
	float s = pow(clamp(l / 0.8, 0.0, 1.0), 0.62);
	float b = 0.115 * sqrt(max(1.0 - pow(2.0 * s - 1.0, 2.0), 0.0));
	float neck = 0.03 * step(0.45, l) * step(l, 0.88);
	return max(b, neck);
}

void fragment() {
	float l = fp.y;
	float x = fp.x;
	float ax = abs(x);
	float bw = body_half(l);
	float in_body = step(ax, bw) * step(0.0, l) * step(l, 0.86);
	// Forked tail fin.
	float tw = mix(0.03, 0.26, smoothstep(0.82, 0.985, l));
	float notch = max(l - 0.93, 0.0) * 1.7;
	float in_tail = step(0.82, l) * step(l, 1.0) * step(ax, tw) * step(notch, ax);
	// Pectoral fins: swept back from just behind the gill.
	float fl = (l - 0.27) / 0.2;
	float in_pec = step(0.0, fl) * step(fl, 1.0) * step(0.08, ax) * step(ax, 0.08 + 0.15 * (1.0 - fl) * smoothstep(0.0, 0.25, fl));
	// Pelvic fins: a pair of small ones further back.
	float pl = (l - 0.48) / 0.12;
	float in_pel = step(0.0, pl) * step(pl, 1.0) * step(0.05, ax) * step(ax, 0.05 + 0.07 * (1.0 - pl) * smoothstep(0.0, 0.3, pl));
	float is_fin = max(max(in_pec, in_pel), in_tail) * (1.0 - in_body);
	float shape = max(max(in_body, in_tail), max(in_pec, in_pel));
	if (shape < 0.5) {
		discard;
	}
	// Body: dark back along the middle, a pale flank at the sides, bars across the back, fine scales.
	float across = clamp(ax / max(bw, 0.001), 0.0, 1.0);
	vec3 col = mix(back_color, flank_color, smoothstep(0.3, 0.95, across) * 0.85);
	col *= 0.78 + 0.34 * smoothstep(0.35, 0.65, abs(fract(l * 7.0 + seed) - 0.5) * 2.0) * (1.0 - across * 0.6);
	vec2 sp = vec2(x * 300.0, l * 220.0);
	sp.x += floor(sp.y) * 0.5;
	float rim = smoothstep(0.25, 0.5, length((fract(sp) - 0.5) * vec2(1.0, 0.8)));
	col *= 0.86 + 0.22 * rim;
	// A rounded body: lighter on the middle of the back, dark at the very edge.
	col *= 0.78 + 0.4 * (1.0 - across * across);
	col *= 1.0 - 0.55 * smoothstep(0.88, 1.0, across);
	// The gill line and the eye.
	float gill = smoothstep(0.012, 0.0, abs(length(vec2(ax * 1.1, l - 0.19)) - 0.1)) * step(0.17, l) * step(ax, 0.1);
	col = mix(col, back_color * 0.5, gill * 0.55);
	float eye_d = length(vec2(ax - 0.062, l - 0.1));
	col = mix(col, vec3(0.88, 0.84, 0.6), smoothstep(0.03, 0.026, eye_d));
	col = mix(col, vec3(0.02), smoothstep(0.019, 0.016, eye_d));
	// Fins: the flank colour with rays, a little see-through at their tips.
	float rays = 0.8 + 0.25 * sin(atan(ax, l - 0.3) * 70.0 + l * 90.0);
	vec3 fin_col = mix(flank_color, back_color, 0.35) * rays * 1.05;
	col = mix(col, fin_col, is_fin);
	// Seen through a little water: lit up and lightly tinted.
	float open_water = 1.0 - cover;
	col = mix(col, col * 1.3 + vec3(0.03, 0.04, 0.03), open_water);
	col = mix(col, mix(water_color, ice_color * 0.8, cover), mix(0.1, 0.32, cover));
	ALPHA = mix(open_veil, veil, cover) * fade * (1.0 - is_fin * 0.22);
	ALBEDO = col;
	ALBEDO = gl_colour(ALBEDO);
}
