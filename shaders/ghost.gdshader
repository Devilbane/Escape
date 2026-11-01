shader_type spatial;
// A sneaking hero: any plain part (face, hair, trim, held gear) turns ash grey
// and see-through. Parts drawn with tint.gdshader use tint_fade.gdshader instead.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform vec4 color : source_color = vec4(1.0);
uniform float fade = 0.0;

void fragment() {
	vec4 c = color;
	if (use_tex) {
		c *= texture(tex, UV);
	}
	float light = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = vec3(0.22 + light * 0.7) * vec3(0.93, 0.96, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	ALPHA = (1.0 - fade) * c.a;
}
