shader_type spatial;
render_mode depth_draw_always;
#include "res://shaders/gl_colour.gdshaderinc"
// A sneaking hero: any plain part (face, hair, trim, held gear) turns ash grey
// and see-through. Parts drawn with tint.gdshader use tint_fade.gdshader instead.
// depth_draw_always (here, in hair_fade and tint_fade): only the hero's front surface takes
// the light of each lamp. Without it every layer behind (the back of the head, the body
// under the cape) adds that light again, and the hero glares white near lamps.

uniform sampler2D tex : filter_linear_mipmap_anisotropic;
uniform bool use_tex = false;
uniform vec4 color = vec4(1.0);
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
	ALBEDO = gl_colour(ALBEDO);
}
