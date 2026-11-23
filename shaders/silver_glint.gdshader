shader_type spatial;
// Raw silver in the old mine: bright metal that glimmers now and then. Every piece has its
// own rhythm (from where it lies), so the ore twinkles one fleck at a time, not all at once.

uniform vec3 silver : source_color = vec3(0.82, 0.85, 0.9);
uniform float glimmer = 2.2;

void fragment() {
	ALBEDO = silver;
	METALLIC = 0.95;
	ROUGHNESS = 0.22;
	vec3 where = MODEL_MATRIX[3].xyz;
	float phase = dot(where, vec3(12.9, 7.3, 9.1));
	float tick = sin(TIME * 1.6 + phase);
	float flash = pow(max(tick, 0.0), 14.0);
	EMISSION = silver * (0.18 + glimmer * flash);
}
