shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// The weather that drifts or falls around the hero: rain streaks, patches of mist and autumn
// leaves (see Weather.make_rain, make_mist and LeafFall). Unlit and see-through, like the plain
// material they had before, but they leave out every spot inside a house (see indoors.gdshaderinc):
// a streak or patch that is itself in there, and anything drawn over a surface that is in there,
// so the room stays clear while the weather goes on outside.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://shaders/indoors.gdshaderinc"

uniform vec4 albedo = vec4(1.0);
uniform sampler2D texture_albedo : filter_linear_mipmap_anisotropic, hint_default_white;
// 0 as placed, 1 facing the camera (particles: with their own size and spin), 2 upright facing it.
uniform int billboard = 0;
uniform bool use_vertex_color = false;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;

void vertex() {
	if (billboard == 1) {
		// As BILLBOARD_PARTICLES with keep scale: a particle that has not started yet has no
		// size and draws nothing (without its scale it showed as a big black patch, see Weather).
		mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
				vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),
				vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * world;
	} else if (billboard == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
				vec4(0.0, 1.0, 0.0, 0.0),
				vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	}
	if (billboard != 0) {
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	world_pos = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	if (indoors(world_pos) || indoors(indoor_surface(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX))) {
		discard;
	}
	vec4 c = albedo * texture(texture_albedo, UV);
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALBEDO = gl_colour(ALBEDO);
}
