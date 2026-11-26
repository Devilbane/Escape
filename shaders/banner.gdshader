shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
// A lettered banner that flutters in the wind (see ChapelPenguin and FlagWind).
// Seen from behind, the letters are turned round so they still read.

#include "res://shaders/flutter.gdshaderinc"

uniform sampler2D banner_tex : filter_linear_mipmap_anisotropic, hint_default_white;

void vertex() {
	flutter_vertex(VERTEX, NORMAL, TANGENT, dot(NODE_POSITION_WORLD, vec3(0.37, 0.0, 0.61)));
}

void fragment() {
	vec2 uv = UV;
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
		NORMAL = -NORMAL;
	}
	vec4 c = texture(banner_tex, uv);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.9;
	ALBEDO = gl_colour(ALBEDO);
}
