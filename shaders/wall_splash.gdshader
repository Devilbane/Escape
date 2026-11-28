shader_type spatial;
// A raindrop's splash on the rock (see WallRain): a small soft ring that spreads and fades (the particle's colour alpha).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(0.85, 0.9, 1.0, 0.6);

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.35, 0.7, r) * (1.0 - smoothstep(0.7, 1.0, r));
	ALBEDO = tint.rgb;
	ALPHA = ring * tint.a * COLOR.a;
}
