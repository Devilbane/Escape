shader_type spatial;
// The village's birds (see VillageBirds), all in one MultiMesh. The wings
// beat in the vertex shader: COLOR.a of a vertex is how far out on a wing it
// sits (0 on the body, 1 at the tip, the sign says which wing), and each
// bird's INSTANCE_CUSTOM holds the beat's phase (x), how wide it swings (y),
// how the wings rest between beats (z: 0 spread out, 1 folded) and its
// kind (w: (kind + 0.5) / KINDS). COLOR.r says which part of the bird a
// vertex is (0 back, 0.25 breast, 0.5 wings and tail, 0.75 head, 1 beak),
// and the kind's colours below paint it. (The MultiMesh has instance
// colours, all white: without them the compatibility renderer hands the
// vertex shader a COLOR of zero.)
render_mode cull_disabled;

uniform float beats = 16.0;

const int KINDS = 7;
// Per kind: back, breast, wings, head, beak (sRGB).
const vec3 PLUMAGE[35] = vec3[](
	// Robin: brown, with an orange face and breast.
	vec3(0.45, 0.33, 0.2), vec3(0.97, 0.45, 0.12), vec3(0.38, 0.27, 0.16), vec3(0.95, 0.42, 0.12), vec3(0.15, 0.12, 0.1),
	// Blue tit: green back, yellow breast, blue wings and cap.
	vec3(0.5, 0.65, 0.3), vec3(1.0, 0.86, 0.15), vec3(0.2, 0.45, 0.92), vec3(0.15, 0.4, 0.95), vec3(0.12, 0.12, 0.14),
	// Goldfinch: buff, golden wings, a red face.
	vec3(0.65, 0.5, 0.32), vec3(0.97, 0.9, 0.75), vec3(0.98, 0.8, 0.05), vec3(0.92, 0.1, 0.1), vec3(0.96, 0.86, 0.75),
	// Kingfisher: turquoise above, orange below.
	vec3(0.05, 0.7, 0.85), vec3(0.98, 0.5, 0.12), vec3(0.06, 0.45, 0.8), vec3(0.08, 0.58, 0.85), vec3(0.1, 0.1, 0.1),
	// Bullfinch: grey, a rosy breast, black cap and wings.
	vec3(0.5, 0.5, 0.56), vec3(0.96, 0.36, 0.42), vec3(0.12, 0.12, 0.15), vec3(0.09, 0.09, 0.11), vec3(0.12, 0.12, 0.12),
	// Oriole: bright yellow with black wings.
	vec3(1.0, 0.82, 0.08), vec3(1.0, 0.9, 0.25), vec3(0.14, 0.12, 0.1), vec3(1.0, 0.85, 0.1), vec3(0.95, 0.55, 0.5),
	// Green finch: green with a red head.
	vec3(0.3, 0.75, 0.2), vec3(0.78, 0.92, 0.32), vec3(0.14, 0.55, 0.22), vec3(0.92, 0.2, 0.15), vec3(0.97, 0.72, 0.2)
);

void vertex() {
	int kind = clamp(int(INSTANCE_CUSTOM.w * float(KINDS)), 0, KINDS - 1);
	int part = clamp(int(round(COLOR.r * 4.0)), 0, 4);
	vec3 paint = PLUMAGE[kind * 5 + part];
	float out_on_wing = abs(COLOR.a * 2.0 - 1.0);
	float side = sign(COLOR.a - 0.5);
	if (out_on_wing > 0.01) {
		float angle = sin(TIME * beats + INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y - INSTANCE_CUSTOM.z * 0.3;
		// Turn the wing about the body's long axis (z), the tip furthest.
		float c = cos(angle * side);
		float s = sin(angle * side);
		vec2 xy = VERTEX.xy;
		VERTEX.x = xy.x * c - xy.y * s;
		VERTEX.y = xy.x * s + xy.y * c;
		// Folded wings lie close along the body, drooping a little.
		VERTEX.x *= 1.0 - INSTANCE_CUSTOM.z * 0.75;
		// The wing tips a shade darker.
		paint *= 1.0 - out_on_wing * 0.3;
	}
	// The colours are picked in sRGB; light works in linear.
	COLOR.rgb = pow(paint, vec3(2.2));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.7;
}
