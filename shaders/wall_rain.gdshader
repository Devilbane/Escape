shader_type spatial;
// A raindrop as a thin, soft-edged streak (see WallRain): brightest in the middle, fading at the head and tail and at
// both sides, fainter the farther it is and gone when it is right at the camera (so no hard, fat bar ever crosses the
// screen).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(0.8, 0.86, 0.95, 0.5);
varying float depth;

void vertex() {
	depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float side = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float fade = smoothstep(1.5, 4.0, depth) * mix(1.0, 0.25, smoothstep(8.0, 45.0, depth));
	ALBEDO = tint.rgb;
	ALPHA = side * side * along * tint.a * fade;
}
