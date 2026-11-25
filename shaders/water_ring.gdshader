shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
// A ring of ripples spreading over the water where a fish stirs just below the surface (see IceFish):
// two thin rings that widen and fade as the ring ages. INSTANCE_CUSTOM.x is the ring's age, 0 to 1.

uniform vec3 ring_color = vec3(0.82, 0.92, 0.95);
uniform float strength = 0.26;

varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.x;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float r = age * 0.92;
	float outer = smoothstep(0.034, 0.0, abs(d - r));
	float inner = smoothstep(0.026, 0.0, abs(d - r * 0.62)) * 0.6;
	float fading = pow(clamp(1.0 - age, 0.0, 1.0), 1.4);
	ALPHA = (outer + inner) * fading * strength * smoothstep(1.0, 0.85, d) * step(age, 0.999);
	ALBEDO = ring_color;
	ALBEDO = gl_colour(ALBEDO);
}
