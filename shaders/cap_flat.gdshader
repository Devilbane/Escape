shader_type spatial;
// The flat, matt tops and outer sides of the walls (see WallCaps): the same look as a plain
// material. A cap in front of the hero fades with its wall (WallFade) and, near or far, opens in the
// see-through circle around the hero (reveal.gdshaderinc), so a wall top never hides the hero.

#include "res://shaders/reveal.gdshaderinc"

uniform vec3 albedo_color : source_color = vec3(0.33, 0.31, 0.29);
instance uniform float fade = 0.0;

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (fade > 0.0) {
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(bayer[q.y * 4 + q.x]) + 0.5) / 16.0 < fade) {
			discard;
		}
	}
	if (reveal_cut(VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
}
