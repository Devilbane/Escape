shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
// A ghost of the dungeon (see Enemy._ghostly): the model's own texture,
// washed out to a pale white, see-through, with a neon aura at its edges. It
// fades away towards the floor, so it has no feet, and its lower part sways.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform vec4 color : source_color = vec4(0.95, 1.0, 0.97, 1.0);
// The glowing aura at its edges.
uniform vec4 aura : source_color = vec4(0.3, 1.0, 0.45, 1.0);
// How much of it shows: 1 in full, near 0 a mere shimmer (a wraith that has
// not noticed the hero), 0 gone.
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Model-space heights: below fade_low nothing shows, above fade_high all of it.
uniform float fade_low = 0.15;
uniform float fade_high = 0.9;
uniform float phase = 0.0;
// 0 for something held (a blade), which keeps still in the hand.
uniform float sway = 1.0;

varying float height;

void vertex() {
	float t = TIME + phase;
	// The lower it hangs, the more it trails and sways.
	float loose = clamp(1.0 - VERTEX.y / max(fade_high, 0.01), 0.0, 1.0) * sway;
	VERTEX.x += sin(t * 2.3 + VERTEX.y * 3.0) * 0.05 * loose;
	VERTEX.z += cos(t * 1.9 + VERTEX.y * 2.0) * 0.04 * loose;
	height = VERTEX.y;
}

void fragment() {
	vec3 base = color.rgb;
	if (use_tex) {
		float light = dot(texture(tex, UV).rgb, vec3(0.3, 0.59, 0.11));
		base *= 0.45 + light * 0.75;
	}
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(edge, 3.0);
	float flicker = 0.9 + 0.1 * sin(TIME * 7.0 + phase * 3.0);
	ALBEDO = base * 0.6;
	EMISSION = (base * 0.85 * (1.0 - rim) + aura.rgb * rim * 3.0) * flicker;
	ROUGHNESS = 1.0;
	float feet = smoothstep(fade_low, fade_high, height);
	ALPHA = clamp(alpha * (0.42 + 0.55 * rim) * feet * flicker, 0.0, 1.0);
}
