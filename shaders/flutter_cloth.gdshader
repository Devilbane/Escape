shader_type spatial;
// Plain cloth that flutters in the wind (see FlagWind): the banners of the
// dragon's lair, which keep the colours and texture of their own model (a
// copy of its StandardMaterial3D's look) and only gain the flutter.

#include "res://shaders/flutter.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;

void vertex() {
	flutter_vertex(VERTEX, NORMAL, TANGENT, dot(NODE_POSITION_WORLD, vec3(0.37, 0.0, 0.61)));
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
