shader_type canvas_item;
// The cloud sea at the foot of the view (see WallStage): once a climber is so high that the ground has left the
// screen, a bank of cloud fills the bottom of it, thick at the very bottom and thinning out upwards in soft,
// slowly drifting billows (noise over the screen, a few layers moving at different speeds). One cheap pass.
#include "res://shaders/detail.gdshaderinc"

// 0 = nothing, 1 = the whole band.
uniform float density = 0.0;
uniform vec3 haze = vec3(0.88, 0.9, 0.94);

void fragment() {
	// 0 at the top edge of the band, 1 at the bottom of the screen.
	float down = UV.y;
	vec2 p = vec2(UV.x * 5.0, down * 2.2);
	float slow = fbm(vec3(p * 0.9 + vec2(TIME * 0.03, 0.0), 1.0));
	float quick = fbm(vec3(p * 1.8 + vec2(TIME * 0.07, 3.0), 7.0));
	// Where the bank's upper edge lies: ragged, between 0.25 and 0.7 of the band's height.
	float edge = 0.28 + slow * 0.45;
	float body = smoothstep(edge, edge + 0.3, down + (quick - 0.5) * 0.35);
	vec3 col = mix(haze * 0.8, haze, smoothstep(0.3, 0.9, quick));
	COLOR = vec4(col, clamp(body * density, 0.0, 0.96));
}
