shader_type spatial;
// The village's birds (see VillageBirds), all in one MultiMesh. The wings
// beat in the vertex shader: COLOR.a of a vertex is how far out on a wing it
// sits (0 on the body, 1 at the tip, the sign says which wing), and each
// bird's INSTANCE_CUSTOM holds the beat's phase (x), how wide it swings (y)
// and how the wings rest between beats (z: 0 spread out, 1 folded down).
render_mode cull_disabled;

uniform float beats = 16.0;

void vertex() {
	float out_on_wing = abs(COLOR.a * 2.0 - 1.0);
	float side = sign(COLOR.a - 0.5);
	if (out_on_wing > 0.01) {
		float angle = sin(TIME * beats + INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y - INSTANCE_CUSTOM.z * 1.25;
		// Turn the wing about the body's long axis (z), the tip furthest.
		float c = cos(angle * side);
		float s = sin(angle * side);
		vec2 xy = VERTEX.xy;
		VERTEX.x = xy.x * c - xy.y * s;
		VERTEX.y = xy.x * s + xy.y * c;
		// Folded wings lie close along the body.
		VERTEX.x *= 1.0 - INSTANCE_CUSTOM.z * 0.6;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}
