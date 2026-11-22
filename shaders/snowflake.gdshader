shader_type spatial;
// The falling snowflakes (see Weather.make_snow). A flake shows only as much as light reaches it:
// it gives no light of its own and is drawn added onto what lies behind it, so an unlit flake is
// invisible rather than a dark speck. By day the sun and the sky light every flake; at night only
// the moon (as bright as tonight's phase, so a thin crescent leaves the flakes barely there), the
// lamps, torches, lit windows and the hero's lantern do, each on the flakes near it.
// No flake falls inside a house, nor over what lies in one (see indoors.gdshaderinc).
render_mode blend_add, depth_draw_never, cull_disabled, specular_disabled;

#include "res://shaders/indoors.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.92, 0.94, 1.0, 0.9);
uniform sampler2D dot_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

void vertex() {
	// Faces the camera, keeping each particle's own scale and spin (as BILLBOARD_PARTICLES does).
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	world_pos = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	if (indoors(world_pos) || indoors(indoor_surface(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX))) {
		discard;
	}
	vec4 tex = texture(dot_tex, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ALPHA = albedo.a * tex.a;
}

void light() {
	// A flake is lit from whichever side the light comes (it tumbles, and light shines through
	// it), so the light's angle to the quad does not matter, only how much of it arrives.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION / PI;
}
