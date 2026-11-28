shader_type spatial;
// Priestess Elsbeth's rain shield (see RainShield): a see-through, light blue umbrella of magic that
// hovers above her head. A soft rim where the dome turns away, thin ribs running from the tip to each
// scallop of the edge, and a slow shimmer that drifts over the cloth. One cheap unlit surface.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
// 0 to 1: how much of the shield is there (the cast swells it in, the end of the rain fades it).
uniform float fade = 1.0;
uniform float ribs = 8.0;
uniform float body_alpha = 0.16;
uniform float rim_alpha = 0.5;
uniform float shimmer_speed = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// UV.x runs round the dome (0 to 1), UV.y from the tip (0) to the edge (1).
	float view = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - view, 2.2);
	float rib = smoothstep(0.93, 1.0, abs(fract(UV.x * ribs) - 0.5) * 2.0) * (0.35 + 0.65 * UV.y);
	float edge = smoothstep(0.9, 1.0, UV.y);
	vec2 p = vec2(UV.x * 6.0 + TIME * shimmer_speed, UV.y * 3.0 - TIME * shimmer_speed * 0.6);
	float glint = smoothstep(0.62, 0.95, vnoise(p * 2.0) * 0.6 + vnoise(p * 5.0 + 7.0) * 0.4);
	float a = body_alpha + rim * rim_alpha + rib * 0.28 + edge * 0.3 + glint * 0.22;
	vec3 col = tint.rgb + vec3(0.25) * (rib + glint + edge * 0.6);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.85) * fade;
}
