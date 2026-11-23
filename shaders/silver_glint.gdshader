shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// Raw silver in the old mine: bright metal that glimmers now and then. Every piece has its
// own rhythm (from where it lies), so the ore twinkles one fleck at a time, not all at once.

uniform vec3 silver = vec3(0.6, 0.63, 0.68);
uniform float glimmer = 1.4;

void fragment() {
	ALBEDO = silver;
	METALLIC = 0.95;
	ROUGHNESS = 0.35;
	vec3 where = MODEL_MATRIX[3].xyz;
	float phase = dot(where, vec3(12.9, 7.3, 9.1));
	float tick = sin(TIME * 1.6 + phase);
	float flash = pow(max(tick, 0.0), 24.0);
	EMISSION = silver * (0.03 + glimmer * flash);
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
