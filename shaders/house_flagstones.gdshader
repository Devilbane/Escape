shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// The stone floors of the player's houses (see HouseLooks.flagstones): the
// same paving as the village square round the smith's forge, laid in world
// space so the stones run on from one floor tile to the next without a seam.
// The edges of a floor are drawn from the side the face looks to.

#include "res://shaders/detail.gdshaderinc"
#include "res://shaders/cobbles.gdshaderinc"

uniform vec3 paving = vec3(0.50, 0.47, 0.43);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = world_pos.xz;
	if (n.x > n.y && n.x > n.z) {
		p = world_pos.zy;
	} else if (n.z > n.y) {
		p = world_pos.xy;
	}
	float px = length(fwidth(world_pos));
	float h;
	vec3 col = cobbles(p, px, 0.0, paving, h);
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
	ALBEDO = gl_colour(ALBEDO);
}
