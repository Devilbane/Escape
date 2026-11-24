shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
#include "res://shaders/gl_colour.gdshaderinc"
// The water of the river's spring, falling down the cliff (see Waterfall): streaks of water running
// down at their own pace, white where it tumbles over a ledge and at the foot, and fading out at the
// sides and the top. In winter the same fall is frozen: the streaks stand still as ridges of
// pale blue ice, thick and glassy, with a few dark veins.
//
// UV.x runs across the sheet (0 to 1), UV.y down it in metres from the top, so the streaks keep
// their size whatever the length of the sheet.

#include "res://shaders/detail.gdshaderinc"

// 0 flowing, 1 frozen solid.
uniform float ice = 0.0;
uniform vec3 deep_color = vec3(0.36, 0.68, 0.82);
uniform vec3 foam_color = vec3(0.92, 0.97, 1.0);
uniform vec3 ice_color = vec3(0.62, 0.82, 0.94);
uniform vec3 ice_deep = vec3(0.3, 0.52, 0.7);
// How fast the water runs down (metres per second).
uniform float speed = 4.5;
// How many streaks side by side per metre of width.
uniform float streaks = 1.6;
// The width of the sheet in metres, to know how many streaks fit.
uniform float width = 5.0;
// Where along the sheet (metres from the top) a ledge breaks the fall into foam, and the length.
uniform float ledge_at = -1.0;
uniform float length_m = 10.0;
// Snow lying on the frozen fall's upper edge, 0 to 1.
uniform float snow = 0.0;
// A doorway broken through the frozen sheet at its foot (0 closed, 1 open; see SpringCave): the ice is
// gone from a jagged opening a little wider than the hero and just taller.
uniform float hole = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float across = UV.x * width;
	float down = UV.y;
	if (hole > 0.0) {
		float jag = vnoise(vec3(across * 3.0, down * 3.0, 31.0)) * 0.5;
		bool wide = abs(across - width * 0.5) < 0.95 + jag * 0.8;
		bool tall = down > length_m - 2.7 - jag * 0.9;
		if (wide && tall) {
			discard;
		}
	}
	// Running water: long streaks sliding down, two layers at different pace.
	float run = 1.0 - ice;
	float s1 = vnoise(vec3(across * streaks * 2.0, down * 0.35 - t * speed * 0.42 * run, 1.0));
	float s2 = vnoise(vec3(across * streaks * 5.0 + 4.0, down * 0.9 - t * speed * 0.9 * run, 7.0));
	float s3 = vnoise(vec3(across * streaks * 11.0 + 9.0, down * 2.2 - t * speed * run, 3.0));
	float body = 0.5 * s1 + 0.32 * s2 + 0.18 * s3;
	// Foam where the water is churned: below a ledge, down the heavy streaks, and at the foot.
	float foot = smoothstep(length_m - 1.6, length_m, down);
	float below = 0.0;
	if (ledge_at > 0.0) {
		below = exp(-abs(down - ledge_at - 0.2) * 1.8) * step(ledge_at - 0.5, down);
	}
	float fizz = vnoise(vec3(across * 9.0, down * 3.0 - t * 5.0 * run, 11.0));
	float foam = clamp(smoothstep(0.62, 0.9, body) * 0.7 + foot * (0.55 + 0.45 * fizz) + below * fizz, 0.0, 1.0);
	// Faded at the sides and the top, so the sheet has no hard edge.
	float side = smoothstep(0.0, 0.16, UV.x) * smoothstep(1.0, 0.84, UV.x);
	side *= 0.55 + 0.45 * smoothstep(0.0, 0.4, vnoise(vec3(down * 0.8, across * 0.3, 21.0)) + 0.35);
	float top = smoothstep(0.0, 0.9, down);

	vec3 water = mix(deep_color, foam_color, clamp(foam + 0.4 * body, 0.0, 1.0));
	float water_alpha = clamp((0.6 + 0.4 * body + 0.4 * foam) * side * top, 0.0, 0.95);

	// Ice: the same streaks, standing still, as ridges; darker veins between, a glassy sheen.
	float ridge = vnoise(vec3(across * streaks * 3.0, down * 0.28, 5.0));
	float vein = smoothstep(0.58, 0.64, vnoise(vec3(across * 7.0, down * 0.5, 13.0)));
	vec3 frozen = mix(ice_deep, ice_color, 0.35 + 0.65 * ridge);
	frozen = mix(frozen, foam_color, 0.5 * foam + 0.18 * vein);
	float ice_alpha = clamp((0.8 + 0.2 * ridge) * side * smoothstep(0.0, 0.5, down), 0.0, 0.97);

	ALBEDO = mix(water, frozen, ice);
	ALPHA = mix(water_alpha, ice_alpha, ice);
	float bumps = (ridge - 0.5) * 0.06 * ice;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(bumps), dFdy(bumps));
	ROUGHNESS = mix(0.35, 0.14, ice);
	SPECULAR = mix(0.35, 0.8, ice);
	EMISSION = mix(water * 0.22, frozen * 0.09, ice);
	// Snow along the top edge of the ice.
	float lid = (1.0 - smoothstep(0.0, 1.6, down)) * snow * ice;
	ALBEDO = mix(ALBEDO, vec3(0.93, 0.95, 0.99), lid);
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
