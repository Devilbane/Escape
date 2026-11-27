shader_type spatial;
// Large, soft fog clouds that float in the air over the open ground. Each of three thin layers
// a few metres up is two layers of tiling noise read in world space (so the clouds stay put in
// the world while the camera moves), with clear gaps between the banks; under them only a thin
// haze lies on the ground. The clouds stay as they are around the hero too, but leave out
// what lies inside a house (see indoors.gdshaderinc).
// Drawn at the lowest render priority of all see-through things: every label
// (damage numbers, speech bubbles, news) and every particle is drawn after
// the clouds and so stays exactly as readable as without them.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://shaders/gl_colour.gdshaderinc"

#include "res://shaders/indoors.gdshaderinc"
#include "res://shaders/depth.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 haze : source_color = vec3(0.66, 0.68, 0.72);
// 0 = no clouds, 1 = the thickest fog.
uniform float strength = 0.0;
// How much of the ground the clouds cover (0 to 1); the rest is clear air.
uniform float coverage = 0.5;
uniform vec2 drift = vec2(0.0);
// 0 = patchy clouds with clear gaps, 1 = one soft, even haze.
uniform float even = 0.0;
uniform float breathe = 0.0;
uniform float max_distance = 90.0;
// The heights of the cloud layers above the ground, and the thin haze left on the ground.
uniform vec3 layers = vec3(2.4, 3.3, 4.3);
uniform float ground_haze = 0.18;
// How many metres below a layer's height its cloud thins out against a surface that rises into it.
uniform float soft_edge = 1.6;
// How much thinner the clouds are drawn on the modern renderer (see the end of fragment()).
uniform float modern_thin = 0.55;

void vertex() {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
#else
	// The modern renderer's clip space runs from 1 (near) to 0 (far): on the near plane.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
#endif
}

// How thick a cloud is at a point of its layer: banks with a short edge and a denser core.
float cloud(vec2 p, float shift) {
	float big = texture(noise_tex, p * 0.026 + drift * 0.6 + vec2(shift, shift * 0.6)).r;
	float small = texture(noise_tex, p * 0.06 + drift * 1.0 + vec2(0.37 + shift, 0.71)).r;
	float c = big * 0.72 + small * 0.28 + breathe;
	float lo = 1.0 - coverage - 0.12;
	float edge = smoothstep(lo, lo + 0.14, c);
	float core = smoothstep(lo + 0.18, lo + 0.42, c);
	return mix(edge * 0.5 + core * 0.65, 0.8 + 0.2 * c, even);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = depth_ndc(SCREEN_UV, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	// Nothing of the clouds over what lies inside a house: the outside keeps them. The indoor mask reaches
	// past the floor plan over the walls (see IndoorMask), so the outer face of a wall lies inside it. Above
	// the floor a spot is therefore read 0.8 m nearer to the camera (the mask is coarse, half a metre per
	// pixel): seen from outside, the outer face of a wall then lies outside the house and keeps its fog,
	// while floors, wall tops and what stands deep inside are read where they are.
	vec3 probe = world;
	vec2 towards = cam.xz - world.xz;
	if (world.y > 0.2 && dot(towards, towards) > 1e-6) {
		probe.xz += normalize(towards) * 0.8;
	}
	if (indoors(probe)) {
		discard;
	}
	// The clouds float in the air: a few thin layers above the ground. The view ray meets each
	// layer above whatever it hits, so tall things (trees, roofs) stand up through the clouds,
	// and the layers slide against the ground and each other as the camera moves.
	float alpha = 0.0;
	for (int i = 2; i >= 0; i--) {
		float h = layers[i];
		// Where the ground or a rock face rises through a layer the cloud thins out over the last
		// `soft_edge` metres below it, so it fades into the surface instead of ending in a hard line.
		float fade = 1.0 - smoothstep(h - soft_edge, h, world.y);
		if (cam.y <= h || fade <= 0.0) {
			continue;
		}
		vec3 q = mix(cam, world, (cam.y - h) / (cam.y - world.y));
		float a = cloud(q.xz, float(i) * 0.29) * 0.45 * fade;
		alpha += (1.0 - alpha) * a;
	}
	// Under the clouds only a thin haze lies on the ground.
	float low = exp(-max(world.y, 0.0) * 0.3);
	alpha += (1.0 - alpha) * ground_haze * low * mix(1.0, 3.0, even);
	// Nothing on the sky or far away.
	float reach = 1.0 - smoothstep(max_distance * 0.7, max_distance, length(view.xyz));
	ALBEDO = haze;
	// An even haze covers everything, so it is lighter than patchy clouds.
	ALPHA = clamp(alpha * reach * strength * mix(1.0, 0.6, even), 0.0, 0.9);
	ALPHA = gl_alpha(haze, ALPHA);
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	// Measured against OpenGL on the village square (tests/lighting_reference_shots.gd): the banks
	// still came out thicker on the modern renderer, and winter's softened banks one milky film.
	ALPHA *= modern_thin;
#endif
}
