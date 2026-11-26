shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// The ground round a cellar as the hero sees it from down there (see CellarView):
// not the grass of the surface but the earth the cellar is dug into, as if cut open.
// Packed soil from BareEarth's picture (laid twice, turned, so it never tiles), with
// grey rock showing through in lumps and seams, a band of darker, damper soil along
// the cellar's rim, and the whole fading into darkness away from the cellar.
// It lies under the ground, out of the sun: no shadows fall on it (the house's storeys above,
// faded while the hero is down here, cast none across it).
render_mode shadows_disabled;

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D soil : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float size_a = 1.6;
uniform float size_b = 2.47;
uniform float turn_b = 0.83;
uniform vec2 shift_b = vec2(0.37, 0.71);
// The cellar's outline (x, z of its corners): the earth darkens away from it.
uniform vec2 pit_min = vec2(0.0);
uniform vec2 pit_max = vec2(0.0);
// Metres from the cellar where the darkness is complete.
uniform float dark_reach = 15.0;
uniform vec3 rock_colour = vec3(0.3, 0.28, 0.26);
uniform float bump = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;
	float mixing = smoothstep(0.38, 0.62, fbm(vec3(uv / 3.1, 0.5)));
	vec2 a = uv / size_a;
	float c = cos(turn_b);
	float s = sin(turn_b);
	vec2 b = mat2(vec2(c, s), vec2(-s, c)) * uv / size_b + shift_b;
	vec3 colour = mix(texture(soil, a).rgb, texture(soil, b).rgb, mixing);
	vec2 tilt = mix(texture(soil_normal, a).xy * 2.0 - 1.0, mat2(vec2(c, -s), vec2(s, c)) * (texture(soil_normal, b).xy * 2.0 - 1.0), mixing);
	// Deeper down the soil is packed and darker than the cellar floor.
	colour *= 0.78;
	// Layers of clay and darker loam in broad bands that wander.
	float layer = fbm(vec3(uv * 0.11, 7.3));
	colour = mix(colour, colour * vec3(1.12, 0.92, 0.78), smoothstep(0.55, 0.75, layer) * 0.5);
	colour = mix(colour, colour * 0.7, smoothstep(0.45, 0.25, layer) * 0.5);
	// Rock: lumps and seams of grey stone in the earth, with a dark rim where they meet the soil.
	float r = fbm(vec3(uv * 0.42, 2.1)) + fbm(vec3(uv * 1.7, 4.4)) * 0.18;
	float rock = smoothstep(0.74, 0.77, r);
	float rim = smoothstep(0.69, 0.74, r) * (1.0 - rock);
	// Each rock's face is broken: lighter edges where it catches the light, cracks across it.
	float grain = fbm(vec3(uv * 3.5, 1.0));
	vec3 stone = rock_colour * (0.7 + grain * 0.5) * mix(1.0, 0.6, smoothstep(0.55, 0.6, fbm(vec3(uv * 6.0, 9.0))));
	colour = mix(colour * (1.0 - rim * 0.45), stone, rock);
	// Distance from the cellar's outline: near it the light from the opening reaches, further
	// out the earth sinks into darkness, so nothing of the surface seems to lie beyond.
	vec2 out_by = max(max(pit_min - uv, uv - pit_max), vec2(0.0));
	float away = length(out_by);
	colour *= mix(1.0, 0.05, smoothstep(1.0, dark_reach, away));
	// A damp band right along the rim.
	colour *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 1.2, away));
	ALBEDO = colour;
	ROUGHNESS = mix(0.95, 0.7, rock);
	vec3 bent = normalize(vec3(0.0, 1.0, 0.0) + vec3(tilt.x, 0.0, tilt.y) * bump * relief_strength * (1.0 - rock * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ALBEDO = gl_colour(ALBEDO);
}
