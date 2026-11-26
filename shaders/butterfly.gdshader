shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
// A butterfly: a body and two wings painted on an atlas of four kinds (see InsectLife.wing_atlas). The
// instance's custom data holds the kind (x), the flap's phase (y), its speed in radians a second (z) and
// how far the wings open (w, 1 is a full beat). The wings are flapped here, so a hundred cost no more than one.
uniform sampler2D wings : filter_linear_mipmap_anisotropic, repeat_disable;

varying flat float kind;

void vertex() {
	kind = INSTANCE_CUSTOM.x;
	// Body vertices are green in the vertex colour and stay still.
	if (COLOR.g < 0.5) {
		float side = sign(VERTEX.x);
		float ax = abs(VERTEX.x);
		float angle = (0.15 + 0.85 * (0.5 + 0.5 * sin(TIME * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.y))) * 1.15 * INSTANCE_CUSTOM.w;
		// Lift the wings off the flat about the body's line and curve them a little.
		float lift = ax * sin(angle);
		VERTEX.x = side * ax * cos(angle);
		VERTEX.y += lift + ax * ax * 0.25 * sin(angle);
	}
}

void fragment() {
	vec2 uv = (UV + vec2(mod(kind, 2.0), floor(kind / 2.0))) * 0.5;
	vec4 tex = texture(wings, uv);
	bool body = COLOR.g > 0.5;
	float alpha = body ? 1.0 : tex.a;
	if (alpha < 0.5) {
		discard;
	}
	vec3 col = body ? vec3(0.1, 0.07, 0.05) : tex.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	EMISSION = col * 0.18;
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
