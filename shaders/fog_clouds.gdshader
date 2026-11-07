shader_type spatial;
// Large, soft fog clouds that drift over the open air. The clouds are two
// layers of tiling noise read in world space (so they stay put in the world
// while the camera moves), hug the ground, and leave clear gaps between them.
// Drawn at the lowest render priority of all see-through things: every label
// (damage numbers, speech bubbles, news) and every particle is drawn after
// the clouds and so stays exactly as readable as without them.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 haze : source_color = vec3(0.66, 0.68, 0.72);
// 0 = no clouds, 1 = the thickest fog.
uniform float strength = 0.0;
// How much of the ground the clouds cover (0 to 1); the rest is clear air.
uniform float coverage = 0.5;
uniform vec2 drift = vec2(0.0);
uniform float breathe = 0.0;
uniform float max_distance = 90.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec2 p = world.xz;
	// A big, slow layer and a smaller, faster one: they slide against each
	// other, which gives the clouds depth and keeps them from looking printed.
	float big = texture(noise_tex, p * 0.012 + drift * 0.6).r;
	float small = texture(noise_tex, p * 0.031 + drift * 1.0 + vec2(0.37, 0.71)).r;
	float c = big * 0.72 + small * 0.28 + breathe;
	// Soft, irregular edges: a wide ramp from clear to cloud.
	float lo = 1.0 - coverage - 0.12;
	float body = smoothstep(lo, lo + 0.3, c);
	// Ground-hugging: thick at the feet, thin higher up.
	float low = exp(-max(world.y, 0.0) * 0.3);
	// Nothing on the sky or far away.
	float reach = 1.0 - smoothstep(max_distance * 0.7, max_distance, length(view.xyz));
	ALBEDO = haze;
	ALPHA = clamp(body * low * reach * strength * 0.8, 0.0, 0.85);
}
