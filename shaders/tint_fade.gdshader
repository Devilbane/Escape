shader_type spatial;
// Recolours a textured part of the hero (cloak, armour, shoes): keeps the
// light and dark of the texture but swaps its colour for the tint. This
// version fades the part, for a sneaking hero.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float metal = 0.0;

uniform float fade = 0.0;

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float light = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = tint * (0.45 + light * 1.4);
	METALLIC = metal;
	ROUGHNESS = 1.0 - metal * 0.6;
	ALPHA = 1.0 - fade;
}
